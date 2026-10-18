-- Dormant branches; online-only counts. Existing products remain the stock source.
begin;
insert into public.permissions(id,description) values
 ('stocktake','Participate in online stocktaking'),('approve_stocktake','Explicit manager stocktake reconciliation'),
 ('dispose_stock','Classify damaged, expired or lost stock'),('restore_stock','Explicit inspected stock restoration'),
 ('writeoff_stock','Explicit nonsellable stock write-off') on conflict(id) do nothing;
create table public.stocktake_sessions(
 id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),
 branch_id uuid references public.branches(id),name text not null,created_by uuid not null references auth.users(id),
 status text not null default 'open' check(status in('open','review','closed','cancelled')),
 created_at timestamptz not null default now(),closed_at timestamptz,approved_by uuid references auth.users(id),reason text);
create unique index stocktake_one_active on public.stocktake_sessions(business_id,branch_id) nulls not distinct where status in('open','review');
create table public.stocktake_counts(
 id uuid primary key default gen_random_uuid(),session_id uuid not null references public.stocktake_sessions(id),
 product_id uuid not null references public.products(id),counted_by uuid references auth.users(id),
 counted numeric(18,3),expected_at_count numeric(18,3),version integer not null default 0,
 counted_at timestamptz,applied_delta numeric(18,3),stock_after numeric(18,3),unique(session_id,product_id));
create index stocktake_counts_product on public.stocktake_counts(product_id);
create table public.stock_condition_entries(
 id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),product_id uuid not null references public.products(id),
 condition text not null check(condition in('damaged','expired','defective')),quantity numeric(18,3) not null,
 kind text not null check(kind in('classify','customer_return','restore','writeoff','supplier_dispatch','supplier_restore')),
 request_id uuid not null,actor_id uuid not null references auth.users(id),reason text not null,created_at timestamptz not null default now(),unique(request_id,product_id,condition));
create index stock_condition_balance on public.stock_condition_entries(business_id,product_id,condition);
create table public.inventory_reconciliation_reviews(
 id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),session_id uuid not null references public.stocktake_sessions(id),
 sale_id uuid not null references public.sales(id),product_id uuid not null references public.products(id),quantity numeric(18,3) not null,
 status text not null default 'pending' check(status in('pending','resolved')),reason text,reviewed_by uuid references auth.users(id),reviewed_at timestamptz,
 unique(session_id,sale_id,product_id));
