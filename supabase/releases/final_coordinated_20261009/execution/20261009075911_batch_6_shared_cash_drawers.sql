begin;
-- Release history guard and history insert are in the SAME transaction as DDL.
select pg_advisory_xact_lock(hashtextextended('trexven:coordinated-release',0));
do $trexven_history_guard$ begin
 if (select array_agg(version order by version) from supabase_migrations.schema_migrations)
    is distinct from array['20260819180000','20260823100000','20261002014604','20261002015419','20261002123039','20261002124738','20261003224001','20261004025120','20261005004045','20261007215736','20261007215743','20261007215831','20261008002119','20261008020234','20261008021428','20261009003200','20261009070338','20261009070340','20261009075117','20261009075318','20261009075612']::text[] then
  raise exception 'TREXVEN predecessor history mismatch; no migration changes committed';
 end if;
end $trexven_history_guard$;

insert into public.permissions(id,description) values('cash_shifts','Operate an assigned shared cash drawer'),('cash_movements','Record explained cash-in/out'),('review_cash_shifts','Explicit manager cash reconciliation review') on conflict(id) do nothing;
create table public.cash_registers(id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),branch_id uuid references public.branches(id),name text not null,active boolean not null default true,unique(business_id,name));
create table public.cash_register_assignments(id uuid primary key default gen_random_uuid(),register_id uuid not null references public.cash_registers(id),member_id uuid not null references public.business_members(id),active boolean not null default true,unique(register_id,member_id));
create table public.cash_shifts(id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),register_id uuid not null references public.cash_registers(id),branch_id uuid references public.branches(id),
 opened_by uuid not null references auth.users(id),opened_at timestamptz not null default now(),opening_amount numeric(18,2) not null check(opening_amount>=0),status text not null default 'open' check(status in('open','closed')),
 closed_at timestamptz,closed_by uuid references auth.users(id),counted_amount numeric(18,2),expected_at_close numeric(18,2),difference_at_close numeric(18,2),close_reason text,
 review_status text not null default 'pending' check(review_status in('pending','reviewed')),review_reason text,reviewed_by uuid references auth.users(id),reviewed_at timestamptz);
create unique index cash_register_one_open on public.cash_shifts(register_id) where status='open';
create index cash_shifts_business on public.cash_shifts(business_id,opened_at);
create table public.cash_shift_members(id uuid primary key default gen_random_uuid(),shift_id uuid not null references public.cash_shifts(id),member_id uuid not null references public.business_members(id),joined_at timestamptz not null default now(),unique(shift_id,member_id));
create table public.cash_events(id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),shift_id uuid not null references public.cash_shifts(id),member_id uuid not null references public.business_members(id),actor_id uuid not null references auth.users(id),
 amount numeric(18,2) not null,kind text not null check(kind in('sale','repayment','refund','repayment_reversal','cash_in','cash_out')),reference_id uuid not null,reason text,late boolean not null default false,created_at timestamptz not null default now(),unique(kind,reference_id));
create index cash_events_shift on public.cash_events(shift_id,created_at);
create table public.cash_handovers(id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),shift_id uuid not null references public.cash_shifts(id),outgoing_member uuid not null references public.business_members(id),incoming_member uuid not null references public.business_members(id),
 requested_by uuid not null references auth.users(id),confirmed_by uuid references auth.users(id),counted numeric(18,2) not null,expected numeric(18,2) not null,reason text not null,status text not null default 'pending' check(status in('pending','accepted','rejected')),created_at timestamptz not null default now());
do $$ declare t text;begin
 foreach t in array array['cash_registers','cash_shifts','cash_events','cash_handovers'] loop
  execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select on public.%I to authenticated',t);
  execute format('create policy "Cash business read" on public.%I for select to authenticated using(public.user_owns_business(business_id) or private.has_business_permission(business_id,''cash_shifts'') or private.has_business_permission(business_id,''review_cash_shifts''))',t);
 end loop;
 foreach t in array array['cash_register_assignments','cash_shift_members'] loop
  execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select on public.%I to authenticated',t);
 end loop;
