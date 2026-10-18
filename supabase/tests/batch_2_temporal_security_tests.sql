begin;
\ir batch_2_fixture.sql
set local role authenticated;
update public.businesses set timezone='America/New_York' where id=(select id from batch2_ids where key='business');
select set_config('request.jwt.claim.sub',(select id::text from batch2_ids where key='sales_user'),true);
select pg_temp.assert_true(private.sales_history_access((select id from batch2_ids where key='business'),date_trunc('day',current_timestamp at time zone 'America/New_York') at time zone 'America/New_York'),'business-local midnight visible');
select pg_temp.assert_true(not private.sales_history_access((select id from batch2_ids where key='business'),(date_trunc('day',current_timestamp at time zone 'America/New_York') at time zone 'America/New_York')-interval '1 microsecond'),'previous local day excluded');
select pg_temp.assert_true(not private.sales_history_access((select id from batch2_ids where key='business'),(date_trunc('day',current_timestamp at time zone 'America/New_York')+interval '1 day') at time zone 'America/New_York'),'next local day excluded');
select pg_temp.assert_true(extract(hour from timestamptz '2026-03-08 06:59:59+00' at time zone 'America/New_York')=1,'DST spring before gap');
select pg_temp.assert_true(extract(hour from timestamptz '2026-03-08 07:00:00+00' at time zone 'America/New_York')=3,'DST spring after gap');
select pg_temp.assert_true((timestamp '2026-03-09' at time zone 'America/New_York')-(timestamp '2026-03-08' at time zone 'America/New_York')=interval '23 hours','spring day is 23 hours');
select pg_temp.assert_true((timestamp '2026-11-02' at time zone 'America/New_York')-(timestamp '2026-11-01' at time zone 'America/New_York')=interval '25 hours','fall day is 25 hours');
select set_config('request.jwt.claim.sub',(select id::text from batch2_ids where key='owner'),true);
select pg_temp.denied(format('select public.set_trexven_employee_permission(%L,''override_price'',true)',(select id from batch2_ids where key='inventory')));
select pg_temp.assert_true(not has_table_privilege('authenticated','public.products','MAINTAIN'),'client maintenance removed');
select pg_temp.denied(format('update public.products set business_id=%L where id=%L',(select id from batch2_ids where key='other_business'),(select id from batch2_ids where key='product')));
reset role;
rollback;
