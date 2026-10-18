begin;
alter table public.cash_handovers add column accepted_counted numeric(18,2);
alter table public.cash_handovers add column expected_at_accept numeric(18,2);
alter table public.cash_handovers add column accepted_at timestamptz;
create function private.can_read_cash_register(reg uuid) returns boolean language sql stable security definer set search_path='' as $$
 select exists(select 1 from public.cash_registers r where r.id=reg and
 (r.branch_id is null or private.has_branch_access(r.business_id,r.branch_id)) and
 (public.user_owns_business(r.business_id) or (private.has_business_permission(r.business_id,'review_cash_shifts') and exists(
 select 1 from public.employees e where e.business_id=r.business_id and e.user_id=auth.uid() and e.status='active' and e.role='manager')) or exists(
 select 1 from public.cash_register_assignments a join public.business_members m on m.id=a.member_id where a.register_id=r.id and a.active and m.business_id=r.business_id and m.user_id=auth.uid() and m.status='active')))
$$;
revoke all on function private.can_read_cash_register(uuid) from public,anon;
grant execute on function private.can_read_cash_register(uuid) to authenticated;
create policy "Assigned register boundary" on public.cash_registers as restrictive for select to authenticated using(private.can_read_cash_register(id));
create policy "Assigned shift boundary" on public.cash_shifts as restrictive for select to authenticated using(private.can_read_cash_register(register_id));
create policy "Event shift boundary" on public.cash_events as restrictive for select to authenticated using(exists(select 1 from public.cash_shifts where id=shift_id));
create policy "Handover shift boundary" on public.cash_handovers as restrictive for select to authenticated using(exists(select 1 from public.cash_shifts where id=shift_id));
create function public.request_trexven_cash_handover(p_shift_id uuid,p_request_id uuid,p_incoming_member uuid,p_counted numeric,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.cash_shifts%rowtype; member uuid; payload jsonb; prior jsonb; result jsonb; handover uuid;
begin
 select * into s from public.cash_shifts where id=p_shift_id;if not found then raise exception 'Shift unavailable' using errcode='42501';end if;
 perform private.operations_context(s.business_id,'cash_shifts',s.branch_id);
 payload:=jsonb_build_object('operation','request_handover','shift',s.id,'incoming',p_incoming_member,'counted',p_counted,'reason',p_reason);
 prior:=private.operation_replay(s.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select id into member from public.business_members where business_id=s.business_id and user_id=auth.uid() and status='active';
 perform private.validate_operational_shift(s.business_id,member,s.id,s.branch_id);
 if not private.valid_money(p_counted,true) or p_incoming_member=member or nullif(btrim(p_reason),'') is null or not exists(
 select 1 from public.cash_register_assignments a join public.business_members m on m.id=a.member_id where a.register_id=s.register_id and a.member_id=p_incoming_member and a.active and m.business_id=s.business_id and m.status='active') then raise exception 'Distinct assigned incoming employee, count and reason required';end if;
 insert into public.cash_handovers(business_id,shift_id,outgoing_member,incoming_member,requested_by,counted,expected,reason)
 values(s.business_id,s.id,member,p_incoming_member,auth.uid(),p_counted,s.opening_amount+coalesce((select sum(amount) from public.cash_events where shift_id=s.id),0),p_reason) returning id into handover;
 result:=jsonb_build_object('id',handover,'status','pending');perform private.operation_save(s.business_id,p_request_id,payload,result);return result;
end $$;
create function public.confirm_trexven_cash_handover(p_handover_id uuid,p_request_id uuid,p_accept boolean,p_counted numeric)
returns jsonb language plpgsql security definer set search_path='' as $$
declare h public.cash_handovers%rowtype; s public.cash_shifts%rowtype; payload jsonb; prior jsonb; result jsonb; member uuid;
begin
 select * into h from public.cash_handovers where id=p_handover_id;if not found then raise exception 'Handover unavailable' using errcode='42501';end if;
 select * into s from public.cash_shifts where id=h.shift_id;
 perform private.operations_context(h.business_id,'cash_shifts',s.branch_id);
 select id into member from public.business_members where business_id=h.business_id and user_id=auth.uid() and status='active';
 if member is distinct from h.incoming_member then raise exception 'Only the assigned incoming employee may confirm' using errcode='42501';end if;
 payload:=jsonb_build_object('operation','confirm_handover','handover',h.id,'accept',p_accept,'counted',p_counted);prior:=private.operation_replay(h.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select * into s from public.cash_shifts where id=h.shift_id for update;
 select * into h from public.cash_handovers where id=p_handover_id for update;
 if h.status<>'pending' or s.status<>'open' or p_accept is null or not private.valid_money(p_counted,true) then raise exception 'Pending open drawer and incoming count required';end if;
 insert into public.cash_shift_members(shift_id,member_id) values(s.id,member) on conflict do nothing;
 perform private.validate_operational_shift(h.business_id,member,s.id,s.branch_id);
 update public.cash_handovers set status=case when p_accept then 'accepted' else 'rejected' end,confirmed_by=auth.uid(),accepted_counted=p_counted,
 expected_at_accept=s.opening_amount+coalesce((select sum(amount) from public.cash_events where shift_id=s.id),0),accepted_at=clock_timestamp() where id=h.id;
 result:=jsonb_build_object('id',h.id,'accepted',p_accept);insert into public.audit_logs(business_id,actor_id,action,metadata) values(h.business_id,auth.uid(),'shared_drawer_handover',payload);
 perform private.operation_save(h.business_id,p_request_id,payload,result);return result;
end $$;
revoke all on function public.request_trexven_cash_handover(uuid,uuid,uuid,numeric,text),public.confirm_trexven_cash_handover(uuid,uuid,boolean,numeric) from public,anon;
grant execute on function public.request_trexven_cash_handover(uuid,uuid,uuid,numeric,text),public.confirm_trexven_cash_handover(uuid,uuid,boolean,numeric) to authenticated;
commit;
