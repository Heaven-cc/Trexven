-- PREPARED ONLY. No prices, provider registration, entitlement activation or charging.
-- Existing global billing APIs remain available for historical compatibility.
do $guard$
begin
 if md5(pg_get_functiondef('public.activate_verified_trexven_billing_subscription(uuid,text)'::regprocedure)) <> '8c8419cb8986887e151d1e257da64120' then
  raise exception 'Billing activation definition drift: review before deployment';
 end if;
 if (select proacl::text from pg_proc where oid='public.activate_verified_trexven_billing_subscription(uuid,text)'::regprocedure)
    is distinct from '{postgres=X/postgres,service_role=X/postgres}' then
  raise exception 'Billing activation ACL drift: review before deployment';
 end if;
end $guard$;

create table public.subscription_country_prices (
 plan_id text not null references public.subscription_plans(id),
 country_code text not null check(country_code in ('NG','GH','TG','CI')),
 interval_months integer not null check(interval_months in (1,12)),
 currency text not null,
 price numeric(18,2),
 enabled boolean not null default false,
 primary key(plan_id,country_code,interval_months),
 check(currency=case country_code when 'NG' then 'NGN' when 'GH' then 'GHS' else 'XOF' end),
 check(price is null or price>0),
 check(currency<>'XOF' or price=trunc(price)),
 check(not enabled or price is not null)
);
alter table public.subscription_country_prices enable row level security;
-- Commercial configuration is server-managed. Only the owner-scoped catalog RPC reads it.
revoke all on public.subscription_country_prices from public,anon,authenticated;
grant select,insert,update,delete on public.subscription_country_prices to service_role;

alter table public.billing_sessions
 add column country_code text,
 add column interval_months integer,
 add constraint billing_sessions_country_snapshot_check check (
  (country_code is null and interval_months is null)
  or (country_code is not null and country_code in ('NG','GH','TG','CI')
   and interval_months is not null and interval_months in (1,12)
   and amount is not null and amount>0 and currency is not null
   and currency=case country_code when 'NG' then 'NGN' when 'GH' then 'GHS' else 'XOF' end
   and (currency<>'XOF' or amount=trunc(amount)))
 );

create function private.trexven_billing_country(value text) returns text
 language sql immutable strict set search_path='' as $fn$
 select case upper(btrim(value))
 when 'NG' then 'NG' when 'NIGERIA' then 'NG'
 when 'GH' then 'GH' when 'GHANA' then 'GH'
 when 'TG' then 'TG' when 'TOGO' then 'TG'
 when 'CI' then 'CI' when 'IVORY COAST' then 'CI'
 when 'COTE D''IVOIRE' then 'CI' when 'CÔTE D''IVOIRE' then 'CI'
 when 'COTE D’IVOIRE' then 'CI' when 'CÔTE D’IVOIRE' then 'CI'
 else null end
 $fn$;
revoke all on function private.trexven_billing_country(text) from public,anon,authenticated;

create function public.get_trexven_country_billing_catalog(p_business_id uuid)
 returns jsonb language plpgsql security definer set search_path='' as $fn$
declare country text;country_name text;currency_code text;plans jsonb;
begin
 if not public.user_owns_business(p_business_id) then raise exception 'Owner required' using errcode='42501';end if;
 select private.trexven_billing_country(b.country) into country from public.businesses b where b.id=p_business_id;
 country_name:=case country when 'NG' then 'Nigeria' when 'GH' then 'Ghana' when 'TG' then 'Togo' when 'CI' then 'Ivory Coast' end;
 currency_code:=case country when 'NG' then 'NGN' when 'GH' then 'GHS' when 'TG' then 'XOF' when 'CI' then 'XOF' end;
 select coalesce(jsonb_agg(jsonb_build_object(
  'id',p.id,'name',p.name,'features',p.features,
  'price',case when c.enabled then c.price end,
  'currency',currency_code,'interval_months',cycle.months
 ) order by p.rank,cycle.months),'[]'::jsonb) into plans
 from public.subscription_plans p cross join (values(1),(12)) cycle(months)
 left join public.subscription_country_prices c
 on c.plan_id=p.id and c.country_code=country and c.interval_months=cycle.months
 where p.active;
 return jsonb_build_object('country_code',country,'country_name',country_name,
  'plans',plans,'checkout_available',false);
end $fn$;
revoke all on function public.get_trexven_country_billing_catalog(uuid) from public,anon;
grant execute on function public.get_trexven_country_billing_catalog(uuid) to authenticated,service_role;

create function public.request_trexven_country_billing_session(
 p_business_id uuid,p_request_id uuid,p_plan_id text,p_country_code text,p_interval_months integer)
 returns jsonb language plpgsql security definer set search_path='' as $fn$
