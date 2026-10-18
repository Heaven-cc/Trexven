-- Batch 4: additive transaction evidence, credit and inspected returns.
-- Local/staging only until a separate consolidated production authorization.
begin;
-- Preserve the historical payment-method constraint and existing values.
alter table public.sales add column payment_kind text check(payment_kind in('cash','bank_transfer','card','split','credit'));
insert into public.permissions(id,description) values
 ('approve_credit','Explicit manager approval of a specific credit sale'),
 ('record_credit_repayment','Record confirmed credit repayments'),
 ('approve_refund','Explicit manager authority to approve inspected returns'),
 ('inspect_returns','Inspect returned goods before stock disposition') on conflict(id) do nothing;

create function private.operations_context(business uuid,permission text,branch uuid default null,sensitive boolean default false)
returns void language plpgsql security definer set search_path='' as $$
declare enabled boolean;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 select branches_enabled into enabled from public.businesses where id=business for share;
 if not found then raise exception 'Business access denied' using errcode='42501'; end if;
 perform id from public.employees where business_id=business and user_id=auth.uid() for share;
 perform id from public.business_members where business_id=business and user_id=auth.uid() for share;
 if not private.has_business_permission(business,permission) then raise exception 'Operation permission denied' using errcode='42501'; end if;
 if sensitive and not public.user_owns_business(business) and not exists(
  select 1 from public.employees e join public.employee_permissions p on p.employee_id=e.id
  where e.business_id=business and e.user_id=auth.uid() and e.status='active' and e.role='manager'
  and p.permission_id=permission and p.granted) then
  raise exception 'Explicit owner-granted manager permission required' using errcode='42501'; end if;
 if enabled and (branch is null or not private.has_branch_access(business,branch)) then raise exception 'Authorized branch required' using errcode='42501'; end if;
 if not enabled and branch is not null then raise exception 'Branches are dormant' using errcode='42501'; end if;
end $$;
revoke all on function private.operations_context(uuid,text,uuid,boolean) from public,anon,authenticated;

create table private.operation_cancellations(request_id uuid primary key,business_id uuid not null references public.businesses(id),
 actor_id uuid not null references auth.users(id),created_at timestamptz not null default now());
alter table private.operation_cancellations enable row level security;
revoke all on private.operation_cancellations from public,anon,authenticated;
create function private.operation_replay(business uuid,request uuid,payload jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare prior private.catalog_requests%rowtype;
begin
 if request is null then raise exception 'Durable request ID required'; end if;
 perform pg_advisory_xact_lock(hashtextextended(request::text,0));
 if exists(select 1 from private.operation_cancellations c where c.request_id=request) then
  if exists(select 1 from private.operation_cancellations c where c.request_id=request and c.business_id=business and c.actor_id=auth.uid()) then raise exception 'This operation was explicitly cancelled before commitment';end if;
  raise exception 'Request identity conflict' using errcode='42501';
 end if;
 select * into prior from private.catalog_requests where request_id=request;
 if found then
  if prior.business_id<>business or prior.actor_id<>auth.uid() or prior.payload<>payload then raise exception 'Request identity conflict' using errcode='42501'; end if;
  return prior.response;
 end if;
 return null;
end $$;
create function private.operation_save(business uuid,request uuid,payload jsonb,response jsonb)
returns void language sql security definer set search_path='' as $$
 insert into private.catalog_requests(request_id,business_id,actor_id,payload,response) values(request,business,auth.uid(),payload,response)
$$;
revoke all on function private.operation_replay(uuid,uuid,jsonb),private.operation_save(uuid,uuid,jsonb,jsonb) from public,anon,authenticated;

create function private.valid_money(amount numeric,allow_zero boolean default false) returns boolean
language sql immutable set search_path='' as $$
 select amount is not null and amount::text not in ('NaN','Infinity','-Infinity') and scale(amount)<=2 and (amount>0 or (allow_zero and amount=0))
$$;
revoke all on function private.valid_money(numeric,boolean) from public,anon,authenticated;

-- Replaced by the Batch 6 shared-drawer implementation; no new legacy cash record.
create function private.record_operational_cash(business uuid,member uuid,amount numeric,kind text,reference uuid,shift uuid default null)
returns void language plpgsql security definer set search_path='' as $$ begin return; end $$;
create function private.validate_operational_shift(business uuid,member uuid,shift uuid,branch uuid default null,offline boolean default false)
returns void language plpgsql security definer set search_path='' as $$ begin
 if shift is not null then raise exception 'Cash shift contract is not installed yet'; end if;
end $$;
revoke all on function private.record_operational_cash(uuid,uuid,numeric,text,uuid,uuid),private.validate_operational_shift(uuid,uuid,uuid,uuid,boolean) from public,anon,authenticated;

create table public.sale_payments(
 id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),
 sale_id uuid not null references public.sales(id),request_id uuid not null,actor_id uuid not null references auth.users(id),
 method text not null check(method in ('cash','bank_transfer','card')),amount numeric(18,2) not null check(amount>=0),
 evidence text,confirmed_at timestamptz not null default now(),unique(request_id,method));
create index sale_payments_business_sale on public.sale_payments(business_id,sale_id);
create table public.credit_approvals(
 id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),branch_id uuid references public.branches(id),
 request_id uuid not null unique,requested_by uuid not null references auth.users(id),payload jsonb not null,
 status text not null default 'pending' check(status in ('pending','approved','rejected')),
 approved_by uuid references auth.users(id),over_limit_reason text,created_at timestamptz not null default now(),decided_at timestamptz);
