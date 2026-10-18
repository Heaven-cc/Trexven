-- Inert foundation: no automatic default branch, stock allocation or activation.
begin;
alter table public.businesses add column if not exists timezone text;
alter table public.businesses add column if not exists branches_enabled boolean not null default false;
-- Recovery control only; not a subscription or business lifecycle entitlement.
alter table public.businesses add column if not exists pos_writes_paused boolean not null default false;
alter table public.businesses add column if not exists compatibility_branch_id uuid;
alter table public.products add constraint batch_2_products_identity unique(id,business_id);
alter table public.employees add constraint batch_2_employees_identity unique(id,business_id);
-- Legacy duplicates stop the migration; never rewrite existing employee codes.
create unique index batch_2_employee_code_unique on public.employees(employee_code);

create table public.branches(
 id uuid primary key default gen_random_uuid(), business_id uuid not null references public.businesses(id),
 name text not null check(nullif(trim(name),'') is not null), is_active boolean not null default true,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(), unique(id,business_id));
create index branches_business_idx on public.branches(business_id);
create table public.employee_branch_assignments(
 business_id uuid not null, employee_id uuid not null, branch_id uuid not null,
 is_active boolean not null default true, created_at timestamptz not null default now(),
 primary key(employee_id,branch_id),
 foreign key(employee_id,business_id) references public.employees(id,business_id),
 foreign key(branch_id,business_id) references public.branches(id,business_id));
create index employee_branch_business_idx on public.employee_branch_assignments(business_id,branch_id);
alter table public.businesses add constraint batch_2_compatibility_branch foreign key(compatibility_branch_id,id)
 references public.branches(id,business_id) not valid;

alter table public.inventory add column if not exists branch_id uuid;
alter table public.inventory_movements add column if not exists branch_id uuid;
alter table public.sales add column if not exists branch_id uuid;
alter table public.inventory add constraint batch_2_inventory_product foreign key(product_id,business_id) references public.products(id,business_id) not valid;
alter table public.inventory_movements add constraint batch_2_movement_product foreign key(product_id,business_id) references public.products(id,business_id) not valid;
do $$ declare t text; begin
 foreach t in array array['inventory','inventory_movements','sales'] loop
   execute format('alter table public.%I add constraint batch_2_%s_branch foreign key(branch_id,business_id) references public.branches(id,business_id) not valid',t,t);
   execute format('create index batch_2_%s_branch_idx on public.%I(business_id,branch_id)',t,t);
 end loop;
end $$;
create unique index batch_2_inventory_branch_product on public.inventory(business_id,branch_id,product_id) where branch_id is not null;

