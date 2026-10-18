begin;
-- Release history guard and history insert are in the SAME transaction as DDL.
select pg_advisory_xact_lock(hashtextextended('trexven:coordinated-release',0));
do $trexven_history_guard$ begin
 if (select array_agg(version order by version) from supabase_migrations.schema_migrations)
    is distinct from array['20260819180000','20260823100000','20261002014604','20261002015419','20261002123039','20261002124738','20261003224001','20261004025120','20261005004045','20261007215736','20261007215743','20261007215831','20261008002119','20261008020234','20261008021428','20261009003200','20261009070338','20261009070340','20261009075117','20261009075318']::text[] then
  raise exception 'TREXVEN predecessor history mismatch; no migration changes committed';
 end if;
end $trexven_history_guard$;

insert into public.permissions(id,description) values('supplier_returns','Dispatch nonsellable supplier returns'),('approve_supplier_returns','Review supplier acknowledgments') on conflict(id) do nothing;
create table public.supplier_stock_returns(
 id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),product_id uuid not null references public.products(id),
 supplier_name text not null,condition text not null check(condition in('damaged','expired','defective')),quantity numeric(18,3) not null check(quantity>0),
 status text not null default 'dispatched' check(status in('dispatched','acknowledged')),accepted numeric(18,3),returned numeric(18,3),
 reason text not null,acknowledgment text,request_id uuid not null unique,created_by uuid not null references auth.users(id),reviewed_by uuid references auth.users(id),created_at timestamptz not null default now());
