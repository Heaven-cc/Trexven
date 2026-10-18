-- Signed 24-hour per-device cash scope. No noncash/offline credit or refund.
begin;
-- Release history guard and history insert are in the SAME transaction as DDL.
select pg_advisory_xact_lock(hashtextextended('trexven:coordinated-release',0));
do $trexven_history_guard$ begin
 if (select array_agg(version order by version) from supabase_migrations.schema_migrations)
    is distinct from array['20260819180000','20260823100000','20261002014604','20261002015419','20261002123039','20261002124738','20261003224001','20261004025120','20261005004045','20261007215736','20261007215743','20261007215831','20261008002119','20261008020234','20261008021428','20261009003200','20261009070338']::text[] then
  raise exception 'TREXVEN predecessor history mismatch; no migration changes committed';
 end if;
end $trexven_history_guard$;

insert into public.permissions(id,description) values('offline_cash','Owner-authorized offline cash reconciliation') on conflict(id) do nothing;
create table private.offline_cash_leases(
 id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),
 user_id uuid not null references auth.users(id),member_id uuid not null references public.business_members(id),device_id uuid not null,
 scope jsonb not null,signature text not null,signing_key bytea not null,issued_at timestamptz not null,expires_at timestamptz not null);
alter table private.offline_cash_leases enable row level security;
revoke all on private.offline_cash_leases from public,anon,authenticated;
create table public.offline_sale_reconciliations(
 id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),sale_id uuid not null references public.sales(id),
 lease_id uuid not null references private.offline_cash_leases(id),request_id uuid not null unique,
 device_id uuid not null,actor_id uuid not null references auth.users(id),occurred_at timestamptz not null,
 discrepancies jsonb not null default '[]',reviewed_by uuid references auth.users(id),review_reason text,created_at timestamptz not null default now());
alter table public.offline_sale_reconciliations enable row level security;
revoke all on public.offline_sale_reconciliations from public,anon,authenticated;
grant select on public.offline_sale_reconciliations to authenticated;
create policy "Offline reconciliation scoped read" on public.offline_sale_reconciliations for select to authenticated
 using(public.user_owns_business(business_id) or (public.is_business_member(business_id) and (actor_id=auth.uid() or private.has_business_permission(business_id,'view_finance'))));

create function public.issue_trexven_offline_scope(p_business_id uuid,p_device_id uuid,p_shift_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare member uuid; leaseid uuid:=gen_random_uuid(); secret bytea; scope jsonb; signature text; started timestamptz:=clock_timestamp();
begin
 perform private.operations_context(p_business_id,'offline_cash');
 if not private.has_business_permission(p_business_id,'complete_sales') or not private.has_business_permission(p_business_id,'pos_access') then raise exception 'Cash sale permission required' using errcode='42501';end if;
 if p_device_id is null then raise exception 'Stable device identity required';end if;
 select m.id into member from public.business_members m where business_id=p_business_id and user_id=auth.uid() and status='active';
 perform private.validate_operational_shift(p_business_id,member,p_shift_id,null,false);
 select jsonb_build_object('version',1,'lease_id',leaseid,'business_id',p_business_id,'user_id',auth.uid(),'membership_id',member,'device_id',p_device_id,
 'issued_at',started,'expires_at',started+interval '24 hours','branch_id',null,'shift_id',p_shift_id,'products',coalesce(jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'unit',p.unit,'price',p.selling_price,'quantity',p.quantity,'barcode',p.barcode,'sku',p.sku) order by p.id),'[]'::jsonb)) into scope
 from public.products p where business_id=p_business_id and p.selling_price is not null and p.active is true and p.is_active;
 secret:=extensions.gen_random_bytes(32);
 signature:=encode(extensions.hmac(convert_to(scope::text,'UTF8'),secret,'sha256'),'hex');
 insert into private.offline_cash_leases values(leaseid,p_business_id,auth.uid(),member,p_device_id,scope,signature,secret,started,started+interval '24 hours');
 return jsonb_build_object('scope',scope,'signature',signature);
end $$;

create function public.sync_trexven_offline_cash(p_request_id uuid,p_ticket jsonb,p_items jsonb,p_total numeric,p_occurred_at timestamptz)
returns jsonb language plpgsql security definer set search_path='' as $$
declare lease private.offline_cash_leases%rowtype; payload jsonb; prior jsonb; receipt jsonb; sale uuid; x jsonb; snapshot jsonb;
 product public.products%rowtype; qty numeric; price numeric; v_total numeric:=0; missing numeric; discrepancies jsonb:='[]'; shift uuid;
