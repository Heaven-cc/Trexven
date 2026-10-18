begin;
-- Change the request row and its old positional INSERT function atomically.
alter table private.sale_requests add column if not exists branch_id uuid;
alter table private.sale_requests add constraint batch_2_request_branch foreign key(branch_id,business_id) references public.branches(id,business_id) not valid;
-- One transaction core replaces three duplicated implementations. Public entry
-- points, membership actors, integer quantities and receipt math stay compatible.
create or replace function private.process_trexven_sale(
 p_business_id uuid,p_employee_id uuid,p_total numeric,p_payment_method text,p_items jsonb,
 p_quick boolean,p_branch_id uuid default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare b public.businesses%rowtype; item jsonb; product public.products%rowtype;
 member uuid; sale uuid; branch uuid; qty integer; price numeric; v_discount numeric; v_total numeric:=0;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 select * into b from public.businesses where id=p_business_id for share;
 if not found then raise exception 'Business access denied' using errcode='42501'; end if;
 if b.pos_writes_paused then raise exception 'Sale writes are temporarily paused for recovery.' using errcode='42501'; end if;
 -- Lock trusted authorization rows so revocation is ordered against the sale.
 perform id from public.employees where business_id=b.id and user_id=auth.uid() for share;
 select id into member from public.business_members where business_id=b.id and user_id=auth.uid() and status='active' for share;
 if not public.is_business_member(b.id) or not private.has_business_permission(b.id,'complete_sales')
 or not private.has_business_permission(b.id,'pos_access') then
 raise exception 'Sale permission denied' using errcode='42501'; end if;
 if p_quick is null or (not p_quick and p_employee_id is distinct from member)
 or (p_quick and p_employee_id is not null) then raise exception 'Employee does not match session' using errcode='42501'; end if;
 if p_payment_method is null or p_payment_method not in ('cash','card','bank_transfer','mobile_money','other') then raise exception 'Invalid payment method'; end if;
 if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Items required'; end if;
 if p_quick and jsonb_array_length(p_items)<>1 then raise exception 'Invalid quick sale'; end if;
 branch:=p_branch_id;
 if b.branches_enabled then
   if branch is null then
     branch:=b.compatibility_branch_id;
     if not public.user_owns_business(b.id) and (select count(*) from public.employee_branch_assignments a
       join public.employees e on e.id=a.employee_id and e.business_id=a.business_id
       join public.branches br on br.id=a.branch_id and br.business_id=a.business_id
       where a.business_id=b.id and e.user_id=auth.uid() and a.is_active and br.is_active)<>1 then
       raise exception 'Explicit branch context required' using errcode='42501'; end if;
   end if;
   if not private.has_branch_access(b.id,branch) then raise exception 'Branch access denied' using errcode='42501'; end if;
   perform id from public.branches where id=branch and business_id=b.id and is_active for share;
   perform a.employee_id from public.employee_branch_assignments a join public.employees e on e.id=a.employee_id
     where a.branch_id=branch and a.business_id=b.id and e.user_id=auth.uid() and a.is_active for share of a;
   if not private.has_branch_access(b.id,branch) then raise exception 'Branch access denied' using errcode='42501'; end if;
 elsif branch is not null then
   raise exception 'Branch operations not activated' using errcode='42501';
 end if;
 perform id from public.products where business_id=b.id and id in
 (select (value->>'product_id')::uuid from jsonb_array_elements(p_items)) order by id for update;
 if branch is not null then
   perform product_id from public.inventory where business_id=b.id and branch_id=branch and product_id in
   (select (value->>'product_id')::uuid from jsonb_array_elements(p_items)) order by product_id for update;
 end if;
 insert into public.sales(business_id,employee_id,total,payment_method,status,branch_id)
 values(b.id,member,0,p_payment_method,'completed',branch) returning id into sale;
 for item in select * from jsonb_array_elements(p_items) loop
   qty:=(item->>'quantity')::integer; price:=(item->>'unit_price')::numeric;
   v_discount:=coalesce((item->>'discount')::numeric,0);
   if qty is null or qty<=0 or price is null or price<0 or price::text in ('NaN','Infinity','-Infinity')
   or v_discount::text in ('NaN','Infinity','-Infinity') or v_discount<0 or v_discount>qty*price then raise exception 'Invalid sale item'; end if;
   if v_discount>0 and (p_quick or not private.has_business_permission(b.id,'apply_discount')) then
     raise exception 'Discount permission denied' using errcode='42501'; end if;
   select * into product from public.products where id=(item->>'product_id')::uuid and business_id=b.id;
   if not found then raise exception 'Product not found in this business'; end if;
   if product.selling_price is null or product.is_active is not true or product.active is false then
     raise exception 'Product is pending or inactive'; end if;
   if price is distinct from product.selling_price then raise exception 'Product price changed'; end if;
   if branch is null then
     if coalesce(product.quantity,0)<qty then raise exception 'Insufficient stock'; end if;
     update public.products set quantity=quantity-qty where id=product.id and business_id=b.id;
   else
     update public.inventory set quantity=quantity-qty where business_id=b.id and branch_id=branch and product_id=product.id
       and quantity-coalesce(reserved_quantity,0)>=qty;
     if not found then raise exception 'Insufficient branch stock'; end if;
   end if;
   insert into public.sale_items(sale_id,product_id,product_name,quantity,unit_price,discount,total)
   values(sale,product.id,product.name,qty,price,v_discount,qty*price-v_discount);
   v_total:=v_total+qty*price-v_discount;
 end loop;
 if v_total is distinct from p_total then raise exception 'Sale total does not match items'; end if;
 update public.sales set total=v_total,total_amount=v_total,
 subtotal=(select sum(quantity*unit_price) from public.sale_items where sale_id=sale),
 discount=(select sum(i.discount) from public.sale_items i where i.sale_id=sale) where id=sale;
 -- Preserve the legacy single-product quick-sale columns.
 if p_quick then update public.sales set product_id=product.id,quantity=qty,unit_price=price where id=sale; end if;
 return sale;
end $$;
revoke all on function private.process_trexven_sale(uuid,uuid,numeric,text,jsonb,boolean,uuid) from public,anon,authenticated;

create or replace function private.complete_pos_sale_with_receipt(p_business_id uuid,p_employee_id uuid,p_total numeric,p_payment_method text,p_items jsonb)
returns uuid language sql security definer set search_path='' as $$
 select private.process_trexven_sale(p_business_id,p_employee_id,p_total,p_payment_method,p_items,false,null)
$$;
create or replace function private.complete_pos_sale(p_business_id uuid,p_employee_id uuid,p_total numeric,p_payment_method text,p_items jsonb)
returns void language plpgsql security definer set search_path='' as $$
begin perform private.complete_pos_sale_with_receipt(p_business_id,p_employee_id,p_total,p_payment_method,p_items); end $$;
create or replace function private.record_trexven_sale(p_business_id uuid,p_product_id uuid,p_quantity integer,p_unit_price numeric)
returns uuid language sql security definer set search_path='' as $$
 select private.process_trexven_sale(p_business_id,null,p_quantity*p_unit_price,'cash',
 jsonb_build_array(jsonb_build_object('product_id',p_product_id,'quantity',p_quantity,'unit_price',p_unit_price,'discount',0)),true,null)
$$;

create or replace function private.submit_sale_request(p_request_id uuid,p_business_id uuid,p_employee_id uuid,
 p_total numeric,p_payment_method text,p_items jsonb,p_quick boolean,p_branch_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare payload jsonb; saved private.sale_requests%rowtype; sale uuid; receipt jsonb;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 perform id from public.businesses where id=p_business_id for share;
 perform id from public.employees where business_id=p_business_id and user_id=auth.uid() for share;
 perform id from public.business_members where business_id=p_business_id and user_id=auth.uid() for share;
 if auth.uid() is null or not public.is_business_member(p_business_id) or not private.has_business_permission(p_business_id,'complete_sales')
 or not private.has_business_permission(p_business_id,'pos_access') then
 raise exception 'Sale permission denied' using errcode='42501'; end if;
 if p_request_id is null or p_quick is null then raise exception 'Sale request ID and type required'; end if;
 payload:=jsonb_build_object('employee',p_employee_id,'total',p_total,'payment',p_payment_method,'items',p_items,'quick',p_quick);
 perform pg_advisory_xact_lock(hashtextextended(p_business_id::text||auth.uid()::text||p_request_id::text,0));
 select * into saved from private.sale_requests where business_id=p_business_id and user_id=auth.uid() and request_id=p_request_id;
 if found then
   if saved.branch_id is null and not public.user_owns_business(p_business_id)
   and exists(select 1 from public.businesses where id=p_business_id and branches_enabled) then
     raise exception 'Legacy receipt has no verified branch mapping. Ask the owner to review the saved sale.' using errcode='42501'; end if;
   if saved.payload is distinct from payload or (p_branch_id is not null and saved.branch_id is distinct from p_branch_id) then
     raise exception 'This sale was already submitted with different details. Review its receipt before starting another sale.'; end if;
   if saved.branch_id is not null and not private.has_branch_access(p_business_id,saved.branch_id) then
     raise exception 'Branch access denied' using errcode='42501'; end if;
   return saved.receipt;
 end if;
 sale:=private.process_trexven_sale(p_business_id,p_employee_id,p_total,p_payment_method,p_items,p_quick,p_branch_id);
 update public.sales set sale_number='TRX-'||sale::text where id=sale;
 select (case when s.branch_id is null then to_jsonb(s)-'branch_id' else to_jsonb(s) end)||jsonb_build_object('sale_items',
 (select jsonb_agg(to_jsonb(i) order by i.id) from public.sale_items i where i.sale_id=sale)) into receipt from public.sales s where s.id=sale;
 insert into private.sale_requests(business_id,user_id,request_id,payload,receipt,branch_id)
 select p_business_id,auth.uid(),p_request_id,payload,receipt,s.branch_id from public.sales s where s.id=sale;
 return receipt;
end $$;
revoke all on function private.submit_sale_request(uuid,uuid,uuid,numeric,text,jsonb,boolean,uuid) from public,anon,authenticated;
create or replace function private.submit_trexven_sale(p_request_id uuid,p_business_id uuid,p_employee_id uuid,p_total numeric,p_payment_method text,p_items jsonb,p_quick boolean)
returns jsonb language sql security definer set search_path='' as $$
 select private.submit_sale_request(p_request_id,p_business_id,p_employee_id,p_total,p_payment_method,p_items,p_quick,null)
$$;
create or replace function public.submit_trexven_branch_sale(p_request_id uuid,p_business_id uuid,p_employee_id uuid,
 p_total numeric,p_payment_method text,p_items jsonb,p_quick boolean,p_branch_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
begin
 if p_branch_id is null or not private.has_branch_access(p_business_id,p_branch_id) then
 raise exception 'Branch access denied' using errcode='42501'; end if;
 return private.submit_sale_request(p_request_id,p_business_id,p_employee_id,p_total,p_payment_method,p_items,p_quick,p_branch_id);
end $$;
revoke all on function public.submit_trexven_branch_sale(uuid,uuid,uuid,numeric,text,jsonb,boolean,uuid) from public,anon;
grant execute on function public.submit_trexven_branch_sale(uuid,uuid,uuid,numeric,text,jsonb,boolean,uuid) to authenticated;
-- Inventory writes are closed until a reviewed adjustment/movement API ships.
-- This avoids creating a second independently writable stock source.
notify pgrst,'reload schema';
commit;
