-- Included after the synthetic B2 fixture; transaction always rolls back.
set local role authenticated;
select id::text as business from batch2_ids where key='business' \gset
select id::text as product from batch2_ids where key='product' \gset
select id::text as owner from batch2_ids where key='owner' \gset
select id::text as seller from batch2_ids where key='sales_user' \gset
select id::text as manager from batch2_ids where key='manager_user' \gset
select id::text as seller_member from batch2_ids where key='sales_member' \gset
select id::text as owner_member from public.business_members where business_id=:'business' and user_id=:'owner' \gset
select jsonb_build_array(jsonb_build_object('product_id',:'product','quantity',2,'unit_price',10,'discount',0))::text as items \gset
select jsonb_build_array(jsonb_build_object('method','cash','amount',5,'confirmed',true))::text as payments \gset
select jsonb_build_object('debtor_name','Synthetic debtor','contact','Synthetic contact','due_date',(current_date+1)::text)::text as credit \gset
select gen_random_uuid()::text as request \gset
select jsonb_build_object('member',:'owner_member','total',20,'items',:'items'::jsonb,'payments',:'payments'::jsonb,'credit',:'credit'::jsonb,'branch',null,'shift',null)::text as draft \gset
select public.request_trexven_credit_approval(:'business',:'request',:'draft')::text as approval \gset
select pg_temp.fails(format('select public.complete_trexven_transaction(%L,%L,%L,20,%L,%L,%L)',:'request',:'business',:'owner_member',:'items',:'payments',(:'credit'::jsonb||jsonb_build_object('approval_id',:'approval'))::text));
select public.decide_trexven_credit_approval(:'approval',true);
select public.complete_trexven_transaction(:'request',:'business',:'owner_member',20,:'items',:'payments',:'credit'::jsonb||jsonb_build_object('approval_id',:'approval'))::text as receipt \gset
select :'receipt'::jsonb->>'id' as sale \gset
select pg_temp.assert_true((select outstanding=15 from public.credit_accounts where sale_id=:'sale'),'only actual unpaid amount becomes debt');
select pg_temp.assert_true(public.complete_trexven_transaction(:'request',:'business',:'owner_member',20,:'items',:'payments',:'credit'::jsonb||jsonb_build_object('approval_id',:'approval'))=:'receipt'::jsonb,'exact retry returns same receipt');
select pg_temp.assert_true((select quantity=98 from public.products where id=:'product'),'duplicate retry deducts stock once');
select gen_random_uuid()::text as repayment \gset
select public.repay_trexven_credit(:'sale',:'repayment',3,'cash',true);
select public.repay_trexven_credit(:'sale',:'repayment',3,'cash',true);
select pg_temp.assert_true((select outstanding=12 from public.credit_accounts where sale_id=:'sale'),'partial repayment replay is once');
select pg_temp.fails(format('select public.repay_trexven_credit(%L,gen_random_uuid(),13,''cash'',true)',:'sale'));
select pg_temp.fails(format('select public.repay_trexven_credit(%L,gen_random_uuid(),1,''bank_transfer'',false,''Screenshot'')',:'sale'));
select id::text as sale_item from public.sale_items where sale_id=:'sale' \gset
select public.request_trexven_return(:'sale',gen_random_uuid(),jsonb_build_array(jsonb_build_object('sale_item_id',:'sale_item','quantity',1)),'Inspected synthetic return')::text as return1 \gset
select pg_temp.fails(format('select public.approve_trexven_return(%L,gen_random_uuid(),''cash'',true)',:'return1'));
select public.inspect_trexven_return(:'return1',gen_random_uuid(),jsonb_build_array(jsonb_build_object('sale_item_id',:'sale_item','condition','sellable')));
select gen_random_uuid()::text as approve_return1 \gset
select public.approve_trexven_return(:'return1',:'approve_return1','cash',false)::text as return_receipt1 \gset
select pg_temp.assert_true((:'return_receipt1'::jsonb->>'debt_reduction')::numeric=10 and (:'return_receipt1'::jsonb->>'refund')::numeric=0,'return reduces debt before actual refund');
select public.approve_trexven_return(:'return1',:'approve_return1','cash',false);
select pg_temp.assert_true((select quantity=99 from public.products where id=:'product'),'sellable inspected quantity restocked once');
select public.repay_trexven_credit(:'sale',gen_random_uuid(),2,'cash',true);
select pg_temp.assert_true((select outstanding=0 from public.credit_accounts where sale_id=:'sale'),'full settlement');
select public.request_trexven_return(:'sale',gen_random_uuid(),jsonb_build_array(jsonb_build_object('sale_item_id',:'sale_item','quantity',1)),'Damaged return')::text as return2 \gset
select public.inspect_trexven_return(:'return2',gen_random_uuid(),jsonb_build_array(jsonb_build_object('sale_item_id',:'sale_item','condition','damaged')));
select public.approve_trexven_return(:'return2',gen_random_uuid(),'cash',true)::text as return_receipt2 \gset
select pg_temp.assert_true((:'return_receipt2'::jsonb->>'refund')::numeric=10,'refund limited to original actual cash and repayments');
select pg_temp.assert_true((select quantity=99 from public.products where id=:'product'),'damaged returns do not enter sellable stock');
select pg_temp.assert_true((select count(*)=1 from public.sales where id=:'sale'),'refund never erases original sale');
select public.request_trexven_return(:'sale',gen_random_uuid(),jsonb_build_array(jsonb_build_object('sale_item_id',:'sale_item','quantity',1)),'Too many')::text as return3 \gset
select public.inspect_trexven_return(:'return3',gen_random_uuid(),jsonb_build_array(jsonb_build_object('sale_item_id',:'sale_item','condition','sellable')));
select pg_temp.fails(format('select public.approve_trexven_return(%L,gen_random_uuid(),''cash'',true)',:'return3'));
select pg_temp.denied(format('update public.credit_accounts set outstanding=0 where sale_id=%L',:'sale'));
select pg_temp.denied(format('delete from public.sales where id=%L',:'sale'));
select set_config('request.jwt.claim.sub',:'seller',true);
select pg_temp.denied(format('select public.decide_trexven_credit_approval(%L,true)',:'approval'));
select pg_temp.denied(format('select public.approve_trexven_return(%L,gen_random_uuid(),''cash'',true)',:'return3'));
select pg_temp.denied(format('select public.repay_trexven_credit(%L,gen_random_uuid(),1,''cash'',true)',:'sale'));
select set_config('request.jwt.claim.sub',:'manager',true);
select pg_temp.denied(format('select public.decide_trexven_credit_approval(%L,true)',:'approval'));
select set_config('request.jwt.claim.sub',:'owner',true);
select pg_temp.fails(format('select public.complete_trexven_transaction(gen_random_uuid(),%L,%L,20,%L,''[{"method":"bank_transfer","amount":20,"confirmed":false,"evidence":"Screenshot"}]'')',:'business',:'owner_member',:'items'));
select public.set_trexven_credit_limit(:'business',0);
select gen_random_uuid()::text as request2 \gset
select public.request_trexven_credit_approval(:'business',:'request2',:'draft')::text as approval2 \gset
select public.decide_trexven_credit_approval(:'approval2',true);
select pg_temp.fails(format('select public.complete_trexven_transaction(%L,%L,%L,20,%L,%L,%L)',:'request2',:'business',:'owner_member',:'items',:'payments',(:'credit'::jsonb||jsonb_build_object('approval_id',:'approval2'))::text));
select public.get_trexven_financial_summary(:'business',now()-interval '1 day',now()+interval '1 day')::text as summary \gset
select pg_temp.assert_true((:'summary'::jsonb->>'receivables')::numeric=0 and (:'summary'::jsonb->>'refunds')::numeric=10,'financial summary separates debt reduction from money refunded');
