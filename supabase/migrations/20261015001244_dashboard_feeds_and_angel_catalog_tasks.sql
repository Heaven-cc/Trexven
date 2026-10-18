-- Authorized dashboard/calendar repair and owner-confirmed Angel catalog tasks.
-- Filename aligned with the verified production migration identity.
-- No historical sale timestamps or existing product values are rewritten.
create function private.initialize_trexven_business_timezone() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if new.timezone is null and lower(btrim(new.country)) in ('nigeria','ng') then
  new.timezone := 'Africa/Lagos';
 end if;
 return new;
end $$;
revoke all on function private.initialize_trexven_business_timezone() from public,anon,authenticated;
create trigger initialize_trexven_business_timezone before insert or update of country,timezone
on public.businesses for each row execute function private.initialize_trexven_business_timezone();

-- Older installed clients include this optional display field in their projection.
alter table public.alerts add column if not exists camera_name text;

create table private.angel_catalog_actions (
 id uuid primary key default gen_random_uuid(),
 business_id uuid not null references public.businesses(id),
 actor_id uuid not null references auth.users(id),
 conversation_id uuid not null references public.angel_conversations(id) on delete cascade,
 product_id uuid not null references public.products(id),
 operation text not null check(operation in ('price','stock_set','stock_adjust')),
 value numeric not null, before_value numeric, after_value numeric not null,
 product_name text not null, sku text, unit text,
 reason text not null, source_message text not null,
 status text not null default 'pending' check(status in ('pending','completed','cancelled','expired','conflict')),
 receipt jsonb,
 created_at timestamptz not null default now(),
 expires_at timestamptz not null default now()+interval '10 minutes'
);
alter table private.angel_catalog_actions enable row level security;
revoke all on private.angel_catalog_actions from public,anon,authenticated;
create index angel_catalog_actions_conversation on private.angel_catalog_actions(conversation_id,created_at desc);