begin
 select * into lease from private.offline_cash_leases where id=(p_ticket->'scope'->>'lease_id')::uuid;
 if not found or auth.uid() is distinct from lease.user_id or p_ticket->'scope' is distinct from lease.scope or
 p_ticket->>'signature' is distinct from encode(extensions.hmac(convert_to(lease.scope::text,'UTF8'),lease.signing_key,'sha256'),'hex') then raise exception 'Invalid signed offline authorization' using errcode='42501';end if;
 perform private.operations_context(lease.business_id,'offline_cash');
 if not private.has_business_permission(lease.business_id,'complete_sales') or not exists(select 1 from public.business_members where id=lease.member_id and user_id=auth.uid() and business_id=lease.business_id and status='active') then raise exception 'Current sale authorization required; retain queue for owner review' using errcode='42501';end if;
 payload:=jsonb_build_object('operation','offline_cash','ticket',p_ticket,'items',p_items,'total',p_total,'occurred_at',p_occurred_at);
 perform pg_advisory_xact_lock(hashtextextended(lease.business_id::text||auth.uid()::text||p_request_id::text,0));
 prior:=private.operation_replay(lease.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 if exists(select 1 from private.sale_requests where business_id=lease.business_id and user_id=auth.uid() and request_id=p_request_id) then raise exception 'This key belongs to an original checkout; recover that receipt before another submission';end if;
 if exists(select 1 from public.businesses where id=lease.business_id and pos_writes_paused) then raise exception 'POS writes are paused; retain the encrypted cash queue';end if;
 if p_occurred_at is null or p_occurred_at<lease.issued_at or p_occurred_at>=lease.expires_at or p_occurred_at>clock_timestamp()+interval '5 minutes'
 or not private.valid_money(p_total,true) or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Cash sale is outside its authorized scope';end if;
 if exists(select 1 from jsonb_array_elements(p_items) i group by i->>'product_id' having count(*)>1) then raise exception 'Duplicate offline product';end if;
 shift:=(lease.scope->>'shift_id')::uuid;
 perform id from public.products where business_id=lease.business_id and id in(select (i->>'product_id')::uuid from jsonb_array_elements(p_items)i) order by id for update;
 perform private.validate_operational_shift(lease.business_id,lease.member_id,shift,null,true);
 perform set_config('trexven.transaction_contract','v2',true);
 perform set_config('trexven.catalog_operation','offline_cash',true);
 insert into public.sales(business_id,employee_id,total,total_amount,payment_method,status,sold_at) values(lease.business_id,lease.member_id,p_total,p_total,'cash','completed',p_occurred_at) returning id into sale;
 for x in select * from jsonb_array_elements(p_items) loop
  select s into snapshot from jsonb_array_elements(lease.scope->'products') s where s->>'id'=x->>'product_id';
  qty:=(x->>'quantity')::numeric;price:=(x->>'unit_price')::numeric;
  if snapshot is null or qty is null or qty<=0 or qty::text in('NaN','Infinity','-Infinity') or scale(qty)>3 or price is distinct from (snapshot->>'price')::numeric or coalesce((x->>'discount')::numeric,0)<>0 then raise exception 'Offline quantities and price must match signed catalog';end if;
  if lower(coalesce(snapshot->>'unit','piece')) not in('kg','g','litre','ml','metre','cm') and qty<>trunc(qty) then raise exception 'Countable offline stock requires whole units';end if;
  select * into product from public.products where id=(x->>'product_id')::uuid and business_id=lease.business_id;
  if not found then raise exception 'Original offline product is missing; retain for reconciliation';end if;
  missing:=greatest(qty-coalesce(product.quantity,0),0);
  if missing>0 then discrepancies:=discrepancies||jsonb_build_array(jsonb_build_object('product_id',product.id,'requested',qty,'shortfall',missing));end if;
  perform set_config('trexven.catalog_operation','offline_cash',true);perform set_config('trexven.catalog_request',sale::text,true);
  perform set_config('trexven.catalog_reason','Offline cash reconciliation; requested '||qty||', shortfall '||missing,true);
  update public.products set quantity=greatest(coalesce(quantity,0)-qty,0),updated_at=now() where id=product.id;
  insert into public.sale_items(sale_id,product_id,product_name,quantity,unit_price,discount,total) values(sale,product.id,snapshot->>'name',qty,price,0,round(qty*price,2));
  v_total:=v_total+round(qty*price,2);
 end loop;
 if v_total is distinct from p_total then raise exception 'Offline total mismatch';end if;
 update public.sales set sale_number='TRX-'||sale::text,subtotal=v_total where id=sale;
 insert into public.sale_payments(business_id,sale_id,request_id,actor_id,method,amount,evidence,confirmed_at) values(lease.business_id,sale,p_request_id,auth.uid(),'cash',v_total,'Signed offline cash scope',p_occurred_at);
 insert into public.offline_sale_reconciliations(business_id,sale_id,lease_id,request_id,device_id,actor_id,occurred_at,discrepancies) values(lease.business_id,sale,lease.id,p_request_id,lease.device_id,auth.uid(),p_occurred_at,discrepancies);
 if v_total>0 then perform private.record_operational_cash(lease.business_id,lease.member_id,v_total,'sale',sale,shift);end if;
 if jsonb_array_length(discrepancies)>0 then
  insert into public.audit_logs(business_id,actor_id,action,metadata) values(lease.business_id,auth.uid(),'offline_stock_discrepancy',jsonb_build_object('sale_id',sale,'discrepancies',discrepancies));
 end if;
 select to_jsonb(s)||jsonb_build_object('sale_items',(select jsonb_agg(to_jsonb(i) order by i.id) from public.sale_items i where sale_id=s.id),'offline_discrepancies',discrepancies) into receipt from public.sales s where id=sale;
 perform private.operation_save(lease.business_id,p_request_id,payload,receipt);
 perform set_config('trexven.catalog_operation','',true);perform set_config('trexven.catalog_request','',true);perform set_config('trexven.catalog_reason','',true);perform set_config('trexven.transaction_contract','',true);
 return receipt;
end $$;
revoke all on function public.issue_trexven_offline_scope(uuid,uuid,uuid),public.sync_trexven_offline_cash(uuid,jsonb,jsonb,numeric,timestamptz) from public,anon;
grant execute on function public.issue_trexven_offline_scope(uuid,uuid,uuid),public.sync_trexven_offline_cash(uuid,jsonb,jsonb,numeric,timestamptz) to authenticated;
notify pgrst,'reload schema';
insert into supabase_migrations.schema_migrations(version,name,statements) values ('20261009070340','batch_4_offline_cash_reconciliation',array[$trexven_release_source$-- Signed 24-hour per-device cash scope. No noncash/offline credit or refund.
begin;
insert into public.permissions(id,description) values('offline_cash','Owner-authorized offline cash reconciliation') on conflict(id) do nothing;
create table private.offline_cash_leases(
 id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),
 user_id uuid not null references auth.users(id),member_id uuid not null references public.business_members(id),device_id uuid not null,
 scope jsonb not null,signature text not null,signing_key bytea not null,issued_at timestamptz not null,expires_at timestamptz not null);
alter table private.offline_cash_leases enable row level security;
revoke all on private.offline_cash_leases from public,anon,authenticated;
create table public.offline_sale_reconciliations(
 id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),sale_id uuid not null references public.sales(id),
 lease_id uuid not null references private.offline_cash_leases(id),request_id uuid not null unique,
 device_id uuid not null,actor_id uuid not null references auth.users(id),occurred_at timestamptz not null,
 discrepancies jsonb not null default '[]',reviewed_by uuid references auth.users(id),review_reason text,created_at timestamptz not null default now());
alter table public.offline_sale_reconciliations enable row level security;
revoke all on public.offline_sale_reconciliations from public,anon,authenticated;
grant select on public.offline_sale_reconciliations to authenticated;
create policy "Offline reconciliation scoped read" on public.offline_sale_reconciliations for select to authenticated
 using(public.user_owns_business(business_id) or (public.is_business_member(business_id) and (actor_id=auth.uid() or private.has_business_permission(business_id,'view_finance'))));

create function public.issue_trexven_offline_scope(p_business_id uuid,p_device_id uuid,p_shift_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare member uuid; leaseid uuid:=gen_random_uuid(); secret bytea; scope jsonb; signature text; started timestamptz:=clock_timestamp();
begin
 perform private.operations_context(p_business_id,'offline_cash');
 if not private.has_business_permission(p_business_id,'complete_sales') or not private.has_business_permission(p_business_id,'pos_access') then raise exception 'Cash sale permission required' using errcode='42501';end if;
 if p_device_id is null then raise exception 'Stable device identity required';end if;
 select m.id into member from public.business_members m where business_id=p_business_id and user_id=auth.uid() and status='active';
 perform private.validate_operational_shift(p_business_id,member,p_shift_id,null,false);
 select jsonb_build_object('version',1,'lease_id',leaseid,'business_id',p_business_id,'user_id',auth.uid(),'membership_id',member,'device_id',p_device_id,
 'issued_at',started,'expires_at',started+interval '24 hours','branch_id',null,'shift_id',p_shift_id,'products',coalesce(jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'unit',p.unit,'price',p.selling_price,'quantity',p.quantity,'barcode',p.barcode,'sku',p.sku) order by p.id),'[]'::jsonb)) into scope
 from public.products p where business_id=p_business_id and p.selling_price is not null and p.active is true and p.is_active;
 secret:=extensions.gen_random_bytes(32);
 signature:=encode(extensions.hmac(convert_to(scope::text,'UTF8'),secret,'sha256'),'hex');
 insert into private.offline_cash_leases values(leaseid,p_business_id,auth.uid(),member,p_device_id,scope,signature,secret,started,started+interval '24 hours');
 return jsonb_build_object('scope',scope,'signature',signature);
