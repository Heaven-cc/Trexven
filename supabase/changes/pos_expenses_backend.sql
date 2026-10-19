-- POS Expenses backend only. Owner expense SELECT projection remains unchanged.
-- No automatic employee permission grants and no historical data rewrite.
set lock_timeout = '5s';
set statement_timeout = '30s';

alter table public.expenses
 add column branch_id uuid references public.branches(id),
 add column shift_id uuid references public.cash_shifts(id),
 add column request_id uuid,
 add column business_date date,
 add column business_timezone text;
create unique index expenses_request_id_key on public.expenses(request_id) where request_id is not null;
create index expenses_branch_history_idx on public.expenses(business_id,branch_id,created_at desc,id desc);
create index expenses_member_history_idx on public.expenses(business_id,employee_id,branch_id,created_at desc,id desc);
create index expenses_shift_idx on public.expenses(shift_id) where shift_id is not null;

insert into public.permissions(id,description) values
 ('record_expenses','Owner-granted authority to record cash expenses and read own branch expense history'),
 ('view_pos_expenses','Owner-granted manager authority to read expense history within an assigned branch')
on conflict(id) do nothing;

-- Keep existing restrictive account/admin/finance boundaries. Employees use scoped RPCs.
revoke all on public.expenses from public, anon;
revoke insert,update,delete,truncate,references,trigger on public.expenses from authenticated;
grant select on public.expenses to authenticated;
create policy "Expenses owner raw read boundary" on public.expenses
 as restrictive for select to authenticated
 using (public.user_owns_business(business_id));
create policy "Expenses owner read compatibility" on public.expenses
 for select to authenticated using (public.user_owns_business(business_id));

create function private.guard_expense_links() returns trigger
language plpgsql security definer set search_path = '' as $fn$
begin
 if new.employee_id is not null and not exists(
  select 1 from public.business_members m where m.id=new.employee_id and m.business_id=new.business_id
 ) then raise exception 'Expense member business mismatch' using errcode='23514'; end if;
 if new.branch_id is not null and not exists(
  select 1 from public.branches b where b.id=new.branch_id and b.business_id=new.business_id
 ) then raise exception 'Expense branch business mismatch' using errcode='23514'; end if;
 if new.shift_id is not null and not exists(
  select 1 from public.cash_shifts s where s.id=new.shift_id and s.business_id=new.business_id
  and s.branch_id is not distinct from new.branch_id
 ) then raise exception 'Expense shift business or branch mismatch' using errcode='23514'; end if;
 return new;
end $fn$;
revoke all on function private.guard_expense_links() from public,anon,authenticated;
create trigger expense_links_boundary before insert or update on public.expenses
for each row execute function private.guard_expense_links();

create function public.record_pos_expense(
 p_business_id uuid, p_request_id uuid, p_amount numeric, p_category text,
 p_description text default null, p_branch_id uuid default null, p_shift_id uuid default null
) returns jsonb language plpgsql security definer set search_path = '' as $fn$
declare
 v_member uuid; v_payload jsonb; v_prior jsonb; v_day jsonb;
 v_expense public.expenses%rowtype; v_result jsonb; v_now timestamptz;
begin
 perform private.operations_context(p_business_id,'pos_access',p_branch_id);
 perform private.operations_context(p_business_id,'record_expenses',p_branch_id);
 if private.has_business_permission(p_business_id,'pos_access') is distinct from true
 or private.has_business_permission(p_business_id,'record_expenses') is distinct from true then
  raise exception 'Explicit expense authority required' using errcode='42501'; end if;
 select m.id into v_member from public.business_members m
 where m.business_id=p_business_id and m.user_id=auth.uid() and m.status='active' for share;
 if v_member is null then raise exception 'Active business membership required' using errcode='42501'; end if;
 -- Payload contains exact submitted values. Changing a retry intent is never silently accepted.
 v_payload:=jsonb_build_object('operation','record_pos_expense','amount',p_amount,
  'category',p_category,'description',p_description,'branch',p_branch_id,'shift',p_shift_id);
 v_prior:=private.operation_replay(p_business_id,p_request_id,v_payload);
 if v_prior is not null then return v_prior; end if;
 if not private.valid_money(p_amount,false) or p_category is null or p_category not in
 ('Shop supplies','Food & refreshments','Transport','Utilities','Other expense')
 or coalesce(length(p_description),0)>2000 then
  raise exception 'Positive money with at most two decimals, supported category and description up to 2000 characters required'
   using errcode='22023';
 end if;
 -- Null intentionally means no drawer, even if active registers exist.
 if p_shift_id is not null then
  perform private.operations_context(p_business_id,'cash_shifts',p_branch_id);
  -- Locks the selected shift and rechecks open status, business/branch,
  -- active member/register assignment, and joined shift membership.
  perform private.validate_operational_shift(p_business_id,v_member,p_shift_id,p_branch_id,false);
 end if;
 v_day:=public.get_trexven_business_day(p_business_id);
 v_now:=private.business_timestamp();
 insert into public.expenses(business_id,employee_id,category,description,amount,payment_method,
  created_at,branch_id,shift_id,request_id,business_date,business_timezone)
 values(p_business_id,v_member,p_category,nullif(btrim(p_description),''),p_amount,'cash',
  v_now,p_branch_id,p_shift_id,p_request_id,(v_day->>'local_date')::date,v_day->>'timezone')
 returning * into v_expense;
 if p_shift_id is not null then
  -- Expense UUID is the cash reference, distinct from a manual movement request.
  -- No cash_transactions entry: drawer totals already sum cash_events.
  insert into public.cash_events(business_id,shift_id,member_id,actor_id,amount,kind,reference_id,reason,late)
  values(p_business_id,p_shift_id,v_member,auth.uid(),-p_amount,'cash_out',v_expense.id,
   'Expense: '||p_category||coalesce(' - '||nullif(btrim(p_description),''),''),false);
 end if;
 v_result:=to_jsonb(v_expense);
 insert into public.audit_logs(business_id,actor_id,action,metadata)
 values(p_business_id,auth.uid(),'pos_expense_recorded',jsonb_build_object(
  'expense_id',v_expense.id,'request_id',p_request_id,'member_id',v_member,
  'branch_id',p_branch_id,'shift_id',p_shift_id,'amount',p_amount,'payment_method','cash',
  'business_date',v_expense.business_date));
 perform private.operation_save(p_business_id,p_request_id,v_payload,v_result);
 return v_result;
