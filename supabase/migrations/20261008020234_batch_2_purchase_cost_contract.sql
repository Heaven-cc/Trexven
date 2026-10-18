-- Additive Batch 2 correction: purchase cost is deferred; retain all historical values.
-- Clients must explicitly project supported product columns. RLS still controls rows.
-- Roll forward if needed: retain column restrictions; update incompatible clients.
-- Do not restore broad grants as a rollback. No historical rows are rewritten.
begin;
revoke select,insert,update,references on public.products from public,anon,authenticated;
revoke select(cost_price),insert(cost_price),update(cost_price),references(cost_price)
 on public.products from public,anon,authenticated;
grant select(id,business_id,sku,barcode,name,description,category,brand,unit,selling_price,reorder_level,image_url,is_active,created_at,updated_at,quantity,low_stock_threshold,supplier,location,active),insert(id,business_id,sku,barcode,name,description,category,brand,unit,selling_price,reorder_level,image_url,is_active,created_at,updated_at,quantity,low_stock_threshold,supplier,location,active),update(id,business_id,sku,barcode,name,description,category,brand,unit,selling_price,reorder_level,image_url,is_active,created_at,updated_at,quantity,low_stock_threshold,supplier,location,active) on public.products to authenticated;
-- Prevent existing legacy cost-bearing audit JSON from becoming an alternate API.
-- Rows and their historical metadata are retained for trusted recovery.
create policy "Deferred purchase cost audit boundary" on public.audit_logs
 as restrictive for select to authenticated
 using (not (jsonb_path_exists(coalesce(metadata,'{}'::jsonb),'$.**.cost_price')
 or jsonb_path_exists(coalesce(metadata,'{}'::jsonb),'$.**.purchase_cost')
 or jsonb_path_exists(coalesce(metadata,'{}'::jsonb),'$.**.purchase_price')));
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
   if not can_price and new.selling_price is not null then
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
   if not can_price and (new.selling_price is distinct from old.selling_price) then
     raise exception 'Price permission denied' using errcode='42501'; end if;
 end if;
 if new.selling_price is not null and (new.selling_price<0 or new.selling_price::text in ('NaN','Infinity','-Infinity')) then
   raise exception 'Invalid selling price'; end if;
 if new.selling_price is null then new.active:=false; new.is_active:=false; end if;
 return new;
end $$;

create or replace function private.audit_product_price()
returns trigger language plpgsql security definer set search_path='' as $$
declare before_price jsonb;
begin
 if auth.uid() is null then return new; end if;
 if tg_op='INSERT' then
   if new.selling_price is null then return new; end if;
 else
   if new.selling_price is not distinct from old.selling_price then return new; end if;
   before_price:=jsonb_build_object('selling_price',old.selling_price);
 end if;
 insert into public.audit_logs(business_id,actor_id,action,metadata)
 values(new.business_id,auth.uid(),'product_price_changed',jsonb_build_object('product_id',new.id,
 'before',before_price,
 'after',jsonb_build_object('selling_price',new.selling_price)));
 return new;
end $$;

create or replace function private.has_business_permission(business uuid, permission text)
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is not null and permission is not null and permission <> 'view_profit' and (
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
 and (permission not in ('view_finance') or e.role='manager')
 and not exists(select 1 from public.employee_permissions denied where denied.employee_id=e.id
                and denied.permission_id=permission and not denied.granted)
 and (exists(select 1 from public.employee_permissions p join public.permissions d on d.id=p.permission_id
             where p.employee_id=e.id and p.permission_id=permission and p.granted)
 or (e.role='manager' and permission in ('pos_access','complete_sales','view_inventory','add_products','edit_products','manage_employees','adjust_stock'))
 or (e.role='sales_employee' and permission in ('pos_access','complete_sales','view_inventory'))
 or (e.role='inventory_employee' and permission in ('view_inventory','add_products','edit_products')))))
$$;

create or replace function public.set_trexven_employee_permission(p_employee_id uuid,p_permission text,p_granted boolean)
returns void language plpgsql security definer set search_path='' as $$
declare e public.employees%rowtype;
begin
 select * into e from public.employees where id=p_employee_id for update;
 if not found or not public.user_owns_business(e.business_id) then
   raise exception 'Owner permission required' using errcode='42501'; end if;
 if e.role='owner' or e.user_id=auth.uid() or p_granted is null
 or not exists(select 1 from public.permissions where id=p_permission)
 or p_permission in ('view_camera_events','manage_permissions','assign_roles','owner_app','view_profit') then
   raise exception 'Invalid employee permission' using errcode='42501'; end if;
 if p_granted and ((p_permission in ('override_price','edit_prices','change_prices','manage_prices','set_prices','branch_price_override','view_finance') and e.role<>'manager')
 or (p_permission='apply_discount' and e.role='inventory_employee')) then
   raise exception 'Permission forbidden for employee role' using errcode='42501'; end if;
 insert into public.employee_permissions(employee_id,permission_id,granted) values(e.id,p_permission,p_granted)
 on conflict(employee_id,permission_id) do update set granted=excluded.granted;
 insert into public.audit_logs(business_id,actor_id,target_id,action,metadata)
 values(e.business_id,auth.uid(),e.id,'employee_permission_changed',jsonb_build_object('permission',p_permission,'granted',p_granted));
end $$;
-- Replace only the Batch 2 trigger; no product column or record is dropped.
drop trigger batch_2_price_assignment on public.products;
create trigger batch_2_price_assignment before update of selling_price on public.products
 for each row execute function private.guard_price_assignment();
notify pgrst,'reload schema';
commit;
