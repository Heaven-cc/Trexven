begin;
\ir batch_2_fixture.sql
set local role authenticated;
select public.create_trexven_branch((select id from batch2_ids where key='business'),'Synthetic A') as a \gset
select public.create_trexven_branch((select id from batch2_ids where key='business'),'Synthetic B') as b \gset
select public.create_trexven_branch((select id from batch2_ids where key='business'),'Synthetic C') as c \gset
select public.set_trexven_branch_assignment((select id from batch2_ids where key='sales'),:'a',true);
select public.set_trexven_branch_assignment((select id from batch2_ids where key='sales'),:'b',true);
select set_config('request.jwt.claim.sub',(select id::text from batch2_ids where key='sales_user'),true);
select pg_temp.assert_true(private.has_branch_access((select id from batch2_ids where key='business'),:'a'),'first assigned branch');
select pg_temp.assert_true(private.has_branch_access((select id from batch2_ids where key='business'),:'b'),'second assigned branch');
select pg_temp.assert_true(not private.has_branch_access((select id from batch2_ids where key='business'),:'c'),'unassigned branch denied');
select pg_temp.assert_true(not private.has_branch_access((select id from batch2_ids where key='other_business'),:'a'),'forged business/branch combination denied');
select pg_temp.assert_true((select count(*) from public.branches where business_id=(select id from batch2_ids where key='business'))=2,'RLS only assigned branches');
select pg_temp.denied(format('select public.set_trexven_branch_assignment(%L,%L,true)',(select id from batch2_ids where key='sales'),:'c'));
select pg_temp.denied(format('update public.businesses set branches_enabled=true where id=%L',(select id from batch2_ids where key='business')));
select set_config('request.jwt.claim.sub',(select id::text from batch2_ids where key='owner'),true);
select pg_temp.denied(format('update public.businesses set branches_enabled=true where id=%L',(select id from batch2_ids where key='business')));
select public.set_trexven_branch_assignment((select id from batch2_ids where key='sales'),:'a',false);
select set_config('request.jwt.claim.sub',(select id::text from batch2_ids where key='sales_user'),true);
select pg_temp.assert_true(not private.has_branch_access((select id from batch2_ids where key='business'),:'a'),'assignment revocation immediate');
select pg_temp.assert_true(private.has_branch_access((select id from batch2_ids where key='business'),:'b'),'other assignment remains valid');
select set_config('request.jwt.claim.sub',(select id::text from batch2_ids where key='owner'),true);
select public.set_trexven_branch_status(:'b',false);
select set_config('request.jwt.claim.sub',(select id::text from batch2_ids where key='sales_user'),true);
select pg_temp.assert_true(not private.has_branch_access((select id from batch2_ids where key='business'),:'b'),'inactive branch denied');
select set_config('request.jwt.claim.sub',(select id::text from batch2_ids where key='owner'),true);
select public.set_trexven_branch_status(:'b',true);
-- Explicit synthetic activation for compatibility tests only. No activation API.
reset role;
select set_config('request.jwt.claim.sub','',true);
update public.businesses set branches_enabled=true,compatibility_branch_id=:'b'
 where id=(select id from batch2_ids where key='business');
insert into public.inventory(business_id,branch_id,product_id,quantity,reserved_quantity)
 values((select id from batch2_ids where key='business'),:'b',(select id from batch2_ids where key='product'),5,0);
select set_config('request.jwt.claim.sub',(select id::text from batch2_ids where key='sales_user'),true);
set local role authenticated;
select gen_random_uuid() as request \gset
select jsonb_build_array(jsonb_build_object('product_id',(select id from batch2_ids where key='product'),'quantity',2,'unit_price',10,'discount',0))::text as items \gset
select public.submit_trexven_branch_sale(:'request',(select id from batch2_ids where key='business'),
 (select id from batch2_ids where key='sales_member'),20,'cash',:'items',false,:'b')::text as receipt \gset
select pg_temp.assert_true((:'receipt'::jsonb->>'branch_id')::uuid=:'b','receipt branch identity');
select pg_temp.assert_true((select quantity from public.inventory where branch_id=:'b')=3,'only selected branch stock decremented');
select pg_temp.assert_true((select quantity from public.products where id=(select id from batch2_ids where key='product'))=100,'legacy stock untouched');
select pg_temp.assert_true(public.submit_trexven_branch_sale(:'request',(select id from batch2_ids where key='business'),
 (select id from batch2_ids where key='sales_member'),20,'cash',:'items',false,:'b')=:'receipt'::jsonb,'branch replay exact');
select set_config('request.jwt.claim.sub',(select id::text from batch2_ids where key='owner'),true);
select public.set_trexven_branch_assignment((select id from batch2_ids where key='sales'),:'a',true);
select set_config('request.jwt.claim.sub',(select id::text from batch2_ids where key='sales_user'),true);
select pg_temp.fails(format('select public.submit_trexven_branch_sale(%L,%L,%L,20,''cash'',%L,false,%L)',
 :'request',(select id from batch2_ids where key='business'),(select id from batch2_ids where key='sales_member'),:'items',:'a'));
select pg_temp.fails(format('select public.complete_pos_sale(%L,%L,20,''cash'',%L)',
 (select id from batch2_ids where key='business'),(select id from batch2_ids where key='sales_member'),:'items'));
reset role;
select 'Branch assertions completed (isolated runtime required)' as result;
rollback;
