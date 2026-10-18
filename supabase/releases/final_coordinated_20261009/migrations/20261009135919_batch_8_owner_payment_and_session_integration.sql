begin;
-- Runtime correction: table aliases must not collide with the shift row variable.
create or replace function private.record_operational_cash(business uuid,member uuid,amount numeric,kind text,reference uuid,shift uuid default null)
returns void language plpgsql security definer set search_path='' as $$
declare s public.cash_shifts%rowtype; offline boolean:=current_setting('trexven.catalog_operation',true)='offline_cash';
begin
 if shift is null then
  if not exists(select 1 from public.cash_registers where business_id=business and active) then return;end if;
  if (select count(*) from public.cash_shifts cs join public.cash_shift_members m on m.shift_id=cs.id where cs.business_id=business and cs.status='open' and m.member_id=member)<>1 then raise exception 'Select the shared register';end if;
  select cs.id into shift from public.cash_shifts cs join public.cash_shift_members m on m.shift_id=cs.id where cs.business_id=business and cs.status='open' and m.member_id=member;
 end if;
 select * into s from public.cash_shifts where id=shift for update;
 perform private.validate_operational_shift(business,member,shift,s.branch_id,coalesce(offline,false));
 if amount is null or amount::text in('NaN','Infinity','-Infinity') or scale(amount)>2 then raise exception 'Invalid cash amount';end if;
 insert into public.cash_events(business_id,shift_id,member_id,actor_id,amount,kind,reference_id,late)
 values(business,shift,member,auth.uid(),amount,kind,reference,s.status='closed');
 if s.status='closed' then
  update public.cash_shifts set review_status='pending' where id=s.id;
  insert into public.audit_logs(business_id,actor_id,action,metadata) values(business,auth.uid(),'late_cash_reconciliation',jsonb_build_object('shift_id',s.id,'reference_id',reference,'amount',amount));
 end if;
end $$;
-- Authenticated context is reconstructed from current database identity. No
-- user metadata, supplied role or cached grant authorizes access. This endpoint
-- does not create or reactivate employment/membership records.
create function public.get_trexven_pos_context(p_business_id uuid default null)
returns jsonb language plpgsql stable security definer set search_path='' as $$
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
       select unnest(array['pos_access','complete_sales','view_inventory','add_products','edit_products','manage_employees'])) p
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
end $$;
revoke all on function public.get_trexven_pos_context(uuid) from public,anon;
grant execute on function public.get_trexven_pos_context(uuid) to authenticated;

-- Owner quick-sale adapter uses the same confirmed-payment core as POS.
-- Historical receipts are returned without backfilling payments or stock.
create function public.record_confirmed_trexven_owner_sale(p_business_id uuid,p_request_id uuid,
 p_product_id uuid,p_units numeric,p_unit_price numeric,p_payments jsonb,p_shift_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare items jsonb;total numeric;owner_payload jsonb;previous jsonb;member uuid;result jsonb;
 saved private.sale_requests%rowtype; method text; sale uuid;
begin
 if auth.uid() is null or not public.user_owns_business(p_business_id) then
 raise exception 'Verified business owner required' using errcode='42501';end if;
 if p_units is null or p_units<=0 or p_units::text in('NaN','Infinity','-Infinity') or scale(p_units)>3
 or not private.valid_money(p_unit_price,true) then raise exception 'Invalid sale';end if;
 total:=round(p_units*p_unit_price,2);
 items:=jsonb_build_array(jsonb_build_object('product_id',p_product_id,'quantity',p_units,'unit_price',p_unit_price,'discount',0));
 owner_payload:=jsonb_build_object('operation','owner_confirmed_sale','items',items,'payments',p_payments,'shift',p_shift_id);
 perform pg_advisory_xact_lock(hashtextextended(p_business_id::text||auth.uid()::text||p_request_id::text,0));
 previous:=private.operation_replay(p_business_id,p_request_id,owner_payload);if previous is not null then return previous;end if;
 method:=case when jsonb_array_length(p_payments)=1 then p_payments->0->>'method' else 'other' end;
 select * into saved from private.sale_requests where business_id=p_business_id and user_id=auth.uid() and request_id=p_request_id;
 if found then
  if saved.payload is distinct from jsonb_build_object('employee',null,'total',total,'payment',method,'items',items,'quick',true)
  or saved.branch_id is not null then raise exception 'Original owner sale payload required' using errcode='42501';end if;
  return saved.receipt;
 end if;
 if jsonb_typeof(p_payments) is distinct from 'array'
 or (select coalesce(sum((line->>'amount')::numeric),0) from jsonb_array_elements(p_payments) line) is distinct from total then
 raise exception 'Quick sale requires its full confirmed payment; use approved credit workflow for debt';end if;
 select id into member from public.business_members where business_id=p_business_id and user_id=auth.uid() and status='active';
 result:=public.complete_trexven_transaction(p_request_id,p_business_id,member,total,items,p_payments,null,null,p_shift_id);
 sale:=(result->>'id')::uuid;
 -- Populate the legacy single-product projection only on this new sale inside
 -- its original transaction. Historical transactions are never rewritten.
 update public.sales set product_id=p_product_id,quantity=p_units,unit_price=p_unit_price where id=sale;
 result:=result||jsonb_build_object('product_id',p_product_id,'quantity',p_units,'unit_price',p_unit_price);
 update private.catalog_requests set payload=owner_payload,response=result where request_id=p_request_id;
 update private.sale_requests set payload=jsonb_build_object('employee',null,'total',total,'payment',method,'items',items,'quick',true),receipt=result
 where business_id=p_business_id and user_id=auth.uid() and request_id=p_request_id;
 return result;
end $$;
revoke all on function public.record_confirmed_trexven_owner_sale(uuid,uuid,uuid,numeric,numeric,jsonb,uuid) from public,anon;
grant execute on function public.record_confirmed_trexven_owner_sale(uuid,uuid,uuid,numeric,numeric,jsonb,uuid) to authenticated;
-- Retain the earlier development journal's integer p_quantity argument name.
-- Distinct argument names avoid ambiguous PostgREST JSON overload resolution.
create function public.record_confirmed_trexven_owner_sale(p_business_id uuid,p_request_id uuid,
 p_product_id uuid,p_quantity integer,p_unit_price numeric,p_payments jsonb,p_shift_id uuid default null)
returns jsonb language sql security invoker set search_path='' as $$
 select public.record_confirmed_trexven_owner_sale(p_business_id,p_request_id,p_product_id,
  p_quantity::numeric,p_unit_price,p_payments,p_shift_id)
$$;
revoke all on function public.record_confirmed_trexven_owner_sale(uuid,uuid,uuid,integer,numeric,jsonb,uuid) from public,anon;
grant execute on function public.record_confirmed_trexven_owner_sale(uuid,uuid,uuid,integer,numeric,jsonb,uuid) to authenticated;
commit;