end $$;
create policy "Register assignment read" on public.cash_register_assignments for select to authenticated using(exists(select 1 from public.cash_registers r where r.id=register_id));
create policy "Shift member read" on public.cash_shift_members for select to authenticated using(exists(select 1 from public.cash_shifts s where s.id=shift_id));
create or replace function private.validate_operational_shift(business uuid,member uuid,shift uuid,branch uuid default null,offline boolean default false)
returns void language plpgsql security definer set search_path='' as $$
declare s public.cash_shifts%rowtype;
begin
 if shift is null then
  if exists(select 1 from public.cash_registers where business_id=business and active) then raise exception 'Select and join an authorized cash drawer';end if;
  return;
 end if;
 select * into s from public.cash_shifts where id=shift and business_id=business for update;
 if not found or s.branch_id is distinct from branch or (s.status<>'open' and not offline)
 or not exists(select 1 from public.business_members m join public.cash_register_assignments a on a.member_id=m.id
  join public.cash_registers r on r.id=a.register_id where m.id=member and m.user_id=auth.uid() and m.business_id=business and m.status='active'
  and a.register_id=s.register_id and a.active and r.active)
 or not exists(select 1 from public.cash_shift_members where shift_id=s.id and member_id=member)
 then raise exception 'Authorized shared drawer membership required' using errcode='42501';end if;
end $$;
create or replace function private.record_operational_cash(business uuid,member uuid,amount numeric,kind text,reference uuid,shift uuid default null)
returns void language plpgsql security definer set search_path='' as $$
declare s public.cash_shifts%rowtype; offline boolean:=current_setting('trexven.catalog_operation',true)='offline_cash';
begin
 if shift is null then
  if not exists(select 1 from public.cash_registers where business_id=business and active) then return;end if;
  if (select count(*) from public.cash_shifts s join public.cash_shift_members m on m.shift_id=s.id where s.business_id=business and s.status='open' and m.member_id=member)<>1 then raise exception 'Select the shared register';end if;
  select s.id into shift from public.cash_shifts s join public.cash_shift_members m on m.shift_id=s.id where s.business_id=business and s.status='open' and m.member_id=member;
 end if;
 select * into s from public.cash_shifts where id=shift for update;
 perform private.validate_operational_shift(business,member,shift,s.branch_id,coalesce(offline,false));
 if amount is null or amount::text in('NaN','Infinity','-Infinity') or scale(amount)>2 then raise exception 'Invalid cash amount';end if;
 insert into public.cash_events(business_id,shift_id,member_id,actor_id,amount,kind,reference_id,late)
 values(business,shift,member,auth.uid(),amount,kind,reference,s.status='closed');
 if s.status='closed' then
  update public.cash_shifts set review_status='pending' where id=s.id;
  insert into public.audit_logs(business_id,actor_id,action,metadata) values(business,auth.uid(),'late_cash_reconciliation',jsonb_build_object('shift_id',s.id,'reference_id',reference,'amount',amount));
 end if;
end $$;
create function public.configure_trexven_register(p_business_id uuid,p_request_id uuid,p_name text,p_members uuid[])
returns jsonb language plpgsql security definer set search_path='' as $$
declare reg uuid; payload jsonb; prior jsonb; result jsonb; member uuid;
begin
 perform private.operations_context(p_business_id,'cash_shifts');if not public.user_owns_business(p_business_id) then raise exception 'Owner required' using errcode='42501';end if;
 payload:=jsonb_build_object('operation','configure_register','name',p_name,'members',p_members);prior:=private.operation_replay(p_business_id,p_request_id,payload);if prior is not null then return prior;end if;
 if nullif(btrim(p_name),'') is null or p_members is null then raise exception 'Register name and assignments required';end if;
 insert into public.cash_registers(business_id,name) values(p_business_id,p_name) on conflict(business_id,name) do update set name=excluded.name returning id into reg;
 perform id from public.cash_shifts where register_id=reg and status='open' for update;
 if found then raise exception 'Close the register before changing assignments';end if;
 update public.cash_register_assignments set active=false where register_id=reg;
 foreach member in array p_members loop
  if not exists(select 1 from public.business_members where id=member and business_id=p_business_id and status='active') then raise exception 'Active business membership required';end if;
  insert into public.cash_register_assignments(register_id,member_id) values(reg,member) on conflict(register_id,member_id) do update set active=true;
 end loop;
 result:=jsonb_build_object('id',reg);insert into public.audit_logs(business_id,actor_id,action,metadata) values(p_business_id,auth.uid(),'register_configured',payload);
 perform private.operation_save(p_business_id,p_request_id,payload,result);return result;
