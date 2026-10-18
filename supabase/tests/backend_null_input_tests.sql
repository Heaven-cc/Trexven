-- Runner supplies an empty, synthetic database fixture and outer rollback.
-- Before repair, backend.audit_expect_rejection=false proves the defects.
-- After repair, the same inputs must fail and leave every row/receipt unchanged.
create function pg_temp.validation_probe(statement text,label text,expected boolean default null) returns void
language plpgsql as $$
declare rejected boolean:=false;
begin
 begin
  execute statement;
  -- Undo even a successful reproduction, including its operation receipt.
  raise exception using errcode='ZX001',message='Undo successful probe';
 exception
  when sqlstate 'ZX001' then rejected:=false;
  when raise_exception or invalid_parameter_value then rejected:=true;
 end;
 perform pg_temp.assert_true(rejected=coalesce(expected,current_setting('backend.audit_expect_rejection')::boolean),label);
end $$;
set local role authenticated;
select id::text as business from batch2_ids where key='business' \gset
select id::text as product from batch2_ids where key='product' \gset
select id::text as member from public.business_members where business_id=:'business' and user_id=auth.uid() \gset
select public.start_trexven_stocktake(:'business',gen_random_uuid(),'Null validation count')->>'id' as session \gset
select pg_temp.validation_probe(format('select public.count_trexven_stock(%L,gen_random_uuid(),null)',:'session'),'SQL NULL bulk count');
select pg_temp.assert_true((select bool_and(counted is null and version=0) from public.stocktake_counts where session_id=:'session'),'count probe preserves versions and quantities');

select jsonb_build_array(jsonb_build_object('product_id',:'product','quantity',2,'unit_price',10,'discount',0))::text as items \gset
select '{"debtor_name":"Synthetic validation debtor","contact":"Synthetic contact","due_date":"2099-01-01"}'::text as credit \gset
select gen_random_uuid()::text as null_payment_request \gset
select jsonb_build_object('member',:'member','total',20,'items',:'items'::jsonb,'payments',null,'credit',:'credit'::jsonb,'branch',null,'shift',null)::text as null_draft \gset
select public.request_trexven_credit_approval(:'business',:'null_payment_request',:'null_draft')::text as null_approval \gset
select public.decide_trexven_credit_approval(:'null_approval',true);
select (:'credit'::jsonb||jsonb_build_object('approval_id',:'null_approval'))::text as null_credit \gset
select pg_temp.validation_probe(format('select public.complete_trexven_transaction(%L,%L,%L,20,%L,null,%L)',:'null_payment_request',:'business',:'member',:'items',:'null_credit'),'SQL NULL payment collection');
select pg_temp.assert_true((select quantity=100 from public.products where id=:'product'),'null payment probe preserves stock');

select '[{"method":"cash","amount":5,"confirmed":true}]'::text as payments \gset
select gen_random_uuid()::text as request \gset
select jsonb_build_object('member',:'member','total',20,'items',:'items'::jsonb,'payments',:'payments'::jsonb,'credit',:'credit'::jsonb,'branch',null,'shift',null)::text as draft \gset
select public.request_trexven_credit_approval(:'business',:'request',:'draft')::text as approval \gset
select public.decide_trexven_credit_approval(:'approval',true);
select public.complete_trexven_transaction(:'request',:'business',:'member',20,:'items',:'payments',:'credit'::jsonb||jsonb_build_object('approval_id',:'approval'))->>'id' as sale \gset
select pg_temp.validation_probe(format('select public.repay_trexven_credit(%L,gen_random_uuid(),1,null,true)',:'sale'),'SQL NULL repayment method');
select pg_temp.assert_true((select outstanding=15 from public.credit_accounts where sale_id=:'sale'),'repayment probe preserves debt');
select pg_temp.validation_probe(format('select public.request_trexven_return(%L,gen_random_uuid(),null,''Synthetic return'')',:'sale'),'SQL NULL return collection');
select id::text as sale_item from public.sale_items where sale_id=:'sale' \gset
select public.request_trexven_return(:'sale',gen_random_uuid(),jsonb_build_array(jsonb_build_object('sale_item_id',:'sale_item','quantity',1)),'Synthetic validation return')::text as return_id \gset
select pg_temp.validation_probe(format('select public.inspect_trexven_return(%L,gen_random_uuid(),null)',:'return_id'),'SQL NULL inspection collection');
select pg_temp.validation_probe(format('select public.inspect_trexven_return(%L,gen_random_uuid(),%L)',:'return_id',jsonb_build_array(jsonb_build_object('sale_item_id',:'sale_item'))::text),'missing inspection condition');
select pg_temp.assert_true((select status='requested' from public.sale_returns where id=:'return_id'),'inspection probes preserve review state');

