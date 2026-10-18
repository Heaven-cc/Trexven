-- Synthetic fixture only; the outer transaction always rolls back.
set local role authenticated;
select id::text as business from batch2_ids where key='business' \gset
select id::text as product from batch2_ids where key='product' \gset
select id::text as owner from batch2_ids where key='owner' \gset
select id::text as seller from batch2_ids where key='sales_user' \gset
select jsonb_build_array(jsonb_build_object('product_id',:'product','quantity',1,'unit_price',10,'discount',0))::text as items \gset
select '[{"method":"bank_transfer","amount":10,"confirmed":true,"evidence":"Synthetic bank confirmation"}]'::text as payments \gset
select pg_temp.assert_true(jsonb_array_length(public.get_trexven_pos_context())=1,'owner context is verified from ownership');
select pg_temp.assert_true(public.get_trexven_pos_context()->0->'employee'->>'user_id'=auth.uid()::text,'context retains Auth identity');
select pg_temp.assert_true(jsonb_array_length(public.get_trexven_pos_context((select id from batch2_ids where key='other_business')))=0,'forged business context denied');
select gen_random_uuid()::text as request \gset
select public.record_confirmed_trexven_owner_sale(:'business',:'request',:'product',1,10,:'payments')::text as receipt \gset
select pg_temp.assert_true(public.record_confirmed_trexven_owner_sale(:'business',:'request',:'product',1,10,:'payments')=:'receipt'::jsonb,'owner payment replay retains receipt');
select pg_temp.assert_true(public.submit_trexven_sale(:'request',:'business',null,10,'bank_transfer',:'items',true)=:'receipt'::jsonb,'older Owner build recovers the same new receipt');
select pg_temp.assert_true((select quantity=99 from public.products where id=:'product'),'owner confirmed payment deducts stock once');
select pg_temp.assert_true((select count(*)=1 from public.sale_payments where request_id=:'request'),'one genuine payment record');
select pg_temp.fails(format('select public.record_confirmed_trexven_owner_sale(%L,%L,%L,1,10,''[{"method":"cash","amount":10,"confirmed":true}]'')',:'business',:'request',:'product'));
select gen_random_uuid()::text as legacy_key \gset
select public.submit_trexven_sale(:'legacy_key',:'business',null,10,'cash',:'items',true)::text as original \gset
select pg_temp.assert_true(public.record_confirmed_trexven_owner_sale(:'business',:'legacy_key',:'product',1,10,'[{"method":"cash","amount":10,"confirmed":true}]')=:'original'::jsonb,'new Owner recovers existing historical quick sale');
select pg_temp.assert_true((select quantity=98 from public.products where id=:'product'),'historical replay does not alter stock again');
select public.import_trexven_catalog(:'business',gen_random_uuid(),'[{"name":"Synthetic measured item","unit":"kg","selling_price":10,"initial_quantity":10}]')->>0 as weighted \gset
select gen_random_uuid()::text as new_key \gset
select public.record_confirmed_trexven_owner_sale(:'business',:'new_key',:'weighted',2.5::numeric,10,'[{"method":"cash","amount":25,"confirmed":true}]')::text as new_receipt \gset
select pg_temp.assert_true((:'new_receipt'::jsonb->>'quantity')::numeric=2.5,'Owner receipt preserves fractional measured units');
select pg_temp.assert_true((select quantity=7.5 from public.products where id=:'weighted'),'measured stock deducted exactly');
select pg_temp.assert_true(public.record_confirmed_trexven_owner_sale(:'business',:'new_key',:'weighted',2.5::numeric,10,'[{"method":"cash","amount":25,"confirmed":true}]')=:'new_receipt'::jsonb,'fractional receipt replay remains exact');
select pg_temp.fails(format('select public.record_confirmed_trexven_owner_sale(%L,gen_random_uuid(),%L,0.0001::numeric,10,''[{"method":"cash","amount":0,"confirmed":true}]'')',:'business',:'weighted'));
select pg_temp.fails(format('select public.record_confirmed_trexven_owner_sale(%L,gen_random_uuid(),%L,1,10,''[{"method":"card","amount":10,"confirmed":false}]'')',:'business',:'product'));
select set_config('request.jwt.claim.sub',:'seller',true);
select pg_temp.assert_true(public.get_trexven_pos_context()->0->'employee'->>'role'='sales_employee','employee role comes from current database');
select pg_temp.denied(format('select public.record_confirmed_trexven_owner_sale(%L,gen_random_uuid(),%L,1,10,''[{"method":"cash","amount":10,"confirmed":true}]'')',:'business',:'product'));
select set_config('request.jwt.claim.sub',:'owner',true);
reset role;
update public.employees set status='suspended' where id=(select id from batch2_ids where key='sales');
set local role authenticated;
select set_config('request.jwt.claim.sub',:'seller',true);
select pg_temp.assert_true(jsonb_array_length(public.get_trexven_pos_context())=0,'revoked employment invalidates restored context');
select set_config('request.jwt.claim.sub','',true);
select pg_temp.denied('select public.get_trexven_pos_context()');