create table public.credit_limits(
 id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),branch_id uuid references public.branches(id),
 amount numeric(18,2) not null check(amount>=0),unique nulls not distinct(business_id,branch_id));
create table public.credit_accounts(
 sale_id uuid primary key references public.sales(id),business_id uuid not null references public.businesses(id),branch_id uuid references public.branches(id),
 debtor_name text not null,contact text not null,due_date date not null,original_amount numeric(18,2) not null check(original_amount>0),
 outstanding numeric(18,2) not null check(outstanding>=0),approval_id uuid not null unique references public.credit_approvals(id),created_at timestamptz not null default now());
create index credit_accounts_business_due on public.credit_accounts(business_id,due_date) where outstanding>0;
create table public.credit_entries(
 id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),sale_id uuid not null references public.credit_accounts(sale_id),
 request_id uuid not null unique,actor_id uuid not null references auth.users(id),kind text not null check(kind in('sale','repayment','return','repayment_reversal')),
 amount numeric(18,2) not null,method text check(method in('cash','bank_transfer','card')),evidence text,reason text,reference_id uuid,created_at timestamptz not null default now());
create table public.sale_returns(
 id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),sale_id uuid not null references public.sales(id),branch_id uuid references public.branches(id),
 request_id uuid not null unique,requested_by uuid not null references auth.users(id),reason text not null,
 status text not null default 'requested' check(status in('requested','inspected','approved','rejected')),
 inspected_by uuid references auth.users(id),approved_by uuid references auth.users(id),value numeric(18,2),debt_reduction numeric(18,2),
 refund_amount numeric(18,2),refund_method text,refund_evidence text,created_at timestamptz not null default now(),approved_at timestamptz);
create table public.return_items(
 id uuid primary key default gen_random_uuid(),return_id uuid not null references public.sale_returns(id),sale_item_id uuid not null references public.sale_items(id),
 quantity numeric(18,3) not null check(quantity>0),condition text check(condition in('sellable','damaged','defective')),value numeric(18,2),unique(return_id,sale_item_id));

do $$ declare t text; begin
 foreach t in array array['sale_payments','credit_approvals','credit_limits','credit_accounts','credit_entries','sale_returns','return_items'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('revoke all on public.%I from public,anon,authenticated',t);
  execute format('grant select on public.%I to authenticated',t);
 end loop;
end $$;
create policy "Payment authorized read" on public.sale_payments for select to authenticated using(exists(select 1 from public.sales s where s.id=sale_id));
create policy "Credit approval scoped read" on public.credit_approvals for select to authenticated using(public.user_owns_business(business_id) or requested_by=auth.uid() or private.has_business_permission(business_id,'approve_credit'));
create policy "Credit limit owner read" on public.credit_limits for select to authenticated using(public.user_owns_business(business_id));
create policy "Credit account scoped read" on public.credit_accounts for select to authenticated using(public.user_owns_business(business_id) or private.has_business_permission(business_id,'view_finance') or private.has_business_permission(business_id,'record_credit_repayment'));
create policy "Credit entry scoped read" on public.credit_entries for select to authenticated using(exists(select 1 from public.credit_accounts a where a.sale_id=credit_entries.sale_id));
create policy "Return scoped read" on public.sale_returns for select to authenticated using(public.user_owns_business(business_id) or requested_by=auth.uid() or private.has_business_permission(business_id,'inspect_returns') or private.has_business_permission(business_id,'approve_refund'));
create policy "Return item scoped read" on public.return_items for select to authenticated using(exists(select 1 from public.sale_returns r where r.id=return_id));
create policy "Credit approval membership boundary" on public.credit_approvals as restrictive for select to authenticated
 using(public.user_owns_business(business_id) or (public.is_business_member(business_id) and (branch_id is null or private.has_branch_access(business_id,branch_id))));
create policy "Credit account branch boundary" on public.credit_accounts as restrictive for select to authenticated
 using(public.user_owns_business(business_id) or (public.is_business_member(business_id) and (branch_id is null or private.has_branch_access(business_id,branch_id))));
create policy "Return membership boundary" on public.sale_returns as restrictive for select to authenticated
 using(public.user_owns_business(business_id) or (public.is_business_member(business_id) and (branch_id is null or private.has_branch_access(business_id,branch_id))));

create function public.cancel_trexven_uncommitted_operation(p_business_id uuid,p_request_id uuid,p_no_money_moved boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare prior private.catalog_requests%rowtype; cancellation private.operation_cancellations%rowtype;
begin
 if p_request_id is null or p_no_money_moved is distinct from true or not public.is_business_member(p_business_id) then raise exception 'Original authorized context and explicit no-money-moved confirmation required' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_business_id::text||auth.uid()::text||p_request_id::text,0));
 perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
 if exists(select 1 from private.sale_requests where request_id=p_request_id) then raise exception 'Checkout already committed. Recover its original receipt.';end if;
 select * into prior from private.catalog_requests where request_id=p_request_id;
 if found then
  if prior.business_id<>p_business_id or prior.actor_id<>auth.uid() then raise exception 'Request identity denied' using errcode='42501';end if;
  raise exception 'Operation already committed. Recover and inspect its server receipt; it cannot be discarded.';
 end if;
 select * into cancellation from private.operation_cancellations where request_id=p_request_id;
 if found and (cancellation.business_id<>p_business_id or cancellation.actor_id<>auth.uid()) then raise exception 'Cancellation context mismatch' using errcode='42501';end if;
 insert into private.operation_cancellations(request_id,business_id,actor_id) values(p_request_id,p_business_id,auth.uid()) on conflict do nothing;
 return jsonb_build_object('status','cancelled');
