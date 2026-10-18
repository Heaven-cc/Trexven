begin;
create function public.get_trexven_operation_receipt(p_business_id uuid,p_request_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if not public.is_business_member(p_business_id) then raise exception 'Current business membership required' using errcode='42501';end if;
 select response into result from private.catalog_requests where request_id=p_request_id and business_id=p_business_id and actor_id=auth.uid();
 return result;
end $$;
revoke all on function public.get_trexven_operation_receipt(uuid,uuid) from public,anon;grant execute on function public.get_trexven_operation_receipt(uuid,uuid) to authenticated;
create function private.subscription_read_feature(business uuid,feature text) returns boolean language sql stable security definer set search_path='' as $$
 select public.is_business_member(business) and private.subscription_entitled(business,feature)
$$;
revoke all on function private.subscription_read_feature(uuid,text) from public,anon;grant execute on function private.subscription_read_feature(uuid,text) to authenticated;
create policy "Subscription detailed log boundary" on public.audit_logs as restrictive for select to authenticated using(private.subscription_read_feature(business_id,'detailed_activity_logs'));
create function private.subscription_cash_open() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if not private.subscription_entitled(new.business_id,'pos') then raise exception 'POS subscription required to open a new cash drawer';end if;return new;
end $$;
revoke all on function private.subscription_cash_open() from public,anon,authenticated;
create trigger batch_7_new_shift_entitlement before insert on public.cash_shifts for each row execute function private.subscription_cash_open();
do $$ begin
 if exists(select 1 from pg_publication where pubname='supabase_realtime') and not exists(select 1 from pg_publication_tables where pubname='supabase_realtime' and schemaname='public' and tablename='business_subscriptions') then
  alter publication supabase_realtime add table public.business_subscriptions;
 end if;
end $$;
create or replace function private.catalog_stock_events() returns trigger
language plpgsql security definer set search_path='' as $$
declare before_qty numeric:=0; member uuid; below boolean; was_below boolean; reason text; request uuid; kind text;
begin
 if auth.uid() is null then return new; end if;
 if tg_op='UPDATE' then before_qty:=coalesce(old.quantity,0); end if;
 if coalesce(new.quantity,0)<>before_qty then
  select id into member from public.business_members where business_id=new.business_id and user_id=auth.uid();
  reason:=nullif(current_setting('trexven.catalog_reason',true),'');request:=nullif(current_setting('trexven.catalog_request',true),'')::uuid;
  kind:=case when current_setting('trexven.catalog_operation',true)='sale' then 'sale' else 'adjustment' end;
  insert into public.inventory_movements(business_id,product_id,employee_id,movement_type,quantity,previous_quantity,new_quantity,reference_id,reason,source)
   values(new.business_id,new.id,member,kind,new.quantity-before_qty,before_qty,new.quantity,request,coalesce(reason,'Confirmed checkout stock deduction'),'catalog');
 end if;
 -- Suppress the intermediate zero stock of atomic import creation.
 if current_setting('trexven.catalog_import',true)='creating' then return new; end if;
 below:=private.subscription_entitled(new.business_id,'low_stock_alerts') and new.active is true and new.is_active is true and new.selling_price is not null and coalesce(new.quantity,0)<=coalesce(new.low_stock_threshold,0);
 select below_threshold into was_below from private.catalog_low_stock_state where product_id=new.id;
 if below and coalesce(was_below,false)=false then
  insert into public.alerts(business_id,alert_type,title,message,severity,source,reference_id)
  values(new.business_id,'low_stock','Low stock',new.name||' has '||coalesce(new.quantity,0)||' '||coalesce(new.unit,'piece')||' available',case when coalesce(new.quantity,0)=0 then 'high' else 'warning' end,'inventory',new.id);
 end if;
 insert into private.catalog_low_stock_state values(new.id,new.business_id,below)
 on conflict(product_id)do update set below_threshold=excluded.below_threshold;
 return new;
end $$;
commit;
