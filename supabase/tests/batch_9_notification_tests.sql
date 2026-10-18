set local role authenticated;
select id::text as business from batch2_ids where key='business' \gset
select id::text as owner from batch2_ids where key='owner' \gset
select id::text as seller from batch2_ids where key='sales_user' \gset
select id::text as inventory from batch2_ids where key='inventory_user' \gset
select id::text as other_business from batch2_ids where key='other_business' \gset
select pg_temp.assert_true(jsonb_typeof(public.get_trexven_notifications(:'business','owner'))='array','owner notification access');
select pg_temp.fails(format('select public.get_trexven_notifications(%L,null)',:'business'));
select pg_temp.fails(format('select public.get_trexven_notifications(%L,''forged'')',:'business'));
select pg_temp.fails('select public.get_trexven_notifications(null)');
select pg_temp.fails(format('select public.get_trexven_notifications(%L)',:'other_business'));
reset role;
select gen_random_uuid()::text as alert_id \gset
insert into public.alerts(id,business_id,alert_type,title,message,severity,source) values(:'alert_id',:'business','low_stock','Synthetic low stock','Synthetic product only','warning','inventory');
insert into public.alerts(business_id,alert_type,title,message,severity,source) values(:'business','camera_motion','Synthetic Vision','Owner-only evidence','warning','vision');
set local role authenticated;
select pg_temp.assert_true(jsonb_array_length(public.get_trexven_notifications(:'business','owner'))=2,'owner sees permitted inventory and Vision evidence');
select public.mark_trexven_notification_read(:'business','alert:'||:'alert_id',true,'owner');
select pg_temp.assert_true((select count(*)=1 from public.trexven_notification_reads),'owner acknowledgement is personal');
select set_config('request.jwt.claim.sub',:'inventory',true);
select pg_temp.assert_true(jsonb_array_length(public.get_trexven_notifications(:'business'))=1,'inventory sees stock and never Vision');
select pg_temp.assert_true(public.get_trexven_notifications(:'business')->0->>'read_at' is null,'another employee does not inherit owner read status');
select public.mark_trexven_notification_read(:'business','alert:'||:'alert_id',true);
select pg_temp.assert_true((select count(*)=1 from public.trexven_notification_reads),'read RLS hides other users');
select pg_temp.fails(format('select public.get_trexven_notifications(%L,''owner'')',:'business'));
select pg_temp.fails(format('select public.mark_trexven_notification_read(%L,''forged'',true)',:'business'));
select pg_temp.fails(format('insert into public.trexven_notification_reads values(%L,%L,''forged'',now())',:'business',:'owner'));
select set_config('request.jwt.claim.sub',:'seller',true);
select pg_temp.assert_true(jsonb_array_length(public.get_trexven_notifications(:'business'))=0,'sales employee does not receive inventory/admin/Vision alerts');
select pg_temp.fails(format('select public.mark_trexven_notification_read(%L,%L,true)',:'business','alert:'||:'alert_id'));
select set_config('request.jwt.claim.sub',:'owner',true);
select public.set_trexven_employee_permission((select id from public.employees where user_id=:'inventory' and business_id=:'business'),'view_inventory',false);
select set_config('request.jwt.claim.sub',:'inventory',true);
select pg_temp.assert_true(jsonb_array_length(public.get_trexven_notifications(:'business'))=0,'notification revocation takes effect without token refresh');
select set_config('request.jwt.claim.sub','',true);
select pg_temp.fails(format('select public.get_trexven_notifications(%L)',:'business'));
