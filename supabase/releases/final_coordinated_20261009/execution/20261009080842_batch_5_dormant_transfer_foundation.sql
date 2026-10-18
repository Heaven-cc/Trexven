-- No branch activation, stock redistribution, or historical mapping.
begin;
-- Release history guard and history insert are in the SAME transaction as DDL.
select pg_advisory_xact_lock(hashtextextended('trexven:coordinated-release',0));
do $trexven_history_guard$ begin
 if (select array_agg(version order by version) from supabase_migrations.schema_migrations)
    is distinct from array['20260819180000','20260823100000','20261002014604','20261002015419','20261002123039','20261002124738','20261003224001','20261004025120','20261005004045','20261007215736','20261007215743','20261007215831','20261008002119','20261008020234','20261008021428','20261009003200','20261009070338','20261009070340','20261009075117','20261009075318','20261009075612','20261009075911','20261009080227','20261009080751']::text[] then
  raise exception 'TREXVEN predecessor history mismatch; no migration changes committed';
 end if;
end $trexven_history_guard$;

alter table public.businesses add column inventory_transfers_enabled boolean not null default false;
insert into public.permissions(id,description) values('transfer_stock','Explicit branch stock transfer authority') on conflict(id) do nothing;
create table public.stock_transfers(id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),
 source_branch uuid not null references public.branches(id),destination_branch uuid not null references public.branches(id),product_id uuid not null references public.products(id),
 quantity numeric(18,3) not null check(quantity>0),received numeric(18,3) not null default 0 check(received>=0),
 status text not null default 'in_transit' check(status in('in_transit','received','discrepancy_closed')),reason text not null,
 dispatched_by uuid not null references auth.users(id),received_by uuid references auth.users(id),resolution_reason text,created_at timestamptz not null default now(),check(source_branch<>destination_branch));
alter table public.stock_transfers enable row level security;revoke all on public.stock_transfers from public,anon,authenticated;grant select on public.stock_transfers to authenticated;
create policy "Transfer assigned read" on public.stock_transfers for select to authenticated using(private.has_business_permission(business_id,'view_inventory') and private.has_branch_access(business_id,source_branch) and private.has_branch_access(business_id,destination_branch));
create function private.transfer_context(business uuid,source uuid,destination uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.businesses where id=business and branches_enabled and inventory_transfers_enabled) then raise exception 'Branch transfer workflow is dormant';end if;
 perform private.operations_context(business,'transfer_stock',source,true);
 if source=destination or not private.has_branch_access(business,destination) or not exists(select 1 from public.branches where id=destination and business_id=business and is_active) then raise exception 'Authorized destination required' using errcode='42501';end if;
