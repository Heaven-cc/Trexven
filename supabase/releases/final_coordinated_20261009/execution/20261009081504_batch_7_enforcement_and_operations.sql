begin;
-- Release history guard and history insert are in the SAME transaction as DDL.
select pg_advisory_xact_lock(hashtextextended('trexven:coordinated-release',0));
do $trexven_history_guard$ begin
 if (select array_agg(version order by version) from supabase_migrations.schema_migrations)
    is distinct from array['20260819180000','20260823100000','20261002014604','20261002015419','20261002123039','20261002124738','20261003224001','20261004025120','20261005004045','20261007215736','20261007215743','20261007215831','20261008002119','20261008020234','20261008021428','20261009003200','20261009070338','20261009070340','20261009075117','20261009075318','20261009075612','20261009075911','20261009080227','20261009080751','20261009080842','20261009081002']::text[] then
  raise exception 'TREXVEN predecessor history mismatch; no migration changes committed';
 end if;
end $trexven_history_guard$;

create table public.account_lifecycle_requests(id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),request_id uuid not null unique,requested_by uuid not null references auth.users(id),
 kind text not null check(kind in('deletion','recovery')),reason text not null,status text not null default 'requested' check(status in('requested','reviewing','resolved','rejected')),created_at timestamptz not null default now());
create table public.operational_backup_status(id uuid primary key default gen_random_uuid(),business_id uuid references public.businesses(id),artifact_id text not null,sha256 text not null check(sha256~'^[a-f0-9]{64}$'),
 captured_at timestamptz not null,recovery_checked_at timestamptz,status text not null check(status in('captured','recovery_verified','failed')),details_code text not null,check(status<>'recovery_verified' or recovery_checked_at is not null));
create table public.application_error_events(id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),actor_id uuid references auth.users(id),application text not null check(application in('owner','pos','backend')),error_code text not null,created_at timestamptz not null default now());
create index application_error_recent on public.application_error_events(business_id,created_at);
do $$ declare t text;begin
 foreach t in array array['account_lifecycle_requests','operational_backup_status','application_error_events'] loop
  execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select on public.%I to authenticated',t);
  execute format('create policy "Owner operations read" on public.%I for select to authenticated using(public.user_owns_business(business_id))',t);
 end loop;
end $$;
-- These triggers enforce current trusted subscriptions even for service-backed
-- employee creation. Legacy businesses remain unchanged until separately enrolled.
create function private.guard_subscription_employee() returns trigger language plpgsql security definer set search_path='' as $$
declare ceiling integer;
begin
 if tg_op='UPDATE' and (new.status<>'active' or (new.status=old.status and new.business_id=old.business_id)) then return new;end if;
 if new.status<>'active' then return new;end if;
 perform pg_advisory_xact_lock(hashtextextended(new.business_id::text||':subscription',0));
 if not private.subscription_entitled(new.business_id,'basic_employees') then raise exception 'Subscription does not permit employee activation';end if;
 select p.employee_limit into ceiling from public.business_subscriptions s join public.subscription_plans p on p.id=s.plan_id where s.business_id=new.business_id and s.enforce;
 if ceiling is not null and (select count(*) from public.employees where business_id=new.business_id and status='active' and id<>new.id)>=ceiling then raise exception 'Configured employee limit reached';end if;
 return new;
end $$;
revoke all on function private.guard_subscription_employee() from public,anon,authenticated;
create trigger batch_7_employee_entitlements before insert or update on public.employees for each row execute function private.guard_subscription_employee();
create function private.guard_subscription_product() returns trigger language plpgsql security definer set search_path='' as $$
begin
 -- Approved historical cash/returns settle safely after expiry. These contexts
 -- can only be set by the trusted, authenticated transaction implementations.
 if current_setting('trexven.catalog_operation',true) in('offline_cash','return') then return new;end if;
 if not private.subscription_entitled(new.business_id,'inventory') then raise exception 'Subscription inventory access expired';end if;
 if tg_op='UPDATE' and new.variant_attributes is distinct from old.variant_attributes and not private.subscription_entitled(new.business_id,'multiple_pricing') then raise exception 'Plan does not include advanced catalog features';end if;
 return new;
end $$;
revoke all on function private.guard_subscription_product() from public,anon,authenticated;
create trigger batch_7_product_entitlements before insert or update on public.products for each row execute function private.guard_subscription_product();
create function private.guard_subscription_sale() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if current_setting('trexven.catalog_operation',true)<>'offline_cash' or current_setting('trexven.catalog_operation',true) is null then
  if not private.subscription_entitled(new.business_id,'pos') then raise exception 'Subscription POS access expired';end if;
 end if;return new;
