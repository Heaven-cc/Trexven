-- Incremental repair against the inspected TREXVEN production schema.
-- The original schema predates this repository; see docs/backend-audit.md.
alter table public.businesses add column if not exists email text;
alter table public.businesses add column if not exists website text;
alter table public.businesses add column if not exists business_hours jsonb;

-- Members must never transfer ownership by updating the business row.
drop policy if exists "business members can update business" on public.businesses;

create policy "Users can read their own membership status"
on public.business_members for select to authenticated using (user_id = auth.uid());

alter table public.permissions enable row level security;
create policy "Authenticated users can read permission definitions"
on public.permissions for select to authenticated using (true);

create or replace function public.is_business_member(target_business_id uuid)
returns boolean language sql stable security definer set search_path = public
as $$
  select exists(select 1 from public.businesses where id = target_business_id and owner_id = auth.uid())
  or exists(select 1 from public.business_members where business_id = target_business_id
    and user_id = auth.uid() and status = 'active');
$$;

-- Lock by authenticated account so simultaneous callbacks/retries cannot create duplicates.
create or replace function public.complete_trexven_onboarding(
 p_business_name text, p_business_type text, p_country text, p_currency text,
 p_address text default null, p_phone text default null)
returns uuid language plpgsql security definer set search_path = public
as $$
declare v_user uuid := auth.uid(); v_business uuid; v_name text; v_email text;
begin
 if v_user is null then raise exception 'Authentication required' using errcode = '42501'; end if;
 if nullif(trim(p_business_name),'') is null or nullif(trim(p_business_type),'') is null
 or nullif(trim(p_country),'') is null or nullif(trim(p_currency),'') is null then
   raise exception 'Complete all required business fields';
 end if;
 perform pg_advisory_xact_lock(hashtextextended(v_user::text, 0));
 select id into v_business from public.businesses where owner_id = v_user order by created_at limit 1;
 if v_business is null and exists(select 1 from public.business_members where user_id = v_user) then
   raise exception 'This account is already associated with a business' using errcode = '42501';
 end if;
 if v_business is null then
   insert into public.businesses(owner_id,business_name,business_type,country,currency,address,phone)
   values(v_user,trim(p_business_name),p_business_type,p_country,p_currency,p_address,p_phone)
   returning id into v_business;
 else
   update public.businesses set business_name=trim(p_business_name),business_type=p_business_type,
   country=p_country,currency=p_currency,address=p_address,phone=p_phone where id=v_business;
 end if;
 select coalesce(nullif(raw_user_meta_data->>'full_name',''),nullif(raw_user_meta_data->>'name',''),'Owner'),email
 into v_name,v_email from auth.users where id=v_user;
 insert into public.business_members(business_id,user_id,full_name,email,role,status)
 values(v_business,v_user,v_name,v_email,'owner','active')
 on conflict(business_id,user_id) do update set full_name=excluded.full_name,role='owner',status='active';
 return v_business;
end;
$$;
revoke all on function public.complete_trexven_onboarding(text,text,text,text,text,text) from public;
grant execute on function public.complete_trexven_onboarding(text,text,text,text,text,text) to authenticated;

-- One transaction and one row lock: a failed/oversold sale never leaves stock or revenue half-updated.
create or replace function public.record_trexven_sale(
 p_business_id uuid, p_product_id uuid, p_quantity integer, p_unit_price numeric)
