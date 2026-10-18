-- Synthetic-only fixture. Included inside each suite's transaction.
do $$ begin
 if not exists(select 1 from private.batch_2_test_environment where marker='TREXVEN_SYNTHETIC_ONLY') then
 raise exception 'Isolated synthetic test environment required'; end if;
end $$;
create temporary table batch2_ids(key text primary key,id uuid);
grant select on batch2_ids to authenticated,anon;
create function pg_temp.assert_true(value boolean,label text) returns void language plpgsql as $$
begin if value is not true then raise exception 'ASSERTION FAILED: %',label; end if; end $$;
create function pg_temp.denied(statement text) returns void language plpgsql as $$
declare n bigint;
begin
 begin
   execute statement;
   get diagnostics n=row_count;
   if n=0 then return; end if;
 exception when insufficient_privilege then return;
 end;
 raise exception 'Unauthorized operation succeeded: %',statement;
end $$;
create function pg_temp.fails(statement text) returns void language plpgsql as $$
begin
 begin execute statement;
 exception when insufficient_privilege or raise_exception then return; end;
 raise exception 'Invalid operation succeeded: %',statement;
end $$;
do $$
declare o uuid:=gen_random_uuid(); other uuid:=gen_random_uuid(); manager uuid:=gen_random_uuid();
 seller uuid:=gen_random_uuid(); clerk uuid:=gen_random_uuid(); business uuid; second uuid; e uuid; p uuid;
begin
 insert into auth.users(id,email) values(o,o||'@example.invalid'),(other,other||'@example.invalid'),
 (manager,manager||'@example.invalid'),(seller,seller||'@example.invalid'),(clerk,clerk||'@example.invalid');
 insert into batch2_ids values('owner',o),('other_owner',other),('manager_user',manager),('sales_user',seller),('inventory_user',clerk);
 perform set_config('request.jwt.claim.sub',o::text,true); set local role authenticated;
 business:=public.complete_trexven_onboarding('Synthetic Batch 2','Other','Nigeria','NGN');
 update public.businesses set timezone='UTC' where id=business;
 insert into public.products(business_id,name,selling_price,quantity) values(business,'Synthetic product',10,100) returning id into p;
 reset role;
 insert into batch2_ids values('business',business),('product',p);
 insert into public.employees(business_id,user_id,name,role,employee_code,status)
 values(business,manager,'Synthetic manager','manager','B2-'||manager,'active') returning id into e;
 insert into batch2_ids values('manager',e);
 insert into public.employees(business_id,user_id,name,role,employee_code,status)
 values(business,seller,'Synthetic sales','sales_employee','B2-'||seller,'active') returning id into e;
 insert into batch2_ids values('sales',e);
 insert into public.employees(business_id,user_id,name,role,employee_code,status)
 values(business,clerk,'Synthetic inventory','inventory_employee','B2-'||clerk,'active') returning id into e;
 insert into batch2_ids values('inventory',e);
 insert into public.business_members(business_id,user_id,full_name,role,status) values
 (business,manager,'Synthetic manager','manager','active'),(business,seller,'Synthetic sales','employee','active'),(business,clerk,'Synthetic inventory','employee','active');
 insert into batch2_ids select 'sales_member',id from public.business_members where business_id=business and user_id=seller;
 perform set_config('request.jwt.claim.sub',other::text,true); set local role authenticated;
 second:=public.complete_trexven_onboarding('Synthetic other business','Other','Nigeria','NGN'); reset role;
 insert into batch2_ids values('other_business',second);
 perform set_config('request.jwt.claim.sub',o::text,true);
end $$;
