-- Commercial values stay NULL until separately configured. No subscriptions are
-- assigned to legacy businesses, and no charging/enforcement is activated here.
begin;
create table public.subscription_plans(
 id text primary key check(id in('start','core','pro')),name text not null,rank integer not null unique,
 price numeric(18,2) check(price>=0),currency text,interval_months integer check(interval_months>0),
 trial_days integer check(trial_days>=0),grace_days integer check(grace_days>=0),employee_limit integer check(employee_limit>=0),camera_limit integer check(camera_limit>=0),
 features jsonb not null check(jsonb_typeof(features)='object'),active boolean not null default true);
insert into public.subscription_plans(id,name,rank,features) values
 ('start','START',1,'{"pos":true,"inventory":true,"barcode":true,"sales":true,"basic_reports":true,"basic_employees":true,"basic_vision":true}'),
 ('core','CORE',2,'{"pos":true,"inventory":true,"barcode":true,"sales":true,"basic_reports":true,"basic_employees":true,"basic_vision":true,"advanced_inventory":true,"low_stock_alerts":true,"employee_permissions":true,"advanced_reports":true,"multiple_pricing":true,"analytics":true,"enhanced_vision":true}'),
 ('pro','PRO',3,'{"pos":true,"inventory":true,"barcode":true,"sales":true,"basic_reports":true,"basic_employees":true,"basic_vision":true,"advanced_inventory":true,"low_stock_alerts":true,"employee_permissions":true,"advanced_reports":true,"multiple_pricing":true,"analytics":true,"enhanced_vision":true,"advanced_analytics":true,"detailed_activity_logs":true,"advanced_employee_controls":true,"highest_vision":true,"priority_support":true,"early_access":true}');
create table public.business_subscriptions(
 id uuid primary key default gen_random_uuid(),business_id uuid not null unique references public.businesses(id),plan_id text not null references public.subscription_plans(id),
 status text not null check(status in('trialing','active','past_due','canceled','expired')),
 started_at timestamptz not null,renews_at timestamptz,expires_at timestamptz not null,grace_until timestamptz,
 enforce boolean not null default false,cancel_at_period_end boolean not null default false,version integer not null default 1,
 updated_at timestamptz not null default now(),check(expires_at>started_at),check(grace_until is null or grace_until>=expires_at));
create table public.subscription_events(id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),
 event_key text not null unique,kind text not null,actor_id uuid references auth.users(id),details jsonb not null default '{}',created_at timestamptz not null default now());
create table public.billing_customers(id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),provider text not null,provider_customer_ref text not null,unique(provider,provider_customer_ref),unique(business_id,provider));
create table public.billing_sessions(id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),request_id uuid not null unique,
 plan_id text not null references public.subscription_plans(id),provider text,provider_session_ref text,amount numeric(18,2),currency text,
 status text not null default 'requested' check(status in('requested','pending','verified','failed','cancelled')),created_at timestamptz not null default now(),unique(provider,provider_session_ref));
create table private.billing_provider_events(provider text not null,event_id text not null,payload jsonb not null,result jsonb not null,created_at timestamptz not null default now(),primary key(provider,event_id));
alter table private.billing_provider_events enable row level security;revoke all on private.billing_provider_events from public,anon,authenticated;
create table public.billing_payments(id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),session_id uuid not null references public.billing_sessions(id),provider text not null,payment_ref text not null,
 amount numeric(18,2) not null check(amount>=0),currency text not null,status text not null check(status in('verified','failed')),verified_at timestamptz,unique(provider,payment_ref));
create unique index billing_session_one_verified on public.billing_payments(session_id) where status='verified';
create table public.billing_invoices(id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),payment_id uuid not null unique references public.billing_payments(id),invoice_number text not null unique,amount numeric(18,2) not null,currency text not null,issued_at timestamptz not null default now());
create table public.subscription_change_requests(id uuid primary key default gen_random_uuid(),business_id uuid not null references public.businesses(id),request_id uuid not null unique,
 requested_by uuid not null references auth.users(id),plan_id text references public.subscription_plans(id),action text not null check(action in('change_plan','cancel')),status text not null default 'pending' check(status in('pending','processed','rejected')),created_at timestamptz not null default now());
do $$ declare t text;begin
 foreach t in array array['subscription_plans','business_subscriptions','subscription_events','billing_customers','billing_sessions','billing_payments','billing_invoices','subscription_change_requests'] loop
  execute format('alter table public.%I enable row level security',t);execute format('revoke all on public.%I from public,anon,authenticated',t);execute format('grant select on public.%I to authenticated',t);
  if t='subscription_plans' then execute 'create policy "Plan catalog read" on public.subscription_plans for select to authenticated using(active)';
  elsif t='business_subscriptions' then execute 'create policy "Subscription member read" on public.business_subscriptions for select to authenticated using(public.is_business_member(business_id))';
  else execute format('create policy "Owner billing read" on public.%I for select to authenticated using(public.user_owns_business(business_id))',t);end if;
 end loop;