create or replace function private.has_branch_access(business uuid, branch uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and exists(select 1 from public.branches b
 where b.id=branch and b.business_id=business and b.is_active and (
 public.user_owns_business(business) or (public.is_business_member(business) and exists(
 select 1 from public.employee_branch_assignments a join public.employees e on e.id=a.employee_id and e.business_id=a.business_id
 where a.business_id=business and a.branch_id=branch and a.is_active and e.user_id=auth.uid() and e.status='active'))))
$$;
revoke all on function private.has_branch_access(uuid,uuid) from public,anon;
grant execute on function private.has_branch_access(uuid,uuid) to authenticated;

alter table public.branches enable row level security;
alter table public.employee_branch_assignments enable row level security;
revoke all on public.branches,public.employee_branch_assignments from public,anon,authenticated;
grant select on public.branches,public.employee_branch_assignments to authenticated;
create policy "Branch authorized read" on public.branches for select to authenticated
 using(public.user_owns_business(business_id) or private.has_branch_access(business_id,id));
create policy "Assignment authorized read" on public.employee_branch_assignments for select to authenticated
 using(public.user_owns_business(business_id) or exists(select 1 from public.employees e where e.id=employee_id and e.user_id=(select auth.uid())));

create or replace function public.create_trexven_branch(p_business_id uuid,p_name text)
returns uuid language plpgsql security definer set search_path='' as $$
declare result uuid; begin
 if not public.user_owns_business(p_business_id) then raise exception 'Owner required' using errcode='42501'; end if;
 insert into public.branches(business_id,name) values(p_business_id,trim(p_name)) returning id into result;
 insert into public.audit_logs(business_id,actor_id,action,metadata) values(p_business_id,auth.uid(),'branch_created',jsonb_build_object('branch_id',result));
 return result;
end $$;
create or replace function public.set_trexven_branch_assignment(p_employee_id uuid,p_branch_id uuid,p_active boolean)
returns void language plpgsql security definer set search_path='' as $$
declare e public.employees%rowtype; begin
 select * into e from public.employees where id=p_employee_id for update;
 if not found or not public.user_owns_business(e.business_id) or p_active is null then
 raise exception 'Owner required' using errcode='42501'; end if;
 if not exists(select 1 from public.branches where id=p_branch_id and business_id=e.business_id and (is_active or not p_active)) then
 raise exception 'Invalid branch' using errcode='42501'; end if;
 insert into public.employee_branch_assignments(business_id,employee_id,branch_id,is_active)
 values(e.business_id,e.id,p_branch_id,p_active) on conflict(employee_id,branch_id) do update set is_active=excluded.is_active;
 insert into public.audit_logs(business_id,actor_id,target_id,action,metadata)
 values(e.business_id,auth.uid(),e.id,'branch_assignment_changed',jsonb_build_object('branch_id',p_branch_id,'active',p_active));
end $$;
revoke all on function public.create_trexven_branch(uuid,text),public.set_trexven_branch_assignment(uuid,uuid,boolean) from public,anon;
grant execute on function public.create_trexven_branch(uuid,text),public.set_trexven_branch_assignment(uuid,uuid,boolean) to authenticated;

create or replace function public.set_trexven_branch_status(p_branch_id uuid,p_active boolean)
returns void language plpgsql security definer set search_path='' as $$
declare b public.branches%rowtype; begin
 select * into b from public.branches where id=p_branch_id for update;
 if not found or p_active is null or not public.user_owns_business(b.business_id) then
 raise exception 'Owner required' using errcode='42501'; end if;
 update public.branches set is_active=p_active,updated_at=now() where id=b.id;
 insert into public.audit_logs(business_id,actor_id,action,metadata)
 values(b.business_id,auth.uid(),'branch_status_changed',jsonb_build_object('branch_id',b.id,'active',p_active));
end $$;
revoke all on function public.set_trexven_branch_status(uuid,boolean) from public,anon;
grant execute on function public.set_trexven_branch_status(uuid,boolean) to authenticated;

-- Activation is intentionally unavailable through client APIs until a separate
-- reviewed stock-allocation migration and runtime rehearsal have succeeded.
create or replace function private.guard_business_foundation()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if new.timezone is not null and not exists(select 1 from pg_catalog.pg_timezone_names where name=new.timezone) then
 raise exception 'Invalid business timezone'; end if;
 if auth.uid() is not null then
   if tg_op='INSERT' then
     if new.owner_id is distinct from auth.uid() or new.branches_enabled or new.pos_writes_paused or new.compatibility_branch_id is not null then
       raise exception 'Business identity/activation requires reviewed migration' using errcode='42501'; end if;
   elsif new.owner_id is distinct from old.owner_id or new.branches_enabled is distinct from old.branches_enabled
     or new.pos_writes_paused is distinct from old.pos_writes_paused
     or new.compatibility_branch_id is distinct from old.compatibility_branch_id then
     raise exception 'Business identity/activation requires reviewed migration' using errcode='42501'; end if;
 end if;
 return new;
end $$;
revoke all on function private.guard_business_foundation() from public,anon,authenticated;
create trigger batch_2_business_foundation before insert or update on public.businesses for each row execute function private.guard_business_foundation();

create or replace function private.branch_record_access(business uuid,branch uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select public.user_owns_business(business) or (public.is_business_member(business) and
 (case when branch is not null then private.has_branch_access(business,branch)
 else exists(select 1 from public.businesses where id=business and not branches_enabled) end))
$$;
revoke all on function private.branch_record_access(uuid,uuid) from public,anon;
grant execute on function private.branch_record_access(uuid,uuid) to authenticated;
create policy "Sales branch boundary" on public.sales as restrictive for select to authenticated
 using(private.branch_record_access(business_id,branch_id));
create policy "Inventory branch boundary" on public.inventory as restrictive for select to authenticated
 using(private.branch_record_access(business_id,branch_id));
create policy "Movement branch boundary" on public.inventory_movements as restrictive for select to authenticated
 using(private.branch_record_access(business_id,branch_id));

create or replace function private.guard_legacy_stock()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if tg_op='INSERT' then
   if coalesce(new.quantity,0)=0 then return new; end if;
 else
   if new.quantity is not distinct from old.quantity then return new; end if;
 end if;
 if exists(select 1 from public.businesses where id=new.business_id and branches_enabled) then
   raise exception 'Activated stock requires branch context' using errcode='42501'; end if;
 return new;
end $$;
revoke all on function private.guard_legacy_stock() from public,anon,authenticated;
create trigger batch_2_legacy_stock before insert or update of quantity on public.products for each row execute function private.guard_legacy_stock();

create or replace function private.can_read_staff(business uuid,employee uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select public.user_owns_business(business) or exists(select 1 from public.employees e
 where e.id=employee and e.business_id=business and public.is_business_member(business) and
 (e.user_id=auth.uid() or (e.role not in ('owner','manager') and private.has_business_permission(business,'manage_employees') and
 (exists(select 1 from public.businesses b where b.id=business and not b.branches_enabled) or
 (exists(select 1 from public.employee_branch_assignments a where a.employee_id=e.id and a.is_active) and
 not exists(select 1 from public.employee_branch_assignments a where a.employee_id=e.id and a.is_active and not private.has_branch_access(business,a.branch_id)))))))
$$;
revoke all on function private.can_read_staff(uuid,uuid) from public,anon;
grant execute on function private.can_read_staff(uuid,uuid) to authenticated;
create policy "Staff read scope" on public.employees as restrictive for select to authenticated
 using(private.can_read_staff(business_id,id));
create policy "Membership read scope" on public.business_members as restrictive for select to authenticated
 using(public.user_owns_business(business_id) or user_id=(select auth.uid()) or
 exists(select 1 from public.employees e where e.business_id=business_members.business_id and e.user_id=business_members.user_id
        and private.can_read_staff(e.business_id,e.id)));
create policy "Owner settings boundary" on public.business_settings as restrictive for all to authenticated
 using(public.user_owns_business(business_id)) with check(public.user_owns_business(business_id));
-- Legacy financial rows have no branch mapping. Never expose business-wide
-- unmapped financial data to branch-restricted staff after activation.
do $$ declare t text; begin
 foreach t in array array['expenses','cash_transactions','financial_transactions'] loop
   execute format('create policy "Legacy finance branch boundary" on public.%I as restrictive for all to authenticated using (private.branch_record_access(business_id,null)) with check (private.branch_record_access(business_id,null))',t);
 end loop;
end $$;

create or replace function private.sales_history_access(business uuid,sold_at timestamptz)
returns boolean language sql stable security definer set search_path='' as $$
 select public.user_owns_business(business) or (private.has_business_permission(business,'pos_access') and
 (private.has_business_permission(business,'view_finance') or exists(select 1 from public.businesses b
 join pg_catalog.pg_timezone_names tz on tz.name=b.timezone where b.id=business
 and (sold_at at time zone b.timezone)::date=(current_timestamp at time zone b.timezone)::date)))
$$;
revoke all on function private.sales_history_access(uuid,timestamptz) from public,anon;
grant execute on function private.sales_history_access(uuid,timestamptz) to authenticated;
alter policy "Sales read permission" on public.sales using(private.sales_history_access(business_id,created_at));
-- Child rows must inherit the exact sale visibility, even with older permissive policies.
create policy "Sale item scoped read" on public.sale_items as restrictive for select to authenticated
 using(exists(select 1 from public.sales s where s.id=sale_id));
-- Edge Functions call this with the verified caller's bearer token, never with
-- client-provided actor IDs or the service-role session.
create or replace function public.assert_trexven_staff_access(p_business_id uuid,p_employee_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare e public.employees%rowtype; owned boolean;
begin
 owned:=public.user_owns_business(p_business_id);
 if auth.uid() is null or (not owned and not private.has_business_permission(p_business_id,'manage_employees')) then
 raise exception 'Staff administration denied' using errcode='42501'; end if;
 if p_employee_id is not null then
   select * into e from public.employees where id=p_employee_id and business_id=p_business_id;
   if not found or e.role='owner' or exists(select 1 from public.businesses where id=p_business_id and owner_id=e.user_id)
   or (not owned and (e.role='manager' or e.user_id=auth.uid())) then
   raise exception 'Staff administration denied' using errcode='42501'; end if;
   if not owned and exists(select 1 from public.businesses where id=p_business_id and branches_enabled) and (
   not exists(select 1 from public.employee_branch_assignments where employee_id=e.id and is_active)
   or exists(select 1 from public.employee_branch_assignments a where a.employee_id=e.id and a.is_active
             and not private.has_branch_access(p_business_id,a.branch_id))) then
     raise exception 'Staff branch scope denied' using errcode='42501'; end if;
 end if;
 return jsonb_build_object('owner',owned);
end $$;
revoke all on function public.assert_trexven_staff_access(uuid,uuid) from public,anon;
grant execute on function public.assert_trexven_staff_access(uuid,uuid) to authenticated;

-- Employee/member/audit writes are atomic; Auth creation is compensated by Edge.
create or replace function public.finalize_trexven_employee(p_business_id uuid,p_user_id uuid,p_name text,
 p_email text,p_phone text,p_role text,p_employee_code text)
returns public.employees language plpgsql security definer set search_path='' as $$
declare access jsonb; e public.employees%rowtype;
begin
 access:=public.assert_trexven_staff_access(p_business_id,null);
 if p_role is null or p_role not in ('manager','sales_employee','inventory_employee','employee')
 or (not (access->>'owner')::boolean and p_role<>'employee') or nullif(trim(p_name),'') is null then
 raise exception 'Owner role assignment required' using errcode='42501'; end if;
 perform id from auth.users where id=p_user_id for update;
 if not found or exists(select 1 from public.businesses where owner_id=p_user_id)
 or exists(select 1 from public.employees where user_id=p_user_id)
 or exists(select 1 from public.business_members where user_id=p_user_id) then
 raise exception 'Employee identity unavailable' using errcode='42501'; end if;
 insert into public.employees(business_id,user_id,name,email,phone,role,employee_code,status)
 values(p_business_id,p_user_id,trim(p_name),p_email,p_phone,p_role,p_employee_code,'active') returning * into e;
 insert into public.business_members(business_id,user_id,full_name,email,phone,role,status,permissions)
 values(p_business_id,p_user_id,e.name,p_email,p_phone,case when p_role='manager' then 'manager' else 'employee' end,'active','{}');
 insert into public.audit_logs(business_id,actor_id,target_id,action,metadata)
 values(p_business_id,auth.uid(),e.id,'employee_created',jsonb_build_object('role',p_role,'employee_code',p_employee_code));
 return e;
end $$;
revoke all on function public.finalize_trexven_employee(uuid,uuid,text,text,text,text,text) from public,anon;
grant execute on function public.finalize_trexven_employee(uuid,uuid,text,text,text,text,text) to authenticated;

-- Apply branch scope to existing staff update/status wrappers without replacing
-- their identifiers or granting direct table access.
create or replace function private.guard_staff_scope()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if auth.uid() is not null and not public.user_owns_business(old.business_id) then
   perform public.assert_trexven_staff_access(old.business_id,old.id);
   if new.id is distinct from old.id or new.user_id is distinct from old.user_id
   or new.business_id is distinct from old.business_id or new.role is distinct from old.role then
     raise exception 'Staff identity/role is immutable for managers' using errcode='42501'; end if;
 end if;
 return new;
end $$;
revoke all on function private.guard_staff_scope() from public,anon,authenticated;
create trigger batch_2_staff_scope before update on public.employees for each row execute function private.guard_staff_scope();
commit;