do $$ declare t text;begin
 foreach t in array array['stocktake_sessions','stocktake_counts','stock_condition_entries','inventory_reconciliation_reviews'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on public.%I from public,anon,authenticated',t);
  execute format('grant select on public.%I to authenticated',t);
 end loop;
end $$;
create policy "Stocktake read" on public.stocktake_sessions for select to authenticated using(private.has_business_permission(business_id,'view_inventory') and (branch_id is null or private.has_branch_access(business_id,branch_id)));
create policy "Count read" on public.stocktake_counts for select to authenticated using(exists(select 1 from public.stocktake_sessions s where s.id=session_id));
create policy "Condition ledger read" on public.stock_condition_entries for select to authenticated using(private.has_business_permission(business_id,'view_inventory'));
create policy "Inventory review read" on public.inventory_reconciliation_reviews for select to authenticated using(private.has_business_permission(business_id,'view_inventory'));
create function private.valid_stock_quantity(product uuid,quantity numeric,allow_zero boolean default false) returns boolean
language sql stable security definer set search_path='' as $$
 select quantity is not null and quantity::text not in('NaN','Infinity','-Infinity') and scale(quantity)<=3 and
 (quantity>0 or (allow_zero and quantity=0)) and exists(select 1 from public.products p where p.id=product
 and (p.unit in('kg','g','litre','ml','metre','cm') or trunc(quantity)=quantity))
$$;
revoke all on function private.valid_stock_quantity(uuid,numeric,boolean) from public,anon,authenticated;
create function public.start_trexven_stocktake(p_business_id uuid,p_request_id uuid,p_name text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare payload jsonb; prior jsonb; result jsonb; session uuid;
begin
 perform private.operations_context(p_business_id,'stocktake');perform private.catalog_context(p_business_id,'view_inventory');
 payload:=jsonb_build_object('operation','start_stocktake','name',p_name);prior:=private.operation_replay(p_business_id,p_request_id,payload);if prior is not null then return prior;end if;
 if nullif(btrim(p_name),'') is null then raise exception 'Count name required';end if;
 insert into public.stocktake_sessions(business_id,name,created_by) values(p_business_id,p_name,auth.uid()) returning id into session;
 insert into public.stocktake_counts(session_id,product_id) select session,id from public.products where business_id=p_business_id and active and is_active;
 result:=jsonb_build_object('id',session);perform private.operation_save(p_business_id,p_request_id,payload,result);return result;
end $$;
create function public.count_trexven_stock(p_session_id uuid,p_request_id uuid,p_counts jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.stocktake_sessions%rowtype; c public.stocktake_counts%rowtype; line jsonb; p public.products%rowtype; payload jsonb; prior jsonb; result jsonb;
begin
 select * into s from public.stocktake_sessions where id=p_session_id;
 if not found then raise exception 'Count session unavailable' using errcode='42501';end if;
 perform private.operations_context(s.business_id,'stocktake',s.branch_id);
 payload:=jsonb_build_object('operation','count_stock','session',p_session_id,'counts',p_counts);prior:=private.operation_replay(s.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select * into s from public.stocktake_sessions where id=p_session_id for update;
 if s.status<>'open' or jsonb_typeof(p_counts)<>'array' or jsonb_array_length(p_counts)=0 then raise exception 'Open online session and counts required';end if;
 if exists(select 1 from jsonb_array_elements(p_counts) x group by x->>'product_id' having count(*)>1) then raise exception 'Duplicate count';end if;
 for line in select * from jsonb_array_elements(p_counts) order by value->>'product_id' loop
  select * into c from public.stocktake_counts where session_id=s.id and product_id=(line->>'product_id')::uuid for update;
  if not found or (line->>'version')::integer is distinct from c.version or (c.counted_by is not null and c.counted_by<>auth.uid()) then raise exception 'Count changed or belongs to another counter; refresh or request reassignment';end if;
  select * into p from public.products where id=c.product_id and business_id=s.business_id for update;
  if not found or not private.valid_stock_quantity(p.id,(line->>'quantity')::numeric,true) then raise exception 'Invalid physical quantity';end if;
  update public.stocktake_counts set counted=(line->>'quantity')::numeric,expected_at_count=coalesce(p.quantity,0),counted_by=auth.uid(),counted_at=clock_timestamp(),version=version+1 where id=c.id;
 end loop;
 result:=jsonb_build_object('counted',jsonb_array_length(p_counts));perform private.operation_save(s.business_id,p_request_id,payload,result);return result;
end $$;
create function public.submit_trexven_stocktake(p_session_id uuid,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.stocktake_sessions%rowtype; payload jsonb; prior jsonb; result jsonb;
begin
 select * into s from public.stocktake_sessions where id=p_session_id;if not found then raise exception 'Session unavailable' using errcode='42501';end if;
 perform private.operations_context(s.business_id,'stocktake',s.branch_id);
 payload:=jsonb_build_object('operation','submit_stocktake','session',s.id);prior:=private.operation_replay(s.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select * into s from public.stocktake_sessions where id=p_session_id for update;
 if s.status<>'open' or exists(select 1 from public.stocktake_counts where session_id=s.id and counted is null) then raise exception 'Complete every count before review';end if;
 update public.stocktake_sessions set status='review' where id=s.id;result:=jsonb_build_object('status','review');perform private.operation_save(s.business_id,p_request_id,payload,result);return result;
end $$;
create function public.approve_trexven_stocktake(p_session_id uuid,p_request_id uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.stocktake_sessions%rowtype; c public.stocktake_counts%rowtype; p public.products%rowtype; delta numeric; payload jsonb; prior jsonb; result jsonb;
begin
 select * into s from public.stocktake_sessions where id=p_session_id;if not found then raise exception 'Session unavailable' using errcode='42501';end if;
 perform private.operations_context(s.business_id,'approve_stocktake',s.branch_id,true);
 payload:=jsonb_build_object('operation','approve_stocktake','session',s.id,'reason',p_reason);prior:=private.operation_replay(s.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select * into s from public.stocktake_sessions where id=p_session_id for update;
 if s.status<>'review' or nullif(btrim(p_reason),'') is null then raise exception 'Reviewed complete session and reason required';end if;
 perform set_config('trexven.catalog_request',p_request_id::text,true);perform set_config('trexven.catalog_reason','Stocktake: '||p_reason,true);
 for c in select * from public.stocktake_counts where session_id=s.id order by product_id loop
  select * into p from public.products where id=c.product_id and business_id=s.business_id for update;
  delta:=c.counted-c.expected_at_count;
  if c.counted is null or coalesce(p.quantity,0)+delta<0 then raise exception 'Later movements require recount; no negative stock reconciliation';end if;
  update public.products set quantity=coalesce(quantity,0)+delta,updated_at=now() where id=p.id;
  update public.stocktake_counts set applied_delta=delta,stock_after=coalesce(p.quantity,0)+delta where id=c.id;
 end loop;
 perform set_config('trexven.catalog_request','',true);perform set_config('trexven.catalog_reason','',true);
 update public.stocktake_sessions set status='closed',closed_at=clock_timestamp(),approved_by=auth.uid(),reason=p_reason where id=s.id;
 result:=jsonb_build_object('id',s.id,'status','closed');insert into public.audit_logs(business_id,actor_id,action,metadata) values(s.business_id,auth.uid(),'stocktake_approved',result||jsonb_build_object('reason',p_reason));
 perform private.operation_save(s.business_id,p_request_id,payload,result);return result;
end $$;
create function public.classify_trexven_stock(p_business_id uuid,p_product_id uuid,p_request_id uuid,p_quantity numeric,p_condition text,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.products%rowtype; payload jsonb; prior jsonb; result jsonb;
begin
 perform private.operations_context(p_business_id,'dispose_stock');perform private.catalog_context(p_business_id,'adjust_stock');
 payload:=jsonb_build_object('operation','classify_stock','product',p_product_id,'quantity',p_quantity,'condition',p_condition,'reason',p_reason);
 prior:=private.operation_replay(p_business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select * into p from public.products where id=p_product_id and business_id=p_business_id for update;
 if not found or not private.valid_stock_quantity(p.id,p_quantity) or p_quantity>coalesce(p.quantity,0) or p_condition not in('damaged','expired','defective','lost') or nullif(btrim(p_reason),'') is null then raise exception 'Valid stock, condition and reason required';end if;
 perform set_config('trexven.catalog_request',p_request_id::text,true);perform set_config('trexven.catalog_reason',p_condition||': '||p_reason,true);
 update public.products set quantity=coalesce(quantity,0)-p_quantity,updated_at=now() where id=p.id;
 if p_condition<>'lost' then insert into public.stock_condition_entries(business_id,product_id,condition,quantity,kind,request_id,actor_id,reason) values(p_business_id,p.id,p_condition,p_quantity,'classify',p_request_id,auth.uid(),p_reason);end if;
 perform set_config('trexven.catalog_request','',true);perform set_config('trexven.catalog_reason','',true);
 result:=jsonb_build_object('product_id',p.id,'remaining',coalesce(p.quantity,0)-p_quantity,'condition',p_condition);
 insert into public.audit_logs(business_id,actor_id,action,metadata) values(p_business_id,auth.uid(),'stock_classified',result||jsonb_build_object('quantity',p_quantity,'reason',p_reason));
 perform private.operation_save(p_business_id,p_request_id,payload,result);return result;
end $$;
create function public.resolve_trexven_condition_stock(p_business_id uuid,p_product_id uuid,p_request_id uuid,p_quantity numeric,p_condition text,p_action text,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.products%rowtype; balance numeric; payload jsonb; prior jsonb; result jsonb;
begin
 if p_action not in('restore','writeoff') then raise exception 'Inspected restore or write-off required';end if;
 perform private.operations_context(p_business_id,case when p_action='restore' then 'restore_stock' else 'writeoff_stock' end,null,true);
 perform private.catalog_context(p_business_id,'adjust_stock');
 payload:=jsonb_build_object('operation','resolve_stock','product',p_product_id,'quantity',p_quantity,'condition',p_condition,'action',p_action,'reason',p_reason);
 prior:=private.operation_replay(p_business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select * into p from public.products where id=p_product_id and business_id=p_business_id for update;
 if not found then raise exception 'Product unavailable' using errcode='42501';end if;
 select coalesce(sum(quantity),0) into balance from public.stock_condition_entries where business_id=p_business_id and product_id=p_product_id and condition=p_condition;
 if not found or not private.valid_stock_quantity(p_product_id,p_quantity) or p_quantity>balance or p_condition not in('damaged','expired','defective') or nullif(btrim(p_reason),'') is null then raise exception 'Inspected available condition stock and reason required';end if;
 insert into public.stock_condition_entries(business_id,product_id,condition,quantity,kind,request_id,actor_id,reason) values(p_business_id,p_product_id,p_condition,-p_quantity,p_action,p_request_id,auth.uid(),p_reason);
 if p_action='restore' then
  perform set_config('trexven.catalog_request',p_request_id::text,true);perform set_config('trexven.catalog_reason','Inspected restoration: '||p_reason,true);
  update public.products set quantity=coalesce(quantity,0)+p_quantity,updated_at=now() where id=p_product_id and business_id=p_business_id;
  perform set_config('trexven.catalog_request','',true);perform set_config('trexven.catalog_reason','',true);
 end if;
 result:=jsonb_build_object('product_id',p_product_id,'condition_remaining',balance-p_quantity,'action',p_action);
 insert into public.audit_logs(business_id,actor_id,action,metadata) values(p_business_id,auth.uid(),'condition_stock_resolved',result||jsonb_build_object('reason',p_reason));
 perform private.operation_save(p_business_id,p_request_id,payload,result);return result;
end $$;
-- Capture inspected nonsellable customer returns once, alongside Batch 4's sellable restock.
create function private.capture_return_condition_stock() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.status='approved' and old.status<>'approved' then
  insert into public.stock_condition_entries(business_id,product_id,condition,quantity,kind,request_id,actor_id,reason)
  select new.business_id,s.product_id,i.condition,sum(i.quantity),'customer_return',new.id,auth.uid(),new.reason
  from public.return_items i join public.sale_items s on s.id=i.sale_item_id where i.return_id=new.id and i.condition in('damaged','defective') group by s.product_id,i.condition;
 end if;return new;
end $$;
revoke all on function private.capture_return_condition_stock() from public,anon,authenticated;
create trigger batch_5_return_conditions after update of status on public.sale_returns for each row execute function private.capture_return_condition_stock();
-- Late offline sales generate review records; never rewrite the completed count.
create function private.offline_stocktake_review() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.inventory_reconciliation_reviews(business_id,session_id,sale_id,product_id,quantity)
 select new.business_id,s.id,new.sale_id,c.product_id,i.quantity from public.stocktake_sessions s
 join public.stocktake_counts c on c.session_id=s.id join public.sale_items i on i.product_id=c.product_id and i.sale_id=new.sale_id
 where s.business_id=new.business_id and s.status='closed' and new.occurred_at<=c.counted_at and new.created_at>s.closed_at on conflict do nothing;
 return new;
end $$;
revoke all on function private.offline_stocktake_review() from public,anon,authenticated;
-- Trigger column names checked against the Batch 4 reconciliation contract before deployment.
create trigger batch_5_late_offline_review after insert on public.offline_sale_reconciliations for each row execute function private.offline_stocktake_review();
do $$ declare f record;begin
 for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in('start_trexven_stocktake','count_trexven_stock','submit_trexven_stocktake','approve_trexven_stocktake','classify_trexven_stock','resolve_trexven_condition_stock') loop
  execute format('revoke all on function %s from public,anon',f.signature);execute format('grant execute on function %s to authenticated',f.signature);
 end loop;
end $$;
commit;
