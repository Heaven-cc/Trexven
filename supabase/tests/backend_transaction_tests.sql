begin;
do $$
declare ua uuid:=gen_random_uuid(); ub uuid:=gen_random_uuid(); ue uuid:=gen_random_uuid();
 ba uuid; bb uuid; product_a uuid; product_b uuid; eid uuid; sid uuid; n int; failed boolean;
begin
 insert into auth.users(id,email,raw_user_meta_data) values
 (ua,'audit-'||ua||'@example.invalid','{"full_name":"Audit owner"}'),
 (ub,'audit-'||ub||'@example.invalid','{}'),(ue,'audit-'||ue||'@example.invalid','{}');
 perform set_config('request.jwt.claim.sub',ua::text,true);
 set local role authenticated;
 ba:=public.complete_trexven_onboarding('Audit A','Other','Nigeria','NGN');
 if ba<>public.complete_trexven_onboarding('Audit A','Other','Nigeria','NGN') then raise exception 'Onboarding duplicated business'; end if;
 select count(*) into n from public.business_members where business_id=ba and user_id=ua;
 if n<>1 then raise exception 'Onboarding membership count %',n; end if;
 insert into public.products(business_id,name,selling_price,quantity) values(ba,'Audit product A',10,5) returning id into product_a;
 update public.businesses set email='test@example.invalid',website='https://example.invalid',business_hours='{}' where id=ba;
 perform set_config('request.jwt.claim.sub',ub::text,true);
 bb:=public.complete_trexven_onboarding('Audit B','Other','Nigeria','NGN');
 insert into public.products(business_id,name,selling_price,quantity) values(bb,'Audit product B',20,3) returning id into product_b;
 select count(*) into n from public.products where id=product_a;
 if n<>0 then raise exception 'Cross-business product read'; end if;
 failed:=false;
 begin perform public.record_trexven_sale(ba,product_a,1,10); exception when others then failed:=true; end;
 if not failed then raise exception 'Cross-business sale permitted'; end if;
 perform set_config('request.jwt.claim.sub',ua::text,true);
 sid:=public.record_trexven_sale(ba,product_a,2,10);
 if (select quantity from public.products where id=product_a)<>3 then raise exception 'Stock not decremented'; end if;
 if (select total from public.sales where id=sid)<>20 then raise exception 'Sale total wrong'; end if;
 if (select count(*) from public.sale_items where sale_id=sid)<>1 then raise exception 'Sale item missing'; end if;
 failed:=false;
 begin perform public.record_trexven_sale(ba,product_a,4,10); exception when others then failed:=true; end;
 if not failed or (select quantity from public.products where id=product_a)<>3
 or (select count(*) from public.sales where business_id=ba)<>1 then raise exception 'Oversell was not atomic'; end if;
 failed:=false;
 begin perform public.record_trexven_sale(ba,product_b,1,20); exception when others then failed:=true; end;
 if not failed then raise exception 'Foreign product accepted'; end if;
 failed:=false;
 begin perform public.record_trexven_sale(ba,product_a,1,1); exception when others then failed:=true; end;
 if not failed then raise exception 'Price mismatch accepted'; end if;
 perform public.complete_pos_sale(ba,(select id from public.business_members where business_id=ba and user_id=ua),18,'cash',
 jsonb_build_array(jsonb_build_object('product_id',product_a,'quantity',2,'unit_price',10,'discount',2)));
 if (select quantity from public.products where id=product_a)<>1 then raise exception 'POS stock wrong'; end if;
 reset role;
 insert into public.employees(business_id,user_id,name,role,employee_code,status)
 values(ba,ue,'Audit employee','sales_employee','AUDIT-'||ue,'active') returning id into eid;
 insert into public.business_members(business_id,user_id,full_name,role,status)
 values(ba,ue,'Audit employee','employee','active');
 set local role authenticated;
 perform public.set_trexven_employee_status(eid,'suspended');
 if (select status from public.business_members where business_id=ba and user_id=ue)<>'suspended' then raise exception 'Membership suspension failed'; end if;
 perform set_config('request.jwt.claim.sub',ue::text,true);
 if public.is_business_member(ba) then raise exception 'Suspended member retains access'; end if;
 if (select count(*) from public.products where business_id=ba)<>0 then raise exception 'Suspended member can read products'; end if;
 failed:=false;
 begin perform public.complete_trexven_onboarding('Duplicate','Other','Nigeria','NGN'); exception when others then failed:=true; end;
 if not failed then raise exception 'Suspended member was onboarded as owner'; end if;
 perform set_config('request.jwt.claim.sub',ub::text,true);
 failed:=false;
 begin perform public.set_trexven_employee_status(eid,'active'); exception when others then failed:=true; end;
 if not failed then raise exception 'Other business can manage employee'; end if;
 perform set_config('request.jwt.claim.sub',ua::text,true);
 perform public.set_trexven_employee_status(eid,'active');
 perform set_config('request.jwt.claim.sub',ue::text,true);
 update public.businesses set owner_id=ue where id=ba;
 if found then raise exception 'Member can transfer business ownership'; end if;
 if not public.is_business_member(ba) then raise exception 'Reactivation failed'; end if;
 reset role;
end;
$$;
select 'PASS: idempotent onboarding, required membership, profile fields, tenant isolation, atomic sale, oversell rollback, price validation, POS, employee suspension/reactivation, ownership protection' as verification;
rollback;