end $$;
revoke all on function private.transfer_context(uuid,uuid,uuid) from public,anon,authenticated;
create function public.dispatch_trexven_stock_transfer(p_business_id uuid,p_request_id uuid,p_source uuid,p_destination uuid,p_product_id uuid,p_quantity numeric,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare payload jsonb;prior jsonb;result jsonb;transfer uuid;
begin
 perform private.transfer_context(p_business_id,p_source,p_destination);
 payload:=jsonb_build_object('operation','dispatch_transfer','source',p_source,'destination',p_destination,'product',p_product_id,'quantity',p_quantity,'reason',p_reason);
 prior:=private.operation_replay(p_business_id,p_request_id,payload);if prior is not null then return prior;end if;
 perform id from public.products where id=p_product_id and business_id=p_business_id for update;
 if not found or not private.valid_stock_quantity(p_product_id,p_quantity) or nullif(btrim(p_reason),'') is null then raise exception 'Product, quantity and reason required';end if;
 perform id from public.inventory where business_id=p_business_id and product_id=p_product_id and branch_id in(p_source,p_destination) order by branch_id for update;
 update public.inventory set quantity=quantity-p_quantity,updated_at=now() where business_id=p_business_id and product_id=p_product_id and branch_id=p_source and quantity-reserved_quantity>=p_quantity;
 if not found then raise exception 'Insufficient available source stock';end if;
 insert into public.stock_transfers(business_id,source_branch,destination_branch,product_id,quantity,reason,dispatched_by) values(p_business_id,p_source,p_destination,p_product_id,p_quantity,p_reason,auth.uid()) returning id into transfer;
 result:=jsonb_build_object('id',transfer,'status','in_transit');insert into public.audit_logs(business_id,actor_id,action,metadata) values(p_business_id,auth.uid(),'stock_transfer_dispatched',payload||result);
 perform private.operation_save(p_business_id,p_request_id,payload,result);return result;
end $$;
create function public.receive_trexven_stock_transfer(p_transfer_id uuid,p_request_id uuid,p_quantity numeric,p_close_discrepancy boolean default false,p_reason text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare t public.stock_transfers%rowtype;payload jsonb;prior jsonb;result jsonb;
begin
 select * into t from public.stock_transfers where id=p_transfer_id;if not found then raise exception 'Transfer unavailable' using errcode='42501';end if;
 perform private.transfer_context(t.business_id,t.source_branch,t.destination_branch);
 payload:=jsonb_build_object('operation','receive_transfer','transfer',t.id,'quantity',p_quantity,'close_discrepancy',p_close_discrepancy,'reason',p_reason);
 prior:=private.operation_replay(t.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select * into t from public.stock_transfers where id=p_transfer_id for update;
 if t.status<>'in_transit' or not private.valid_stock_quantity(t.product_id,p_quantity,true) or t.received+p_quantity>t.quantity
 or (p_close_discrepancy and (not public.user_owns_business(t.business_id) or nullif(btrim(p_reason),'') is null)) then raise exception 'Actual received quantity and owner discrepancy approval required';end if;
 perform id from public.products where id=t.product_id and business_id=t.business_id for update;
 if p_quantity>0 then
  update public.inventory set quantity=quantity+p_quantity,updated_at=now() where business_id=t.business_id and product_id=t.product_id and branch_id=t.destination_branch;
  if not found then raise exception 'Validated destination stock mapping required before transfers';end if;
 end if;
 update public.stock_transfers set received=received+p_quantity,received_by=auth.uid(),status=case when received+p_quantity=quantity then 'received' when p_close_discrepancy then 'discrepancy_closed' else 'in_transit' end,resolution_reason=p_reason where id=t.id;
 result:=jsonb_build_object('id',t.id,'received',t.received+p_quantity,'unaccounted',t.quantity-t.received-p_quantity);insert into public.audit_logs(business_id,actor_id,action,metadata) values(t.business_id,auth.uid(),'stock_transfer_received',payload||result);
 perform private.operation_save(t.business_id,p_request_id,payload,result);return result;
end $$;
revoke all on function public.dispatch_trexven_stock_transfer(uuid,uuid,uuid,uuid,uuid,numeric,text),public.receive_trexven_stock_transfer(uuid,uuid,numeric,boolean,text) from public,anon;
grant execute on function public.dispatch_trexven_stock_transfer(uuid,uuid,uuid,uuid,uuid,numeric,text),public.receive_trexven_stock_transfer(uuid,uuid,numeric,boolean,text) to authenticated;
insert into supabase_migrations.schema_migrations(version,name,statements) values ('20261009080842','batch_5_dormant_transfer_foundation',array[$trexven_release_source$-- No branch activation, stock redistribution, or historical mapping.
begin;
alter table public.businesses add column inventory_transfers_enabled boolean not null default false;
insert into public.permissions(id,description) values('transfer_stock','Explicit branch stock transfer authority') on conflict(id) do nothing;
create table public.stock_transfers(id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),
 source_branch uuid not null references public.branches(id),destination_branch uuid not null references public.branches(id),product_id uuid not null references public.products(id),
 quantity numeric(18,3) not null check(quantity>0),received numeric(18,3) not null default 0 check(received>=0),
 status text not null default 'in_transit' check(status in('in_transit','received','discrepancy_closed')),reason text not null,
 dispatched_by uuid not null references auth.users(id),received_by uuid references auth.users(id),resolution_reason text,created_at timestamptz not null default now(),check(source_branch<>destination_branch));
alter table public.stock_transfers enable row level security;revoke all on public.stock_transfers from public,anon,authenticated;grant select on public.stock_transfers to authenticated;
create policy "Transfer assigned read" on public.stock_transfers for select to authenticated using(private.has_business_permission(business_id,'view_inventory') and private.has_branch_access(business_id,source_branch) and private.has_branch_access(business_id,destination_branch));
create function private.transfer_context(business uuid,source uuid,destination uuid) returns void language plpgsql security definer set search_path='' as $$
begin
 if not exists(select 1 from public.businesses where id=business and branches_enabled and inventory_transfers_enabled) then raise exception 'Branch transfer workflow is dormant';end if;
 perform private.operations_context(business,'transfer_stock',source,true);
 if source=destination or not private.has_branch_access(business,destination) or not exists(select 1 from public.branches where id=destination and business_id=business and is_active) then raise exception 'Authorized destination required' using errcode='42501';end if;
end $$;
revoke all on function private.transfer_context(uuid,uuid,uuid) from public,anon,authenticated;
create function public.dispatch_trexven_stock_transfer(p_business_id uuid,p_request_id uuid,p_source uuid,p_destination uuid,p_product_id uuid,p_quantity numeric,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare payload jsonb;prior jsonb;result jsonb;transfer uuid;
begin
 perform private.transfer_context(p_business_id,p_source,p_destination);
 payload:=jsonb_build_object('operation','dispatch_transfer','source',p_source,'destination',p_destination,'product',p_product_id,'quantity',p_quantity,'reason',p_reason);
 prior:=private.operation_replay(p_business_id,p_request_id,payload);if prior is not null then return prior;end if;
 perform id from public.products where id=p_product_id and business_id=p_business_id for update;
 if not found or not private.valid_stock_quantity(p_product_id,p_quantity) or nullif(btrim(p_reason),'') is null then raise exception 'Product, quantity and reason required';end if;
 perform id from public.inventory where business_id=p_business_id and product_id=p_product_id and branch_id in(p_source,p_destination) order by branch_id for update;
 update public.inventory set quantity=quantity-p_quantity,updated_at=now() where business_id=p_business_id and product_id=p_product_id and branch_id=p_source and quantity-reserved_quantity>=p_quantity;
 if not found then raise exception 'Insufficient available source stock';end if;
 insert into public.stock_transfers(business_id,source_branch,destination_branch,product_id,quantity,reason,dispatched_by) values(p_business_id,p_source,p_destination,p_product_id,p_quantity,p_reason,auth.uid()) returning id into transfer;
 result:=jsonb_build_object('id',transfer,'status','in_transit');insert into public.audit_logs(business_id,actor_id,action,metadata) values(p_business_id,auth.uid(),'stock_transfer_dispatched',payload||result);
 perform private.operation_save(p_business_id,p_request_id,payload,result);return result;
end $$;
create function public.receive_trexven_stock_transfer(p_transfer_id uuid,p_request_id uuid,p_quantity numeric,p_close_discrepancy boolean default false,p_reason text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare t public.stock_transfers%rowtype;payload jsonb;prior jsonb;result jsonb;
begin
 select * into t from public.stock_transfers where id=p_transfer_id;if not found then raise exception 'Transfer unavailable' using errcode='42501';end if;
 perform private.transfer_context(t.business_id,t.source_branch,t.destination_branch);
 payload:=jsonb_build_object('operation','receive_transfer','transfer',t.id,'quantity',p_quantity,'close_discrepancy',p_close_discrepancy,'reason',p_reason);
 prior:=private.operation_replay(t.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select * into t from public.stock_transfers where id=p_transfer_id for update;
 if t.status<>'in_transit' or not private.valid_stock_quantity(t.product_id,p_quantity,true) or t.received+p_quantity>t.quantity
 or (p_close_discrepancy and (not public.user_owns_business(t.business_id) or nullif(btrim(p_reason),'') is null)) then raise exception 'Actual received quantity and owner discrepancy approval required';end if;
 perform id from public.products where id=t.product_id and business_id=t.business_id for update;
 if p_quantity>0 then
  update public.inventory set quantity=quantity+p_quantity,updated_at=now() where business_id=t.business_id and product_id=t.product_id and branch_id=t.destination_branch;
  if not found then raise exception 'Validated destination stock mapping required before transfers';end if;
 end if;
 update public.stock_transfers set received=received+p_quantity,received_by=auth.uid(),status=case when received+p_quantity=quantity then 'received' when p_close_discrepancy then 'discrepancy_closed' else 'in_transit' end,resolution_reason=p_reason where id=t.id;
 result:=jsonb_build_object('id',t.id,'received',t.received+p_quantity,'unaccounted',t.quantity-t.received-p_quantity);insert into public.audit_logs(business_id,actor_id,action,metadata) values(t.business_id,auth.uid(),'stock_transfer_received',payload||result);
 perform private.operation_save(t.business_id,p_request_id,payload,result);return result;
end $$;
revoke all on function public.dispatch_trexven_stock_transfer(uuid,uuid,uuid,uuid,uuid,numeric,text),public.receive_trexven_stock_transfer(uuid,uuid,numeric,boolean,text) from public,anon;
grant execute on function public.dispatch_trexven_stock_transfer(uuid,uuid,uuid,uuid,uuid,numeric,text),public.receive_trexven_stock_transfer(uuid,uuid,numeric,boolean,text) to authenticated;
commit;
$trexven_release_source$]::text[]);
commit;
