begin;
do $$
declare owner_id uuid:=gen_random_uuid(); staff_id uuid:=gen_random_uuid(); other_id uuid:=gen_random_uuid();
 business uuid; employee uuid; product uuid; conversation uuid; denied boolean; i integer;
begin
 insert into auth.users(id,email) values(owner_id,owner_id||'@example.invalid'),
 (staff_id,staff_id||'@example.invalid'),(other_id,other_id||'@example.invalid');
 perform set_config('request.jwt.claim.sub',owner_id::text,true);
 set local role authenticated;
 business:=public.complete_trexven_onboarding('Readiness audit','Other','Nigeria','NGN');
 insert into public.products(business_id,name,selling_price,quantity) values(business,'Audit',10,5) returning id into product;
 insert into public.angel_conversations(business_id,user_id,title) values(business,owner_id,'Private') returning id into conversation;
 reset role;
 insert into public.employees(business_id,user_id,name,role,employee_code,status)
 values(business,staff_id,'Staff','employee','AUDIT-'||staff_id,'active') returning id into employee;
 insert into public.business_members(business_id,user_id,full_name,role,status)
 values(business,staff_id,'Staff','employee','active');
 perform set_config('request.jwt.claim.sub',staff_id::text,true);
 set local role authenticated;
 if private.has_business_permission(business,'complete_sales') then raise exception 'Ungranted sale permission'; end if;
 if (select count(*) from public.products where id=product)<>0 then raise exception 'Ungranted inventory read'; end if;
 if (select count(*) from public.angel_conversations where id=conversation)<>0 then raise exception 'Other author history readable'; end if;
 denied:=false;
 begin perform public.record_trexven_sale(business,product,1,10); exception when insufficient_privilege then denied:=true; end;
 if not denied then raise exception 'Ungranted sale accepted'; end if;
 denied:=false;
 begin perform public.consume_angel_request(staff_id); exception when insufficient_privilege then denied:=true; end;
 if not denied then raise exception 'Client can call internal limiter'; end if;
 reset role;
 perform set_config('request.jwt.claim.sub',owner_id::text,true);
 update public.employees set role='sales_employee' where id=employee;
 perform set_config('request.jwt.claim.sub',staff_id::text,true);
 set local role authenticated;
 if not private.has_business_permission(business,'complete_sales') then raise exception 'Sales role default missing'; end if;
 if private.has_business_permission(business,'view_camera_events') then raise exception 'Sales role camera access'; end if;
 perform public.record_trexven_sale(business,product,1,10);
 if (select quantity from public.products where id=product)<>4 then raise exception 'Permitted sale did not change stock'; end if;
 denied:=false;
 begin update public.products set selling_price=0 where id=product; exception when insufficient_privilege then denied:=true; end;
 if found then raise exception 'Sales role can edit product'; end if;
 reset role;
 perform set_config('request.jwt.claim.sub',owner_id::text,true);
 update public.employees set status='suspended' where id=employee;
 perform set_config('request.jwt.claim.sub',staff_id::text,true);
 set local role authenticated;
 if private.has_business_permission(business,'complete_sales') then raise exception 'Suspended employee permission retained'; end if;
 reset role;
 for i in 1..20 loop
   if not public.consume_angel_request(staff_id) then raise exception 'Limiter rejected before threshold'; end if;
 end loop;
 if public.consume_angel_request(staff_id) then raise exception 'Limiter threshold not enforced'; end if;
end $$;
select 'PASS: employee permission boundaries, private conversations, permitted transactional sale, suspended employee, internal-only distributed limiter' as verification;
rollback;