end $$;
revoke all on function private.guard_subscription_sale() from public,anon,authenticated;
create trigger batch_7_sale_entitlements before insert on public.sales for each row execute function private.guard_subscription_sale();
create function private.guard_subscription_permission() returns trigger language plpgsql security definer set search_path='' as $$
declare business uuid;
begin
 if not new.granted then return new;end if;
 select business_id into business from public.employees where id=new.employee_id;
 if not private.subscription_entitled(business,'employee_permissions') then raise exception 'Plan does not include custom employee permissions';end if;return new;
end $$;
revoke all on function private.guard_subscription_permission() from public,anon,authenticated;
create trigger batch_7_permission_entitlements before insert or update on public.employee_permissions for each row execute function private.guard_subscription_permission();
create function private.guard_advanced_inventory_session() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if not private.subscription_entitled(new.business_id,'advanced_inventory') then raise exception 'Plan does not include advanced inventory';end if;return new;
end $$;
revoke all on function private.guard_advanced_inventory_session() from public,anon,authenticated;
create trigger batch_7_stocktake_entitlements before insert or update on public.stocktake_sessions for each row execute function private.guard_advanced_inventory_session();
create trigger batch_7_condition_entitlements before insert on public.stock_condition_entries for each row execute function private.guard_advanced_inventory_session();
create function public.request_trexven_account_lifecycle(p_business_id uuid,p_request_id uuid,p_kind text,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare payload jsonb;prior jsonb;result jsonb;request uuid;
begin
 if not public.user_owns_business(p_business_id) then raise exception 'Verified owner required' using errcode='42501';end if;
 if p_kind not in('deletion','recovery') or nullif(btrim(p_reason),'') is null then raise exception 'Lifecycle request and reason required';end if;
 payload:=jsonb_build_object('operation','account_lifecycle','kind',p_kind,'reason',p_reason);prior:=private.operation_replay(p_business_id,p_request_id,payload);if prior is not null then return prior;end if;
 insert into public.account_lifecycle_requests(business_id,request_id,requested_by,kind,reason) values(p_business_id,p_request_id,auth.uid(),p_kind,p_reason) returning id into request;
 result:=jsonb_build_object('id',request,'status','requested','financial_records_preserved',true);
 insert into public.audit_logs(business_id,actor_id,action,metadata) values(p_business_id,auth.uid(),'account_lifecycle_requested',payload||result);
 perform private.operation_save(p_business_id,p_request_id,payload,result);return result;
end $$;
create function public.record_trexven_application_error(p_business_id uuid,p_application text,p_error_code text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.is_business_member(p_business_id) or p_error_code is null or p_error_code not in('OPERATION_UNCONFIRMED','OFFLINE_SYNC_UNCONFIRMED','ENCRYPTED_STORAGE_UNAVAILABLE','BILLING_REQUEST_UNCONFIRMED','CAMERA_EVIDENCE_REQUEST_FAILED') or p_application not in('owner','pos','backend') then raise exception 'Authorized fixed error code required' using errcode='42501';end if;
 -- Never accept arbitrary error messages, stack traces, credentials or payloads.
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':error',0));
 if (select count(*) from public.application_error_events where actor_id=auth.uid() and created_at>now()-interval '1 minute')>=20 then return;end if;
 insert into public.application_error_events(business_id,actor_id,application,error_code) values(p_business_id,auth.uid(),p_application,p_error_code);