returns uuid language plpgsql security invoker set search_path = public
as $$
declare v_product public.products%rowtype; v_sale uuid; v_member uuid;
begin
 if auth.uid() is null or not public.is_business_member(p_business_id) then
   raise exception 'Business access denied' using errcode='42501';
 end if;
 if p_quantity is null or p_quantity <= 0 or p_unit_price is null or p_unit_price < 0
 or p_unit_price::text in ('NaN','Infinity','-Infinity') then raise exception 'Invalid quantity or price'; end if;
 select * into v_product from public.products
 where id=p_product_id and business_id=p_business_id for update;
 if not found then raise exception 'Product not found in this business'; end if;
 if coalesce(v_product.quantity,0)<p_quantity then raise exception 'Insufficient stock'; end if;
 if p_unit_price<>v_product.selling_price then raise exception 'Product price changed. Refresh and try again.'; end if;
 select id into v_member from public.business_members where business_id=p_business_id
 and user_id=auth.uid() and status='active';
 insert into public.sales(business_id,employee_id,product_id,quantity,unit_price,subtotal,total,total_amount,status)
 values(p_business_id,v_member,p_product_id,p_quantity,p_unit_price,p_quantity*p_unit_price,
 p_quantity*p_unit_price,p_quantity*p_unit_price,'completed') returning id into v_sale;
 insert into public.sale_items(sale_id,product_id,product_name,quantity,unit_price,discount,total)
 values(v_sale,p_product_id,v_product.name,p_quantity,p_unit_price,0,p_quantity*p_unit_price);
 update public.products set quantity=quantity-p_quantity where id=p_product_id and business_id=p_business_id;
 if not found then raise exception 'Stock update was not permitted'; end if;
 return v_sale;
end;
$$;
revoke all on function public.record_trexven_sale(uuid,uuid,integer,numeric) from public;
grant execute on function public.record_trexven_sale(uuid,uuid,integer,numeric) to authenticated;

-- Keep the deployed POS signature; replace references to nonexistent timestamp/price_level columns.
create or replace function public.complete_pos_sale(p_business_id uuid,p_employee_id uuid,
 p_total numeric,p_payment_method text,p_items jsonb)
returns void language plpgsql security invoker set search_path=public
as $$
declare v_item jsonb; v_total numeric:=0; v_actual_member uuid; v_sale uuid;
 v_product public.products%rowtype; v_quantity integer; v_price numeric; v_discount numeric;
begin
 if auth.uid() is null or not public.is_business_member(p_business_id) then
   raise exception 'Business access denied' using errcode='42501'; end if;
 select id into v_actual_member from public.business_members where business_id=p_business_id
 and user_id=auth.uid() and status='active';
 if p_employee_id is distinct from v_actual_member then raise exception 'Employee does not match session'; end if;
 if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Items required'; end if;
 if p_payment_method is null or p_payment_method not in ('cash','card','bank_transfer','mobile_money','other') then raise exception 'Invalid payment method'; end if;
 -- Lock products in stable order, including repeated items, before checking stock.
 perform id from public.products where business_id=p_business_id and id in
 (select (value->>'product_id')::uuid from jsonb_array_elements(p_items)) order by id for update;
 insert into public.sales(business_id,employee_id,total,payment_method,status)
 values(p_business_id,v_actual_member,0,p_payment_method,'completed') returning id into v_sale;
 for v_item in select * from jsonb_array_elements(p_items) loop
   v_quantity:=(v_item->>'quantity')::integer;
   v_price:=(v_item->>'unit_price')::numeric;
   v_discount:=coalesce((v_item->>'discount')::numeric,0);
   if v_quantity is null or v_quantity<=0 or v_price is null or v_price<0
   or v_price::text in ('NaN','Infinity','-Infinity') or v_discount::text in ('NaN','Infinity','-Infinity')
   or v_discount<0 or v_discount>v_quantity*v_price then raise exception 'Invalid sale item'; end if;
   select * into v_product from public.products where id=(v_item->>'product_id')::uuid and business_id=p_business_id;
   if not found then raise exception 'Product not found in this business'; end if;
   if coalesce(v_product.quantity,0)<v_quantity then raise exception 'Insufficient stock'; end if;
   if v_price<>v_product.selling_price then raise exception 'Product price changed'; end if;
   insert into public.sale_items(sale_id,product_id,product_name,quantity,unit_price,discount,total)
   values(v_sale,v_product.id,v_product.name,v_quantity,v_price,v_discount,v_quantity*v_price-v_discount);
   update public.products set quantity=quantity-v_quantity where id=v_product.id and business_id=p_business_id;
   if not found then raise exception 'Stock update was not permitted'; end if;
   v_total:=v_total+v_quantity*v_price-v_discount;
 end loop;
 if v_total is distinct from p_total then raise exception 'Sale total does not match items'; end if;
 update public.sales set total=v_total,total_amount=v_total,
 subtotal=(select sum(quantity*unit_price) from public.sale_items where sale_id=v_sale),
 discount=(select sum(discount) from public.sale_items where sale_id=v_sale) where id=v_sale;
