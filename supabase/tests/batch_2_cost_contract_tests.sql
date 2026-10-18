begin;
\ir batch_2_fixture.sql
select pg_temp.assert_true(not has_column_privilege('authenticated','public.products','cost_price','SELECT'),'deferred cost SELECT revoked');
select pg_temp.assert_true(not has_column_privilege('authenticated','public.products','cost_price','INSERT'),'deferred cost INSERT revoked');
select pg_temp.assert_true(not has_column_privilege('authenticated','public.products','cost_price','UPDATE'),'deferred cost UPDATE revoked');
select pg_temp.assert_true((select cost_price=0 from public.products where id=(select id from batch2_ids where key='product')),'historical default retained');
insert into public.audit_logs(business_id,actor_id,action,metadata) values
 ((select id from batch2_ids where key='business'),(select id from batch2_ids where key='owner'),'synthetic_legacy_cost','{"before":{"cost_price":91},"after":{"selling_price":10}}');
select set_config('request.jwt.claim.sub',(select id::text from batch2_ids where key='owner'),true);
set local role authenticated;
select pg_temp.denied('select cost_price from public.products');
select pg_temp.denied('select * from public.products');
select pg_temp.denied(format('update public.products set cost_price=999 where id=%L',(select id from batch2_ids where key='product')));
select pg_temp.assert_true((select count(*)=0 from public.audit_logs where action='synthetic_legacy_cost'),'legacy cost audit hidden without rewriting');
update public.products set selling_price=11 where id=(select id from batch2_ids where key='product');
select pg_temp.assert_true((select count(*)>0 from public.audit_logs where action='product_price_changed'),'selling price audit retained');
select pg_temp.assert_true((select count(*)=0 from public.audit_logs where action='product_price_changed' and jsonb_path_exists(metadata,'$.**.cost_price')),'new audit excludes deferred cost');
reset role;
select pg_temp.assert_true((select count(*)=1 from public.audit_logs where action='synthetic_legacy_cost'),'legacy audit retained for trusted recovery');
rollback;
