-- PHASE 1: PREPARED ONLY. Requires explicit production deployment approval.
-- Promote through the migration workflow after approval; do not replay manually.
-- No employee, permission, membership, or transaction rows are rewritten.

DO $guard$
BEGIN
  IF md5(pg_get_functiondef('private.account_deletion_previous_has_business_permission(uuid,text)'::regprocedure)) IS DISTINCT FROM '44ecf70a1f631d0894c1007a0696cf8a' THEN
    RAISE EXCEPTION 'Phase 1 baseline changed: account_deletion_previous_has_business_permission; review before deployment';
  END IF;
  IF md5(pg_get_functiondef('public.update_trexven_employee(uuid,text,text,text,text,text)'::regprocedure)) IS DISTINCT FROM 'ab1c996a9feb34c3110144394e2b8d81' THEN
    RAISE EXCEPTION 'Phase 1 baseline changed: update_trexven_employee; review before deployment';
  END IF;
  IF md5(pg_get_functiondef('public.set_trexven_employee_permission(uuid,text,boolean)'::regprocedure)) IS DISTINCT FROM 'bf73027d08b036d59c4f764470dc1a12' THEN
    RAISE EXCEPTION 'Phase 1 baseline changed: set_trexven_employee_permission; review before deployment';
  END IF;
  IF md5(pg_get_functiondef('private.can_read_staff(uuid,uuid)'::regprocedure)) IS DISTINCT FROM '0c30e7920f871ab593425dc9880cb209' THEN
    RAISE EXCEPTION 'Phase 1 baseline changed: can_read_staff; review before deployment';
  END IF;
  IF md5(pg_get_functiondef('public.assert_trexven_staff_access(uuid,uuid)'::regprocedure)) IS DISTINCT FROM '7359b857651f2d2e6caa4c25e9215f63' THEN
    RAISE EXCEPTION 'Phase 1 baseline changed: assert_trexven_staff_access; review before deployment';
  END IF;
  IF md5(pg_get_functiondef('public.get_trexven_pos_context(uuid)'::regprocedure)) IS DISTINCT FROM '05468b30a9003f4cbcdfd92147754715' THEN
    RAISE EXCEPTION 'Phase 1 baseline changed: get_trexven_pos_context; review before deployment';
  END IF;
END;
$guard$;

CREATE OR REPLACE FUNCTION private.account_deletion_previous_has_business_permission(business uuid, permission text)
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
 select auth.uid() is not null and permission is not null and permission <> 'view_profit' and (
 public.user_owns_business(business) or exists(
 select 1 from public.employees e join public.business_members m
 on m.business_id=e.business_id and m.user_id=e.user_id
 where e.business_id=business and e.user_id=auth.uid()
 and e.status='active' and m.status='active'
 and e.role in ('manager','sales_employee','inventory_employee','employee')
 -- Owner-only services and role/permission administration are never delegable.
 and permission not in ('view_camera_events','manage_permissions','assign_roles','owner_app','manage_employees')
 and (permission not in ('override_price','edit_prices','change_prices','manage_prices','set_prices','branch_price_override')
      or e.role='manager')
 and (permission<>'apply_discount' or e.role<>'inventory_employee')
 and (permission not in ('view_finance') or e.role='manager')
 and not exists(select 1 from public.employee_permissions denied where denied.employee_id=e.id
                and denied.permission_id=permission and not denied.granted)
 and (exists(select 1 from public.employee_permissions p join public.permissions d on d.id=p.permission_id
             where p.employee_id=e.id and p.permission_id=permission and p.granted)
 or (e.role='manager' and permission in ('pos_access','complete_sales','view_inventory','add_products','edit_products','adjust_stock'))
 or (e.role='sales_employee' and permission in ('pos_access','complete_sales','view_inventory'))
 or (e.role='inventory_employee' and permission in ('view_inventory','add_products','edit_products')))))
$function$;

