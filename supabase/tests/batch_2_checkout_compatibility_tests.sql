begin;
\ir batch_2_fixture.sql
set local role authenticated;
select gen_random_uuid() as request \gset
select jsonb_build_array(jsonb_build_object('product_id',(select id from batch2_ids where key='product'),'quantity',2,'unit_price',10,'discount',0))::text as items \gset
select public.submit_trexven_sale(:'request',(select id from batch2_ids where key='business'),null,20,'cash',:'items',true)::text as receipt \gset
select pg_temp.assert_true(public.submit_trexven_sale(:'request',(select id from batch2_ids where key='business'),null,20,'cash',:'items',true)=:'receipt'::jsonb,'receipt replay exact');
select pg_temp.assert_true((select quantity from public.products where id=(select id from batch2_ids where key='product'))=98,'idempotent stock decrement');
select pg_temp.assert_true((:'receipt'::jsonb->>'sale_number') like 'TRX-%','receipt identifier retained');
select pg_temp.fails(format('select public.submit_trexven_sale(%L,%L,null,20,''card'',%L,true)',:'request',(select id from batch2_ids where key='business'),:'items'));
select set_config('request.jwt.claim.sub',(select id::text from batch2_ids where key='sales_user'),true);
select public.complete_pos_sale((select id from batch2_ids where key='business'),(select id from batch2_ids where key='sales_member'),20,'cash',:'items');
select pg_temp.assert_true((select count(*) from public.sales where business_id=(select id from batch2_ids where key='business'))=2,'legacy sales remain visible today');
select pg_temp.fails(format('select public.complete_pos_sale(%L,%L,20,''cash'',%L)',(select id from batch2_ids where key='business'),gen_random_uuid(),:'items'));
select pg_temp.denied(format('select public.submit_trexven_branch_sale(%L,%L,%L,20,''cash'',%L,false,%L)',gen_random_uuid(),(select id from batch2_ids where key='business'),(select id from batch2_ids where key='sales_member'),:'items',gen_random_uuid()));
select set_config('request.jwt.claim.sub',(select id::text from batch2_ids where key='other_owner'),true);
select pg_temp.denied(format('select public.submit_trexven_sale(%L,%L,null,20,''cash'',%L,true)',:'request',(select id from batch2_ids where key='business'),:'items'));
select pg_temp.assert_true((select count(*) from public.sales where business_id=(select id from batch2_ids where key='business'))=0,'cross-business sales read denied');
reset role;
select set_config('request.jwt.claim.sub','',true);
update public.businesses set pos_writes_paused=true where id=(select id from batch2_ids where key='business');
select set_config('request.jwt.claim.sub',(select id::text from batch2_ids where key='owner'),true);
set local role authenticated;
select pg_temp.denied(format('select public.submit_trexven_sale(%L,%L,null,20,''cash'',%L,true)',gen_random_uuid(),(select id from batch2_ids where key='business'),:'items'));
select pg_temp.assert_true(public.submit_trexven_sale(:'request',(select id from batch2_ids where key='business'),null,20,'cash',:'items',true)=:'receipt'::jsonb,'saved receipt recovery remains available while new sales paused');
reset role;
select 'Legacy checkout assertions completed (isolated runtime required)' as result;
rollback;