-- A real refund has no unpaid debt; missing method must never settle it.
select jsonb_build_array(jsonb_build_object('product_id',:'product','quantity',1,'unit_price',10,'discount',0))::text as paid_items \gset
select public.complete_trexven_transaction(gen_random_uuid(),:'business',:'member',10,:'paid_items','[{"method":"cash","amount":10,"confirmed":true}]')->>'id' as paid_sale \gset
select id::text as paid_item from public.sale_items where sale_id=:'paid_sale' \gset
select public.request_trexven_return(:'paid_sale',gen_random_uuid(),jsonb_build_array(jsonb_build_object('sale_item_id',:'paid_item','quantity',1)),'Synthetic refund')::text as paid_return \gset
select public.inspect_trexven_return(:'paid_return',gen_random_uuid(),jsonb_build_array(jsonb_build_object('sale_item_id',:'paid_item','condition','sellable')));
select pg_temp.validation_probe(format('select public.approve_trexven_return(%L,gen_random_uuid(),null,true)',:'paid_return'),'existing refund collection guard rejects NULL method',true);
select pg_temp.assert_true((select status='inspected' from public.sale_returns where id=:'paid_return'),'refund probe preserves inspection and money');

-- Genuine unchanged frontend bulk payload: product/version/quantity string.
select public.manage_trexven_stocktake(:'session',gen_random_uuid(),'cancel',p_reason=>'Synthetic probe complete');
select public.import_trexven_catalog(:'business',gen_random_uuid(),'[{"name":"Second synthetic barcode","barcode":"AUDIT-SECOND","selling_price":10,"initial_quantity":20}]')->>0 as second_product \gset
select public.start_trexven_stocktake(:'business',gen_random_uuid(),'Valid bulk count')->>'id' as bulk_session \gset
select gen_random_uuid()::text as bulk_key \gset
select jsonb_build_array(jsonb_build_object('product_id',:'product','version',0,'quantity','96'),jsonb_build_object('product_id',:'second_product','version',0,'quantity','19'))::text as bulk_counts \gset
select public.count_trexven_stock(:'bulk_session',:'bulk_key',:'bulk_counts')::text as bulk_receipt \gset
select pg_temp.assert_true(:'bulk_receipt'::jsonb='{"counted":2}'::jsonb,'bulk response remains unchanged');
select pg_temp.assert_true(public.count_trexven_stock(:'bulk_session',:'bulk_key',:'bulk_counts')=:'bulk_receipt'::jsonb,'bulk retry returns original receipt');
select pg_temp.assert_true((select count(*)=2 and bool_and(version=1 and counted is not null) from public.stocktake_counts where session_id=:'bulk_session'),'bulk retry persists every line once');
select pg_temp.fails(format('select public.count_trexven_stock(%L,gen_random_uuid(),%L)',:'bulk_session',jsonb_build_array(jsonb_build_object('product_id',:'product','version',1,'quantity','95'),jsonb_build_object('product_id',:'second_product','version',0,'quantity','18'))::text));
select pg_temp.assert_true((select bool_and(version=1) from public.stocktake_counts where session_id=:'bulk_session'),'invalid bulk line rolls back every version');
select pg_temp.assert_true((select counted=96 from public.stocktake_counts where session_id=:'bulk_session' and product_id=:'product'),'invalid bulk line never partially persists');