end $$;

create function public.sync_trexven_offline_cash(p_request_id uuid,p_ticket jsonb,p_items jsonb,p_total numeric,p_occurred_at timestamptz)
returns jsonb language plpgsql security definer set search_path='' as $$
declare lease private.offline_cash_leases%rowtype; payload jsonb; prior jsonb; receipt jsonb; sale uuid; x jsonb; snapshot jsonb;
 product public.products%rowtype; qty numeric; price numeric; v_total numeric:=0; missing numeric; discrepancies jsonb:='[]'; shift uuid;
begin
 select * into lease from private.offline_cash_leases where id=(p_ticket->'scope'->>'lease_id')::uuid;
 if not found or auth.uid() is distinct from lease.user_id or p_ticket->'scope' is distinct from lease.scope or
 p_ticket->>'signature' is distinct from encode(extensions.hmac(convert_to(lease.scope::text,'UTF8'),lease.signing_key,'sha256'),'hex') then raise exception 'Invalid signed offline authorization' using errcode='42501';end if;
 perform private.operations_context(lease.business_id,'offline_cash');
 if not private.has_business_permission(lease.business_id,'complete_sales') or not exists(select 1 from public.business_members where id=lease.member_id and user_id=auth.uid() and business_id=lease.business_id and status='active') then raise exception 'Current sale authorization required; retain queue for owner review' using errcode='42501';end if;
 payload:=jsonb_build_object('operation','offline_cash','ticket',p_ticket,'items',p_items,'total',p_total,'occurred_at',p_occurred_at);
 perform pg_advisory_xact_lock(hashtextextended(lease.business_id::text||auth.uid()::text||p_request_id::text,0));
 prior:=private.operation_replay(lease.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 if exists(select 1 from private.sale_requests where business_id=lease.business_id and user_id=auth.uid() and request_id=p_request_id) then raise exception 'This key belongs to an original checkout; recover that receipt before another submission';end if;
 if exists(select 1 from public.businesses where id=lease.business_id and pos_writes_paused) then raise exception 'POS writes are paused; retain the encrypted cash queue';end if;
 if p_occurred_at is null or p_occurred_at<lease.issued_at or p_occurred_at>=lease.expires_at or p_occurred_at>clock_timestamp()+interval '5 minutes'
 or not private.valid_money(p_total,true) or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Cash sale is outside its authorized scope';end if;
 if exists(select 1 from jsonb_array_elements(p_items) i group by i->>'product_id' having count(*)>1) then raise exception 'Duplicate offline product';end if;
 shift:=(lease.scope->>'shift_id')::uuid;
 perform id from public.products where business_id=lease.business_id and id in(select (i->>'product_id')::uuid from jsonb_array_elements(p_items)i) order by id for update;
 perform private.validate_operational_shift(lease.business_id,lease.member_id,shift,null,true);
 perform set_config('trexven.transaction_contract','v2',true);
 perform set_config('trexven.catalog_operation','offline_cash',true);
 insert into public.sales(business_id,employee_id,total,total_amount,payment_method,status,sold_at) values(lease.business_id,lease.member_id,p_total,p_total,'cash','completed',p_occurred_at) returning id into sale;
 for x in select * from jsonb_array_elements(p_items) loop
  select s into snapshot from jsonb_array_elements(lease.scope->'products') s where s->>'id'=x->>'product_id';
  qty:=(x->>'quantity')::numeric;price:=(x->>'unit_price')::numeric;
  if snapshot is null or qty is null or qty<=0 or qty::text in('NaN','Infinity','-Infinity') or scale(qty)>3 or price is distinct from (snapshot->>'price')::numeric or coalesce((x->>'discount')::numeric,0)<>0 then raise exception 'Offline quantities and price must match signed catalog';end if;
  if lower(coalesce(snapshot->>'unit','piece')) not in('kg','g','litre','ml','metre','cm') and qty<>trunc(qty) then raise exception 'Countable offline stock requires whole units';end if;
  select * into product from public.products where id=(x->>'product_id')::uuid and business_id=lease.business_id;
  if not found then raise exception 'Original offline product is missing; retain for reconciliation';end if;
  missing:=greatest(qty-coalesce(product.quantity,0),0);
  if missing>0 then discrepancies:=discrepancies||jsonb_build_array(jsonb_build_object('product_id',product.id,'requested',qty,'shortfall',missing));end if;
  perform set_config('trexven.catalog_operation','offline_cash',true);perform set_config('trexven.catalog_request',sale::text,true);
  perform set_config('trexven.catalog_reason','Offline cash reconciliation; requested '||qty||', shortfall '||missing,true);
  update public.products set quantity=greatest(coalesce(quantity,0)-qty,0),updated_at=now() where id=product.id;
  insert into public.sale_items(sale_id,product_id,product_name,quantity,unit_price,discount,total) values(sale,product.id,snapshot->>'name',qty,price,0,round(qty*price,2));
  v_total:=v_total+round(qty*price,2);
 end loop;
 if v_total is distinct from p_total then raise exception 'Offline total mismatch';end if;
 update public.sales set sale_number='TRX-'||sale::text,subtotal=v_total where id=sale;
 insert into public.sale_payments(business_id,sale_id,request_id,actor_id,method,amount,evidence,confirmed_at) values(lease.business_id,sale,p_request_id,auth.uid(),'cash',v_total,'Signed offline cash scope',p_occurred_at);
 insert into public.offline_sale_reconciliations(business_id,sale_id,lease_id,request_id,device_id,actor_id,occurred_at,discrepancies) values(lease.business_id,sale,lease.id,p_request_id,lease.device_id,auth.uid(),p_occurred_at,discrepancies);
 if v_total>0 then perform private.record_operational_cash(lease.business_id,lease.member_id,v_total,'sale',sale,shift);end if;
 if jsonb_array_length(discrepancies)>0 then
  insert into public.audit_logs(business_id,actor_id,action,metadata) values(lease.business_id,auth.uid(),'offline_stock_discrepancy',jsonb_build_object('sale_id',sale,'discrepancies',discrepancies));
 end if;
 select to_jsonb(s)||jsonb_build_object('sale_items',(select jsonb_agg(to_jsonb(i) order by i.id) from public.sale_items i where sale_id=s.id),'offline_discrepancies',discrepancies) into receipt from public.sales s where id=sale;
 perform private.operation_save(lease.business_id,p_request_id,payload,receipt);
 perform set_config('trexven.catalog_operation','',true);perform set_config('trexven.catalog_request','',true);perform set_config('trexven.catalog_reason','',true);perform set_config('trexven.transaction_contract','',true);
 return receipt;
end $$;
revoke all on function public.issue_trexven_offline_scope(uuid,uuid,uuid),public.sync_trexven_offline_cash(uuid,jsonb,jsonb,numeric,timestamptz) from public,anon;
grant execute on function public.issue_trexven_offline_scope(uuid,uuid,uuid),public.sync_trexven_offline_cash(uuid,jsonb,jsonb,numeric,timestamptz) to authenticated;
notify pgrst,'reload schema';
commit;
$trexven_release_source$]::text[]);
commit;