end $$;
create function private.subscription_entitled(business uuid,feature text) returns boolean language sql stable security definer set search_path='' as $$
 select not exists(select 1 from public.business_subscriptions where business_id=business and enforce)
 or exists(select 1 from public.business_subscriptions s join public.subscription_plans p on p.id=s.plan_id where s.business_id=business and s.enforce and p.active
 and coalesce((p.features->>feature)::boolean,false) and
 ((s.status in('active','trialing') and now()<s.expires_at) or (s.status='past_due' and s.grace_until is not null and now()<s.grace_until)))
$$;
revoke all on function private.subscription_entitled(uuid,text) from public,anon,authenticated;
create function public.get_trexven_entitlements(p_business_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare s public.business_subscriptions%rowtype;p public.subscription_plans%rowtype;
begin
 if not public.is_business_member(p_business_id) then raise exception 'Active business access required' using errcode='42501';end if;
 select * into s from public.business_subscriptions where business_id=p_business_id;
 if not found then return jsonb_build_object('configured',false,'enforced',false,'status','unconfigured','features','{}'::jsonb,'employee_limit',null,'camera_limit',null);end if;
 select * into p from public.subscription_plans where id=s.plan_id;
 return jsonb_build_object('configured',true,'enforced',s.enforce,'plan',s.plan_id,'status',case when s.status in('active','trialing') and now()>=s.expires_at then 'expired' when s.status='past_due' and now()>=coalesce(s.grace_until,s.expires_at) then 'expired' else s.status end,
 'started_at',s.started_at,'renews_at',s.renews_at,'expires_at',s.expires_at,'grace_until',s.grace_until,'cancel_at_period_end',s.cancel_at_period_end,'employee_limit',p.employee_limit,'camera_limit',p.camera_limit,
 'features',case when not s.enforce or private.subscription_entitled(p_business_id,'pos') then p.features else '{}'::jsonb end);
end $$;
create function public.request_trexven_subscription_change(p_business_id uuid,p_request_id uuid,p_action text,p_plan_id text default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare payload jsonb;prior jsonb;result jsonb;request uuid;
begin
 if not public.user_owns_business(p_business_id) then raise exception 'Verified owner required' using errcode='42501';end if;
 payload:=jsonb_build_object('operation','subscription_request','action',p_action,'plan',p_plan_id);prior:=private.operation_replay(p_business_id,p_request_id,payload);if prior is not null then return prior;end if;
 if p_action not in('change_plan','cancel') or (p_action='change_plan' and not exists(select 1 from public.subscription_plans where id=p_plan_id and active)) then raise exception 'Approved plan or cancellation required';end if;
 insert into public.subscription_change_requests(business_id,request_id,requested_by,plan_id,action) values(p_business_id,p_request_id,auth.uid(),p_plan_id,p_action) returning id into request;
 insert into public.subscription_events(business_id,event_key,kind,actor_id,details) values(p_business_id,p_request_id::text,'owner_requested_change',auth.uid(),payload);
 result:=jsonb_build_object('id',request,'status','pending','charging_active',false);perform private.operation_save(p_business_id,p_request_id,payload,result);return result;
end $$;
-- Service-only verified state transitions. Never grant to a Flutter role.
create function public.apply_verified_trexven_subscription(p_business_id uuid,p_event_key text,p_plan_id text,p_status text,p_started timestamptz,p_expires timestamptz,
 p_renews timestamptz default null,p_grace_until timestamptz default null,p_expected_version integer default 0,p_enforce boolean default false)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.business_subscriptions%rowtype;details jsonb;old public.subscription_events%rowtype;result jsonb;
begin
 if p_business_id is null or nullif(btrim(p_event_key),'') is null or p_enforce is null then raise exception 'Trusted event identity required';end if;
 details:=jsonb_build_object('plan',p_plan_id,'status',p_status,'started',p_started,'expires',p_expires,'renews',p_renews,'grace',p_grace_until,'version',p_expected_version,'enforce',p_enforce);
 perform pg_advisory_xact_lock(hashtextextended(p_business_id::text||':subscription',0));
 select * into old from public.subscription_events where event_key=p_event_key;
 if found then if old.business_id<>p_business_id or old.details<>details then raise exception 'Event identity conflict';end if;return jsonb_build_object('replayed',true);end if;
 select * into s from public.business_subscriptions where business_id=p_business_id for update;
 if coalesce(s.version,0)<>p_expected_version then raise exception 'Stale subscription version';end if;
 insert into public.business_subscriptions(business_id,plan_id,status,started_at,expires_at,renews_at,grace_until,enforce)
 values(p_business_id,p_plan_id,p_status,p_started,p_expires,p_renews,p_grace_until,p_enforce)
 on conflict(business_id) do update set plan_id=excluded.plan_id,status=excluded.status,started_at=excluded.started_at,expires_at=excluded.expires_at,renews_at=excluded.renews_at,grace_until=excluded.grace_until,enforce=excluded.enforce,version=business_subscriptions.version+1,updated_at=now();
 insert into public.subscription_events(business_id,event_key,kind,details) values(p_business_id,p_event_key,'verified_subscription_transition',details);
 result:=jsonb_build_object('business_id',p_business_id,'status',p_status);return result;
end $$;
create function public.request_trexven_billing_session(p_business_id uuid,p_request_id uuid,p_plan_id text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare plan public.subscription_plans%rowtype;payload jsonb;prior jsonb;result jsonb;session uuid;
begin
 if not public.user_owns_business(p_business_id) then raise exception 'Owner required' using errcode='42501';end if;
 payload:=jsonb_build_object('operation','billing_session','plan',p_plan_id);prior:=private.operation_replay(p_business_id,p_request_id,payload);if prior is not null then return prior;end if;
 select * into plan from public.subscription_plans where id=p_plan_id and active;
 if not found or plan.price is null or plan.currency is null or plan.interval_months is null then raise exception 'Commercial settings are not configured; no charging is active';end if;
 insert into public.billing_sessions(business_id,request_id,plan_id,amount,currency) values(p_business_id,p_request_id,plan.id,plan.price,plan.currency) returning id into session;
 result:=jsonb_build_object('id',session,'status','requested','amount',plan.price,'currency',plan.currency);
 perform private.operation_save(p_business_id,p_request_id,payload,result);return result;
end $$;
create function public.record_verified_trexven_billing_event(p_provider text,p_event_id text,p_session_id uuid,p_payment_ref text,p_amount numeric,p_currency text,p_status text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s public.billing_sessions%rowtype;payload jsonb;old private.billing_provider_events%rowtype;result jsonb;payment uuid; existing public.billing_payments%rowtype;
begin
 if nullif(btrim(p_provider),'') is null or nullif(btrim(p_event_id),'') is null or nullif(btrim(p_payment_ref),'') is null or p_status not in('verified','failed') then raise exception 'Verified provider identity required';end if;
 payload:=jsonb_build_object('session',p_session_id,'payment',p_payment_ref,'amount',p_amount,'currency',p_currency,'status',p_status);
 perform pg_advisory_xact_lock(hashtextextended(p_provider||':'||p_event_id,0));
 select * into old from private.billing_provider_events where provider=p_provider and event_id=p_event_id;
 if found then if old.payload<>payload then raise exception 'Provider event conflict';end if;return old.result;end if;
 select * into s from public.billing_sessions where id=p_session_id for update;
 if not found or s.provider is distinct from p_provider or s.status not in('pending','failed','verified') or s.amount is distinct from p_amount or s.currency is distinct from p_currency then raise exception 'Verified payment does not match trusted session';end if;
 select * into existing from public.billing_payments where provider=p_provider and payment_ref=p_payment_ref for update;
 if found then
  if existing.session_id<>s.id or existing.business_id<>s.business_id or existing.amount<>p_amount or existing.currency<>p_currency then raise exception 'Payment identity conflict';end if;
  payment:=existing.id;
  if existing.status='verified' then
   result:=jsonb_build_object('id',payment,'status','verified','replayed',true);
   insert into private.billing_provider_events(provider,event_id,payload,result) values(p_provider,p_event_id,payload,result);return result;
  end if;
  if p_status='verified' then update public.billing_payments set status='verified',verified_at=now() where id=payment;end if;
 else
 if s.status='verified' then raise exception 'This checkout session already has a verified payment';end if;
 insert into public.billing_payments(business_id,session_id,provider,payment_ref,amount,currency,status,verified_at)
 values(s.business_id,s.id,p_provider,p_payment_ref,p_amount,p_currency,p_status,case when p_status='verified' then now() end) returning id into payment;
 end if;
 update public.billing_sessions set status=case when p_status='verified' then 'verified' else 'failed' end where id=s.id;
 if p_status='verified' then insert into public.billing_invoices(business_id,payment_id,invoice_number,amount,currency) values(s.business_id,payment,'TRX-BILL-'||payment::text,p_amount,p_currency);end if;
 result:=jsonb_build_object('id',payment,'status',p_status);insert into private.billing_provider_events(provider,event_id,payload,result) values(p_provider,p_event_id,payload,result);
 insert into public.subscription_events(business_id,event_key,kind,details) values(s.business_id,'billing:'||p_provider||':'||p_event_id,'billing_'||p_status,result);
 return result;
end $$;
do $$ declare f record;begin
 for f in select p.oid::regprocedure signature,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in('get_trexven_entitlements','request_trexven_subscription_change','request_trexven_billing_session','apply_verified_trexven_subscription','record_verified_trexven_billing_event') loop
  execute format('revoke all on function %s from public,anon,authenticated',f.signature);
  execute format('grant execute on function %s to %I',f.signature,case when f.proname in('apply_verified_trexven_subscription','record_verified_trexven_billing_event') then 'service_role' else 'authenticated' end);
 end loop;
end $$;
commit;
