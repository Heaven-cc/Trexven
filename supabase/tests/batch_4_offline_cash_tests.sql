set local role authenticated;
select id::text as business from batch2_ids where key='business' \gset
select id::text as product from batch2_ids where key='product' \gset
select public.issue_trexven_offline_scope(:'business',gen_random_uuid())::text as ticket \gset
select :'ticket'::jsonb->'scope'->>'issued_at' as occurred \gset
select gen_random_uuid()::text as request \gset
select public.sync_trexven_offline_cash(:'request',:'ticket',jsonb_build_array(jsonb_build_object('product_id',:'product','quantity',101,'unit_price',10)),1010,:'occurred')::text as receipt \gset
select pg_temp.assert_true((select quantity=0 from public.products where id=:'product'),'genuine offline oversell floors available stock');
select pg_temp.assert_true(jsonb_array_length(:'receipt'::jsonb->'offline_discrepancies')=1,'offline shortfall retained as reviewable discrepancy');
select pg_temp.assert_true(public.sync_trexven_offline_cash(:'request',:'ticket',jsonb_build_array(jsonb_build_object('product_id',:'product','quantity',101,'unit_price',10)),1010,:'occurred')=:'receipt'::jsonb,'offline duplicate returns original receipt');
select pg_temp.fails(format('select public.sync_trexven_offline_cash(gen_random_uuid(),%L,%L,1,%L)',:'ticket',jsonb_build_array(jsonb_build_object('product_id',:'product','quantity',1,'unit_price',1))::text,:'occurred'));
select pg_temp.denied(format('select public.sync_trexven_offline_cash(gen_random_uuid(),%L,%L,10,%L)',jsonb_set(:'ticket'::jsonb,'{scope,device_id}','"forged"')::text,jsonb_build_array(jsonb_build_object('product_id',:'product','quantity',1,'unit_price',10))::text,:'occurred'));
select pg_temp.fails(format('select public.sync_trexven_offline_cash(gen_random_uuid(),%L,%L,10,%L)',:'ticket',jsonb_build_array(jsonb_build_object('product_id',:'product','quantity',1,'unit_price',10))::text,((:'ticket'::jsonb->'scope'->>'expires_at')::timestamptz+interval '1 second')::text));
select set_config('request.jwt.claim.sub',(select id::text from batch2_ids where key='other_owner'),true);
select pg_temp.denied(format('select public.sync_trexven_offline_cash(gen_random_uuid(),%L,%L,10,%L)',:'ticket',jsonb_build_array(jsonb_build_object('product_id',:'product','quantity',1,'unit_price',10))::text,:'occurred'));