end $fn$;
revoke all on function public.record_pos_expense(uuid,uuid,numeric,text,text,uuid,uuid) from public,anon;
grant execute on function public.record_pos_expense(uuid,uuid,numeric,text,text,uuid,uuid) to authenticated;

create function public.get_pos_expenses(
 p_business_id uuid, p_branch_id uuid default null, p_limit integer default 50,
 p_before_created_at timestamptz default null, p_before_id uuid default null,
 p_branch_history boolean default false
) returns jsonb language plpgsql security definer set search_path = '' as $fn$
declare v_member uuid; v_rows jsonb; v_last jsonb; v_limit integer;
begin
 perform private.operations_context(p_business_id,'pos_access',p_branch_id);
 if p_branch_history is true then
  -- Only owners or explicitly granted active managers can request branch history.
  perform private.operations_context(p_business_id,'view_pos_expenses',p_branch_id,true);
 else
  perform private.operations_context(p_business_id,'record_expenses',p_branch_id);
 end if;
 if private.has_business_permission(p_business_id,'pos_access') is distinct from true
 or private.has_business_permission(p_business_id,case when p_branch_history is true
  then 'view_pos_expenses' else 'record_expenses' end) is distinct from true then
  raise exception 'Explicit expense history authority required' using errcode='42501'; end if;
 select id into v_member from public.business_members
 where business_id=p_business_id and user_id=auth.uid() and status='active' for share;
 if v_member is null then raise exception 'Active business membership required' using errcode='42501'; end if;
 if (p_before_created_at is null) <> (p_before_id is null) then
  raise exception 'Both cursor fields are required' using errcode='22023'; end if;
 v_limit:=greatest(1,least(coalesce(p_limit,50),100));
 select coalesce(jsonb_agg(to_jsonb(q) order by q.created_at desc,q.id desc),'[]'::jsonb) into v_rows
 from (
  select e.id,e.business_id,e.employee_id,e.category,e.description,e.amount,e.payment_method,
   e.created_at,e.branch_id,e.shift_id,e.request_id,e.business_date,e.business_timezone
  from public.expenses e
  where e.business_id=p_business_id and e.branch_id is not distinct from p_branch_id
   and (p_branch_history is true or e.employee_id=v_member)
   and (p_before_created_at is null or (e.created_at,e.id)<(p_before_created_at,p_before_id))
  order by e.created_at desc,e.id desc limit v_limit
 ) q;
 v_last:=v_rows->(jsonb_array_length(v_rows)-1);
 return jsonb_build_object('items',v_rows,'scope',case when p_branch_history is true then 'branch' else 'own' end,
  'next_cursor',case when jsonb_array_length(v_rows)=v_limit then
   jsonb_build_object('created_at',v_last->'created_at','id',v_last->'id') else null end);
end $fn$;
revoke all on function public.get_pos_expenses(uuid,uuid,integer,timestamptz,uuid,boolean) from public,anon;
grant execute on function public.get_pos_expenses(uuid,uuid,integer,timestamptz,uuid,boolean) to authenticated;

comment on function public.record_pos_expense(uuid,uuid,numeric,text,text,uuid,uuid) is
 'Cash only; server business date; durable actor-bound retries; optional explicitly selected authorized open drawer. POS UI not yet wired.';
notify pgrst, 'reload schema';