create function private.angel_catalog_owner(business uuid,conversation uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform id from public.businesses where id=business for share;
 if auth.uid() is null or not public.user_owns_business(business) then
  raise exception 'Angel tasks require an active business owner' using errcode='42501';
 end if;
 if not exists(select 1 from public.angel_conversations
  where id=conversation and business_id=business and user_id=auth.uid()) then
  raise exception 'Conversation access denied' using errcode='42501';
 end if;
end $$;
revoke all on function private.angel_catalog_owner(uuid,uuid) from public,anon,authenticated;

create function private.angel_catalog_receipt(a private.angel_catalog_actions) returns jsonb
language sql stable set search_path='' as $$
 select jsonb_build_object('id',a.id,'status',a.status,'operation',a.operation,
  'product_id',a.product_id,'product_name',a.product_name,'sku',a.sku,'unit',a.unit,
  'before_value',a.before_value::text,'after_value',a.after_value::text,
  'reason',a.reason,'expires_at',a.expires_at,'verified',a.status='completed')
$$;
revoke all on function private.angel_catalog_receipt(private.angel_catalog_actions) from public,anon,authenticated;

create function public.prepare_trexven_angel_catalog_action(
 p_business_id uuid,p_conversation_id uuid,p_product_query text,p_operation text,
 p_value numeric,p_reason text,p_source_message text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare ids uuid[]; p public.products%rowtype; a private.angel_catalog_actions%rowtype;
 previous numeric; target numeric; matches jsonb;
begin
 perform private.angel_catalog_owner(p_business_id,p_conversation_id);
 perform pg_advisory_xact_lock(hashtextextended(p_conversation_id::text||':angel',0));
 if p_operation is null or p_operation not in ('price','stock_set','stock_adjust')
 or p_value is null or p_value::text in ('NaN','Infinity','-Infinity')
 or nullif(btrim(p_product_query),'') is null or length(p_product_query)>200
 or nullif(btrim(p_reason),'') is null or length(p_reason)>500
 or nullif(btrim(p_source_message),'') is null or length(p_source_message)>5000 then
  raise exception 'Provide a product, valid value and reason';
 end if;
 if (p_operation='price' and (p_value<0 or scale(p_value)>2))
 or (p_operation<>'price' and scale(p_value)>3)
 or (p_operation='stock_set' and p_value<0) then raise exception 'Invalid price or stock quantity';end if;
 update private.angel_catalog_actions set status='cancelled'
 where conversation_id=p_conversation_id and actor_id=auth.uid() and status='pending';
 if p_product_query ~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' then
  select array_agg(id) into ids from public.products where business_id=p_business_id and id=p_product_query::uuid;
 else
  select array_agg(id) into ids from public.products where business_id=p_business_id
   and (lower(btrim(name))=lower(btrim(p_product_query))
    or lower(btrim(sku))=lower(btrim(p_product_query)) or barcode=btrim(p_product_query));
 end if;
 if coalesce(cardinality(ids),0)<>1 then
  select coalesce(jsonb_agg(to_jsonb(m)),'[]'::jsonb) into matches from (
   select id,name,sku,barcode,unit from public.products where business_id=p_business_id
    and (id=any(ids) or position(lower(btrim(p_product_query)) in lower(name))>0)
   order by name,id limit 8) m;
  return jsonb_build_object('status',case when coalesce(cardinality(ids),0)>1 then 'ambiguous' else 'not_found' end,'matches',matches);
 end if;
 select * into p from public.products where id=ids[1] and business_id=p_business_id for share;
 if not found then raise exception 'Product is no longer available';end if;
 previous:=case when p_operation='price' then p.selling_price else coalesce(p.quantity,0) end;
 target:=case when p_operation='stock_adjust' then previous+p_value else p_value end;
 if target<0 then raise exception 'Insufficient stock for adjustment';end if;
 if p_operation<>'price' and lower(btrim(coalesce(p.unit,'piece'))) not in ('kg','g','litre','ml','metre','cm')
 and target<>trunc(target) then raise exception 'Countable units require whole quantities';end if;
 if target is not distinct from previous then return jsonb_build_object('status','unchanged','product_name',p.name,'after_value',target::text);end if;
 -- Check the same catalog permissions/workflow before offering confirmation.
 perform private.catalog_context(p_business_id,case when p_operation='price' then 'edit_products' else 'adjust_stock' end);
 insert into private.angel_catalog_actions(business_id,actor_id,conversation_id,product_id,
  operation,value,before_value,after_value,product_name,sku,unit,reason,source_message)
 values(p_business_id,auth.uid(),p_conversation_id,p.id,p_operation,p_value,previous,target,
  p.name,p.sku,p.unit,btrim(p_reason),p_source_message) returning * into a;
 return private.angel_catalog_receipt(a);
end $$;
revoke all on function public.prepare_trexven_angel_catalog_action(uuid,uuid,text,text,numeric,text,text) from public,anon;
grant execute on function public.prepare_trexven_angel_catalog_action(uuid,uuid,text,text,numeric,text,text) to authenticated;

create function public.resolve_trexven_angel_catalog_action(
 p_business_id uuid,p_conversation_id uuid,p_action_id uuid,p_confirm boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare a private.angel_catalog_actions%rowtype; p public.products%rowtype; actual numeric;
begin
 perform private.angel_catalog_owner(p_business_id,p_conversation_id);
 perform pg_advisory_xact_lock(hashtextextended(p_conversation_id::text||':angel',0));
 select * into a from private.angel_catalog_actions where id=p_action_id
  and business_id=p_business_id and conversation_id=p_conversation_id and actor_id=auth.uid() for update;
 if not found then raise exception 'Action access denied' using errcode='42501';end if;
 if p_confirm is null then raise exception 'Explicit confirmation is required';end if;
 if a.status='completed' then return a.receipt||jsonb_build_object('replayed',true);end if;
 if a.status<>'pending' then return private.angel_catalog_receipt(a);end if;
 if not p_confirm then
  update private.angel_catalog_actions set status='cancelled' where id=a.id returning * into a;
  return private.angel_catalog_receipt(a);
 end if;
 if a.expires_at<=now() then
  update private.angel_catalog_actions set status='expired' where id=a.id returning * into a;
  return private.angel_catalog_receipt(a);
 end if;
 select * into p from public.products where id=a.product_id and business_id=p_business_id for update;
 if not found then raise exception 'Product is no longer available';end if;
 actual:=case when a.operation='price' then p.selling_price else coalesce(p.quantity,0) end;
 if actual is distinct from a.before_value or p.name is distinct from a.product_name
  or p.sku is distinct from a.sku or p.unit is distinct from a.unit then
  update private.angel_catalog_actions set status='conflict' where id=a.id returning * into a;
  return private.angel_catalog_receipt(a);
 end if;
 if a.operation='price' then
  perform public.save_trexven_catalog_product(p_business_id,a.id,a.product_id,jsonb_build_object('selling_price',a.after_value));
 else
  perform public.adjust_trexven_catalog_stock(p_business_id,a.product_id,a.after_value-coalesce(p.quantity,0),a.reason,a.id);
 end if;
 select case when a.operation='price' then selling_price else quantity end into actual
 from public.products where id=a.product_id and business_id=p_business_id;
 if actual is distinct from a.after_value then raise exception 'Saved value verification failed';end if;
 update private.angel_catalog_actions set status='completed' where id=a.id returning * into a;
 a.receipt:=private.angel_catalog_receipt(a);
 update private.angel_catalog_actions set receipt=a.receipt where id=a.id;
 insert into public.audit_logs(business_id,actor_id,action,metadata)
 values(p_business_id,auth.uid(),'angel_catalog_action_completed',a.receipt);
 return a.receipt;
end $$;
revoke all on function public.resolve_trexven_angel_catalog_action(uuid,uuid,uuid,boolean) from public,anon;
grant execute on function public.resolve_trexven_angel_catalog_action(uuid,uuid,uuid,boolean) to authenticated;