end $$;
create function public.get_trexven_operational_health(p_business_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not public.user_owns_business(p_business_id) then raise exception 'Owner required' using errcode='42501';end if;
 return jsonb_build_object('failed_billing_events',(select count(*) from public.billing_payments where business_id=p_business_id and status='failed'),
 'pending_subscription_requests',(select count(*) from public.subscription_change_requests where business_id=p_business_id and status='pending'),
 'recent_application_errors',(select count(*) from public.application_error_events where business_id=p_business_id and created_at>now()-interval '1 day'),
 'latest_backup',(select jsonb_build_object('captured_at',captured_at,'status',status,'recovery_checked_at',recovery_checked_at) from public.operational_backup_status where business_id=p_business_id order by captured_at desc limit 1));
end $$;
revoke all on function public.request_trexven_account_lifecycle(uuid,uuid,text,text),public.record_trexven_application_error(uuid,text,text),public.get_trexven_operational_health(uuid) from public,anon;
grant execute on function public.request_trexven_account_lifecycle(uuid,uuid,text,text),public.record_trexven_application_error(uuid,text,text),public.get_trexven_operational_health(uuid) to authenticated;
grant insert,select,update on public.operational_backup_status to service_role;
insert into supabase_migrations.schema_migrations(version,name,statements) values ('20261009081504','batch_7_enforcement_and_operations',array[$trexven_release_source$begin;
create table public.account_lifecycle_requests(id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),request_id uuid not null unique,requested_by uuid not null references auth.users(id),
 kind text not null check(kind in('deletion','recovery')),reason text not null,status text not null default 'requested' check(status in('requested','reviewing','resolved','rejected')),created_at timestamptz not null default now());
create table public.operational_backup_status(id uuid primary key default gen_random_uuid(),business_id uuid references public.businesses(id),artifact_id text not null,sha256 text not null check(sha256~'^[a-f0-9]{64}$'),
 captured_at timestamptz not null,recovery_checked_at timestamptz,status text not null check(status in('captured','recovery_verified','failed')),details_code text not null,check(status<>'recovery_verified' or recovery_checked_at is not null));
create table public.application_error_events(id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),actor_id uuid references auth.users(id),application text not null check(application in('owner','pos','backend')),error_code text not null,created_at timestamptz not null default now());
create index application_error_recent on public.application_error_events(business_id,created_at);
do $$ declare t text;begin
 foreach t in array array['account_lifecycle_requests','operational_backup_status','application_error_events'] loop
  execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select on public.%I to authenticated',t);
  execute format('create policy "Owner operations read" on public.%I for select to authenticated using(public.user_owns_business(business_id))',t);
 end loop;
end $$;
-- These triggers enforce current trusted subscriptions even for service-backed
-- employee creation. Legacy businesses remain unchanged until separately enrolled.
create function private.guard_subscription_employee() returns trigger language plpgsql security definer set search_path='' as $$
declare ceiling integer;
begin
 if tg_op='UPDATE' and (new.status<>'active' or (new.status=old.status and new.business_id=old.business_id)) then return new;end if;
 if new.status<>'active' then return new;end if;
 perform pg_advisory_xact_lock(hashtextextended(new.business_id::text||':subscription',0));
 if not private.subscription_entitled(new.business_id,'basic_employees') then raise exception 'Subscription does not permit employee activation';end if;
 select p.employee_limit into ceiling from public.business_subscriptions s join public.subscription_plans p on p.id=s.plan_id where s.business_id=new.business_id and s.enforce;
 if ceiling is not null and (select count(*) from public.employees where business_id=new.business_id and status='active' and id<>new.id)>=ceiling then raise exception 'Configured employee limit reached';end if;
 return new;
end $$;
revoke all on function private.guard_subscription_employee() from public,anon,authenticated;
create trigger batch_7_employee_entitlements before insert or update on public.employees for each row execute function private.guard_subscription_employee();
create function private.guard_subscription_product() returns trigger language plpgsql security definer set search_path='' as $$
begin
 -- Approved historical cash/returns settle safely after expiry. These contexts
 -- can only be set by the trusted, authenticated transaction implementations.
 if current_setting('trexven.catalog_operation',true) in('offline_cash','return') then return new;end if;
 if not private.subscription_entitled(new.business_id,'inventory') then raise exception 'Subscription inventory access expired';end if;
 if tg_op='UPDATE' and new.variant_attributes is distinct from old.variant_attributes and not private.subscription_entitled(new.business_id,'multiple_pricing') then raise exception 'Plan does not include advanced catalog features';end if;
 return new;
end $$;
revoke all on function private.guard_subscription_product() from public,anon,authenticated;
create trigger batch_7_product_entitlements before insert or update on public.products for each row execute function private.guard_subscription_product();
create function private.guard_subscription_sale() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if current_setting('trexven.catalog_operation',true)<>'offline_cash' or current_setting('trexven.catalog_operation',true) is null then
  if not private.subscription_entitled(new.business_id,'pos') then raise exception 'Subscription POS access expired';end if;
 end if;return new;
end $$;
revoke all on function private.guard_subscription_sale() from public,anon,authenticated;
create trigger batch_7_sale_entitlements before insert on public.sales for each row execute function private.guard_subscription_sale();
create function private.guard_subscription_permission() returns trigger language plpgsql security definer set search_path='' as $$
declare business uuid;
begin
 if not new.granted then return new;end if;
 select business_id into business from public.employees where id=new.employee_id;
 if not private.subscription_entitled(business,'employee_permissions') then raise exception 'Plan does not include custom employee permissions';end if;return new;
end $$;
revoke all on function private.guard_subscription_permission() from public,anon,authenticated;
create trigger batch_7_permission_entitlements before insert or update on public.employee_permissions for each row execute function private.guard_subscription_permission();
create function private.guard_advanced_inventory_session() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if not private.subscription_entitled(new.business_id,'advanced_inventory') then raise exception 'Plan does not include advanced inventory';end if;return new;
end $$;
revoke all on function private.guard_advanced_inventory_session() from public,anon,authenticated;
create trigger batch_7_stocktake_entitlements before insert or update on public.stocktake_sessions for each row execute function private.guard_advanced_inventory_session();
create trigger batch_7_condition_entitlements before insert on public.stock_condition_entries for each row execute function private.guard_advanced_inventory_session();
create function public.request_trexven_account_lifecycle(p_business_id uuid,p_request_id uuid,p_kind text,p_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare payload jsonb;prior jsonb;result jsonb;request uuid;
begin
 if not public.user_owns_business(p_business_id) then raise exception 'Verified owner required' using errcode='42501';end if;
 if p_kind not in('deletion','recovery') or nullif(btrim(p_reason),'') is null then raise exception 'Lifecycle request and reason required';end if;
 payload:=jsonb_build_object('operation','account_lifecycle','kind',p_kind,'reason',p_reason);prior:=private.operation_replay(p_business_id,p_request_id,payload);if prior is not null then return prior;end if;
 insert into public.account_lifecycle_requests(business_id,request_id,requested_by,kind,reason) values(p_business_id,p_request_id,auth.uid(),p_kind,p_reason) returning id into request;
 result:=jsonb_build_object('id',request,'status','requested','financial_records_preserved',true);
 insert into public.audit_logs(business_id,actor_id,action,metadata) values(p_business_id,auth.uid(),'account_lifecycle_requested',payload||result);
 perform private.operation_save(p_business_id,p_request_id,payload,result);return result;
end $$;
create function public.record_trexven_application_error(p_business_id uuid,p_application text,p_error_code text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if not public.is_business_member(p_business_id) or p_error_code is null or p_error_code not in('OPERATION_UNCONFIRMED','OFFLINE_SYNC_UNCONFIRMED','ENCRYPTED_STORAGE_UNAVAILABLE','BILLING_REQUEST_UNCONFIRMED','CAMERA_EVIDENCE_REQUEST_FAILED') or p_application not in('owner','pos','backend') then raise exception 'Authorized fixed error code required' using errcode='42501';end if;
 -- Never accept arbitrary error messages, stack traces, credentials or payloads.
 perform pg_advisory_xact_lock(hashtextextended(auth.uid()::text||':error',0));
 if (select count(*) from public.application_error_events where actor_id=auth.uid() and created_at>now()-interval '1 minute')>=20 then return;end if;
 insert into public.application_error_events(business_id,actor_id,application,error_code) values(p_business_id,auth.uid(),p_application,p_error_code);
end $$;
create function public.get_trexven_operational_health(p_business_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not public.user_owns_business(p_business_id) then raise exception 'Owner required' using errcode='42501';end if;
 return jsonb_build_object('failed_billing_events',(select count(*) from public.billing_payments where business_id=p_business_id and status='failed'),
 'pending_subscription_requests',(select count(*) from public.subscription_change_requests where business_id=p_business_id and status='pending'),
 'recent_application_errors',(select count(*) from public.application_error_events where business_id=p_business_id and created_at>now()-interval '1 day'),
 'latest_backup',(select jsonb_build_object('captured_at',captured_at,'status',status,'recovery_checked_at',recovery_checked_at) from public.operational_backup_status where business_id=p_business_id order by captured_at desc limit 1));
end $$;
revoke all on function public.request_trexven_account_lifecycle(uuid,uuid,text,text),public.record_trexven_application_error(uuid,text,text),public.get_trexven_operational_health(uuid) from public,anon;
grant execute on function public.request_trexven_account_lifecycle(uuid,uuid,text,text),public.record_trexven_application_error(uuid,text,text),public.get_trexven_operational_health(uuid) to authenticated;
grant insert,select,update on public.operational_backup_status to service_role;
commit;
$trexven_release_source$]::text[]);
commit;
