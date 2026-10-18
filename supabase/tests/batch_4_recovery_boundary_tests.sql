-- Deferred. Runner provides a fresh synthetic fixture and rollback.
set local role authenticated;
select id::text as business from batch2_ids where key='business' \gset
select id::text as product from batch2_ids where key='product' \gset
select id::text as member from public.business_members where business_id=:'business' and user_id=auth.uid() \gset
select jsonb_build_array(jsonb_build_object('product_id',:'product','quantity',1,'unit_price',10,'discount',0))::text as items \gset
select '[{"method":"cash","amount":10,"confirmed":true}]'::text as payments \gset
select gen_random_uuid()::text as legacy_key \gset
select public.submit_trexven_sale(:'legacy_key',:'business',:'member',10,'cash',:'items',false)::text as original \gset
select pg_temp.assert_true(public.complete_trexven_transaction(:'legacy_key',:'business',:'member',10,:'items',:'payments')=:'original'::jsonb,'old checkout recovered through new contract');
select pg_temp.assert_true(public.recover_trexven_legacy_checkout(:'business',:'legacy_key',:'member',10,:'items','cash')=:'original'::jsonb,'recovery fetches original immutable receipt');
select pg_temp.fails(format('select public.cancel_trexven_uncommitted_operation(%L,%L,true)',:'business',:'legacy_key'));
select gen_random_uuid()::text as new_key \gset
select public.complete_trexven_transaction(:'new_key',:'business',:'member',10,:'items',:'payments')::text as new_receipt \gset
select pg_temp.assert_true(public.submit_trexven_sale(:'new_key',:'business',:'member',10,'cash',:'items',false)=:'new_receipt'::jsonb,'new checkout retry through old wrapper returns same receipt');
select pg_temp.assert_true((select quantity=98 from public.products where id=:'product'),'cross-contract retries deduct stock exactly once');
select gen_random_uuid()::text as cancelled \gset
select public.cancel_trexven_uncommitted_operation(:'business',:'cancelled',true);
select pg_temp.fails(format('select public.submit_trexven_sale(%L,%L,%L,10,''cash'',%L,false)',:'cancelled',:'business',:'member',:'items'));
select pg_temp.fails(format('select public.complete_trexven_transaction(%L,%L,%L,10,%L,%L)',:'cancelled',:'business',:'member',:'items',:'payments'));
select pg_temp.assert_true((select quantity=98 from public.products where id=:'product'),'cancelled key cannot mutate stock through either contract');
