-- Deferred. No external project or customer data; outer transaction rolls back.
set local role authenticated;
select id::text as business from batch2_ids where key='business' \gset
select id::text as owner from batch2_ids where key='owner' \gset
select id::text as seller from batch2_ids where key='sales_user' \gset
select id::text as clerk from batch2_ids where key='inventory_user' \gset
select id::text as product from batch2_ids where key='product' \gset
select id::text as seller_member from batch2_ids where key='sales_member' \gset
select id::text as owner_member from public.business_members where business_id=:'business' and user_id=:'owner' \gset
select public.set_trexven_employee_permission((select id from batch2_ids where key='sales'),'cash_shifts',true);
select public.configure_trexven_register(:'business',gen_random_uuid(),'Synthetic drawer',array[:'owner_member'::uuid,:'seller_member'::uuid])->>'id' as register \gset
select public.open_trexven_cash_shift(:'register',gen_random_uuid(),20)->>'id' as shift \gset
select set_config('request.jwt.claim.sub',:'seller',true);
select public.join_trexven_cash_shift(:'shift',gen_random_uuid());
select pg_temp.assert_true((select count(*)=2 from public.cash_shift_members where shift_id=:'shift'),'multiple employees share one drawer');
select public.submit_trexven_sale(gen_random_uuid(),:'business',:'seller_member',10,'cash',jsonb_build_array(jsonb_build_object('product_id',:'product','quantity',1,'unit_price',10,'discount',0)),false);
select pg_temp.assert_true((select sum(amount)=10 from public.cash_events where shift_id=:'shift'),'legacy checkout records final amount rather than initial zero');
select pg_temp.assert_true((public.get_trexven_cash_context(:'business')->'shifts'->0->>'expected_current')::numeric=30,'trusted exact cash total');
select set_config('request.jwt.claim.sub',:'clerk',true);
select pg_temp.assert_true((public.get_trexven_cash_context(:'business')->>'configured')::boolean,'unassigned employee cannot infer absent register from RLS');
select pg_temp.assert_true(jsonb_array_length(public.get_trexven_cash_context(:'business')->'shifts')=0,'unassigned drawer details hidden');
select pg_temp.denied(format('select public.join_trexven_cash_shift(%L,gen_random_uuid())',:'shift'));
select set_config('request.jwt.claim.sub',:'owner',true);
select pg_temp.fails(format('select public.force_close_trexven_cash_shift(%L,gen_random_uuid(),30,''Recovery'',false)',:'shift'));
select gen_random_uuid()::text as close_key \gset
select public.force_close_trexven_cash_shift(:'shift',:'close_key',29,'Physical shortage; retained pending requests',true);
select public.force_close_trexven_cash_shift(:'shift',:'close_key',29,'Physical shortage; retained pending requests',true);
select pg_temp.assert_true((select expected_at_close=30 and counted_amount=29 and difference_at_close=-1 from public.cash_shifts where id=:'shift'),'immutable actual closure and shortage');
select pg_temp.denied(format('update public.cash_shifts set counted_amount=30 where id=%L',:'shift'));
reset role;
update public.employees set status='suspended' where id=(select id from batch2_ids where key='sales');
select set_config('request.jwt.claim.sub',:'seller',true);
set local role authenticated;
select pg_temp.denied(format('select public.get_trexven_cash_context(%L)',:'business'));
