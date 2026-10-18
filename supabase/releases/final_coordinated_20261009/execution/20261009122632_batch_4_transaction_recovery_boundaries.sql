begin;
-- Release history guard and history insert are in the SAME transaction as DDL.
select pg_advisory_xact_lock(hashtextextended('trexven:coordinated-release',0));
do $trexven_history_guard$ begin
 if (select array_agg(version order by version) from supabase_migrations.schema_migrations)
    is distinct from array['20260819180000','20260823100000','20261002014604','20261002015419','20261002123039','20261002124738','20261003224001','20261004025120','20261005004045','20261007215736','20261007215743','20261007215831','20261008002119','20261008020234','20261008021428','20261009003200','20261009070338','20261009070340','20261009075117','20261009075318','20261009075612','20261009075911','20261009080227','20261009080751','20261009080842','20261009081002','20261009081504','20261009082051','20261009082951']::text[] then
  raise exception 'TREXVEN predecessor history mismatch; no migration changes committed';
 end if;
end $trexven_history_guard$;

-- Additional permissive legacy read policies cannot extend a cashier's day.
create policy "Financial business day boundary" on public.sales as restrictive for select to authenticated
 using(private.sales_history_access(business_id,coalesce(sold_at,created_at)));
create function public.review_trexven_offline_reconciliation(p_reconciliation_id uuid,p_request_id uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.offline_sale_reconciliations%rowtype;payload jsonb;prior jsonb;result jsonb;
begin
 select * into r from public.offline_sale_reconciliations where id=p_reconciliation_id;if not found then raise exception 'Reconciliation unavailable' using errcode='42501';end if;
 perform private.operations_context(r.business_id,'review_cash_shifts',null,true);
 payload:=jsonb_build_object('operation','review_offline','reconciliation',r.id,'reason',p_reason);prior:=private.operation_replay(r.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select * into r from public.offline_sale_reconciliations where id=p_reconciliation_id for update;
 if r.reviewed_by is not null or nullif(btrim(p_reason),'') is null then raise exception 'Unreviewed reconciliation and reason required';end if;
 update public.offline_sale_reconciliations set reviewed_by=auth.uid(),review_reason=p_reason where id=r.id;
 result:=jsonb_build_object('id',r.id,'reviewed',true);insert into public.audit_logs(business_id,actor_id,action,metadata) values(r.business_id,auth.uid(),'offline_sale_reviewed',payload);
 perform private.operation_save(r.business_id,p_request_id,payload,result);return result;
end $$;
create function private.finish_cash_shift(shift uuid,counted numeric,reason text,forced boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.cash_shifts%rowtype;expected numeric;result jsonb;
begin
 select * into s from public.cash_shifts where id=shift for update;
 if not found or s.status<>'open' then raise exception 'Open shift required';end if;
 expected:=s.opening_amount+coalesce((select sum(amount) from public.cash_events where shift_id=s.id),0);
 if not private.valid_money(counted,true) or ((counted<>expected or forced) and nullif(btrim(reason),'') is null) then raise exception 'Actual cash count and discrepancy or recovery explanation required';end if;
 update public.cash_shifts set status='closed',closed_at=clock_timestamp(),closed_by=auth.uid(),counted_amount=counted,expected_at_close=expected,difference_at_close=counted-expected,close_reason=reason where id=s.id;
 result:=jsonb_build_object('id',s.id,'expected',expected,'counted',counted,'difference',counted-expected,'forced',forced);
 insert into public.audit_logs(business_id,actor_id,action,metadata) values(s.business_id,auth.uid(),'cash_shift_closed',result||jsonb_build_object('reason',reason));return result;
end $$;
revoke all on function private.finish_cash_shift(uuid,numeric,text,boolean) from public,anon,authenticated;
create function public.force_close_trexven_cash_shift(p_shift_id uuid,p_request_id uuid,p_counted numeric,p_reason text,p_review_pending_cash boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.cash_shifts%rowtype;payload jsonb;prior jsonb;result jsonb;
begin
 select * into s from public.cash_shifts where id=p_shift_id;if not found then raise exception 'Shift unavailable' using errcode='42501';end if;
 perform private.operations_context(s.business_id,'review_cash_shifts',s.branch_id,true);
 payload:=jsonb_build_object('operation','force_close_shift','shift',s.id,'counted',p_counted,'reason',p_reason,'review_pending',p_review_pending_cash);
 prior:=private.operation_replay(s.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 if p_review_pending_cash is distinct from true then raise exception 'Explicit unresolved cash reconciliation acknowledgment required';end if;
 result:=private.finish_cash_shift(s.id,p_counted,p_reason,true);
 perform private.operation_save(s.business_id,p_request_id,payload,result);return result;
end $$;
create function public.get_trexven_return_inspection_items(p_return_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.sale_returns%rowtype;result jsonb;
begin
 select * into r from public.sale_returns where id=p_return_id;if not found then raise exception 'Return unavailable' using errcode='42501';end if;
 perform private.operations_context(r.business_id,'inspect_returns',r.branch_id);
 select coalesce(jsonb_agg(jsonb_build_object('sale_item_id',si.id,'name',si.product_name,'quantity',ri.quantity,'condition',ri.condition) order by si.id),'[]'::jsonb)
 into result from public.return_items ri join public.sale_items si on si.id=ri.sale_item_id where ri.return_id=r.id;return result;
end $$;
revoke all on function public.review_trexven_offline_reconciliation(uuid,uuid,text),public.force_close_trexven_cash_shift(uuid,uuid,numeric,text,boolean),public.get_trexven_return_inspection_items(uuid) from public,anon;
grant execute on function public.review_trexven_offline_reconciliation(uuid,uuid,text),public.force_close_trexven_cash_shift(uuid,uuid,numeric,text,boolean),public.get_trexven_return_inspection_items(uuid) to authenticated;
create or replace function public.close_trexven_cash_shift(p_shift_id uuid,p_request_id uuid,p_counted numeric,p_reason text,p_no_pending_cash boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.cash_shifts%rowtype; member uuid; expected numeric; payload jsonb; prior jsonb; result jsonb;
begin
 select * into s from public.cash_shifts where id=p_shift_id;if not found then raise exception 'Shift unavailable' using errcode='42501';end if;
 perform private.operations_context(s.business_id,'cash_shifts',s.branch_id);
 payload:=jsonb_build_object('operation','close_shift','shift',s.id,'counted',p_counted,'reason',p_reason,'no_pending',p_no_pending_cash);prior:=private.operation_replay(s.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select id into member from public.business_members where business_id=s.business_id and user_id=auth.uid() and status='active';
 perform private.validate_operational_shift(s.business_id,member,s.id,s.branch_id);
 if p_no_pending_cash is distinct from true then raise exception 'Pending-cash confirmation required';end if;
 result:=private.finish_cash_shift(s.id,p_counted,p_reason,false);
 perform private.operation_save(s.business_id,p_request_id,payload,result);return result;
end $$;
-- Do not infer business configuration from an employee's RLS-filtered list.
-- Guard the existing wrapper rather than introduce another checkout core.
do $$ declare definition text;needle text:='sale:=private.process_trexven_sale';replacement text;
begin
 definition:=pg_get_functiondef('private.submit_sale_request(uuid,uuid,uuid,numeric,text,jsonb,boolean,uuid)'::regprocedure);
 if position(needle in definition)=0 then raise exception 'Unexpected legacy checkout wrapper; stop for compatibility review';end if;
 replacement:=$guard$perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
 if exists(select 1 from private.operation_cancellations where request_id=p_request_id) then raise exception 'Request was explicitly cancelled; its key cannot be reused';end if;
 if exists(select 1 from private.catalog_requests where request_id=p_request_id) then raise exception 'Request identity conflict' using errcode='42501';end if;
 sale:=private.process_trexven_sale$guard$;
 execute replace(definition,needle,replacement);
end $$;
create function public.recover_trexven_legacy_checkout(p_business_id uuid,p_request_id uuid,p_employee_id uuid,p_total numeric,p_items jsonb,p_payment_method text,p_branch_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare saved private.sale_requests%rowtype;
begin
 if auth.uid() is null or not public.is_business_member(p_business_id) then raise exception 'Current business membership required' using errcode='42501';end if;
 if (p_branch_id is not null and not private.has_branch_access(p_business_id,p_branch_id)) or
 (p_branch_id is null and not public.user_owns_business(p_business_id) and exists(select 1 from public.businesses where id=p_business_id and branches_enabled)) then raise exception 'Original authorized branch context required' using errcode='42501';end if;
 -- Serialize with both old checkout and its compatible new transaction path.
 perform pg_advisory_xact_lock(hashtextextended(p_business_id::text||auth.uid()::text||p_request_id::text,0));
 select * into saved from private.sale_requests where business_id=p_business_id and user_id=auth.uid() and request_id=p_request_id;
 if not found then return null;end if;
 if saved.payload->>'employee' is distinct from p_employee_id::text or (saved.payload->>'total')::numeric is distinct from p_total
 or saved.payload->'items' is distinct from p_items or saved.payload->>'payment' is distinct from p_payment_method
 or saved.branch_id is distinct from p_branch_id then raise exception 'Original checkout payload required' using errcode='42501';end if;
 return saved.receipt;
end $$;
revoke all on function public.recover_trexven_legacy_checkout(uuid,uuid,uuid,numeric,jsonb,text,uuid) from public,anon;
grant execute on function public.recover_trexven_legacy_checkout(uuid,uuid,uuid,numeric,jsonb,text,uuid) to authenticated;
-- Only authorized register details are returned; amounts are exact decimal text.
create function public.get_trexven_cash_context(p_business_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare member uuid; shifts jsonb;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501';end if;
 select id into member from public.business_members where business_id=p_business_id and user_id=auth.uid() and status='active';
 if not public.is_business_member(p_business_id) then raise exception 'Active business membership required' using errcode='42501';end if;
 select coalesce(jsonb_agg(to_jsonb(s)||jsonb_build_object(
  'register_name',r.name,'register_active',r.active,
  'joined',exists(select 1 from public.cash_shift_members m join public.cash_register_assignments a on a.member_id=m.member_id and a.register_id=s.register_id
    where m.shift_id=s.id and m.member_id=member and a.active),
  'opening_amount',s.opening_amount::text,'counted_amount',s.counted_amount::text,
  'expected_at_close',s.expected_at_close::text,'difference_at_close',s.difference_at_close::text,
  'expected_current',(s.opening_amount+coalesce((select sum(e.amount) from public.cash_events e where e.shift_id=s.id),0))::text)
  order by s.opened_at desc),'[]'::jsonb) into shifts
 from public.cash_shifts s join public.cash_registers r on r.id=s.register_id
 where s.business_id=p_business_id and private.can_read_cash_register(r.id);
 return jsonb_build_object('configured',exists(select 1 from public.cash_registers where business_id=p_business_id and active),'shifts',shifts);
end $$;
revoke all on function public.get_trexven_cash_context(uuid) from public,anon;
grant execute on function public.get_trexven_cash_context(uuid) to authenticated;
alter table public.offline_sale_reconciliations alter column created_at set default clock_timestamp();
insert into supabase_migrations.schema_migrations(version,name,statements) values ('20261009122632','batch_4_transaction_recovery_boundaries',array[$trexven_release_source$begin;
-- Additional permissive legacy read policies cannot extend a cashier's day.
create policy "Financial business day boundary" on public.sales as restrictive for select to authenticated
 using(private.sales_history_access(business_id,coalesce(sold_at,created_at)));
create function public.review_trexven_offline_reconciliation(p_reconciliation_id uuid,p_request_id uuid,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.offline_sale_reconciliations%rowtype;payload jsonb;prior jsonb;result jsonb;
begin
 select * into r from public.offline_sale_reconciliations where id=p_reconciliation_id;if not found then raise exception 'Reconciliation unavailable' using errcode='42501';end if;
 perform private.operations_context(r.business_id,'review_cash_shifts',null,true);
 payload:=jsonb_build_object('operation','review_offline','reconciliation',r.id,'reason',p_reason);prior:=private.operation_replay(r.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select * into r from public.offline_sale_reconciliations where id=p_reconciliation_id for update;
 if r.reviewed_by is not null or nullif(btrim(p_reason),'') is null then raise exception 'Unreviewed reconciliation and reason required';end if;
 update public.offline_sale_reconciliations set reviewed_by=auth.uid(),review_reason=p_reason where id=r.id;
 result:=jsonb_build_object('id',r.id,'reviewed',true);insert into public.audit_logs(business_id,actor_id,action,metadata) values(r.business_id,auth.uid(),'offline_sale_reviewed',payload);
 perform private.operation_save(r.business_id,p_request_id,payload,result);return result;
end $$;
create function private.finish_cash_shift(shift uuid,counted numeric,reason text,forced boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.cash_shifts%rowtype;expected numeric;result jsonb;
begin
 select * into s from public.cash_shifts where id=shift for update;
 if not found or s.status<>'open' then raise exception 'Open shift required';end if;
 expected:=s.opening_amount+coalesce((select sum(amount) from public.cash_events where shift_id=s.id),0);
 if not private.valid_money(counted,true) or ((counted<>expected or forced) and nullif(btrim(reason),'') is null) then raise exception 'Actual cash count and discrepancy or recovery explanation required';end if;
 update public.cash_shifts set status='closed',closed_at=clock_timestamp(),closed_by=auth.uid(),counted_amount=counted,expected_at_close=expected,difference_at_close=counted-expected,close_reason=reason where id=s.id;
 result:=jsonb_build_object('id',s.id,'expected',expected,'counted',counted,'difference',counted-expected,'forced',forced);
 insert into public.audit_logs(business_id,actor_id,action,metadata) values(s.business_id,auth.uid(),'cash_shift_closed',result||jsonb_build_object('reason',reason));return result;
end $$;
revoke all on function private.finish_cash_shift(uuid,numeric,text,boolean) from public,anon,authenticated;
create function public.force_close_trexven_cash_shift(p_shift_id uuid,p_request_id uuid,p_counted numeric,p_reason text,p_review_pending_cash boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.cash_shifts%rowtype;payload jsonb;prior jsonb;result jsonb;
begin
 select * into s from public.cash_shifts where id=p_shift_id;if not found then raise exception 'Shift unavailable' using errcode='42501';end if;
 perform private.operations_context(s.business_id,'review_cash_shifts',s.branch_id,true);
 payload:=jsonb_build_object('operation','force_close_shift','shift',s.id,'counted',p_counted,'reason',p_reason,'review_pending',p_review_pending_cash);
 prior:=private.operation_replay(s.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 if p_review_pending_cash is distinct from true then raise exception 'Explicit unresolved cash reconciliation acknowledgment required';end if;
 result:=private.finish_cash_shift(s.id,p_counted,p_reason,true);
 perform private.operation_save(s.business_id,p_request_id,payload,result);return result;
end $$;
create function public.get_trexven_return_inspection_items(p_return_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.sale_returns%rowtype;result jsonb;
begin
 select * into r from public.sale_returns where id=p_return_id;if not found then raise exception 'Return unavailable' using errcode='42501';end if;
 perform private.operations_context(r.business_id,'inspect_returns',r.branch_id);
 select coalesce(jsonb_agg(jsonb_build_object('sale_item_id',si.id,'name',si.product_name,'quantity',ri.quantity,'condition',ri.condition) order by si.id),'[]'::jsonb)
 into result from public.return_items ri join public.sale_items si on si.id=ri.sale_item_id where ri.return_id=r.id;return result;
end $$;
revoke all on function public.review_trexven_offline_reconciliation(uuid,uuid,text),public.force_close_trexven_cash_shift(uuid,uuid,numeric,text,boolean),public.get_trexven_return_inspection_items(uuid) from public,anon;
grant execute on function public.review_trexven_offline_reconciliation(uuid,uuid,text),public.force_close_trexven_cash_shift(uuid,uuid,numeric,text,boolean),public.get_trexven_return_inspection_items(uuid) to authenticated;
create or replace function public.close_trexven_cash_shift(p_shift_id uuid,p_request_id uuid,p_counted numeric,p_reason text,p_no_pending_cash boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.cash_shifts%rowtype; member uuid; expected numeric; payload jsonb; prior jsonb; result jsonb;
begin
 select * into s from public.cash_shifts where id=p_shift_id;if not found then raise exception 'Shift unavailable' using errcode='42501';end if;
 perform private.operations_context(s.business_id,'cash_shifts',s.branch_id);
 payload:=jsonb_build_object('operation','close_shift','shift',s.id,'counted',p_counted,'reason',p_reason,'no_pending',p_no_pending_cash);prior:=private.operation_replay(s.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select id into member from public.business_members where business_id=s.business_id and user_id=auth.uid() and status='active';
 perform private.validate_operational_shift(s.business_id,member,s.id,s.branch_id);
 if p_no_pending_cash is distinct from true then raise exception 'Pending-cash confirmation required';end if;
 result:=private.finish_cash_shift(s.id,p_counted,p_reason,false);
 perform private.operation_save(s.business_id,p_request_id,payload,result);return result;
end $$;
-- Do not infer business configuration from an employee's RLS-filtered list.
-- Guard the existing wrapper rather than introduce another checkout core.
do $$ declare definition text;needle text:='sale:=private.process_trexven_sale';replacement text;
begin
 definition:=pg_get_functiondef('private.submit_sale_request(uuid,uuid,uuid,numeric,text,jsonb,boolean,uuid)'::regprocedure);
 if position(needle in definition)=0 then raise exception 'Unexpected legacy checkout wrapper; stop for compatibility review';end if;
 replacement:=$guard$perform pg_advisory_xact_lock(hashtextextended(p_request_id::text,0));
 if exists(select 1 from private.operation_cancellations where request_id=p_request_id) then raise exception 'Request was explicitly cancelled; its key cannot be reused';end if;
 if exists(select 1 from private.catalog_requests where request_id=p_request_id) then raise exception 'Request identity conflict' using errcode='42501';end if;
 sale:=private.process_trexven_sale$guard$;
 execute replace(definition,needle,replacement);
end $$;
create function public.recover_trexven_legacy_checkout(p_business_id uuid,p_request_id uuid,p_employee_id uuid,p_total numeric,p_items jsonb,p_payment_method text,p_branch_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare saved private.sale_requests%rowtype;
begin
 if auth.uid() is null or not public.is_business_member(p_business_id) then raise exception 'Current business membership required' using errcode='42501';end if;
 if (p_branch_id is not null and not private.has_branch_access(p_business_id,p_branch_id)) or
 (p_branch_id is null and not public.user_owns_business(p_business_id) and exists(select 1 from public.businesses where id=p_business_id and branches_enabled)) then raise exception 'Original authorized branch context required' using errcode='42501';end if;
 -- Serialize with both old checkout and its compatible new transaction path.
 perform pg_advisory_xact_lock(hashtextextended(p_business_id::text||auth.uid()::text||p_request_id::text,0));
 select * into saved from private.sale_requests where business_id=p_business_id and user_id=auth.uid() and request_id=p_request_id;
 if not found then return null;end if;
 if saved.payload->>'employee' is distinct from p_employee_id::text or (saved.payload->>'total')::numeric is distinct from p_total
 or saved.payload->'items' is distinct from p_items or saved.payload->>'payment' is distinct from p_payment_method
 or saved.branch_id is distinct from p_branch_id then raise exception 'Original checkout payload required' using errcode='42501';end if;
 return saved.receipt;
end $$;
revoke all on function public.recover_trexven_legacy_checkout(uuid,uuid,uuid,numeric,jsonb,text,uuid) from public,anon;
grant execute on function public.recover_trexven_legacy_checkout(uuid,uuid,uuid,numeric,jsonb,text,uuid) to authenticated;
-- Only authorized register details are returned; amounts are exact decimal text.
create function public.get_trexven_cash_context(p_business_id uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare member uuid; shifts jsonb;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501';end if;
 select id into member from public.business_members where business_id=p_business_id and user_id=auth.uid() and status='active';
 if not public.is_business_member(p_business_id) then raise exception 'Active business membership required' using errcode='42501';end if;
 select coalesce(jsonb_agg(to_jsonb(s)||jsonb_build_object(
  'register_name',r.name,'register_active',r.active,
  'joined',exists(select 1 from public.cash_shift_members m join public.cash_register_assignments a on a.member_id=m.member_id and a.register_id=s.register_id
    where m.shift_id=s.id and m.member_id=member and a.active),
  'opening_amount',s.opening_amount::text,'counted_amount',s.counted_amount::text,
  'expected_at_close',s.expected_at_close::text,'difference_at_close',s.difference_at_close::text,
  'expected_current',(s.opening_amount+coalesce((select sum(e.amount) from public.cash_events e where e.shift_id=s.id),0))::text)
  order by s.opened_at desc),'[]'::jsonb) into shifts
 from public.cash_shifts s join public.cash_registers r on r.id=s.register_id
 where s.business_id=p_business_id and private.can_read_cash_register(r.id);
 return jsonb_build_object('configured',exists(select 1 from public.cash_registers where business_id=p_business_id and active),'shifts',shifts);
end $$;
revoke all on function public.get_trexven_cash_context(uuid) from public,anon;
grant execute on function public.get_trexven_cash_context(uuid) to authenticated;
alter table public.offline_sale_reconciliations alter column created_at set default clock_timestamp();
commit;
$trexven_release_source$]::text[]);
commit;
