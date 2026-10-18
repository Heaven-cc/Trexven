-- Deferred. Runner supplies a fresh synthetic fixture and outer rollback.
set local role authenticated;
select id::text as business from batch2_ids where key='business' \gset
select id::text as product from batch2_ids where key='product' \gset
select id::text as owner from batch2_ids where key='owner' \gset
select id::text as seller from batch2_ids where key='sales_user' \gset
select id::text as member from public.business_members where business_id=:'business' and user_id=:'owner' \gset
select public.start_trexven_stocktake(:'business',gen_random_uuid(),'Synthetic count')->>'id' as session \gset
select public.count_trexven_stock(:'session',gen_random_uuid(),jsonb_build_array(jsonb_build_object('product_id',:'product','version',0,'quantity',98)));
select pg_temp.fails(format('select public.count_trexven_stock(%L,gen_random_uuid(),%L)',:'session',jsonb_build_array(jsonb_build_object('product_id',:'product','version',0,'quantity',99))::text));
-- A sale after the physical count is retained by delta reconciliation.
select public.submit_trexven_sale(gen_random_uuid(),:'business',:'member',10,'cash',jsonb_build_array(jsonb_build_object('product_id',:'product','quantity',1,'unit_price',10,'discount',0)),false);
select public.submit_trexven_stocktake(:'session',gen_random_uuid());
select gen_random_uuid()::text as approve_key \gset
select public.approve_trexven_stocktake(:'session',:'approve_key','Count verified');
select public.approve_trexven_stocktake(:'session',:'approve_key','Count verified');
select pg_temp.assert_true((select quantity=97 from public.products where id=:'product'),'apply count delta once without erasing later sale');
select public.classify_trexven_stock(:'business',:'product',gen_random_uuid(),2,'damaged','Physical inspection');
select pg_temp.assert_true((select quantity=95 from public.products where id=:'product'),'damaged stock leaves sellable quantity');
select pg_temp.fails(format('select public.resolve_trexven_condition_stock(%L,%L,gen_random_uuid(),3,''damaged'',''restore'',''Inspected'')',:'business',:'product'));
select public.resolve_trexven_condition_stock(:'business',:'product',gen_random_uuid(),1,'damaged','restore','Inspected sellable');
select pg_temp.assert_true((select quantity=96 from public.products where id=:'product'),'only inspected quantity becomes sellable');
select set_config('request.jwt.claim.sub',:'seller',true);
select pg_temp.denied(format('select public.approve_trexven_stocktake(%L,gen_random_uuid(),''Forged approval'')',:'session'));
select pg_temp.denied(format('update public.stocktake_counts set counted=999 where session_id=%L',:'session'));
select pg_temp.assert_true((select count(*)=0 from public.stocktake_sessions where business_id=(select id from batch2_ids where key='other_business')),'cross-business counts hidden');
select pg_temp.assert_true((select not branches_enabled and not inventory_transfers_enabled from public.businesses where id=:'business'),'branch and transfer workflows remain dormant');