end $$;
create function public.open_trexven_cash_shift(p_register_id uuid,p_request_id uuid,p_opening numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.cash_registers%rowtype; member uuid; shift uuid; payload jsonb; prior jsonb; result jsonb;
begin
 select * into r from public.cash_registers where id=p_register_id;if not found then raise exception 'Register unavailable' using errcode='42501';end if;
 perform private.operations_context(r.business_id,'cash_shifts',r.branch_id);
 payload:=jsonb_build_object('operation','open_shift','register',r.id,'opening',p_opening);prior:=private.operation_replay(r.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 perform id from public.cash_registers where id=r.id for update;
 select m.id into member from public.business_members m join public.cash_register_assignments a on a.member_id=m.id where m.business_id=r.business_id and m.user_id=auth.uid() and m.status='active' and a.register_id=r.id and a.active;
 if not r.active or member is null or not private.valid_money(p_opening,true) then raise exception 'Authorized register and actual opening count required' using errcode='42501';end if;
 insert into public.cash_shifts(business_id,register_id,branch_id,opened_by,opening_amount) values(r.business_id,r.id,r.branch_id,auth.uid(),p_opening) returning id into shift;
 insert into public.cash_shift_members(shift_id,member_id) values(shift,member);
 result:=jsonb_build_object('id',shift,'status','open');perform private.operation_save(r.business_id,p_request_id,payload,result);return result;
end $$;
create function public.join_trexven_cash_shift(p_shift_id uuid,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.cash_shifts%rowtype; member uuid; payload jsonb; prior jsonb; result jsonb;
begin
 select * into s from public.cash_shifts where id=p_shift_id;if not found then raise exception 'Shift unavailable' using errcode='42501';end if;
 perform private.operations_context(s.business_id,'cash_shifts',s.branch_id);
 payload:=jsonb_build_object('operation','join_shift','shift',s.id);prior:=private.operation_replay(s.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select * into s from public.cash_shifts where id=p_shift_id for update;
 select m.id into member from public.business_members m join public.cash_register_assignments a on a.member_id=m.id where m.business_id=s.business_id and m.user_id=auth.uid() and m.status='active' and a.register_id=s.register_id and a.active;
 if s.status<>'open' or member is null then raise exception 'Open assigned register required' using errcode='42501';end if;
 insert into public.cash_shift_members(shift_id,member_id) values(s.id,member) on conflict do nothing;
 result:=jsonb_build_object('id',s.id,'status','joined');perform private.operation_save(s.business_id,p_request_id,payload,result);return result;
end $$;
create function public.move_trexven_cash(p_shift_id uuid,p_request_id uuid,p_amount numeric,p_kind text,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.cash_shifts%rowtype; member uuid; payload jsonb; prior jsonb; result jsonb;
begin
 select * into s from public.cash_shifts where id=p_shift_id;if not found then raise exception 'Shift unavailable' using errcode='42501';end if;
 perform private.operations_context(s.business_id,'cash_movements',s.branch_id);
 payload:=jsonb_build_object('operation','cash_movement','shift',s.id,'amount',p_amount,'kind',p_kind,'reason',p_reason);prior:=private.operation_replay(s.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 if not private.valid_money(p_amount) or p_kind not in('cash_in','cash_out') or nullif(btrim(p_reason),'') is null then raise exception 'Actual cash movement and reason required';end if;
 select id into member from public.business_members where business_id=s.business_id and user_id=auth.uid() and status='active';
 perform private.validate_operational_shift(s.business_id,member,s.id,s.branch_id);
 perform private.record_operational_cash(s.business_id,member,case when p_kind='cash_out' then -p_amount else p_amount end,p_kind,p_request_id,s.id);
 update public.cash_events set reason=p_reason where kind=p_kind and reference_id=p_request_id;
 result:=jsonb_build_object('id',p_request_id);perform private.operation_save(s.business_id,p_request_id,payload,result);return result;
end $$;
create function public.close_trexven_cash_shift(p_shift_id uuid,p_request_id uuid,p_counted numeric,p_reason text,p_no_pending_cash boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.cash_shifts%rowtype; member uuid; expected numeric; payload jsonb; prior jsonb; result jsonb;
begin
 select * into s from public.cash_shifts where id=p_shift_id;if not found then raise exception 'Shift unavailable' using errcode='42501';end if;
 perform private.operations_context(s.business_id,'cash_shifts',s.branch_id);
 payload:=jsonb_build_object('operation','close_shift','shift',s.id,'counted',p_counted,'reason',p_reason,'no_pending',p_no_pending_cash);prior:=private.operation_replay(s.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select id into member from public.business_members where business_id=s.business_id and user_id=auth.uid() and status='active';
 perform private.validate_operational_shift(s.business_id,member,s.id,s.branch_id);
 select * into s from public.cash_shifts where id=p_shift_id for update;
 expected:=s.opening_amount+coalesce((select sum(amount) from public.cash_events where shift_id=s.id),0);
 if not private.valid_money(p_counted,true) or p_no_pending_cash is distinct from true or (p_counted<>expected and nullif(btrim(p_reason),'') is null) then raise exception 'Actual drawer count, pending-cash confirmation and discrepancy reason required';end if;
 update public.cash_shifts set status='closed',closed_at=clock_timestamp(),closed_by=auth.uid(),counted_amount=p_counted,expected_at_close=expected,difference_at_close=p_counted-expected,close_reason=p_reason where id=s.id;
 result:=jsonb_build_object('id',s.id,'expected',expected,'counted',p_counted,'difference',p_counted-expected);
 insert into public.audit_logs(business_id,actor_id,action,metadata) values(s.business_id,auth.uid(),'cash_shift_closed',result||jsonb_build_object('reason',p_reason));
 perform private.operation_save(s.business_id,p_request_id,payload,result);return result;
end $$;
create function public.review_trexven_cash_shift(p_shift_id uuid,p_request_id uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.cash_shifts%rowtype; payload jsonb; prior jsonb; result jsonb;
begin
 select * into s from public.cash_shifts where id=p_shift_id;if not found then raise exception 'Shift unavailable' using errcode='42501';end if;
 perform private.operations_context(s.business_id,'review_cash_shifts',s.branch_id,true);
 payload:=jsonb_build_object('operation','review_shift','shift',s.id,'reason',p_reason);prior:=private.operation_replay(s.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select * into s from public.cash_shifts where id=p_shift_id for update;
 if s.status<>'closed' or nullif(btrim(p_reason),'') is null then raise exception 'Closed shift and review explanation required';end if;
 update public.cash_shifts set review_status='reviewed',review_reason=p_reason,reviewed_by=auth.uid(),reviewed_at=now() where id=s.id;
 result:=jsonb_build_object('id',s.id,'reviewed',true,'expected_now',s.opening_amount+coalesce((select sum(amount) from public.cash_events where shift_id=s.id),0),'original_close_expected',s.expected_at_close);
 insert into public.audit_logs(business_id,actor_id,action,metadata) values(s.business_id,auth.uid(),'cash_shift_reviewed',result||jsonb_build_object('reason',p_reason));
 perform private.operation_save(s.business_id,p_request_id,payload,result);return result;
end $$;
-- Legacy cash RPCs remain usable when exactly one assigned shared drawer is open.
create function private.legacy_cash_shift_post() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is not null and new.payment_method='cash' and new.status='completed' and new.total is distinct from old.total and coalesce(current_setting('trexven.transaction_contract',true),'')<>'v2' then
  perform private.record_operational_cash(new.business_id,new.employee_id,new.total,'sale',new.id,null);
 end if;return new;
end $$;
revoke all on function private.legacy_cash_shift_post() from public,anon,authenticated;
create trigger batch_6_legacy_cash after update of total on public.sales for each row execute function private.legacy_cash_shift_post();
do $$ declare f record;begin
 for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in('configure_trexven_register','open_trexven_cash_shift','join_trexven_cash_shift','move_trexven_cash','close_trexven_cash_shift','review_trexven_cash_shift') loop
 execute format('revoke all on function %s from public,anon',f.signature);execute format('grant execute on function %s to authenticated',f.signature);end loop;
end $$;
insert into supabase_migrations.schema_migrations(version,name,statements) values ('20261009075911','batch_6_shared_cash_drawers',array[$trexven_release_source$begin;
insert into public.permissions(id,description) values('cash_shifts','Operate an assigned shared cash drawer'),('cash_movements','Record explained cash-in/out'),('review_cash_shifts','Explicit manager cash reconciliation review') on conflict(id) do nothing;
create table public.cash_registers(id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),branch_id uuid references public.branches(id),name text not null,active boolean not null default true,unique(business_id,name));
create table public.cash_register_assignments(id uuid primary key default gen_random_uuid(),register_id uuid not null references public.cash_registers(id),member_id uuid not null references public.business_members(id),active boolean not null default true,unique(register_id,member_id));
create table public.cash_shifts(id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),register_id uuid not null references public.cash_registers(id),branch_id uuid references public.branches(id),
 opened_by uuid not null references auth.users(id),opened_at timestamptz not null default now(),opening_amount numeric(18,2) not null check(opening_amount>=0),status text not null default 'open' check(status in('open','closed')),
 closed_at timestamptz,closed_by uuid references auth.users(id),counted_amount numeric(18,2),expected_at_close numeric(18,2),difference_at_close numeric(18,2),close_reason text,
 review_status text not null default 'pending' check(review_status in('pending','reviewed')),review_reason text,reviewed_by uuid references auth.users(id),reviewed_at timestamptz);
create unique index cash_register_one_open on public.cash_shifts(register_id) where status='open';
create index cash_shifts_business on public.cash_shifts(business_id,opened_at);
create table public.cash_shift_members(id uuid primary key default gen_random_uuid(),shift_id uuid not null references public.cash_shifts(id),member_id uuid not null references public.business_members(id),joined_at timestamptz not null default now(),unique(shift_id,member_id));
create table public.cash_events(id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),shift_id uuid not null references public.cash_shifts(id),member_id uuid not null references public.business_members(id),actor_id uuid not null references auth.users(id),
 amount numeric(18,2) not null,kind text not null check(kind in('sale','repayment','refund','repayment_reversal','cash_in','cash_out')),reference_id uuid not null,reason text,late boolean not null default false,created_at timestamptz not null default now(),unique(kind,reference_id));
create index cash_events_shift on public.cash_events(shift_id,created_at);
create table public.cash_handovers(id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),shift_id uuid not null references public.cash_shifts(id),outgoing_member uuid not null references public.business_members(id),incoming_member uuid not null references public.business_members(id),
 requested_by uuid not null references auth.users(id),confirmed_by uuid references auth.users(id),counted numeric(18,2) not null,expected numeric(18,2) not null,reason text not null,status text not null default 'pending' check(status in('pending','accepted','rejected')),created_at timestamptz not null default now());
do $$ declare t text;begin
 foreach t in array array['cash_registers','cash_shifts','cash_events','cash_handovers'] loop
  execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select on public.%I to authenticated',t);
  execute format('create policy "Cash business read" on public.%I for select to authenticated using(public.user_owns_business(business_id) or private.has_business_permission(business_id,''cash_shifts'') or private.has_business_permission(business_id,''review_cash_shifts''))',t);
 end loop;
 foreach t in array array['cash_register_assignments','cash_shift_members'] loop
  execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select on public.%I to authenticated',t);
 end loop;
end $$;
create policy "Register assignment read" on public.cash_register_assignments for select to authenticated using(exists(select 1 from public.cash_registers r where r.id=register_id));
create policy "Shift member read" on public.cash_shift_members for select to authenticated using(exists(select 1 from public.cash_shifts s where s.id=shift_id));
create or replace function private.validate_operational_shift(business uuid,member uuid,shift uuid,branch uuid default null,offline boolean default false)
returns void language plpgsql security definer set search_path='' as $$
declare s public.cash_shifts%rowtype;
begin
 if shift is null then
  if exists(select 1 from public.cash_registers where business_id=business and active) then raise exception 'Select and join an authorized cash drawer';end if;
  return;
 end if;
 select * into s from public.cash_shifts where id=shift and business_id=business for update;
 if not found or s.branch_id is distinct from branch or (s.status<>'open' and not offline)
 or not exists(select 1 from public.business_members m join public.cash_register_assignments a on a.member_id=m.id
  join public.cash_registers r on r.id=a.register_id where m.id=member and m.user_id=auth.uid() and m.business_id=business and m.status='active'
  and a.register_id=s.register_id and a.active and r.active)
 or not exists(select 1 from public.cash_shift_members where shift_id=s.id and member_id=member)
 then raise exception 'Authorized shared drawer membership required' using errcode='42501';end if;
end $$;
create or replace function private.record_operational_cash(business uuid,member uuid,amount numeric,kind text,reference uuid,shift uuid default null)
returns void language plpgsql security definer set search_path='' as $$
declare s public.cash_shifts%rowtype; offline boolean:=current_setting('trexven.catalog_operation',true)='offline_cash';
begin
 if shift is null then
  if not exists(select 1 from public.cash_registers where business_id=business and active) then return;end if;
  if (select count(*) from public.cash_shifts s join public.cash_shift_members m on m.shift_id=s.id where s.business_id=business and s.status='open' and m.member_id=member)<>1 then raise exception 'Select the shared register';end if;
  select s.id into shift from public.cash_shifts s join public.cash_shift_members m on m.shift_id=s.id where s.business_id=business and s.status='open' and m.member_id=member;
 end if;
 select * into s from public.cash_shifts where id=shift for update;
 perform private.validate_operational_shift(business,member,shift,s.branch_id,coalesce(offline,false));
 if amount is null or amount::text in('NaN','Infinity','-Infinity') or scale(amount)>2 then raise exception 'Invalid cash amount';end if;
 insert into public.cash_events(business_id,shift_id,member_id,actor_id,amount,kind,reference_id,late)
 values(business,shift,member,auth.uid(),amount,kind,reference,s.status='closed');
 if s.status='closed' then
  update public.cash_shifts set review_status='pending' where id=s.id;
  insert into public.audit_logs(business_id,actor_id,action,metadata) values(business,auth.uid(),'late_cash_reconciliation',jsonb_build_object('shift_id',s.id,'reference_id',reference,'amount',amount));
 end if;
end $$;
create function public.configure_trexven_register(p_business_id uuid,p_request_id uuid,p_name text,p_members uuid[])
returns jsonb language plpgsql security definer set search_path='' as $$
declare reg uuid; payload jsonb; prior jsonb; result jsonb; member uuid;
begin
 perform private.operations_context(p_business_id,'cash_shifts');if not public.user_owns_business(p_business_id) then raise exception 'Owner required' using errcode='42501';end if;
 payload:=jsonb_build_object('operation','configure_register','name',p_name,'members',p_members);prior:=private.operation_replay(p_business_id,p_request_id,payload);if prior is not null then return prior;end if;
 if nullif(btrim(p_name),'') is null or p_members is null then raise exception 'Register name and assignments required';end if;
 insert into public.cash_registers(business_id,name) values(p_business_id,p_name) on conflict(business_id,name) do update set name=excluded.name returning id into reg;
 perform id from public.cash_shifts where register_id=reg and status='open' for update;
 if found then raise exception 'Close the register before changing assignments';end if;
 update public.cash_register_assignments set active=false where register_id=reg;
 foreach member in array p_members loop
  if not exists(select 1 from public.business_members where id=member and business_id=p_business_id and status='active') then raise exception 'Active business membership required';end if;
  insert into public.cash_register_assignments(register_id,member_id) values(reg,member) on conflict(register_id,member_id) do update set active=true;
 end loop;
 result:=jsonb_build_object('id',reg);insert into public.audit_logs(business_id,actor_id,action,metadata) values(p_business_id,auth.uid(),'register_configured',payload);
 perform private.operation_save(p_business_id,p_request_id,payload,result);return result;
end $$;
create function public.open_trexven_cash_shift(p_register_id uuid,p_request_id uuid,p_opening numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.cash_registers%rowtype; member uuid; shift uuid; payload jsonb; prior jsonb; result jsonb;
begin
 select * into r from public.cash_registers where id=p_register_id;if not found then raise exception 'Register unavailable' using errcode='42501';end if;
 perform private.operations_context(r.business_id,'cash_shifts',r.branch_id);
 payload:=jsonb_build_object('operation','open_shift','register',r.id,'opening',p_opening);prior:=private.operation_replay(r.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 perform id from public.cash_registers where id=r.id for update;
 select m.id into member from public.business_members m join public.cash_register_assignments a on a.member_id=m.id where m.business_id=r.business_id and m.user_id=auth.uid() and m.status='active' and a.register_id=r.id and a.active;
 if not r.active or member is null or not private.valid_money(p_opening,true) then raise exception 'Authorized register and actual opening count required' using errcode='42501';end if;
 insert into public.cash_shifts(business_id,register_id,branch_id,opened_by,opening_amount) values(r.business_id,r.id,r.branch_id,auth.uid(),p_opening) returning id into shift;
 insert into public.cash_shift_members(shift_id,member_id) values(shift,member);
 result:=jsonb_build_object('id',shift,'status','open');perform private.operation_save(r.business_id,p_request_id,payload,result);return result;
end $$;
create function public.join_trexven_cash_shift(p_shift_id uuid,p_request_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.cash_shifts%rowtype; member uuid; payload jsonb; prior jsonb; result jsonb;
begin
 select * into s from public.cash_shifts where id=p_shift_id;if not found then raise exception 'Shift unavailable' using errcode='42501';end if;
 perform private.operations_context(s.business_id,'cash_shifts',s.branch_id);
 payload:=jsonb_build_object('operation','join_shift','shift',s.id);prior:=private.operation_replay(s.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select * into s from public.cash_shifts where id=p_shift_id for update;
 select m.id into member from public.business_members m join public.cash_register_assignments a on a.member_id=m.id where m.business_id=s.business_id and m.user_id=auth.uid() and m.status='active' and a.register_id=s.register_id and a.active;
 if s.status<>'open' or member is null then raise exception 'Open assigned register required' using errcode='42501';end if;
 insert into public.cash_shift_members(shift_id,member_id) values(s.id,member) on conflict do nothing;
 result:=jsonb_build_object('id',s.id,'status','joined');perform private.operation_save(s.business_id,p_request_id,payload,result);return result;
end $$;
create function public.move_trexven_cash(p_shift_id uuid,p_request_id uuid,p_amount numeric,p_kind text,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.cash_shifts%rowtype; member uuid; payload jsonb; prior jsonb; result jsonb;
begin
 select * into s from public.cash_shifts where id=p_shift_id;if not found then raise exception 'Shift unavailable' using errcode='42501';end if;
 perform private.operations_context(s.business_id,'cash_movements',s.branch_id);
 payload:=jsonb_build_object('operation','cash_movement','shift',s.id,'amount',p_amount,'kind',p_kind,'reason',p_reason);prior:=private.operation_replay(s.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 if not private.valid_money(p_amount) or p_kind not in('cash_in','cash_out') or nullif(btrim(p_reason),'') is null then raise exception 'Actual cash movement and reason required';end if;
 select id into member from public.business_members where business_id=s.business_id and user_id=auth.uid() and status='active';
 perform private.validate_operational_shift(s.business_id,member,s.id,s.branch_id);
 perform private.record_operational_cash(s.business_id,member,case when p_kind='cash_out' then -p_amount else p_amount end,p_kind,p_request_id,s.id);
 update public.cash_events set reason=p_reason where kind=p_kind and reference_id=p_request_id;
 result:=jsonb_build_object('id',p_request_id);perform private.operation_save(s.business_id,p_request_id,payload,result);return result;
end $$;
create function public.close_trexven_cash_shift(p_shift_id uuid,p_request_id uuid,p_counted numeric,p_reason text,p_no_pending_cash boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.cash_shifts%rowtype; member uuid; expected numeric; payload jsonb; prior jsonb; result jsonb;
begin
 select * into s from public.cash_shifts where id=p_shift_id;if not found then raise exception 'Shift unavailable' using errcode='42501';end if;
 perform private.operations_context(s.business_id,'cash_shifts',s.branch_id);
 payload:=jsonb_build_object('operation','close_shift','shift',s.id,'counted',p_counted,'reason',p_reason,'no_pending',p_no_pending_cash);prior:=private.operation_replay(s.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select id into member from public.business_members where business_id=s.business_id and user_id=auth.uid() and status='active';
 perform private.validate_operational_shift(s.business_id,member,s.id,s.branch_id);
 select * into s from public.cash_shifts where id=p_shift_id for update;
 expected:=s.opening_amount+coalesce((select sum(amount) from public.cash_events where shift_id=s.id),0);
 if not private.valid_money(p_counted,true) or p_no_pending_cash is distinct from true or (p_counted<>expected and nullif(btrim(p_reason),'') is null) then raise exception 'Actual drawer count, pending-cash confirmation and discrepancy reason required';end if;
 update public.cash_shifts set status='closed',closed_at=clock_timestamp(),closed_by=auth.uid(),counted_amount=p_counted,expected_at_close=expected,difference_at_close=p_counted-expected,close_reason=p_reason where id=s.id;
 result:=jsonb_build_object('id',s.id,'expected',expected,'counted',p_counted,'difference',p_counted-expected);
 insert into public.audit_logs(business_id,actor_id,action,metadata) values(s.business_id,auth.uid(),'cash_shift_closed',result||jsonb_build_object('reason',p_reason));
 perform private.operation_save(s.business_id,p_request_id,payload,result);return result;
end $$;
create function public.review_trexven_cash_shift(p_shift_id uuid,p_request_id uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.cash_shifts%rowtype; payload jsonb; prior jsonb; result jsonb;
begin
 select * into s from public.cash_shifts where id=p_shift_id;if not found then raise exception 'Shift unavailable' using errcode='42501';end if;
 perform private.operations_context(s.business_id,'review_cash_shifts',s.branch_id,true);
 payload:=jsonb_build_object('operation','review_shift','shift',s.id,'reason',p_reason);prior:=private.operation_replay(s.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select * into s from public.cash_shifts where id=p_shift_id for update;
 if s.status<>'closed' or nullif(btrim(p_reason),'') is null then raise exception 'Closed shift and review explanation required';end if;
 update public.cash_shifts set review_status='reviewed',review_reason=p_reason,reviewed_by=auth.uid(),reviewed_at=now() where id=s.id;
 result:=jsonb_build_object('id',s.id,'reviewed',true,'expected_now',s.opening_amount+coalesce((select sum(amount) from public.cash_events where shift_id=s.id),0),'original_close_expected',s.expected_at_close);
 insert into public.audit_logs(business_id,actor_id,action,metadata) values(s.business_id,auth.uid(),'cash_shift_reviewed',result||jsonb_build_object('reason',p_reason));
 perform private.operation_save(s.business_id,p_request_id,payload,result);return result;
end $$;
-- Legacy cash RPCs remain usable when exactly one assigned shared drawer is open.
create function private.legacy_cash_shift_post() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is not null and new.payment_method='cash' and new.status='completed' and new.total is distinct from old.total and coalesce(current_setting('trexven.transaction_contract',true),'')<>'v2' then
  perform private.record_operational_cash(new.business_id,new.employee_id,new.total,'sale',new.id,null);
 end if;return new;
end $$;
revoke all on function private.legacy_cash_shift_post() from public,anon,authenticated;
create trigger batch_6_legacy_cash after update of total on public.sales for each row execute function private.legacy_cash_shift_post();
do $$ declare f record;begin
 for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in('configure_trexven_register','open_trexven_cash_shift','join_trexven_cash_shift','move_trexven_cash','close_trexven_cash_shift','review_trexven_cash_shift') loop
 execute format('revoke all on function %s from public,anon',f.signature);execute format('grant execute on function %s to authenticated',f.signature);end loop;
end $$;
commit;
$trexven_release_source$]::text[]);
commit;
