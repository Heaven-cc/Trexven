-- Deferred. All commercial values below are synthetic test configuration only.
set local role authenticated;
select id::text as business from batch2_ids where key='business' \gset
select id::text as owner from batch2_ids where key='owner' \gset
select id::text as seller from batch2_ids where key='sales_user' \gset
select pg_temp.assert_true((select count(*)=3 from public.subscription_plans),'approved three plans');
select pg_temp.assert_true((select bool_and(price is null and employee_limit is null and camera_limit is null and trial_days is null and grace_days is null) from public.subscription_plans),'no invented commercial configuration');
select pg_temp.assert_true(not (public.get_trexven_entitlements(:'business')->>'enforced')::boolean,'legacy business not silently enrolled');
select pg_temp.assert_true(not has_function_privilege('authenticated','public.record_verified_trexven_billing_event(text,text,uuid,text,numeric,text,text)','EXECUTE'),'clients cannot confirm billing');
select pg_temp.fails(format('select public.request_trexven_billing_session(%L,gen_random_uuid(),''start'')',:'business'));
select set_config('request.jwt.claim.sub',:'seller',true);
select pg_temp.denied(format('select public.request_trexven_subscription_change(%L,gen_random_uuid(),''change_plan'',''pro'')',:'business'));
select set_config('request.jwt.claim.sub',:'owner',true);
reset role;
select public.apply_verified_trexven_subscription(:'business','synthetic-active-expired','start','active',now()-interval '2 days',now()-interval '1 day',null,now()+interval '1 day',0,true);
set local role authenticated;
select pg_temp.assert_true(public.get_trexven_entitlements(:'business')->>'status'='expired','active expiry is not extended by unused grace');
select pg_temp.denied(format('select public.require_trexven_feature(%L,''pos'')',:'business'));
reset role;
select public.apply_verified_trexven_subscription(:'business','synthetic-grace','start','past_due',now()-interval '2 days',now()-interval '1 day',null,now()+interval '1 day',1,true);
set local role authenticated;
select pg_temp.assert_true(public.require_trexven_feature(:'business','pos'),'configured past-due grace grants its approved feature');
select pg_temp.denied(format('select public.require_trexven_feature(%L,''advanced_inventory'')',:'business'));
select public.request_trexven_account_lifecycle(:'business',gen_random_uuid(),'deletion','Synthetic reviewed deletion request');
select pg_temp.assert_true((select count(*)=1 from public.businesses where id=:'business'),'deletion request retains business');
select pg_temp.assert_true((select count(*)=1 from public.products where business_id=:'business'),'deletion request retains inventory');
select pg_temp.assert_true((public.get_trexven_operational_health(:'business')->'latest_backup')='null'::jsonb,'metadata absence is not claimed as verified backup');
reset role;
update public.subscription_plans set price=1,currency='NGN',interval_months=1 where id='start';
insert into private.billing_provider_configuration(provider,enabled) values('synthetic',true);
set local role authenticated;
select public.request_trexven_billing_session(:'business',gen_random_uuid(),'start')->>'id' as billing_session \gset
reset role;
select public.attach_trexven_billing_provider_session(:'billing_session','synthetic','synthetic-provider-session');
select pg_temp.fails(format('select public.record_verified_trexven_billing_event(''synthetic'',''wrong-amount'',%L,''payment-1'',2,''NGN'',''verified'')',:'billing_session'));
select public.record_verified_trexven_billing_event('synthetic','event-failed',:'billing_session','payment-1',1,'NGN','failed');
select pg_temp.assert_true((select count(*)=0 from public.billing_invoices where business_id=:'business'),'failed payment creates no invoice');
select public.record_verified_trexven_billing_event('synthetic','event-verified',:'billing_session','payment-1',1,'NGN','verified');
select public.record_verified_trexven_billing_event('synthetic','event-verified',:'billing_session','payment-1',1,'NGN','verified');
select public.record_verified_trexven_billing_event('synthetic','event-duplicate',:'billing_session','payment-1',1,'NGN','verified');
select pg_temp.assert_true((select count(*)=1 from public.billing_payments where business_id=:'business'),'failed-to-verified uses one payment identity');
select pg_temp.assert_true((select count(*)=1 from public.billing_invoices where business_id=:'business'),'duplicate webhook/payment creates one invoice');
select pg_temp.fails(format('select public.record_verified_trexven_billing_event(''synthetic'',''event-verified'',%L,''payment-1'',1,''USD'',''verified'')',:'billing_session'));
