begin;
create table private.billing_provider_configuration(provider text primary key,enabled boolean not null default false);
alter table private.billing_provider_configuration enable row level security;revoke all on private.billing_provider_configuration from public,anon,authenticated;
grant select,insert,update on private.billing_provider_configuration to service_role;
create function public.attach_trexven_billing_provider_session(p_session_id uuid,p_provider text,p_provider_session_ref text)
returns void language plpgsql security definer set search_path='' as $$
declare s public.billing_sessions%rowtype;
begin
 if not exists(select 1 from private.billing_provider_configuration where provider=p_provider and enabled) or nullif(btrim(p_provider_session_ref),'') is null then raise exception 'Reviewed provider adapter is not enabled';end if;
 select * into s from public.billing_sessions where id=p_session_id for update;
 if not found then raise exception 'Billing session unavailable';end if;
 if s.provider=p_provider and s.provider_session_ref=p_provider_session_ref then return;end if;
 if s.status<>'requested' then raise exception 'Billing session already attached';end if;
 update public.billing_sessions set provider=p_provider,provider_session_ref=p_provider_session_ref,status='pending' where id=s.id;
end $$;
create function public.activate_verified_trexven_billing_subscription(p_payment_id uuid,p_event_key text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare payment public.billing_payments%rowtype;session public.billing_sessions%rowtype;plan public.subscription_plans%rowtype;s public.business_subscriptions%rowtype;expires timestamptz;result jsonb;
begin
 select * into payment from public.billing_payments where id=p_payment_id and status='verified';if not found then raise exception 'Server-verified billing payment required';end if;
 select * into session from public.billing_sessions where id=payment.session_id;
 select * into plan from public.subscription_plans where id=session.plan_id and active;
 if not found or plan.interval_months is null then raise exception 'Renewal interval not configured';end if;
 perform pg_advisory_xact_lock(hashtextextended(payment.business_id::text||':subscription',0));
 if exists(select 1 from public.subscription_events where event_key='payment-activation:'||payment.id::text) then return jsonb_build_object('replayed',true);end if;
 select * into s from public.business_subscriptions where business_id=payment.business_id for update;
 expires:=greatest(coalesce(s.expires_at,payment.verified_at),payment.verified_at)+make_interval(months=>plan.interval_months);
 result:=public.apply_verified_trexven_subscription(payment.business_id,p_event_key,plan.id,'active',coalesce(s.started_at,payment.verified_at),expires,expires,
  case when plan.grace_days is not null then expires+make_interval(days=>plan.grace_days) end,coalesce(s.version,0),coalesce(s.enforce,false));
 insert into public.subscription_events(business_id,event_key,kind,details) values(payment.business_id,'payment-activation:'||payment.id::text,'verified_renewal',jsonb_build_object('payment_id',payment.id,'expires',expires));
 return result;
end $$;
create function public.process_trexven_subscription_cancellation(p_change_id uuid,p_event_key text)
returns void language plpgsql security definer set search_path='' as $$
declare r public.subscription_change_requests%rowtype;
begin
 select * into r from public.subscription_change_requests where id=p_change_id and action='cancel' for update;if not found then raise exception 'Owner cancellation request required';end if;
 if r.status='processed' then return;end if;
 if r.status<>'pending' or nullif(btrim(p_event_key),'') is null then raise exception 'Pending trusted cancellation required';end if;
 perform pg_advisory_xact_lock(hashtextextended(r.business_id::text||':subscription',0));
 -- Caller must first verify provider-side auto-renew cancellation. No history deletion.
 update public.business_subscriptions set cancel_at_period_end=true,version=version+1,updated_at=now() where business_id=r.business_id;
 update public.subscription_change_requests set status='processed' where id=r.id;
 insert into public.subscription_events(business_id,event_key,kind,details) values(r.business_id,p_event_key,'verified_cancellation_requested',jsonb_build_object('request_id',r.id));
end $$;
create function public.require_trexven_feature(p_business_id uuid,p_feature text) returns boolean language plpgsql stable security definer set search_path='' as $$
begin
 if not public.is_business_member(p_business_id) or p_feature is null or not private.subscription_entitled(p_business_id,p_feature) then raise exception 'Business subscription feature unavailable' using errcode='42501';end if;return true;
end $$;
revoke all on function public.require_trexven_feature(uuid,text) from public,anon;grant execute on function public.require_trexven_feature(uuid,text) to authenticated;
create function private.guard_subscription_camera() returns trigger language plpgsql security definer set search_path='' as $$
declare ceiling integer;
begin
 if not new.is_active then return new;end if;
 if tg_op='UPDATE' and new.is_active=old.is_active and new.business_id=old.business_id then return new;end if;
 perform pg_advisory_xact_lock(hashtextextended(new.business_id::text||':subscription',0));
 if not private.subscription_entitled(new.business_id,'basic_vision') then raise exception 'Subscription Vision access unavailable';end if;
 select p.camera_limit into ceiling from public.business_subscriptions s join public.subscription_plans p on p.id=s.plan_id where s.business_id=new.business_id and s.enforce;
 if ceiling is not null and (select count(*) from public.cameras where business_id=new.business_id and is_active and id<>new.id)>=ceiling then raise exception 'Configured camera limit reached';end if;return new;
end $$;
revoke all on function private.guard_subscription_camera() from public,anon,authenticated;
create trigger batch_7_camera_entitlements before insert or update on public.cameras for each row execute function private.guard_subscription_camera();
create function private.guard_stocktake_count_entitlement() returns trigger language plpgsql security definer set search_path='' as $$
declare business uuid;
begin
 select business_id into business from public.stocktake_sessions where id=new.session_id;
 if not private.subscription_entitled(business,'advanced_inventory') then raise exception 'Advanced inventory entitlement required';end if;return new;
end $$;
revoke all on function private.guard_stocktake_count_entitlement() from public,anon,authenticated;
create trigger batch_7_count_entitlements before insert or update on public.stocktake_counts for each row execute function private.guard_stocktake_count_entitlement();
-- Historical return processing must remain possible after a plan expires.
create or replace function private.guard_advanced_inventory_session() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if tg_table_name='stock_condition_entries' and to_jsonb(new)->>'kind'='customer_return' then return new;end if;
 if tg_table_name='stocktake_sessions' and tg_op='UPDATE' and to_jsonb(new)->>'status'='cancelled' then return new;end if;
 if not private.subscription_entitled(new.business_id,'advanced_inventory') then raise exception 'Plan does not include advanced inventory';end if;return new;
end $$;
create or replace function private.guard_subscription_sale() returns trigger language plpgsql security definer set search_path='' as $$
declare s public.business_subscriptions%rowtype;
begin
 if coalesce(current_setting('trexven.catalog_operation',true),'')='offline_cash' then
  select * into s from public.business_subscriptions where business_id=new.business_id and enforce;
  if found and (new.sold_at>=case when s.status='past_due' then coalesce(s.grace_until,s.expires_at) else s.expires_at end or (s.status='canceled' and new.sold_at>s.updated_at)) then raise exception 'Offline sale occurred after authorized subscription access ended; preserve queue for review';end if;
 elsif not private.subscription_entitled(new.business_id,'pos') then raise exception 'Subscription POS access expired';end if;
 return new;
end $$;
do $$ declare f record;begin
 for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in('attach_trexven_billing_provider_session','activate_verified_trexven_billing_subscription','process_trexven_subscription_cancellation') loop
 execute format('revoke all on function %s from public,anon,authenticated',f.signature);execute format('grant execute on function %s to service_role',f.signature);end loop;
end $$;

-- Retain the centralized authorization contract; add only subscription gates.
create or replace function private.operations_context(business uuid,permission text,branch uuid default null,sensitive boolean default false)
returns void language plpgsql security definer set search_path='' as $$
declare enabled boolean;
begin
 if auth.uid() is null then raise exception 'Authentication required' using errcode='42501'; end if;
 select branches_enabled into enabled from public.businesses where id=business for share;
 if not found then raise exception 'Business access denied' using errcode='42501'; end if;
 perform id from public.employees where business_id=business and user_id=auth.uid() for share;
 perform id from public.business_members where business_id=business and user_id=auth.uid() for share;
 if not private.has_business_permission(business,permission) then raise exception 'Operation permission denied' using errcode='42501'; end if;
 if sensitive and not public.user_owns_business(business) and not exists(
  select 1 from public.employees e join public.employee_permissions p on p.employee_id=e.id
  where e.business_id=business and e.user_id=auth.uid() and e.status='active' and e.role='manager'
  and p.permission_id=permission and p.granted) then
  raise exception 'Explicit owner-granted manager permission required' using errcode='42501'; end if;
 if enabled and (branch is null or not private.has_branch_access(business,branch)) then raise exception 'Authorized branch required' using errcode='42501'; end if;
 if not enabled and branch is not null then raise exception 'Branches are dormant' using errcode='42501'; end if;
 if permission in('stocktake','approve_stocktake','dispose_stock','restore_stock','writeoff_stock','supplier_returns','approve_supplier_returns','transfer_stock') and not private.subscription_entitled(business,'advanced_inventory') then raise exception 'Advanced inventory subscription required';end if;
end $$;
create or replace function public.issue_trexven_offline_scope(p_business_id uuid,p_device_id uuid,p_shift_id uuid default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare member uuid; leaseid uuid:=gen_random_uuid(); secret bytea; scope jsonb; signature text; started timestamptz:=clock_timestamp(); expiry timestamptz;
begin
 perform private.operations_context(p_business_id,'offline_cash');
 if not private.subscription_entitled(p_business_id,'pos') then raise exception 'Subscription POS access unavailable';end if;
 expiry:=least(started+interval '24 hours',coalesce((select case when status='past_due' then grace_until else expires_at end from public.business_subscriptions where business_id=p_business_id and enforce),started+interval '24 hours'));
 if not private.has_business_permission(p_business_id,'complete_sales') or not private.has_business_permission(p_business_id,'pos_access') then raise exception 'Cash sale permission required' using errcode='42501';end if;
 if p_device_id is null then raise exception 'Stable device identity required';end if;
 select m.id into member from public.business_members m where business_id=p_business_id and user_id=auth.uid() and status='active';
 perform private.validate_operational_shift(p_business_id,member,p_shift_id,null,false);
 select jsonb_build_object('version',1,'lease_id',leaseid,'business_id',p_business_id,'user_id',auth.uid(),'membership_id',member,'device_id',p_device_id,
 'issued_at',started,'expires_at',expiry,'branch_id',null,'shift_id',p_shift_id,'products',coalesce(jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'unit',p.unit,'price',p.selling_price,'quantity',p.quantity,'barcode',p.barcode,'sku',p.sku) order by p.id),'[]'::jsonb)) into scope
 from public.products p where business_id=p_business_id and p.selling_price is not null and p.active is true and p.is_active;
 secret:=extensions.gen_random_bytes(32);
 signature:=encode(extensions.hmac(convert_to(scope::text,'UTF8'),secret,'sha256'),'hex');
 insert into private.offline_cash_leases values(leaseid,p_business_id,auth.uid(),member,p_device_id,scope,signature,secret,started,expiry);
 return jsonb_build_object('scope',scope,'signature',signature);
end $$;
commit;