end;
$$;
revoke all on function public.complete_pos_sale(uuid,uuid,numeric,text,jsonb) from public;
grant execute on function public.complete_pos_sale(uuid,uuid,numeric,text,jsonb) to authenticated;

create or replace function public.update_trexven_employee(p_employee_id uuid,p_name text,
 p_phone text,p_email text,p_role text,p_status text)
returns void language plpgsql security definer set search_path=public
as $$
declare v_employee public.employees%rowtype; v_owner boolean; v_manager boolean;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 select * into v_employee from public.employees where id=p_employee_id for update;
 if not found then raise exception 'Employee not found'; end if;
 v_owner := public.user_owns_business(v_employee.business_id);
 select exists(select 1 from public.business_members where business_id=v_employee.business_id
 and user_id=auth.uid() and status='active' and role='manager') into v_manager;
 if not (v_owner or v_manager) then raise exception 'Employee access denied' using errcode='42501'; end if;
 if v_employee.role='owner' or exists(select 1 from public.businesses where id=v_employee.business_id and owner_id=v_employee.user_id) then
   raise exception 'Use business profile to manage the owner'; end if;
 if not v_owner and (v_employee.role='manager' or p_role='manager' or v_employee.user_id=auth.uid()) then
   raise exception 'Only the owner can manage managers'; end if;
 if p_role not in ('manager','sales_employee','inventory_employee','employee') or p_role is null
 or p_status not in ('active','suspended','inactive','terminated') or p_status is null
 or nullif(trim(p_name),'') is null then raise exception 'Invalid employee details'; end if;
 update public.employees set name=trim(p_name),phone=p_phone,email=p_email,role=p_role,status=p_status,updated_at=now()
 where id=p_employee_id;
 update public.business_members set full_name=trim(p_name),phone=p_phone,email=p_email,
 role=case when p_role='manager' then 'manager' else 'employee' end,
 status=case when p_status='terminated' then 'inactive' else p_status end
 where business_id=v_employee.business_id and user_id=v_employee.user_id;
 if v_employee.user_id is not null and not found then raise exception 'Employee membership is missing'; end if;
 insert into public.audit_logs(business_id,actor_id,target_id,action,metadata)
 values(v_employee.business_id,auth.uid(),p_employee_id,'employee_updated',jsonb_build_object('role',p_role,'status',p_status));
end;
$$;
revoke all on function public.update_trexven_employee(uuid,text,text,text,text,text) from public;
grant execute on function public.update_trexven_employee(uuid,text,text,text,text,text) to authenticated;
create or replace function public.set_trexven_employee_status(p_employee_id uuid,p_status text)
returns void language plpgsql security definer set search_path=public
as $$
declare e public.employees%rowtype;
begin
 select * into e from public.employees where id=p_employee_id for update;
 if not found then raise exception 'Employee not found'; end if;
 perform public.update_trexven_employee(e.id,e.name,e.phone,e.email,e.role,p_status);
end;
$$;
revoke all on function public.set_trexven_employee_status(uuid,text) from public;
grant execute on function public.set_trexven_employee_status(uuid,text) to authenticated;

-- Membership changes now happen through validated transactional RPCs.
-- Retain SELECT policies but remove direct client employee writes that bypass membership synchronization.
revoke insert,update,delete on public.employees from anon,authenticated;
alter function public.camera_event_to_alert() set search_path=public;

-- Private recording playback: only a recording's owner can request a fresh signed URL.
create policy "Owners read their recording objects" on storage.objects for select to authenticated
using(bucket_id='recordings' and exists(select 1 from public.recordings r
 where r.storage_path=name and public.user_owns_business(r.business_id)));
