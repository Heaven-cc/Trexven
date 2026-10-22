-- PREPARED ONLY: Requires explicit approval before applying to production.
-- Sales History for the POS: returns a seven-business-local-day, identity-scoped
-- receipt feed. Does NOT change existing sales or sale_items RLS policies.
-- Existing POS must be updated before the endpoint is activated.
set lock_timeout = '5s';
set statement_timeout = '30s';

create or replace function public.get_pos_recent_sales(
  p_business_id uuid,
  p_branch_id uuid default null,
  p_offset integer default 0,
  p_limit integer default 100
) returns jsonb
language plpgsql stable security definer
set search_path = ''
as $$
declare
  v_member uuid;
  v_business record;
  v_can_branch_history boolean := false;
  v_result jsonb;
begin
  if auth.uid() is null or p_business_id is null then
    raise exception 'Authenticated business context required' using errcode='42501';
  end if;

  select b.id, b.timezone, b.branches_enabled
    into v_business
  from public.businesses b
  where b.id = p_business_id
    and public.trexven_account_access_allowed()
    and private.admin_business_access_allowed(b.id);

  if not found or coalesce(v_business.timezone,'') = ''
    or not exists(select 1 from pg_catalog.pg_timezone_names t where t.name=v_business.timezone) then
    raise exception 'Business or timezone unavailable' using errcode='42501';
  end if;

  select bm.id into v_member
    from public.business_members bm
   where bm.business_id=p_business_id and bm.user_id=auth.uid()
     and bm.status='active'
     and (public.user_owns_business(p_business_id) or exists (
       select 1 from public.employees e
       where e.business_id=p_business_id and e.user_id=auth.uid()
         and e.status='active'))
   limit 1;

  if v_member is null
    or private.has_business_permission(p_business_id,'pos_access') is distinct from true then
    raise exception 'Active POS membership required' using errcode='42501';
  end if;

  if coalesce(v_business.branches_enabled,false) then
    if p_branch_id is null or private.has_branch_access(p_business_id,p_branch_id) is distinct from true then
      raise exception 'Authorized branch required' using errcode='42501';
    end if;
  elsif p_branch_id is not null then
    raise exception 'Branch must be empty for single-location business' using errcode='22023';
  end if;

  if p_offset is null or p_offset < 0 or p_offset > 100000
     or p_limit is null or p_limit < 1 or p_limit > 200 then
     raise exception 'Invalid pagination' using errcode='22023';
  end if;

  -- Explicit finance permission enables branch-wide operational receipts.
  -- Employees without this grant see only sales tied to their own membership.
  v_can_branch_history :=
    public.user_owns_business(p_business_id)
    or private.has_business_permission(p_business_id,'view_finance');

  select coalesce(jsonb_agg(row_record.payload order by row_record.recorded_at desc, row_record.id desc),'[]'::jsonb)
    into v_result
  from (
    select s.id,
      coalesce(s.sold_at,s.created_at) as recorded_at,
      to_jsonb(s) || jsonb_build_object(
        'sale_items',coalesce((
          select jsonb_agg(to_jsonb(si) order by si.id)
          from public.sale_items si where si.sale_id=s.id
        ),'[]'::jsonb)
      ) as payload
    from public.sales s
    where s.business_id=p_business_id
      and (not coalesce(v_business.branches_enabled,false) or s.branch_id=p_branch_id)
      and (v_can_branch_history or s.employee_id=v_member)
      and (coalesce(s.sold_at,s.created_at) at time zone v_business.timezone)::date
          between ((private.business_timestamp() at time zone v_business.timezone)::date - 6)
              and (private.business_timestamp() at time zone v_business.timezone)::date
    order by recorded_at desc,s.id desc
    offset p_offset limit p_limit
  ) row_record;
  return v_result;
end
$$;

revoke all on function public.get_pos_recent_sales(uuid,uuid,integer,integer)
from public,anon,authenticated;
grant execute on function public.get_pos_recent_sales(uuid,uuid,integer,integer)
to authenticated;

comment on function public.get_pos_recent_sales(uuid,uuid,integer,integer) is
 'Seven business-local days of authorized POS receipts, active employee and branch scoped. Deliberately does not expose cross-business or unauthorized sales.';
