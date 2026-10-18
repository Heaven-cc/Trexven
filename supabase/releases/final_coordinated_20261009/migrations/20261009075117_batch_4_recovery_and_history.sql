-- Append-only corrections. No original receipt or payment is overwritten.
begin;
insert into public.permissions(id,description) values
 ('reverse_credit_repayment','Explicit manager authority for confirmed repayment corrections') on conflict(id) do nothing;
create unique index credit_entries_one_reversal on public.credit_entries(reference_id)
 where kind='repayment_reversal';
create function public.reverse_trexven_credit_repayment(p_entry_id uuid,p_request_id uuid,p_reason text,
 p_confirmed boolean,p_evidence text default null,p_shift_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare e public.credit_entries%rowtype; a public.credit_accounts%rowtype; payload jsonb; prior jsonb; result jsonb; member uuid;
begin
 select * into e from public.credit_entries where id=p_entry_id and kind='repayment';
 if not found then raise exception 'Repayment not found' using errcode='42501';end if;
 select * into a from public.credit_accounts where sale_id=e.sale_id;
 perform private.operations_context(e.business_id,'reverse_credit_repayment',a.branch_id,true);
 payload:=jsonb_build_object('operation','repayment_reversal','entry',p_entry_id,'reason',p_reason,'confirmed',p_confirmed,'evidence',p_evidence,'shift',p_shift_id);
 prior:=private.operation_replay(e.business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select * into a from public.credit_accounts where sale_id=e.sale_id for update;
 if p_confirmed is distinct from true or nullif(btrim(p_reason),'') is null
 or (e.method<>'cash' and nullif(btrim(p_evidence),'') is null) then raise exception 'Confirm actual reversal, reason and external reference';end if;
 if exists(select 1 from public.credit_entries where reference_id=e.id and kind='repayment_reversal') then raise exception 'Repayment already reversed';end if;
 -- Refunded money cannot also be reversed. Keep method-level collections nonnegative.
 if -e.amount > coalesce((select sum(amount) from public.sale_payments where sale_id=e.sale_id and method=e.method),0)
  -coalesce((select sum(amount) from public.credit_entries where sale_id=e.sale_id and method=e.method and kind in('repayment','repayment_reversal')),0)
  -coalesce((select sum(refund_amount) from public.sale_returns where sale_id=e.sale_id and status='approved' and refund_method=e.method),0)
 then raise exception 'Reversal exceeds remaining collected funds';end if;
 select id into member from public.business_members where business_id=e.business_id and user_id=auth.uid() and status='active';
 if e.method='cash' then perform private.validate_operational_shift(e.business_id,member,p_shift_id,a.branch_id);end if;
 insert into public.credit_entries(business_id,sale_id,request_id,actor_id,kind,amount,method,evidence,reason,reference_id)
 values(e.business_id,e.sale_id,p_request_id,auth.uid(),'repayment_reversal',-e.amount,e.method,p_evidence,p_reason,e.id);
 update public.credit_accounts set outstanding=outstanding-e.amount where sale_id=e.sale_id;
 if e.method='cash' then perform private.record_operational_cash(e.business_id,member,e.amount,'repayment_reversal',p_request_id,p_shift_id);end if;
 result:=jsonb_build_object('sale_id',e.sale_id,'outstanding',a.outstanding-e.amount,'reversed_entry',e.id);
 insert into public.audit_logs(business_id,actor_id,action,metadata) values(e.business_id,auth.uid(),'credit_repayment_reversed',result||jsonb_build_object('reason',p_reason));
 perform private.operation_save(e.business_id,p_request_id,payload,result);return result;
end $$;
revoke all on function public.reverse_trexven_credit_repayment(uuid,uuid,text,boolean,text,uuid) from public,anon;
grant execute on function public.reverse_trexven_credit_repayment(uuid,uuid,text,boolean,text,uuid) to authenticated;
commit;
