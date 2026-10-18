-- LOCAL/STAGING ONLY: reviewed against the audited pre-existing schema.
-- No data backfill, price reclassification or production activation.
begin;

-- Existing rows remain grants; explicit false overrides role defaults. This
-- makes owner revocation meaningful without changing employment/membership IDs.
alter table public.employee_permissions add column if not exists granted boolean not null default true;

insert into public.permissions(id,description) values
 ('override_price','Owner-granted manager authority to set product prices'),
 ('apply_discount','Owner-granted transaction discount authority'),
 ('adjust_stock','Authorized inventory stock adjustment'),
 ('view_finance','Owner-granted detailed finance access') on conflict(id) do nothing;

create or replace function public.is_business_member(target_business_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and (public.user_owns_business(target_business_id)
 or exists(select 1 from public.business_members m join public.employees e
 on e.business_id=m.business_id and e.user_id=m.user_id
 where m.business_id=target_business_id and m.user_id=auth.uid()
 and m.status='active' and e.status='active'
 and e.role in ('manager','sales_employee','inventory_employee','employee')))
$$;

create or replace function private.has_business_permission(business uuid, permission text)
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and permission is not null and (
 public.user_owns_business(business) or exists(
 select 1 from public.employees e join public.business_members m
 on m.business_id=e.business_id and m.user_id=e.user_id
 where e.business_id=business and e.user_id=auth.uid()
 and e.status='active' and m.status='active'
 and e.role in ('manager','sales_employee','inventory_employee','employee')
 -- Owner-only services and role/permission administration are never delegable.
 and permission not in ('view_camera_events','manage_permissions','assign_roles','owner_app')
 and (permission not in ('override_price','edit_prices','change_prices','manage_prices','set_prices','branch_price_override')
      or e.role='manager')
 and (permission<>'apply_discount' or e.role<>'inventory_employee')
 and (permission<>'manage_employees' or e.role='manager')
 and (permission not in ('view_finance','view_profit') or e.role='manager')
 and not exists(select 1 from public.employee_permissions denied where denied.employee_id=e.id
                and denied.permission_id=permission and not denied.granted)
 and (exists(select 1 from public.employee_permissions p join public.permissions d on d.id=p.permission_id
             where p.employee_id=e.id and p.permission_id=permission and p.granted)
 or (e.role='manager' and permission in ('pos_access','complete_sales','view_inventory','add_products','edit_products','manage_employees','adjust_stock'))
 or (e.role='sales_employee' and permission in ('pos_access','complete_sales','view_inventory'))
 or (e.role='inventory_employee' and permission in ('view_inventory','add_products','edit_products')))))
$$;
revoke all on function public.is_business_member(uuid),private.has_business_permission(uuid,text) from public,anon;
grant execute on function public.is_business_member(uuid),private.has_business_permission(uuid,text) to authenticated;
-- public is trusted (client CREATE is absent); put temporary schemas last.
alter function public.user_owns_business(uuid) set search_path=public,pg_temp;
alter function public.set_trexven_employee_status(uuid,text) set search_path='';
alter policy "Angel author boundary" on public.angel_conversations
 using(user_id=auth.uid() and public.user_owns_business(business_id))
 with check(user_id=auth.uid() and public.user_owns_business(business_id));
alter policy "Angel message author boundary" on public.angel_messages
 using(exists(select 1 from public.angel_conversations c where c.id=conversation_id and c.user_id=auth.uid() and public.user_owns_business(c.business_id)))
 with check(exists(select 1 from public.angel_conversations c where c.id=conversation_id and c.user_id=auth.uid() and public.user_owns_business(c.business_id)));
create policy "Owner insight boundary" on public.angel_insights as restrictive for all to authenticated
 using(public.user_owns_business(business_id)) with check(public.user_owns_business(business_id));

-- Omitted prices are explicitly pending. Existing zero prices remain unchanged.
alter table public.products alter column selling_price drop not null;
alter table public.products alter column selling_price drop default;
create or replace function private.guard_product_fields()
returns trigger language plpgsql security invoker set search_path='' as $$
declare can_price boolean; maintenance boolean;
begin
 maintenance:=auth.uid() is null and current_user in ('postgres','supabase_admin','service_role');
 can_price:=maintenance or (public.user_owns_business(new.business_id)
   or private.has_business_permission(new.business_id,'override_price'));
 if tg_op='UPDATE' and (new.id is distinct from old.id or new.business_id is distinct from old.business_id) then
   raise exception 'Product identity is immutable' using errcode='42501'; end if;
 if tg_op='INSERT' then
   if not maintenance and coalesce(new.quantity,0)<>0 and not private.has_business_permission(new.business_id,'adjust_stock') then
     raise exception 'Stock adjustment permission required' using errcode='42501'; end if;
   if not can_price and (new.selling_price is not null or coalesce(new.cost_price,0)<>0) then
     raise exception 'Price permission denied' using errcode='42501'; end if;
 else
   -- Direct client stock edits require stock authority; validated transaction
   -- cores run as their trusted definer and check complete_sales themselves.
   if current_user='authenticated' and new.quantity is distinct from old.quantity
   and not private.has_business_permission(new.business_id,'adjust_stock') then
     raise exception 'Stock adjustment permission required' using errcode='42501'; end if;
   if not can_price and (to_jsonb(new)-array['name','barcode','sku','brand','category','description','image_url','unit','supplier','location','reorder_level','low_stock_threshold','quantity','active','is_active','updated_at'])
     is distinct from (to_jsonb(old)-array['name','barcode','sku','brand','category','description','image_url','unit','supplier','location','reorder_level','low_stock_threshold','quantity','active','is_active','updated_at']) then
     raise exception 'Only permitted non-price product fields may change' using errcode='42501'; end if;
   if not can_price and (new.selling_price is distinct from old.selling_price or new.cost_price is distinct from old.cost_price) then
     raise exception 'Price permission denied' using errcode='42501'; end if;
 end if;
 if new.selling_price is not null and (new.selling_price<0 or new.selling_price::text in ('NaN','Infinity','-Infinity')) then
   raise exception 'Invalid selling price'; end if;
 if new.selling_price is null then new.active:=false; new.is_active:=false; end if;
 return new;
end $$;
revoke all on function private.guard_product_fields() from public,anon,authenticated;
create trigger batch_2_product_fields before insert or update on public.products
for each row execute function private.guard_product_fields();

-- Reject price-field assignments even when the value does not change.
create or replace function private.guard_price_assignment()
returns trigger language plpgsql security invoker set search_path='' as $$
begin
 if not (auth.uid() is null and current_user in ('postgres','supabase_admin','service_role'))
 and not public.user_owns_business(old.business_id)
 and not private.has_business_permission(old.business_id,'override_price') then
   raise exception 'Price permission denied' using errcode='42501'; end if;
 return new;
end $$;
revoke all on function private.guard_price_assignment() from public,anon,authenticated;
create trigger batch_2_price_assignment before update of selling_price,cost_price on public.products
for each row execute function private.guard_price_assignment();

create or replace function public.set_trexven_employee_permission(p_employee_id uuid,p_permission text,p_granted boolean)
returns void language plpgsql security definer set search_path='' as $$
declare e public.employees%rowtype;
begin
 select * into e from public.employees where id=p_employee_id for update;
 if not found or not public.user_owns_business(e.business_id) then
   raise exception 'Owner permission required' using errcode='42501'; end if;
 if e.role='owner' or e.user_id=auth.uid() or p_granted is null
 or not exists(select 1 from public.permissions where id=p_permission)
 or p_permission in ('view_camera_events','manage_permissions','assign_roles','owner_app') then
   raise exception 'Invalid employee permission' using errcode='42501'; end if;
 if p_granted and ((p_permission in ('override_price','edit_prices','change_prices','manage_prices','set_prices','branch_price_override','view_finance','view_profit') and e.role<>'manager')
 or (p_permission='apply_discount' and e.role='inventory_employee')) then
   raise exception 'Permission forbidden for employee role' using errcode='42501'; end if;
 insert into public.employee_permissions(employee_id,permission_id,granted) values(e.id,p_permission,p_granted)
 on conflict(employee_id,permission_id) do update set granted=excluded.granted;
 insert into public.audit_logs(business_id,actor_id,target_id,action,metadata)
 values(e.business_id,auth.uid(),e.id,'employee_permission_changed',jsonb_build_object('permission',p_permission,'granted',p_granted));
end $$;
revoke all on function public.set_trexven_employee_permission(uuid,text,boolean) from public,anon;
grant execute on function public.set_trexven_employee_permission(uuid,text,boolean) to authenticated;

create or replace function public.update_trexven_employee(p_employee_id uuid,p_name text,p_phone text,p_email text,p_role text,p_status text)
returns void language plpgsql security definer set search_path='' as $$
declare e public.employees%rowtype; owner_actor boolean;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 select * into e from public.employees where id=p_employee_id for update;
 if not found then raise exception 'Employee access denied' using errcode='42501'; end if;
 owner_actor:=public.user_owns_business(e.business_id);
 if not owner_actor and not private.has_business_permission(e.business_id,'manage_employees') then
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
end $$;
revoke all on function public.update_trexven_employee(uuid,text,text,text,text,text) from public,anon;
grant execute on function public.update_trexven_employee(uuid,text,text,text,text,text) to authenticated;

-- Effective grants, not dormant permissive policies, define mutation entry points.
revoke insert,update,delete on public.employees,public.business_members,public.employee_permissions,public.permissions,
 public.sales,public.sale_items,public.audit_logs from anon,authenticated;
do $$ declare t text; column_name text; begin
 for t in select c.relname from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
          where n.nspname='public' and c.relkind in ('r','p') loop
   execute format('revoke truncate,references,trigger on public.%I from anon,authenticated',t);
 end loop;
 foreach t in array array['employees','business_members','employee_permissions','permissions','sales','sale_items','audit_logs','inventory','inventory_movements'] loop
   for column_name in select a.attname from pg_catalog.pg_attribute a where a.attrelid=('public.'||t)::regclass and a.attnum>0 and not a.attisdropped loop
     execute format('revoke insert(%I),update(%I),references(%I) on public.%I from anon,authenticated',column_name,column_name,column_name,t);
   end loop;
 end loop;
end $$;
alter default privileges in schema public revoke truncate,references,trigger on tables from anon,authenticated;
-- RPC-managed stock evidence: clients cannot forge or rewrite it.
revoke insert,update,delete on public.inventory,public.inventory_movements from anon,authenticated;

create or replace function private.audit_product_price()
returns trigger language plpgsql security definer set search_path='' as $$
declare before_price jsonb;
begin
 if auth.uid() is null then return new; end if;
 if tg_op='INSERT' then
   if new.selling_price is null then return new; end if;
 else
   if new.selling_price is not distinct from old.selling_price and new.cost_price is not distinct from old.cost_price then return new; end if;
   before_price:=jsonb_build_object('selling_price',old.selling_price,'cost_price',old.cost_price);
 end if;
 insert into public.audit_logs(business_id,actor_id,action,metadata)
 values(new.business_id,auth.uid(),'product_price_changed',jsonb_build_object('product_id',new.id,
 'before',before_price,
 'after',jsonb_build_object('selling_price',new.selling_price,'cost_price',new.cost_price)));
 return new;
end $$;
revoke all on function private.audit_product_price() from public,anon,authenticated;
create trigger batch_2_price_audit after insert or update on public.products for each row execute function private.audit_product_price();

-- Install before nullable prices become usable: older transaction wrappers are
-- also covered during the staged migration sequence and cannot sell pending rows.
create or replace function private.guard_sale_item_product()
returns trigger language plpgsql security definer set search_path='' as $$
declare business uuid; p public.products%rowtype;
begin
 if auth.uid() is null then
   if session_user in ('postgres','supabase_admin') then return new; end if;
   raise exception 'Sale authorization required' using errcode='42501';
 end if;
 select business_id into business from public.sales where id=new.sale_id;
 if not private.has_business_permission(business,'complete_sales') or not private.has_business_permission(business,'pos_access') then
 raise exception 'Sale permission denied' using errcode='42501'; end if;
 select * into p from public.products where id=new.product_id and business_id=business;
 if not found or p.selling_price is null or p.is_active is not true or p.active is false
 or new.unit_price is distinct from p.selling_price then raise exception 'Product is pending, inactive or price changed'; end if;
 if coalesce(new.discount,0)>0 and not private.has_business_permission(business,'apply_discount') then
 raise exception 'Discount permission denied' using errcode='42501'; end if;
 return new;
end $$;
revoke all on function private.guard_sale_item_product() from public,anon,authenticated;
create trigger batch_2_sale_item_guard before insert on public.sale_items for each row execute function private.guard_sale_item_product();
commit;