end $$;

create function public.request_trexven_credit_approval(p_business_id uuid,p_request_id uuid,p_payload jsonb,p_branch_id uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare prior public.credit_approvals%rowtype; result uuid;
begin
 perform private.operations_context(p_business_id,'complete_sales',p_branch_id);
 if p_request_id is null or jsonb_typeof(p_payload)<>'object' or nullif(btrim(p_payload->'credit'->>'debtor_name'),'') is null
 or nullif(btrim(p_payload->'credit'->>'contact'),'') is null or (p_payload->'credit'->>'due_date')::date is null then raise exception 'Debtor, contact and due date required'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
 select * into prior from public.credit_approvals where request_id=p_request_id;
 if found then
  if prior.business_id<>p_business_id or prior.requested_by<>auth.uid() or prior.payload<>p_payload or prior.branch_id is distinct from p_branch_id then raise exception 'Approval request conflict' using errcode='42501'; end if;
  return prior.id;
 end if;
 insert into public.credit_approvals(business_id,branch_id,request_id,requested_by,payload) values(p_business_id,p_branch_id,p_request_id,auth.uid(),p_payload) returning id into result;
 return result;
end $$;

create function public.decide_trexven_credit_approval(p_approval_id uuid,p_approve boolean,p_over_limit_reason text default null)
returns void language plpgsql security definer set search_path='' as $$
declare a public.credit_approvals%rowtype;
begin
 select * into a from public.credit_approvals where id=p_approval_id;
 if not found or p_approve is null then raise exception 'Approval not found' using errcode='42501'; end if;
 perform private.operations_context(a.business_id,'approve_credit',a.branch_id,true);
 if nullif(btrim(p_over_limit_reason),'') is not null and not public.user_owns_business(a.business_id) then raise exception 'Only owner may approve an exposure exception' using errcode='42501'; end if;
 select * into a from public.credit_approvals where id=p_approval_id for update;
 if a.status<>'pending' then
  if a.status=(case when p_approve then 'approved' else 'rejected' end) and a.approved_by=auth.uid() and a.over_limit_reason is not distinct from nullif(btrim(p_over_limit_reason),'') then return; end if;
  raise exception 'Approval decision is final'; end if;
 update public.credit_approvals set status=case when p_approve then 'approved' else 'rejected' end,approved_by=auth.uid(),over_limit_reason=nullif(btrim(p_over_limit_reason),''),decided_at=now() where id=a.id;
 insert into public.audit_logs(business_id,actor_id,action,metadata) values(a.business_id,auth.uid(),'credit_approval_decided',jsonb_build_object('approval_id',a.id,'approved',p_approve,'exception_reason',p_over_limit_reason));
end $$;

create function public.set_trexven_credit_limit(p_business_id uuid,p_amount numeric,p_branch_id uuid default null)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.user_owns_business(p_business_id) then raise exception 'Owner required' using errcode='42501'; end if;
 if not private.valid_money(p_amount,true) or (p_branch_id is not null and not exists(select 1 from public.branches where id=p_branch_id and business_id=p_business_id)) then raise exception 'Invalid limit or branch'; end if;
 perform pg_advisory_xact_lock(hashtextextended(p_business_id::text||':credit',0));
 insert into public.credit_limits(business_id,branch_id,amount) values(p_business_id,p_branch_id,p_amount) on conflict(business_id,branch_id) do update set amount=excluded.amount;
 insert into public.audit_logs(business_id,actor_id,action,metadata) values(p_business_id,auth.uid(),'credit_limit_set',jsonb_build_object('branch_id',p_branch_id,'amount',p_amount));
end $$;

create function public.complete_trexven_transaction(p_request_id uuid,p_business_id uuid,p_employee_id uuid,p_total numeric,p_items jsonb,
 p_payments jsonb,p_credit jsonb default null,p_branch_id uuid default null,p_shift_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare payload jsonb; previous jsonb; line jsonb; paid numeric:=0; cash numeric:=0; debt numeric; a public.credit_approvals%rowtype;
 sale uuid; result jsonb; member uuid; exposure numeric; ceiling numeric; method text; legacy private.sale_requests%rowtype;
begin
 perform private.operations_context(p_business_id,'complete_sales',p_branch_id);
 if not private.has_business_permission(p_business_id,'pos_access') then raise exception 'POS access required' using errcode='42501'; end if;
 select id into member from public.business_members where business_id=p_business_id and user_id=auth.uid() and status='active';
 if member is distinct from p_employee_id then raise exception 'Membership identity mismatch' using errcode='42501'; end if;
 payload:=jsonb_build_object('operation','transaction','member',p_employee_id,'total',p_total,'items',p_items,'payments',p_payments,'credit',p_credit,'branch',p_branch_id,'shift',p_shift_id);
 -- Serialize with the original POS request contract before taking the shared
 -- operation key. A format transition can never create a second legacy sale.
 perform pg_advisory_xact_lock(hashtextextended(p_business_id::text||auth.uid()::text||p_request_id::text,0));
 previous:=private.operation_replay(p_business_id,p_request_id,payload); if previous is not null then return previous; end if;
 select * into legacy from private.sale_requests where business_id=p_business_id and user_id=auth.uid() and request_id=p_request_id;
 if found then
  if legacy.payload->>'employee' is distinct from p_employee_id::text or (legacy.payload->>'total')::numeric is distinct from p_total
  or legacy.payload->'items' is distinct from p_items or (legacy.payload->>'quick')::boolean is distinct from false
  or p_credit is not null or jsonb_typeof(p_payments) is distinct from 'array' or jsonb_array_length(p_payments)<>1
  or p_payments->0->>'method' is distinct from legacy.payload->>'payment' or (p_payments->0->>'amount')::numeric is distinct from p_total
  or (p_payments->0->>'confirmed')::boolean is distinct from true or (p_branch_id is not null and p_branch_id is distinct from legacy.branch_id)
  then raise exception 'Legacy request identity conflict; recover its original receipt' using errcode='42501';end if;
  if legacy.branch_id is not null and not private.has_branch_access(p_business_id,legacy.branch_id) then raise exception 'Branch access denied' using errcode='42501';end if;
  return legacy.receipt;
 end if;
 if exists(select 1 from public.businesses where id=p_business_id and pos_writes_paused) then raise exception 'New POS writes are paused; existing receipts remain recoverable';end if;
 if not private.valid_money(p_total,true) or jsonb_typeof(p_payments)<>'array' or jsonb_array_length(p_payments)>3 then raise exception 'Valid total and payment lines required'; end if;
 if exists(select 1 from jsonb_array_elements(p_payments) x group by x->>'method' having count(*)>1) then raise exception 'Combine repeated payment methods'; end if;
 for line in select * from jsonb_array_elements(p_payments) loop
  if not private.valid_money((line->>'amount')::numeric,true) or line->>'method' not in('cash','bank_transfer','card')
  or (line->>'confirmed')::boolean is distinct from true then raise exception 'Payment must be explicitly confirmed'; end if;
  if line->>'method'<>'cash' and nullif(btrim(line->>'evidence'),'') is null then raise exception 'Verified external payment reference required; screenshots are insufficient'; end if;
  paid:=paid+(line->>'amount')::numeric; if line->>'method'='cash' then cash:=cash+(line->>'amount')::numeric; end if;
 end loop;
 if paid>p_total then raise exception 'Payment exceeds total'; end if;
 debt:=p_total-paid;
 if debt>0 then
  if p_credit is null or (p_credit->>'approval_id') is null then raise exception 'Per-sale credit approval required'; end if;
  select * into a from public.credit_approvals where id=(p_credit->>'approval_id')::uuid for update;
  if not found or a.business_id<>p_business_id or a.request_id<>p_request_id or a.requested_by<>auth.uid() or a.status<>'approved'
  or a.branch_id is distinct from p_branch_id or a.payload is distinct from jsonb_build_object('member',p_employee_id,'total',p_total,'items',p_items,'payments',p_payments,'credit',p_credit-'approval_id','branch',p_branch_id,'shift',p_shift_id) then raise exception 'Credit approval does not match exact transaction' using errcode='42501'; end if;
  if (p_credit->>'due_date')::date < (public.get_trexven_business_day(p_business_id)->>'local_date')::date then raise exception 'Credit due date is in the past'; end if;
  perform pg_advisory_xact_lock(hashtextextended(p_business_id::text||':credit',0));
  select coalesce(sum(outstanding),0) into exposure from public.credit_accounts where business_id=p_business_id;
  select amount into ceiling from public.credit_limits where business_id=p_business_id and branch_id is null;
  if ceiling is not null and exposure+debt>ceiling and not (a.approved_by=(select owner_id from public.businesses where id=p_business_id) and a.over_limit_reason is not null) then raise exception 'Business credit exposure limit exceeded'; end if;
  if p_branch_id is not null then
   select coalesce(sum(outstanding),0) into exposure from public.credit_accounts where business_id=p_business_id and branch_id=p_branch_id;
   select amount into ceiling from public.credit_limits where business_id=p_business_id and branch_id=p_branch_id;
   if ceiling is not null and exposure+debt>ceiling and not (a.approved_by=(select owner_id from public.businesses where id=p_business_id) and a.over_limit_reason is not null) then raise exception 'Branch credit exposure limit exceeded'; end if;
  end if;
 elsif p_credit is not null then raise exception 'Credit details supplied for fully paid sale'; end if;
 -- Match legacy checkout's product-before-drawer lock order.
 perform id from public.products where business_id=p_business_id and id in(select (x->>'product_id')::uuid from jsonb_array_elements(p_items) x) order by id for update;
 if cash>0 then perform private.validate_operational_shift(p_business_id,member,p_shift_id,p_branch_id); end if;
 perform set_config('trexven.transaction_contract','v2',true);
 -- Reuse trusted Batch 3 stock/price validation. The recorded payment lines,
 -- rather than a fabricated full cash payment, are authoritative for collections.
 sale:=private.process_trexven_sale(p_business_id,p_employee_id,p_total,'other',p_items,false,p_branch_id);
 method:=case when debt>0 then 'credit' when jsonb_array_length(p_payments)=1 then p_payments->0->>'method' else 'split' end;
 update public.sales set payment_method=case when method in('credit','split') then 'other' else method end,payment_kind=method,sale_number='TRX-'||sale::text,customer_name=p_credit->>'debtor_name' where id=sale;
 for line in select * from jsonb_array_elements(p_payments) loop
  insert into public.sale_payments(business_id,sale_id,request_id,actor_id,method,amount,evidence) values(p_business_id,sale,p_request_id,auth.uid(),line->>'method',(line->>'amount')::numeric,line->>'evidence');
 end loop;
 if debt>0 then
  insert into public.credit_accounts(sale_id,business_id,branch_id,debtor_name,contact,due_date,original_amount,outstanding,approval_id)
  values(sale,p_business_id,p_branch_id,p_credit->>'debtor_name',p_credit->>'contact',(p_credit->>'due_date')::date,debt,debt,a.id);
  insert into public.credit_entries(business_id,sale_id,request_id,actor_id,kind,amount) values(p_business_id,sale,p_request_id,auth.uid(),'sale',debt);
 end if;
 if cash>0 then perform private.record_operational_cash(p_business_id,member,cash,'sale',sale,p_shift_id); end if;
 select to_jsonb(s)||jsonb_build_object('sale_items',(select jsonb_agg(to_jsonb(i) order by i.id) from public.sale_items i where i.sale_id=s.id),
 'payments',p_payments,'outstanding',debt) into result from public.sales s where s.id=sale;
 perform private.operation_save(p_business_id,p_request_id,payload,result);
 insert into private.sale_requests(business_id,user_id,request_id,payload,receipt,branch_id)
 values(p_business_id,auth.uid(),p_request_id,jsonb_build_object('employee',p_employee_id,'total',p_total,'payment',case when method in('credit','split') then 'other' else method end,'items',p_items,'quick',false),result,p_branch_id);
 perform set_config('trexven.transaction_contract','',true);return result;
end $$;

create function public.repay_trexven_credit(p_sale_id uuid,p_request_id uuid,p_amount numeric,p_method text,p_confirmed boolean,p_evidence text default null,p_shift_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare a public.credit_accounts%rowtype; payload jsonb; previous jsonb; result jsonb; member uuid;
begin
 select * into a from public.credit_accounts where sale_id=p_sale_id;
 if not found then raise exception 'Credit account not found' using errcode='42501'; end if;
 perform private.operations_context(a.business_id,'record_credit_repayment',a.branch_id);
 payload:=jsonb_build_object('operation','repayment','sale',p_sale_id,'amount',p_amount,'method',p_method,'confirmed',p_confirmed,'evidence',p_evidence,'shift',p_shift_id);
 previous:=private.operation_replay(a.business_id,p_request_id,payload);if previous is not null then return previous;end if;
 if not private.valid_money(p_amount) or p_confirmed is distinct from true or p_method not in('cash','bank_transfer','card') or (p_method<>'cash' and nullif(btrim(p_evidence),'')is null) then raise exception 'Confirmed repayment and external reference required'; end if;
 select * into a from public.credit_accounts where sale_id=p_sale_id for update;
 if p_amount>a.outstanding then raise exception 'Repayment exceeds outstanding balance'; end if;
 select id into member from public.business_members where business_id=a.business_id and user_id=auth.uid() and status='active';
 if p_method='cash' then perform private.validate_operational_shift(a.business_id,member,p_shift_id,a.branch_id);end if;
 insert into public.credit_entries(business_id,sale_id,request_id,actor_id,kind,amount,method,evidence) values(a.business_id,p_sale_id,p_request_id,auth.uid(),'repayment',-p_amount,p_method,p_evidence);
 update public.credit_accounts set outstanding=outstanding-p_amount where sale_id=p_sale_id returning jsonb_build_object('sale_id',sale_id,'outstanding',outstanding) into result;
 if p_method='cash' then perform private.record_operational_cash(a.business_id,member,p_amount,'repayment',p_request_id,p_shift_id);end if;
 perform private.operation_save(a.business_id,p_request_id,payload,result);return result;
end $$;

create function public.request_trexven_return(p_sale_id uuid,p_request_id uuid,p_items jsonb,p_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare s public.sales%rowtype; line jsonb; item public.sale_items%rowtype; payload jsonb; previous jsonb; result uuid;
begin
 select * into s from public.sales where id=p_sale_id;
 if not found then raise exception 'Sale not found' using errcode='42501'; end if;
 perform private.operations_context(s.business_id,'complete_sales',s.branch_id);
 payload:=jsonb_build_object('operation','return_request','sale',p_sale_id,'items',p_items,'reason',p_reason);
 previous:=private.operation_replay(s.business_id,p_request_id,payload);if previous is not null then return (previous->>'id')::uuid;end if;
 if nullif(btrim(p_reason),'')is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Original sale items and reason required'; end if;
 if exists(select 1 from jsonb_array_elements(p_items) x group by x->>'sale_item_id' having count(*)>1) then raise exception 'Duplicate return item'; end if;
 insert into public.sale_returns(business_id,sale_id,branch_id,request_id,requested_by,reason) values(s.business_id,s.id,s.branch_id,p_request_id,auth.uid(),p_reason) returning id into result;
 for line in select * from jsonb_array_elements(p_items) loop
  select * into item from public.sale_items where id=(line->>'sale_item_id')::uuid and sale_id=s.id;
  if not found or (line->>'quantity')::numeric is null or (line->>'quantity')::numeric<=0 or (line->>'quantity')::numeric>item.quantity or scale((line->>'quantity')::numeric)>3 then raise exception 'Invalid original-sale return quantity';end if;
  insert into public.return_items(return_id,sale_item_id,quantity) values(result,item.id,(line->>'quantity')::numeric);
 end loop;
 perform private.operation_save(s.business_id,p_request_id,payload,jsonb_build_object('id',result));return result;
end $$;

create function public.inspect_trexven_return(p_return_id uuid,p_request_id uuid,p_conditions jsonb)
returns void language plpgsql security definer set search_path='' as $$
declare r public.sale_returns%rowtype; line jsonb; payload jsonb; previous jsonb;
begin
 select * into r from public.sale_returns where id=p_return_id;
 if not found then raise exception 'Return not found' using errcode='42501';end if;
 perform private.operations_context(r.business_id,'inspect_returns',r.branch_id);
 payload:=jsonb_build_object('operation','return_inspection','return',p_return_id,'conditions',p_conditions);
 previous:=private.operation_replay(r.business_id,p_request_id,payload);if previous is not null then return;end if;
 select * into r from public.sale_returns where id=p_return_id for update;
 if r.status<>'requested' or jsonb_typeof(p_conditions)<>'array' or jsonb_array_length(p_conditions)<>(select count(*) from public.return_items where return_id=r.id) then raise exception 'Inspect every return item once';end if;
 if exists(select 1 from jsonb_array_elements(p_conditions) x group by x->>'sale_item_id' having count(*)>1) then raise exception 'Duplicate inspection item';end if;
 for line in select * from jsonb_array_elements(p_conditions) loop
  if line->>'condition' not in('sellable','damaged','defective') then raise exception 'Valid inspected condition required';end if;
  update public.return_items set condition=line->>'condition' where return_id=r.id and sale_item_id=(line->>'sale_item_id')::uuid;
  if not found then raise exception 'Inspection item mismatch';end if;
 end loop;
 update public.sale_returns set status='inspected',inspected_by=auth.uid() where id=r.id;
 perform private.operation_save(r.business_id,p_request_id,payload,jsonb_build_object('inspected',true));
end $$;

create function public.approve_trexven_return(p_return_id uuid,p_request_id uuid,p_method text,p_confirmed boolean,p_evidence text default null,p_shift_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.sale_returns%rowtype; s public.sales%rowtype; a public.credit_accounts%rowtype; x record;
 returned numeric; consumed numeric; v_value numeric:=0; reduction numeric:=0; refund numeric; available numeric; member uuid; payload jsonb; previous jsonb; result jsonb;
begin
 select * into r from public.sale_returns where id=p_return_id;
 if not found then raise exception 'Return not found' using errcode='42501';end if;
 perform private.operations_context(r.business_id,'approve_refund',r.branch_id,true);
 payload:=jsonb_build_object('operation','return_approval','return',p_return_id,'method',p_method,'confirmed',p_confirmed,'evidence',p_evidence,'shift',p_shift_id);
 previous:=private.operation_replay(r.business_id,p_request_id,payload);if previous is not null then return previous;end if;
 select * into s from public.sales where id=r.sale_id for update;
 select * into r from public.sale_returns where id=p_return_id for update;
 if r.status<>'inspected' then raise exception 'Separate condition inspection required';end if;
 for x in select i.*,si.product_id,si.quantity sold_qty,si.total sold_value from public.return_items i join public.sale_items si on si.id=i.sale_item_id where i.return_id=r.id order by si.product_id,i.sale_item_id loop
  select coalesce(sum(i.quantity),0),coalesce(sum(i.value),0) into returned,consumed from public.return_items i join public.sale_returns old on old.id=i.return_id where i.sale_item_id=x.sale_item_id and old.status='approved';
  if returned+x.quantity>x.sold_qty then raise exception 'Return exceeds remaining original quantity';end if;
  if x.quantity+returned=x.sold_qty then available:=x.sold_value-consumed;else available:=least(x.sold_value-consumed,round(x.sold_value*x.quantity/x.sold_qty,2));end if;
  update public.return_items set value=available where id=x.id;v_value:=v_value+available;
 end loop;
 select * into a from public.credit_accounts where sale_id=r.sale_id for update;
 if found then reduction:=least(a.outstanding,v_value);end if;
 refund:=v_value-reduction;
 if refund>0 then
  if p_method not in('cash','bank_transfer','card') or p_confirmed is distinct from true or (p_method<>'cash' and nullif(btrim(p_evidence),'')is null) then raise exception 'Confirm actual refund and external reference';end if;
  select coalesce(sum(amount),0) into available from public.sale_payments where sale_id=r.sale_id and method=p_method;
  if not exists(select 1 from public.sale_payments where sale_id=r.sale_id) and s.payment_method=p_method then available:=s.total;end if;
  available:=available+coalesce((select -sum(amount) from public.credit_entries where sale_id=r.sale_id and kind in('repayment','repayment_reversal') and method=p_method),0)-coalesce((select sum(refund_amount) from public.sale_returns where sale_id=r.sale_id and status='approved' and refund_method=p_method),0);
  if refund>available then raise exception 'Refund exceeds money actually collected by this method';end if;
 end if;
 select id into member from public.business_members where business_id=r.business_id and user_id=auth.uid() and status='active';
 perform p.id from public.products p where p.business_id=r.business_id and p.id in(select si.product_id from public.return_items ri join public.sale_items si on si.id=ri.sale_item_id where ri.return_id=r.id) order by p.id for update;
 if refund>0 and p_method='cash' then perform private.validate_operational_shift(r.business_id,member,p_shift_id,r.branch_id);end if;
 if reduction>0 then
  update public.credit_accounts set outstanding=outstanding-reduction where sale_id=r.sale_id;
  insert into public.credit_entries(business_id,sale_id,request_id,actor_id,kind,amount,reason,reference_id) values(r.business_id,r.sale_id,p_request_id,auth.uid(),'return',-reduction,r.reason,r.id);
 end if;
 for x in select i.*,si.product_id from public.return_items i join public.sale_items si on si.id=i.sale_item_id where i.return_id=r.id order by si.product_id loop
  if x.condition='sellable' then
   if r.branch_id is not null then raise exception 'Branch return stock workflow is not activated';end if;
   -- Inspection is independently authorized above; refund approval may restock
   -- only the exact inspected quantity and original product, never a price field.
   perform set_config('trexven.catalog_reason','Inspected sellable return: '||r.reason,true);
   perform set_config('trexven.catalog_request',r.id::text,true);
   perform set_config('trexven.catalog_operation','return',true);
   update public.products set quantity=coalesce(quantity,0)+x.quantity,updated_at=now() where id=x.product_id and business_id=r.business_id;
  end if;
 end loop;
 perform set_config('trexven.catalog_operation','',true);perform set_config('trexven.catalog_request','',true);perform set_config('trexven.catalog_reason','',true);
 update public.sale_returns set status='approved',approved_by=auth.uid(),value=v_value,debt_reduction=reduction,refund_amount=refund,refund_method=case when refund>0 then p_method end,refund_evidence=p_evidence,approved_at=now() where id=r.id;
 if refund>0 and p_method='cash' then perform private.record_operational_cash(r.business_id,member,-refund,'refund',r.id,p_shift_id);end if;
 result:=jsonb_build_object('return_id',r.id,'value',v_value,'debt_reduction',reduction,'refund',refund);
 insert into public.audit_logs(business_id,actor_id,action,metadata) values(r.business_id,auth.uid(),'sale_return_approved',result);
 perform private.operation_save(r.business_id,p_request_id,payload,result);return result;
end $$;

create function public.get_trexven_financial_summary(p_business_id uuid,p_start timestamptz,p_end timestamptz)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare result jsonb;
begin
 perform private.operations_context(p_business_id,'view_finance',null,true);
 if p_start is null or p_end is null or p_end<=p_start then raise exception 'Valid reporting interval required';end if;
 select jsonb_build_object('gross_sales',coalesce((select sum(total) from public.sales where business_id=p_business_id and status='completed' and coalesce(sold_at,created_at)>=p_start and coalesce(sold_at,created_at)<p_end),0),
 'sale_collections',coalesce((select sum(p.amount) from public.sale_payments p where p.business_id=p_business_id and p.confirmed_at>=p_start and p.confirmed_at<p_end),0)+coalesce((select sum(s.total) from public.sales s where s.business_id=p_business_id and s.status='completed' and s.payment_method in('cash','bank_transfer','card') and s.created_at>=p_start and s.created_at<p_end and not exists(select 1 from public.sale_payments p where p.sale_id=s.id)),0),
 'repayment_collections',coalesce((select -sum(amount) from public.credit_entries where business_id=p_business_id and kind in('repayment','repayment_reversal') and created_at>=p_start and created_at<p_end),0),
 'refunds',coalesce((select sum(refund_amount) from public.sale_returns where business_id=p_business_id and status='approved' and approved_at>=p_start and approved_at<p_end),0),
 'receivables',coalesce((select sum(outstanding) from public.credit_accounts where business_id=p_business_id),0),
 'overdue',coalesce((select sum(outstanding) from public.credit_accounts where business_id=p_business_id and due_date<(public.get_trexven_business_day(p_business_id)->>'local_date')::date),0)) into result;
 result:=result||jsonb_build_object('net_collected',((result->>'sale_collections')::numeric+(result->>'repayment_collections')::numeric-(result->>'refunds')::numeric)::text);
 select jsonb_object_agg(key,to_jsonb(value#>>'{}')) into result from jsonb_each(result);
 return result;
end $$;

do $$ declare f record; begin
 for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in(
 'request_trexven_credit_approval','decide_trexven_credit_approval','set_trexven_credit_limit','complete_trexven_transaction','repay_trexven_credit','request_trexven_return','inspect_trexven_return','approve_trexven_return','get_trexven_financial_summary','cancel_trexven_uncommitted_operation') loop
  execute format('revoke all on function %s from public,anon',f.signature);
  execute format('grant execute on function %s to authenticated',f.signature);
 end loop;
end $$;
create or replace function private.process_trexven_sale(
 p_business_id uuid,p_employee_id uuid,p_total numeric,p_payment_method text,p_items jsonb,
 p_quick boolean,p_branch_id uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare b public.businesses%rowtype; item jsonb; product public.products%rowtype;
 member uuid; sale uuid; branch uuid; qty numeric; price numeric; v_discount numeric; v_total numeric:=0;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 select * into b from public.businesses where id=p_business_id for share;
 if not found then raise exception 'Business access denied' using errcode='42501'; end if;
 if b.pos_writes_paused then raise exception 'Sale writes are temporarily paused for recovery.' using errcode='42501'; end if;
 -- Lock trusted authorization rows so revocation is ordered against the sale.
 perform id from public.employees where business_id=b.id and user_id=auth.uid() for share;
 select id into member from public.business_members where business_id=b.id and user_id=auth.uid() and status='active' for share;
 if not public.is_business_member(b.id) or not private.has_business_permission(b.id,'complete_sales')
 or not private.has_business_permission(b.id,'pos_access') then
 raise exception 'Sale permission denied' using errcode='42501'; end if;
 if p_quick is null or (not p_quick and p_employee_id is distinct from member)
 or (p_quick and p_employee_id is not null) then raise exception 'Employee does not match session' using errcode='42501'; end if;
 if p_payment_method<>'cash' and coalesce(current_setting('trexven.transaction_contract',true),'')<>'v2' then raise exception 'Use confirmed payment-line checkout; legacy receipt replay remains supported'; end if;
 if p_payment_method is null or p_payment_method not in ('cash','card','bank_transfer','mobile_money','other') then raise exception 'Invalid payment method'; end if;
 if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Items required'; end if;
 if p_quick and jsonb_array_length(p_items)<>1 then raise exception 'Invalid quick sale'; end if;
 branch:=p_branch_id;
 if b.branches_enabled then
   if branch is null then
     branch:=b.compatibility_branch_id;
     if not public.user_owns_business(b.id) and (select count(*) from public.employee_branch_assignments a
       join public.employees e on e.id=a.employee_id and e.business_id=a.business_id
       join public.branches br on br.id=a.branch_id and br.business_id=a.business_id
       where a.business_id=b.id and e.user_id=auth.uid() and a.is_active and br.is_active)<>1 then
       raise exception 'Explicit branch context required' using errcode='42501'; end if;
   end if;
   if not private.has_branch_access(b.id,branch) then raise exception 'Branch access denied' using errcode='42501'; end if;
   perform id from public.branches where id=branch and business_id=b.id and is_active for share;
   perform a.employee_id from public.employee_branch_assignments a join public.employees e on e.id=a.employee_id
     where a.branch_id=branch and a.business_id=b.id and e.user_id=auth.uid() and a.is_active for share of a;
   if not private.has_branch_access(b.id,branch) then raise exception 'Branch access denied' using errcode='42501'; end if;
 elsif branch is not null then
   raise exception 'Branch operations not activated' using errcode='42501';
 end if;
 perform id from public.products where business_id=b.id and id in
 (select (value->>'product_id')::uuid from jsonb_array_elements(p_items)) order by id for update;
 if branch is not null then
   perform product_id from public.inventory where business_id=b.id and branch_id=branch and product_id in
   (select (value->>'product_id')::uuid from jsonb_array_elements(p_items)) order by product_id for update;
 end if;
 insert into public.sales(business_id,employee_id,total,payment_method,status,branch_id)
 values(b.id,member,0,p_payment_method,'completed',branch) returning id into sale;
 for item in select * from jsonb_array_elements(p_items) loop
   qty:=(item->>'quantity')::numeric; price:=(item->>'unit_price')::numeric;
   v_discount:=coalesce((item->>'discount')::numeric,0);
   if scale(price)>2 or scale(v_discount)>2 then raise exception 'Money supports two decimal places'; end if;
   if qty is null or qty<=0 or scale(qty)>3 or qty::text in ('NaN','Infinity','-Infinity') or price is null or price<0 or price::text in ('NaN','Infinity','-Infinity')
   or v_discount::text in ('NaN','Infinity','-Infinity') or v_discount<0 or v_discount>qty*price then raise exception 'Invalid sale item'; end if;
   if v_discount>0 and (p_quick or not private.has_business_permission(b.id,'apply_discount')) then
     raise exception 'Discount permission denied' using errcode='42501'; end if;
   select * into product from public.products where id=(item->>'product_id')::uuid and business_id=b.id;
   if not found then raise exception 'Product not found in this business'; end if;
   if product.selling_price is null or product.is_active is not true or product.active is false then
     raise exception 'Product is pending or inactive'; end if;
   if lower(btrim(coalesce(product.unit,'piece'))) not in('kg','g','litre','ml','metre','cm') and qty<>trunc(qty) then raise exception 'Countable units require whole quantities'; end if;
   if price is distinct from product.selling_price and not private.has_business_permission(b.id,'override_price') then raise exception 'Price override permission required' using errcode='42501'; end if;
   if branch is null then
     if coalesce(product.quantity,0)<qty then raise exception 'Insufficient stock'; end if;
     perform set_config('trexven.catalog_operation','sale',true);
     perform set_config('trexven.catalog_request',sale::text,true);
     perform set_config('trexven.catalog_reason','Confirmed checkout stock deduction',true);
     update public.products set quantity=quantity-qty where id=product.id and business_id=b.id;
     perform set_config('trexven.catalog_operation','',true);
     perform set_config('trexven.catalog_request','',true);
     perform set_config('trexven.catalog_reason','',true);
   else
     update public.inventory set quantity=quantity-qty where business_id=b.id and branch_id=branch and product_id=product.id
       and quantity-coalesce(reserved_quantity,0)>=qty;
     if not found then raise exception 'Insufficient branch stock'; end if;
   end if;
   insert into public.sale_items(sale_id,product_id,product_name,quantity,unit_price,discount,total)
   values(sale,product.id,product.name,qty,price,v_discount,round(qty*price-v_discount,2));
   v_total:=v_total+round(qty*price-v_discount,2);
 end loop;
 if v_total is distinct from p_total then raise exception 'Sale total does not match items'; end if;
 update public.sales set total=v_total,total_amount=v_total,
 subtotal=(select sum(round(quantity*unit_price,2)) from public.sale_items where sale_id=sale),
 discount=(select sum(i.discount) from public.sale_items i where i.sale_id=sale) where id=sale;
 -- Preserve the legacy single-product quick-sale columns.
 if p_quick then update public.sales set product_id=product.id,quantity=qty,unit_price=price where id=sale; end if;
 return sale;
end $$;

notify pgrst,'reload schema';
commit;