CREATE OR REPLACE FUNCTION public.assert_trexven_staff_access(p_business_id uuid, p_employee_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare e public.employees%rowtype; owned boolean;
begin
 owned:=public.user_owns_business(p_business_id);
 if auth.uid() is null or not coalesce(owned,false) then
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
end $function$;

CREATE OR REPLACE FUNCTION private.can_read_staff(business uuid, employee uuid)
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path TO ''
AS $function$
 select public.user_owns_business(business) or exists (
   select 1 from public.employees e
   where e.id=employee and e.business_id=business and e.user_id=auth.uid()
   and public.is_business_member(business)
 )
$function$;

CREATE OR REPLACE FUNCTION public.get_trexven_pos_context(p_business_id uuid DEFAULT NULL::uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare result jsonb;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501';end if;
 select coalesce(jsonb_agg(jsonb_build_object(
  'business',jsonb_build_object('id',b.id,'owner_id',b.owner_id,'business_name',b.business_name,
    'currency',b.currency,'branches_enabled',b.branches_enabled),
  'employee',jsonb_build_object('id',coalesce(e.id,m.id),'membership_id',m.id,'user_id',auth.uid(),
    'business_id',b.id,'employee_code',case when b.owner_id=auth.uid() then 'Owner' else e.employee_code end,
    'name',case when b.owner_id=auth.uid() then m.full_name else e.name end,
    'role',case when b.owner_id=auth.uid() then 'owner' else e.role end,'status','active',
    'permissions',(select coalesce(jsonb_agg(permission order by permission),'[]'::jsonb) from
      (select id as permission from public.permissions union
       select unnest(array['pos_access','complete_sales','view_inventory','add_products','edit_products'])) p
      where private.has_business_permission(b.id,p.permission)),
    'denied_permissions',(select coalesce(jsonb_agg(p.permission_id),'[]'::jsonb)
       from public.employee_permissions p where p.employee_id=e.id and not p.granted)
  )) order by b.business_name,b.id),'[]'::jsonb) into result
 from public.businesses b join public.business_members m on m.business_id=b.id and m.user_id=auth.uid() and m.status='active'
 left join public.employees e on e.business_id=b.id and e.user_id=auth.uid() and e.status='active'
 where (p_business_id is null or b.id=p_business_id) and public.is_business_member(b.id)
 and (b.owner_id=auth.uid() or (e.role in('manager','sales_employee','inventory_employee','employee')
   and (private.has_business_permission(b.id,'pos_access') or private.has_business_permission(b.id,'view_inventory'))));
 return result;
end $function$;

CREATE OR REPLACE FUNCTION public.update_trexven_employee(p_employee_id uuid, p_name text, p_phone text, p_email text, p_role text, p_status text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare e public.employees%rowtype; owner_actor boolean;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 select * into e from public.employees where id=p_employee_id for update;
 if not found then raise exception 'Employee access denied' using errcode='42501'; end if;
 owner_actor:=public.user_owns_business(e.business_id);
 if not coalesce(owner_actor,false) then
   raise exception 'Employee access denied' using errcode='42501'; end if;
 if e.role='owner' or exists(select 1 from public.businesses where id=e.business_id and owner_id=e.user_id)
 or (not owner_actor and (e.role='manager' or e.user_id=auth.uid() or p_role is distinct from e.role)) then
   raise exception 'Owner role administration required' using errcode='42501'; end if;
 if p_role is null or p_role not in ('manager','sales_employee','inventory_employee','employee')
 or p_status is null or p_status not in ('active','suspended','inactive','terminated')
 or nullif(trim(p_name),'') is null then raise exception 'Invalid employee details'; end if;
 update public.employees set name=trim(p_name),phone=p_phone,email=p_email,role=p_role,status=p_status,updated_at=now() where id=e.id;
 update public.business_members set full_name=trim(p_name),phone=p_phone,email=p_email,
 role=case when p_role='manager' then 'manager' else 'employee' end,
 status=case when p_status='terminated' then 'inactive' else p_status end where business_id=e.business_id and user_id=e.user_id;
 if e.user_id is not null and not found then raise exception 'Employee membership missing'; end if;
 insert into public.audit_logs(business_id,actor_id,target_id,action,metadata)
 values(e.business_id,auth.uid(),e.id,'employee_updated',jsonb_build_object('old_role',e.role,'role',p_role,'status',p_status));
end $function$;

CREATE OR REPLACE FUNCTION public.set_trexven_employee_permission(p_employee_id uuid, p_permission text, p_granted boolean)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare e public.employees%rowtype;
begin
 select * into e from public.employees where id=p_employee_id for update;
 if not found or not public.user_owns_business(e.business_id) then
   raise exception 'Owner permission required' using errcode='42501'; end if;
 if e.role='owner' or e.user_id=auth.uid() or p_granted is null
 or not exists(select 1 from public.permissions where id=p_permission)
 or p_permission in ('view_camera_events','manage_permissions','assign_roles','owner_app','view_profit','manage_employees') then
   raise exception 'Invalid employee permission' using errcode='42501'; end if;
 if p_granted and ((p_permission in ('override_price','edit_prices','change_prices','manage_prices','set_prices','branch_price_override','view_finance') and e.role<>'manager')
 or (p_permission='apply_discount' and e.role='inventory_employee')) then
   raise exception 'Permission forbidden for employee role' using errcode='42501'; end if;
 insert into public.employee_permissions(employee_id,permission_id,granted) values(e.id,p_permission,p_granted)
 on conflict(employee_id,permission_id) do update set granted=excluded.granted;
 insert into public.audit_logs(business_id,actor_id,target_id,action,metadata)
 values(e.business_id,auth.uid(),e.id,'employee_permission_changed',jsonb_build_object('permission',p_permission,'granted',p_granted));
end $function$;

-- Existing permissive policies remain; these restrictive checks close direct
-- manager writes independently of UI/RPC authorization. Owner workflows retain
-- their existing policies, account-access and admin-business boundaries.
CREATE POLICY "Owner employee insert boundary" ON public.employees
AS RESTRICTIVE FOR INSERT TO authenticated
WITH CHECK (public.user_owns_business(business_id));
CREATE POLICY "Owner employee update boundary" ON public.employees
AS RESTRICTIVE FOR UPDATE TO authenticated
USING (public.user_owns_business(business_id))
WITH CHECK (public.user_owns_business(business_id));
CREATE POLICY "Owner employee delete boundary" ON public.employees
AS RESTRICTIVE FOR DELETE TO authenticated
USING (public.user_owns_business(business_id));