alter table public.supplier_stock_returns enable row level security;
revoke all on public.supplier_stock_returns from public,anon,authenticated;grant select on public.supplier_stock_returns to authenticated;
create policy "Supplier return read" on public.supplier_stock_returns for select to authenticated using(private.has_business_permission(business_id,'view_inventory'));
create function public.dispatch_trexven_supplier_return(p_business_id uuid,p_request_id uuid,p_product_id uuid,p_quantity numeric,p_condition text,p_supplier_name text,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.products%rowtype; balance numeric; payload jsonb; prior jsonb; result jsonb; return_id uuid;
begin
 perform private.operations_context(p_business_id,'supplier_returns');perform private.catalog_context(p_business_id,'view_inventory');
 payload:=jsonb_build_object('operation','supplier_dispatch','product',p_product_id,'quantity',p_quantity,'condition',p_condition,'supplier',p_supplier_name,'reason',p_reason);
 prior:=private.operation_replay(p_business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select * into p from public.products where id=p_product_id and business_id=p_business_id for update;
 if not found then raise exception 'Product unavailable' using errcode='42501';end if;
 select coalesce(sum(quantity),0) into balance from public.stock_condition_entries where business_id=p_business_id and product_id=p_product_id and condition=p_condition;
 if not private.valid_stock_quantity(p_product_id,p_quantity) or p_quantity>balance or nullif(btrim(p_supplier_name),'') is null or nullif(btrim(p_reason),'') is null then raise exception 'Available nonsellable stock, supplier name and reason required';end if;
 insert into public.supplier_stock_returns(business_id,product_id,supplier_name,condition,quantity,reason,request_id,created_by) values(p_business_id,p_product_id,p_supplier_name,p_condition,p_quantity,p_reason,p_request_id,auth.uid()) returning id into return_id;
 insert into public.stock_condition_entries(business_id,product_id,condition,quantity,kind,request_id,actor_id,reason) values(p_business_id,p_product_id,p_condition,-p_quantity,'supplier_dispatch',p_request_id,auth.uid(),p_reason);
 result:=jsonb_build_object('id',return_id,'status','dispatched');perform private.operation_save(p_business_id,p_request_id,payload,result);return result;
end $$;
create function public.acknowledge_trexven_supplier_return(p_return_id uuid,p_request_id uuid,p_accepted numeric,p_returned numeric,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.supplier_stock_returns%rowtype; payload jsonb; prior jsonb; result jsonb;
begin
 select * into r from public.supplier_stock_returns where id=p_return_id;if not found then raise exception 'Return unavailable' using errcode='42501';end if;
 perform private.operations_context(r.business_id,'approve_supplier_returns',null,true);
 payload:=jsonb_build_object('operation','supplier_ack','return',r.id,'accepted',p_accepted,'returned',p_returned,'reason',p_reason);
 prior:=private.operation_replay(r.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select * into r from public.supplier_stock_returns where id=p_return_id for update;
 perform id from public.products where id=r.product_id and business_id=r.business_id for update;
 if r.status<>'dispatched' or not private.valid_stock_quantity(r.product_id,p_accepted,true) or not private.valid_stock_quantity(r.product_id,p_returned,true)
 or p_accepted+p_returned>r.quantity or nullif(btrim(p_reason),'') is null then raise exception 'Actual supplier quantities and discrepancy explanation required';end if;
 if p_returned>0 then insert into public.stock_condition_entries(business_id,product_id,condition,quantity,kind,request_id,actor_id,reason) values(r.business_id,r.product_id,r.condition,p_returned,'supplier_restore',p_request_id,auth.uid(),p_reason);end if;
 update public.supplier_stock_returns set status='acknowledged',accepted=p_accepted,returned=p_returned,acknowledgment=p_reason,reviewed_by=auth.uid() where id=r.id;
 result:=jsonb_build_object('id',r.id,'accepted',p_accepted,'returned_nonsellable',p_returned,'unaccounted',r.quantity-p_accepted-p_returned);
 insert into public.audit_logs(business_id,actor_id,action,metadata) values(r.business_id,auth.uid(),'supplier_return_acknowledged',result||jsonb_build_object('reason',p_reason));
 perform private.operation_save(r.business_id,p_request_id,payload,result);return result;
end $$;
create function public.manage_trexven_stocktake(p_session_id uuid,p_request_id uuid,p_action text,p_product_id uuid default null,p_counter_id uuid default null,p_reason text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.stocktake_sessions%rowtype; payload jsonb; prior jsonb; result jsonb;
begin
 select * into s from public.stocktake_sessions where id=p_session_id;if not found then raise exception 'Session unavailable' using errcode='42501';end if;
 perform private.operations_context(s.business_id,'approve_stocktake',s.branch_id,true);
 payload:=jsonb_build_object('operation','manage_stocktake','session',s.id,'action',p_action,'product',p_product_id,'counter',p_counter_id,'reason',p_reason);
 prior:=private.operation_replay(s.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select * into s from public.stocktake_sessions where id=p_session_id for update;
 if s.status not in('open','review') or nullif(btrim(p_reason),'') is null then raise exception 'Active session and reason required';end if;
 if p_action='reopen' then update public.stocktake_sessions set status='open' where id=s.id;
 elsif p_action='cancel' then update public.stocktake_sessions set status='cancelled',reason=p_reason,closed_at=clock_timestamp() where id=s.id;
 elsif p_action='reassign' then
  if s.status<>'open' or p_product_id is null or (p_counter_id is not null and not exists(select 1 from public.business_members where business_id=s.business_id and user_id=p_counter_id and status='active')) then raise exception 'Open session and active assigned counter required';end if;
  update public.stocktake_counts set counted_by=p_counter_id,version=version+1 where session_id=s.id and product_id=p_product_id;
  if not found then raise exception 'Product not in session';end if;
 else raise exception 'Unknown session action';end if;
 result:=jsonb_build_object('id',s.id,'action',p_action);insert into public.audit_logs(business_id,actor_id,action,metadata) values(s.business_id,auth.uid(),'stocktake_managed',payload);
 perform private.operation_save(s.business_id,p_request_id,payload,result);return result;
end $$;
create function public.review_trexven_inventory_discrepancy(p_review_id uuid,p_request_id uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.inventory_reconciliation_reviews%rowtype; payload jsonb; prior jsonb; result jsonb;
begin
 select * into r from public.inventory_reconciliation_reviews where id=p_review_id;if not found then raise exception 'Review unavailable' using errcode='42501';end if;
 perform private.operations_context(r.business_id,'approve_stocktake',null,true);
 payload:=jsonb_build_object('operation','review_inventory','review',r.id,'reason',p_reason);prior:=private.operation_replay(r.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select * into r from public.inventory_reconciliation_reviews where id=p_review_id for update;
 if r.status<>'pending' or nullif(btrim(p_reason),'') is null then raise exception 'Pending review and reconciliation explanation required';end if;
 -- No quantity changes here. Any independently approved adjustment has its own ledger entry.
 update public.inventory_reconciliation_reviews set status='resolved',reason=p_reason,reviewed_by=auth.uid(),reviewed_at=now() where id=r.id;
 result:=jsonb_build_object('id',r.id,'status','resolved');insert into public.audit_logs(business_id,actor_id,action,metadata) values(r.business_id,auth.uid(),'late_inventory_reviewed',payload);
 perform private.operation_save(r.business_id,p_request_id,payload,result);return result;
end $$;
do $$ declare f record;begin
 for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in('dispatch_trexven_supplier_return','acknowledge_trexven_supplier_return','manage_trexven_stocktake','review_trexven_inventory_discrepancy') loop
 execute format('revoke all on function %s from public,anon',f.signature);execute format('grant execute on function %s to authenticated',f.signature);end loop;
end $$;
insert into supabase_migrations.schema_migrations(version,name,statements) values ('20261009075612','batch_5_inventory_review_controls',array[$trexven_release_source$begin;
insert into public.permissions(id,description) values('supplier_returns','Dispatch nonsellable supplier returns'),('approve_supplier_returns','Review supplier acknowledgments') on conflict(id) do nothing;
create table public.supplier_stock_returns(
 id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),product_id uuid not null references public.products(id),
 supplier_name text not null,condition text not null check(condition in('damaged','expired','defective')),quantity numeric(18,3) not null check(quantity>0),
 status text not null default 'dispatched' check(status in('dispatched','acknowledged')),accepted numeric(18,3),returned numeric(18,3),
 reason text not null,acknowledgment text,request_id uuid not null unique,created_by uuid not null references auth.users(id),reviewed_by uuid references auth.users(id),created_at timestamptz not null default now());
alter table public.supplier_stock_returns enable row level security;
revoke all on public.supplier_stock_returns from public,anon,authenticated;grant select on public.supplier_stock_returns to authenticated;
create policy "Supplier return read" on public.supplier_stock_returns for select to authenticated using(private.has_business_permission(business_id,'view_inventory'));
create function public.dispatch_trexven_supplier_return(p_business_id uuid,p_request_id uuid,p_product_id uuid,p_quantity numeric,p_condition text,p_supplier_name text,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.products%rowtype; balance numeric; payload jsonb; prior jsonb; result jsonb; return_id uuid;
begin
 perform private.operations_context(p_business_id,'supplier_returns');perform private.catalog_context(p_business_id,'view_inventory');
 payload:=jsonb_build_object('operation','supplier_dispatch','product',p_product_id,'quantity',p_quantity,'condition',p_condition,'supplier',p_supplier_name,'reason',p_reason);
 prior:=private.operation_replay(p_business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select * into p from public.products where id=p_product_id and business_id=p_business_id for update;
 if not found then raise exception 'Product unavailable' using errcode='42501';end if;
 select coalesce(sum(quantity),0) into balance from public.stock_condition_entries where business_id=p_business_id and product_id=p_product_id and condition=p_condition;
 if not private.valid_stock_quantity(p_product_id,p_quantity) or p_quantity>balance or nullif(btrim(p_supplier_name),'') is null or nullif(btrim(p_reason),'') is null then raise exception 'Available nonsellable stock, supplier name and reason required';end if;
 insert into public.supplier_stock_returns(business_id,product_id,supplier_name,condition,quantity,reason,request_id,created_by) values(p_business_id,p_product_id,p_supplier_name,p_condition,p_quantity,p_reason,p_request_id,auth.uid()) returning id into return_id;
 insert into public.stock_condition_entries(business_id,product_id,condition,quantity,kind,request_id,actor_id,reason) values(p_business_id,p_product_id,p_condition,-p_quantity,'supplier_dispatch',p_request_id,auth.uid(),p_reason);
 result:=jsonb_build_object('id',return_id,'status','dispatched');perform private.operation_save(p_business_id,p_request_id,payload,result);return result;
end $$;
create function public.acknowledge_trexven_supplier_return(p_return_id uuid,p_request_id uuid,p_accepted numeric,p_returned numeric,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.supplier_stock_returns%rowtype; payload jsonb; prior jsonb; result jsonb;
begin
 select * into r from public.supplier_stock_returns where id=p_return_id;if not found then raise exception 'Return unavailable' using errcode='42501';end if;
 perform private.operations_context(r.business_id,'approve_supplier_returns',null,true);
 payload:=jsonb_build_object('operation','supplier_ack','return',r.id,'accepted',p_accepted,'returned',p_returned,'reason',p_reason);
 prior:=private.operation_replay(r.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select * into r from public.supplier_stock_returns where id=p_return_id for update;
 perform id from public.products where id=r.product_id and business_id=r.business_id for update;
 if r.status<>'dispatched' or not private.valid_stock_quantity(r.product_id,p_accepted,true) or not private.valid_stock_quantity(r.product_id,p_returned,true)
 or p_accepted+p_returned>r.quantity or nullif(btrim(p_reason),'') is null then raise exception 'Actual supplier quantities and discrepancy explanation required';end if;
 if p_returned>0 then insert into public.stock_condition_entries(business_id,product_id,condition,quantity,kind,request_id,actor_id,reason) values(r.business_id,r.product_id,r.condition,p_returned,'supplier_restore',p_request_id,auth.uid(),p_reason);end if;
 update public.supplier_stock_returns set status='acknowledged',accepted=p_accepted,returned=p_returned,acknowledgment=p_reason,reviewed_by=auth.uid() where id=r.id;
 result:=jsonb_build_object('id',r.id,'accepted',p_accepted,'returned_nonsellable',p_returned,'unaccounted',r.quantity-p_accepted-p_returned);
 insert into public.audit_logs(business_id,actor_id,action,metadata) values(r.business_id,auth.uid(),'supplier_return_acknowledged',result||jsonb_build_object('reason',p_reason));
 perform private.operation_save(r.business_id,p_request_id,payload,result);return result;
end $$;
create function public.manage_trexven_stocktake(p_session_id uuid,p_request_id uuid,p_action text,p_product_id uuid default null,p_counter_id uuid default null,p_reason text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.stocktake_sessions%rowtype; payload jsonb; prior jsonb; result jsonb;
begin
 select * into s from public.stocktake_sessions where id=p_session_id;if not found then raise exception 'Session unavailable' using errcode='42501';end if;
 perform private.operations_context(s.business_id,'approve_stocktake',s.branch_id,true);
 payload:=jsonb_build_object('operation','manage_stocktake','session',s.id,'action',p_action,'product',p_product_id,'counter',p_counter_id,'reason',p_reason);
 prior:=private.operation_replay(s.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select * into s from public.stocktake_sessions where id=p_session_id for update;
 if s.status not in('open','review') or nullif(btrim(p_reason),'') is null then raise exception 'Active session and reason required';end if;
 if p_action='reopen' then update public.stocktake_sessions set status='open' where id=s.id;
 elsif p_action='cancel' then update public.stocktake_sessions set status='cancelled',reason=p_reason,closed_at=clock_timestamp() where id=s.id;
 elsif p_action='reassign' then
  if s.status<>'open' or p_product_id is null or (p_counter_id is not null and not exists(select 1 from public.business_members where business_id=s.business_id and user_id=p_counter_id and status='active')) then raise exception 'Open session and active assigned counter required';end if;
  update public.stocktake_counts set counted_by=p_counter_id,version=version+1 where session_id=s.id and product_id=p_product_id;
  if not found then raise exception 'Product not in session';end if;
 else raise exception 'Unknown session action';end if;
 result:=jsonb_build_object('id',s.id,'action',p_action);insert into public.audit_logs(business_id,actor_id,action,metadata) values(s.business_id,auth.uid(),'stocktake_managed',payload);
 perform private.operation_save(s.business_id,p_request_id,payload,result);return result;
end $$;
create function public.review_trexven_inventory_discrepancy(p_review_id uuid,p_request_id uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.inventory_reconciliation_reviews%rowtype; payload jsonb; prior jsonb; result jsonb;
begin
 select * into r from public.inventory_reconciliation_reviews where id=p_review_id;if not found then raise exception 'Review unavailable' using errcode='42501';end if;
 perform private.operations_context(r.business_id,'approve_stocktake',null,true);
 payload:=jsonb_build_object('operation','review_inventory','review',r.id,'reason',p_reason);prior:=private.operation_replay(r.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select * into r from public.inventory_reconciliation_reviews where id=p_review_id for update;
 if r.status<>'pending' or nullif(btrim(p_reason),'') is null then raise exception 'Pending review and reconciliation explanation required';end if;
 -- No quantity changes here. Any independently approved adjustment has its own ledger entry.
 update public.inventory_reconciliation_reviews set status='resolved',reason=p_reason,reviewed_by=auth.uid(),reviewed_at=now() where id=r.id;
 result:=jsonb_build_object('id',r.id,'status','resolved');insert into public.audit_logs(business_id,actor_id,action,metadata) values(r.business_id,auth.uid(),'late_inventory_reviewed',payload);
 perform private.operation_save(r.business_id,p_request_id,payload,result);return result;
end $$;
do $$ declare f record;begin
 for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in('dispatch_trexven_supplier_return','acknowledge_trexven_supplier_return','manage_trexven_stocktake','review_trexven_inventory_discrepancy') loop
 execute format('revoke all on function %s from public,anon',f.signature);execute format('grant execute on function %s to authenticated',f.signature);end loop;
end $$;
commit;
$trexven_release_source$]::text[]);
commit;
