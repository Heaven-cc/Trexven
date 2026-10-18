-- Synthetic disposable database only. The runner supplies the reviewed fixture.
set local role authenticated;
select id::text as business from batch2_ids where key='business' \gset
select id::text as product from batch2_ids where key='product' \gset
select id::text as owner from batch2_ids where key='owner' \gset
select gen_random_uuid()::text as group_id \gset
select public.save_trexven_product_group(:'business',:'group_id','Shirts');
select public.save_trexven_product_group(:'business',:'group_id','Shirts');
select pg_temp.assert_true((select count(*) from public.product_groups where id=:'group_id')=1,'group retry preserves identity');
select gen_random_uuid()::text as save_request \gset
select jsonb_build_object('name','Blue shirt','selling_price',20,'catalog_group_id',:'group_id','barcode',' B3-BLUE ','sku','B3-SHIRT','variant_attributes',jsonb_build_object('size','L','color','Blue'))::text as fields \gset
select public.save_trexven_catalog_product(:'business',:'save_request',null,:'fields')::text as variant \gset
select pg_temp.assert_true(public.save_trexven_catalog_product(:'business',:'save_request',null,:'fields')=:'variant'::uuid,'catalog retry exact identity');
select pg_temp.assert_true((select barcode from public.products where id=:'variant')='B3-BLUE','manufacturer barcode trimming');
select pg_temp.assert_true((select variant_attributes->>'size' from public.products where id=:'variant')='L','variant attributes retained');
select pg_temp.reject(format('select public.save_trexven_catalog_product(%L,gen_random_uuid(),null,%L)',:'business','{"name":"Duplicate","barcode":"B3-BLUE","selling_price":10}'),'23505','duplicate barcode denied');
select pg_temp.reject(format('select public.save_trexven_catalog_product(%L,gen_random_uuid(),null,%L)',:'business','{"name":"Duplicate SKU","sku":"B3-SHIRT","selling_price":10}'),'23505','duplicate SKU denied');
select pg_temp.reject(format('select public.save_trexven_catalog_product(%L,gen_random_uuid(),null,%L)',:'business','{"name":"Cost leak","cost_price":12}'),'42501','cost import field denied');
select gen_random_uuid()::text as stock_request \gset
select public.adjust_trexven_catalog_stock(:'business',:'variant',10,'Received stock',:'stock_request');
select pg_temp.assert_true(public.adjust_trexven_catalog_stock(:'business',:'variant',10,'Received stock',:'stock_request')=10,'restock retry exact quantity');
select pg_temp.assert_true((select count(*) from public.inventory_movements where product_id=:'variant')=1,'one adjustment ledger row');
select pg_temp.denied(format('update public.products set quantity=20 where id=%L',:'variant'));
select public.adjust_trexven_catalog_stock(:'business',:'variant',-6,'Reviewed correction',gen_random_uuid());
select pg_temp.assert_true((select count(*) from public.alerts where reference_id=:'variant' and alert_type='low_stock')=2,'threshold recovery then new alert');
select public.adjust_trexven_catalog_stock(:'business',:'variant',-1,'Damaged item',gen_random_uuid());
select pg_temp.assert_true((select count(*) from public.alerts where reference_id=:'variant' and alert_type='low_stock')=2,'no repeated below-threshold alert');
select pg_temp.fails(format('select public.adjust_trexven_catalog_stock(%L,%L,-100,''Invalid correction'',gen_random_uuid())',:'business',:'variant'));
select pg_temp.fails(format('select public.adjust_trexven_catalog_stock(%L,%L,0.5,''Fractional piece'',gen_random_uuid())',:'business',:'variant'));
select set_config('request.jwt.claim.sub',(select id::text from batch2_ids where key='inventory_user'),true);
select pg_temp.denied(format('select public.save_trexven_catalog_product(%L,gen_random_uuid(),%L,''{"selling_price":9}'')',:'business',:'variant'));
select public.save_trexven_catalog_product(:'business',gen_random_uuid(),null,'{"name":"Pending inventory item","barcode":"B3-PENDING"}')::text as pending \gset
select pg_temp.assert_true((select selling_price is null and not active and not is_active from public.products where id=:'pending'),'inventory creation pending, no arbitrary price');
select pg_temp.denied(format('select public.adjust_trexven_catalog_stock(%L,%L,1,''Unapproved'',gen_random_uuid())',:'business',:'variant'));
select pg_temp.denied(format('select public.save_trexven_catalog_product(%L,gen_random_uuid(),null,''{"name":"Cross business"}'')',(select id from batch2_ids where key='other_business')));
select set_config('request.jwt.claim.sub',(select id::text from batch2_ids where key='manager_user'),true);
select pg_temp.denied(format('select public.save_trexven_catalog_product(%L,gen_random_uuid(),%L,''{"selling_price":21}'')',:'business',:'variant'));
select set_config('request.jwt.claim.sub',:'owner',true);
select public.set_trexven_employee_permission((select id from batch2_ids where key='manager'),'override_price',true);
select set_config('request.jwt.claim.sub',(select id::text from batch2_ids where key='manager_user'),true);
select public.save_trexven_catalog_product(:'business',gen_random_uuid(),:'variant','{"selling_price":21}');
select pg_temp.assert_true((select selling_price from public.products where id=:'variant')=21,'explicit manager price grant');
select set_config('request.jwt.claim.sub',:'owner',true);
select public.set_trexven_employee_permission((select id from batch2_ids where key='manager'),'override_price',false);
select set_config('request.jwt.claim.sub',(select id::text from batch2_ids where key='manager_user'),true);
select pg_temp.denied(format('select public.save_trexven_catalog_product(%L,gen_random_uuid(),%L,''{"selling_price":22}'')',:'business',:'variant'));
select set_config('request.jwt.claim.sub',:'owner',true);
select gen_random_uuid()::text as update_request \gset
select jsonb_build_array(jsonb_build_object('product_id',:'variant','name','Reviewed bulk update','stock_delta',2,'stock_reason','Reviewed delivery','size','XL'))::text as update_rows \gset
select public.import_trexven_catalog(:'business',:'update_request',:'update_rows')::text as updated_ids \gset
select pg_temp.assert_true(public.import_trexven_catalog(:'business',:'update_request',:'update_rows')=:'updated_ids'::jsonb,'bulk update retry preserves identity');
select pg_temp.assert_true((select quantity=5 and selling_price=21 and variant_attributes->>'size'='XL' and variant_attributes->>'color'='Blue' from public.products where id=:'variant'),'bulk update preserves price and other attributes, adjusts stock once');
select pg_temp.fails(format('select public.import_trexven_catalog(%L,gen_random_uuid(),%L)',:'business',jsonb_build_array(jsonb_build_object('product_id',:'variant','initial_quantity',99))));
select pg_temp.fails(format('select public.import_trexven_catalog(%L,gen_random_uuid(),%L)',:'business',jsonb_build_array(jsonb_build_object('product_id',:'variant','stock_delta',1))));
select pg_temp.assert_true((select count(*) from public.audit_logs where action='catalog_price_changed' and metadata->>'product_id'=:'variant')=2,'price history records initial and authorized changed prices only');
select gen_random_uuid()::text as import_request \gset
select public.import_trexven_catalog(:'business',:'import_request','[{"name":"Measured oil","unit":"litre","barcode":"B3-OIL","selling_price":10,"initial_quantity":5.125},{"name":"Measured cloth","unit":"metre","selling_price":2,"initial_quantity":1.5}]')::text as imported \gset
select pg_temp.assert_true(public.import_trexven_catalog(:'business',:'import_request','[{"name":"Measured oil","unit":"litre","barcode":"B3-OIL","selling_price":10,"initial_quantity":5.125},{"name":"Measured cloth","unit":"metre","selling_price":2,"initial_quantity":1.5}]')=:'imported'::jsonb,'bulk retry exact identities');
select pg_temp.reject(format('select public.import_trexven_catalog(%L,gen_random_uuid(),%L)',:'business','[{"name":"Rollback first","barcode":"B3-ROLLBACK"},{"name":"Duplicate second","barcode":"B3-BLUE"}]'),'23505','duplicate import rolls back');
select pg_temp.assert_true(not exists(select 1 from public.products where barcode='B3-ROLLBACK'),'no partial import rows');
select (:'imported'::jsonb->>0) as oil \gset
select pg_temp.assert_true(not exists(select 1 from public.alerts where reference_id=:'oil' and alert_type='low_stock'),'import alerts reflect final stock, not intermediate zero');
select public.import_trexven_catalog(:'business',gen_random_uuid(),'[{"name":"Small green","group_name":"Grouped import","size":"S","color":"Green","selling_price":5},{"name":"Large green","group_name":"Grouped import","size":"L","color":"Green","selling_price":6}]');
select pg_temp.assert_true((select count(*) from public.products p join public.product_groups g on g.id=p.catalog_group_id where g.business_id=:'business' and g.name='Grouped import')=2,'bulk variants share one group');
select public.import_trexven_catalog(:'business',gen_random_uuid(),'[{"name":"Valid free product","selling_price":0,"initial_quantity":2}]')::text as free_ids \gset
select pg_temp.assert_true((public.submit_trexven_sale(gen_random_uuid(),:'business',null,0,'cash',jsonb_build_array(jsonb_build_object('product_id',:'free_ids'::jsonb->>0,'quantity',1,'unit_price',0,'discount',0)),true)->>'total')::numeric=0,'existing explicit zero price remains sellable');
select gen_random_uuid()::text as sale_request \gset
select jsonb_build_array(jsonb_build_object('product_id',:'oil','quantity',0.125,'unit_price',10,'discount',0))::text as items \gset
select public.submit_trexven_sale(:'sale_request',:'business',null,1.25,'cash',:'items',true)::text as receipt \gset
select pg_temp.assert_true(public.submit_trexven_sale(:'sale_request',:'business',null,1.25,'cash',:'items',true)=:'receipt'::jsonb,'fractional receipt replay unchanged');
select pg_temp.assert_true((select quantity from public.products where id=:'oil')=5,'precise stock deduction');
select pg_temp.assert_true((select count(*) from public.inventory_movements where product_id=:'oil' and movement_type='sale' and reference_id=(:'receipt'::jsonb->>'id')::uuid)=1,'sale movement references receipt sale');
select pg_temp.fails(format('select public.submit_trexven_sale(gen_random_uuid(),%L,null,0,''cash'',%L,true)',:'business',jsonb_build_array(jsonb_build_object('product_id',:'pending','quantity',1,'unit_price',0,'discount',0))));
select public.save_trexven_catalog_product(:'business',gen_random_uuid(),:'variant','{"active":false}');
select pg_temp.assert_true((select not active and not is_active from public.products where id=:'variant'),'archive keeps product identity');
select pg_temp.fails(format('select public.submit_trexven_sale(gen_random_uuid(),%L,null,21,''cash'',%L,true)',:'business',jsonb_build_array(jsonb_build_object('product_id',:'variant','quantity',1,'unit_price',21,'discount',0))));
select pg_temp.denied(format('delete from public.inventory_movements where product_id=%L',:'oil'));
select public.adjust_trexven_catalog_stock(:'business',:'oil',-5,'Depleted stock test',gen_random_uuid());
select set_config('request.jwt.claim.sub',(select id::text from batch2_ids where key='inventory_user'),true);
select pg_temp.fails(format('update public.products set unit=''kg'' where id=%L',:'oil'));
select pg_temp.denied(format('insert into public.products(business_id,name,low_stock_threshold) values(%L,''Forged threshold'',999)',:'business'));
select set_config('request.jwt.claim.sub','',true);
select pg_temp.denied(format('select public.save_trexven_catalog_product(%L,gen_random_uuid(),null,''{"name":"Missing auth"}'')',:'business'));
reset role;
select 'BATCH_3_CATALOG_INVENTORY_COMPLETED';
