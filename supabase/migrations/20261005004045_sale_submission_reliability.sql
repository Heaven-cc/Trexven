-- Additive API: legacy callers retain their existing signatures and rules.
-- No client can read or write retry records directly.
create table private.sale_requests (
 business_id uuid not null references public.businesses(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 request_id uuid not null,
 payload jsonb not null,
 receipt jsonb not null,
 primary key(business_id,user_id,request_id)
);
alter table private.sale_requests enable row level security;
revoke all on private.sale_requests from public,anon,authenticated;

-- Copy the validated POS transaction without altering the legacy void API.
-- Its only behavior change is returning the persisted ID to the new wrapper.
do $$ declare definition text; begin
 select pg_get_functiondef('private.complete_pos_sale(uuid,uuid,numeric,text,jsonb)'::regprocedure) into definition;
 definition:=replace(definition,'FUNCTION private.complete_pos_sale(', 'FUNCTION private.complete_pos_sale_with_receipt(');
 definition:=replace(definition,'RETURNS void','RETURNS uuid');
 definition:=regexp_replace(definition, E'end;[\\r\\n]+\\$function\\$', E'return v_sale;\nend;\n$function$');
 if position('return v_sale;' in definition)=0 then raise exception 'Unexpected POS function body'; end if;
 execute definition;
end $$;
revoke all on function private.complete_pos_sale_with_receipt(uuid,uuid,numeric,text,jsonb) from public,anon,authenticated;

create function private.submit_trexven_sale(
 p_request_id uuid,p_business_id uuid,p_employee_id uuid,p_total numeric,
 p_payment_method text,p_items jsonb,p_quick boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v_payload jsonb; v_saved private.sale_requests%rowtype; v_sale uuid; v_receipt jsonb;
begin
 if auth.uid() is null or not public.is_business_member(p_business_id)
 or not private.has_business_permission(p_business_id,'complete_sales') then
   raise exception 'Sale permission denied' using errcode='42501';
 end if;
 if p_request_id is null or p_quick is null then raise exception 'Sale request ID and type required'; end if;
 if p_payment_method is null or p_payment_method not in ('cash','card','bank_transfer','mobile_money','other') then
   raise exception 'Select a valid payment method.'; end if;
 v_payload:=jsonb_build_object('employee',p_employee_id,'total',p_total,'payment',p_payment_method,'items',p_items,'quick',p_quick);
 -- Serialize the same logical request before accessing stock. Hash collisions
 -- merely serialize unrelated requests; the primary key still identifies them.
 perform pg_advisory_xact_lock(hashtextextended(p_business_id::text||auth.uid()::text||p_request_id::text,0));
 select * into v_saved from private.sale_requests where business_id=p_business_id and user_id=auth.uid() and request_id=p_request_id;
 if found then
   if v_saved.payload<>v_payload then raise exception 'This sale was already submitted with different details. Review its receipt before starting another sale.'; end if;
   return v_saved.receipt;
 end if;
 if p_items is null or jsonb_typeof(p_items)<>'array' or jsonb_array_length(p_items)=0 then raise exception 'Items required'; end if;
 if p_quick then
   if jsonb_array_length(p_items)<>1 or p_employee_id is not null
   or coalesce((p_items->0->>'discount')::numeric,0)<>0 then raise exception 'Invalid quick sale'; end if;
   if p_total is distinct from (p_items->0->>'quantity')::integer*(p_items->0->>'unit_price')::numeric then raise exception 'Sale total does not match items'; end if;
   v_sale:=private.record_trexven_sale(p_business_id,(p_items->0->>'product_id')::uuid,
     (p_items->0->>'quantity')::integer,(p_items->0->>'unit_price')::numeric);
   update public.sales set payment_method=p_payment_method where id=v_sale;
 else
   v_sale:=private.complete_pos_sale_with_receipt(p_business_id,p_employee_id,p_total,p_payment_method,p_items);
 end if;
 update public.sales set sale_number='TRX-'||v_sale::text where id=v_sale;
 select to_jsonb(s)||jsonb_build_object('sale_items',
   (select jsonb_agg(to_jsonb(i) order by i.id) from public.sale_items i where i.sale_id=v_sale))
 into v_receipt from public.sales s where s.id=v_sale;
 insert into private.sale_requests values(p_business_id,auth.uid(),p_request_id,v_payload,v_receipt);
 return v_receipt;
end $$;
revoke all on function private.submit_trexven_sale(uuid,uuid,uuid,numeric,text,jsonb,boolean) from public,anon;
grant execute on function private.submit_trexven_sale(uuid,uuid,uuid,numeric,text,jsonb,boolean) to authenticated;

create function public.submit_trexven_sale(
 p_request_id uuid,p_business_id uuid,p_employee_id uuid,p_total numeric,
 p_payment_method text,p_items jsonb,p_quick boolean)
returns jsonb language sql security invoker set search_path='' as $$
 select private.submit_trexven_sale(p_request_id,p_business_id,p_employee_id,p_total,p_payment_method,p_items,p_quick)
$$;
revoke all on function public.submit_trexven_sale(uuid,uuid,uuid,numeric,text,jsonb,boolean) from public,anon;
grant execute on function public.submit_trexven_sale(uuid,uuid,uuid,numeric,text,jsonb,boolean) to authenticated;
notify pgrst,'reload schema';
