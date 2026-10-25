-- Angel Scan authorization contract (staged; apply only with the complete frontend rollout).
-- Explicit manager grant is separate from generic edit_products/add_products.
insert into public.permissions(id,description) values
 ('angel_scan_inventory','Use Angel Scan to prepare product and receipt inventory changes')
on conflict (id) do nothing;

create or replace function public.angel_scan_can_manage_inventory(p_business_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and
  (public.user_owns_business(p_business_id) or exists (
    select 1 from public.business_members m
    join public.employees e on e.business_id=m.business_id and e.user_id=m.user_id
    join public.employee_permissions ep on ep.employee_id=e.id
    where m.business_id=p_business_id and m.user_id=auth.uid()
      and m.status='active' and m.role='manager'
      and e.status='active' and e.role='manager'
      and ep.permission_id='angel_scan_inventory' and ep.granted=true
      and private.has_business_permission(p_business_id,'view_inventory') is true
  ));
$$;
revoke all on function public.angel_scan_can_manage_inventory(uuid) from public,anon;
grant execute on function public.angel_scan_can_manage_inventory(uuid) to authenticated;

create or replace function public.angel_scan_can_sell(p_business_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null
   and (public.user_owns_business(p_business_id) or
     (private.has_business_permission(p_business_id,'pos_access') is true
     and private.has_business_permission(p_business_id,'complete_sales') is true));
$$;
revoke all on function public.angel_scan_can_sell(uuid) from public,anon;
grant execute on function public.angel_scan_can_sell(uuid) to authenticated;

-- Approval inbox: image recognition only PREPARES records; no direct AI database writes.
create table if not exists public.angel_inventory_approval_requests (
 id uuid primary key default gen_random_uuid(),
 business_id uuid not null references public.businesses(id),
 branch_id uuid null,
 requested_by uuid not null references auth.users(id),
 items jsonb not null check (jsonb_typeof(items)='array' and jsonb_array_length(items) between 1 and 80),
 status text not null default 'pending' check (status in ('pending','approved','rejected','cancelled')),
 owner_decided_by uuid null references auth.users(id),
 owner_decided_at timestamptz,
 owner_note text,
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now()
);
create index if not exists angel_inventory_approval_requests_business_status_idx
 on public.angel_inventory_approval_requests(business_id,status,created_at desc);
alter table public.angel_inventory_approval_requests enable row level security;
revoke all on public.angel_inventory_approval_requests from public,anon,authenticated;
grant select on public.angel_inventory_approval_requests to authenticated;
create policy angel_inventory_approval_owner_view on public.angel_inventory_approval_requests
 for select to authenticated using (public.user_owns_business(business_id));
create policy angel_inventory_approval_requester_view on public.angel_inventory_approval_requests
 for select to authenticated using (requested_by=(select auth.uid()) and public.is_business_member(business_id));

create or replace function public.submit_angel_inventory_approval(
 p_business_id uuid,p_items jsonb,p_branch_id uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare new_id uuid;
begin
 if not public.angel_scan_can_manage_inventory(p_business_id)
   or public.user_owns_business(p_business_id)
   or p_items is null or jsonb_typeof(p_items)<>'array'
   or jsonb_array_length(p_items) not between 1 and 80
 then raise exception 'Manager approval submission not permitted' using errcode='42501';end if;
 if p_branch_id is not null and not exists(
  select 1 from public.employee_branch_assignments a join public.employees e on e.id=a.employee_id
  where e.user_id=auth.uid() and a.business_id=p_business_id
   and a.branch_id=p_branch_id and a.is_active=true
 ) then raise exception 'Branch assignment required' using errcode='42501';end if;
 insert into public.angel_inventory_approval_requests(business_id,branch_id,requested_by,items)
 values(p_business_id,p_branch_id,auth.uid(),p_items) returning id into new_id;
 return new_id;
end $$;
revoke all on function public.submit_angel_inventory_approval(uuid,jsonb,uuid) from public,anon;
grant execute on function public.submit_angel_inventory_approval(uuid,jsonb,uuid) to authenticated;

-- Decision marks the request, but does NOT apply stock or price changes.
-- A separate confirmed, idempotent inventory RPC must apply reviewed rows.
create or replace function public.decide_angel_inventory_approval(
 p_business_id uuid,p_request_id uuid,p_approve boolean,p_note text default null)
returns text language plpgsql security definer set search_path='' as $$
declare next_status text;
begin
 if not public.user_owns_business(p_business_id) or p_approve is null then
  raise exception 'Verified owner required' using errcode='42501';end if;
 next_status:=case when p_approve then 'approved' else 'rejected' end;
 update public.angel_inventory_approval_requests
 set status=next_status,owner_decided_by=auth.uid(),owner_decided_at=now(),
 owner_note=left(coalesce(p_note,''),500),updated_at=now()
 where business_id=p_business_id and id=p_request_id and status='pending';
 if not found then raise exception 'Pending request not found';end if;
 return next_status;
end $$;
revoke all on function public.decide_angel_inventory_approval(uuid,uuid,boolean,text) from public,anon;
grant execute on function public.decide_angel_inventory_approval(uuid,uuid,boolean,text) to authenticated;

-- Owner notification feed extension, keeping existing function signatures.
-- Existing private.trexven_visible_notifications is a complex function;
-- adding the inbox at public.get_trexven_notifications avoids replacing
-- POS branch routing or its existing owner notification filtering.
create or replace function public.get_trexven_notifications(
 p_business_id uuid,p_application text default 'pos',p_offset integer default 0)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if p_offset is null or p_offset<0 or p_offset>100000 then raise exception 'Invalid notification page';end if;
 if p_application='owner' and not public.user_owns_business(p_business_id) then
 raise exception 'Verified owner required' using errcode='42501';end if;
 select coalesce(jsonb_agg(to_jsonb(t) order by t.occurred_at desc nulls last,t.alert_key),'[]'::jsonb) into result from (
  select u.*,r.read_at from (
    select n.* from private.trexven_visible_notifications(p_business_id,p_application) n
    union all
    select 'angel_inventory_approval:'||a.id::text,
      'Angel inventory approval requested'::text,
      'A manager submitted '||jsonb_array_length(a.items)::text||' products for review.'::text,
      'angel_inventory_approval'::text,a.id,a.created_at
    from public.angel_inventory_approval_requests a
    where p_application='owner' and public.user_owns_business(p_business_id)
      and a.business_id=p_business_id and a.status='pending'
  ) u left join public.trexven_notification_reads r on
   r.business_id=p_business_id and r.user_id=auth.uid() and r.alert_key=u.alert_key
  order by u.occurred_at desc nulls last,u.alert_key limit 100 offset p_offset
 ) t;
 return result;
end $$;
revoke all on function public.get_trexven_notifications(uuid,text,integer) from public,anon;
grant execute on function public.get_trexven_notifications(uuid,text,integer) to authenticated;
notify pgrst,'reload schema';