declare country text;pricing public.subscription_country_prices%rowtype;
 payload jsonb;prior jsonb;result jsonb;session_id uuid;
begin
 if not public.user_owns_business(p_business_id) then raise exception 'Owner required' using errcode='42501';end if;
 if p_country_code is null or p_country_code not in ('NG','GH','TG','CI')
 or p_interval_months is null or p_interval_months not in (1,12) then raise exception 'Country and billing cycle required';end if;
 payload:=jsonb_build_object('operation','country_billing_session','plan',p_plan_id,
  'country',p_country_code,'interval_months',p_interval_months);
 prior:=private.operation_replay(p_business_id,p_request_id,payload);
 if prior is not null then return prior;end if;
 select private.trexven_billing_country(b.country) into country from public.businesses b where b.id=p_business_id;
 if country is distinct from p_country_code then raise exception 'Billing country changed or unavailable';end if;
 select c.* into pricing from public.subscription_country_prices c
 join public.subscription_plans p on p.id=c.plan_id and p.active
 where c.plan_id=p_plan_id and c.country_code=country
 and c.interval_months=p_interval_months and c.enabled for share of c,p;
 if not found or pricing.price is null then raise exception 'Country price is not configured; checkout unavailable';end if;
 insert into public.billing_sessions(business_id,request_id,plan_id,amount,currency,country_code,interval_months)
 values(p_business_id,p_request_id,pricing.plan_id,pricing.price,pricing.currency,country,p_interval_months)
 returning id into session_id;
 result:=jsonb_build_object('id',session_id,'status','requested','amount',pricing.price::text,
  'currency',pricing.currency,'country_code',country,'interval_months',p_interval_months);
 perform private.operation_save(p_business_id,p_request_id,payload,result);
 return result;
end $fn$;
revoke all on function public.request_trexven_country_billing_session(uuid,uuid,text,text,integer) from public,anon;
grant execute on function public.request_trexven_country_billing_session(uuid,uuid,text,text,integer) to authenticated,service_role;

-- Consume the paid session's cycle; preserve legacy fallback and existing locking/replay.
CREATE OR REPLACE FUNCTION public.activate_verified_trexven_billing_subscription(p_payment_id uuid, p_event_key text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare payment public.billing_payments%rowtype;session public.billing_sessions%rowtype;plan public.subscription_plans%rowtype;s public.business_subscriptions%rowtype;expires timestamptz;result jsonb;billing_interval integer;
begin
 select * into payment from public.billing_payments where id=p_payment_id and status='verified';if not found then raise exception 'Server-verified billing payment required';end if;
 select * into session from public.billing_sessions where id=payment.session_id;
 select * into plan from public.subscription_plans where id=session.plan_id and active;
 if not found then raise exception 'Plan unavailable';end if;
 billing_interval:=coalesce(session.interval_months,plan.interval_months);
 if billing_interval is null then raise exception 'Renewal interval not configured';end if;
 perform pg_advisory_xact_lock(hashtextextended(payment.business_id::text||':subscription',0));
 if exists(select 1 from public.subscription_events where event_key='payment-activation:'||payment.id::text) then return jsonb_build_object('replayed',true);end if;
 select * into s from public.business_subscriptions where business_id=payment.business_id for update;
 expires:=greatest(coalesce(s.expires_at,payment.verified_at),payment.verified_at)+make_interval(months=>billing_interval);
 result:=public.apply_verified_trexven_subscription(payment.business_id,p_event_key,plan.id,'active',coalesce(s.started_at,payment.verified_at),expires,expires,
  case when plan.grace_days is not null then expires+make_interval(days=>plan.grace_days) end,coalesce(s.version,0),coalesce(s.enforce,false));
 insert into public.subscription_events(business_id,event_key,kind,details) values(payment.business_id,'payment-activation:'||payment.id::text,'verified_renewal',jsonb_build_object('payment_id',payment.id,'expires',expires));
 return result;
end $function$;


-- Service-only exact-decimal snapshot. No anonymous/authenticated execution.
create function public.get_trexven_country_billing_session(p_session_id uuid)
 returns jsonb language sql security definer set search_path='' as $fn$
 select jsonb_build_object('id',s.id,'business_id',s.business_id,'plan_id',s.plan_id,
  'amount',s.amount::text,'currency',s.currency,'country_code',s.country_code,
  'interval_months',s.interval_months,'status',s.status)
 from public.billing_sessions s where s.id=p_session_id
 and s.country_code is not null and s.interval_months is not null
 $fn$;
revoke all on function public.get_trexven_country_billing_session(uuid) from public,anon,authenticated;
grant execute on function public.get_trexven_country_billing_session(uuid) to service_role;
