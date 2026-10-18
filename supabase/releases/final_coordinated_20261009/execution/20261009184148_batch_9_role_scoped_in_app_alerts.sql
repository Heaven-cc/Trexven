begin;
-- Release history guard and history insert are in the SAME transaction as DDL.
select pg_advisory_xact_lock(hashtextextended('trexven:coordinated-release',0));
do $trexven_history_guard$ begin
 if (select array_agg(version order by version) from supabase_migrations.schema_migrations)
    is distinct from array['20260819180000','20260823100000','20261002014604','20261002015419','20261002123039','20261002124738','20261003224001','20261004025120','20261005004045','20261007215736','20261007215743','20261007215831','20261008002119','20261008020234','20261008021428','20261009003200','20261009070338','20261009070340','20261009075117','20261009075318','20261009075612','20261009075911','20261009080227','20261009080751','20261009080842','20261009081002','20261009081504','20261009082051','20261009082951','20261009122632','20261009135919']::text[] then
  raise exception 'TREXVEN predecessor history mismatch; no migration changes committed';
 end if;
end $trexven_history_guard$;

-- Reuse existing alerts/audits/review records. Only read acknowledgements are
-- new; no historical notification, financial or inventory record is rewritten.
create table public.trexven_notification_reads(
 business_id uuid not null references public.businesses(id),
 user_id uuid not null references auth.users(id),
 alert_key text not null check(length(alert_key) between 1 and 120),
 read_at timestamptz not null default now(),
 primary key(business_id,user_id,alert_key)
);
alter table public.trexven_notification_reads enable row level security;
revoke all on public.trexven_notification_reads from public,anon,authenticated;
grant select on public.trexven_notification_reads to authenticated;
create policy "Own current business notification acknowledgements" on public.trexven_notification_reads
 for select to authenticated using(user_id=(select auth.uid()) and public.is_business_member(business_id));

create function private.trexven_visible_notifications(business uuid,application text)
returns table(alert_key text,title text,message text,route text,reference_id uuid,occurred_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare owner_actor boolean; employee_role text; inventory_access boolean; staff_access boolean; cash_access boolean;
begin
 if auth.uid() is null or not public.is_business_member(business) or application is null or application not in ('owner','pos') then
  raise exception 'Active business notification access required' using errcode='42501';end if;
 owner_actor:=public.user_owns_business(business);
 if application='owner' and not owner_actor then raise exception 'Verified owner required' using errcode='42501';end if;
 if exists(select 1 from public.businesses b where b.id=business and b.branches_enabled) then
  raise exception 'Branch notifications require an approved branch-scoped contract' using errcode='42501';end if;
 select e.role into employee_role from public.employees e where e.business_id=business and e.user_id=auth.uid() and e.status='active';
 if application='pos' and not owner_actor and not coalesce(employee_role in ('manager','sales_employee','inventory_employee'),false) then
  raise exception 'Authorized POS role required' using errcode='42501';end if;
 inventory_access:=(owner_actor or employee_role in ('manager','inventory_employee')) and private.has_business_permission(business,'view_inventory');
 staff_access:=(owner_actor or employee_role='manager') and private.has_business_permission(business,'manage_employees');
 cash_access:=(owner_actor or employee_role='manager') and private.has_business_permission(business,'review_cash_shifts');
 return query
 select 'alert:'||a.id::text,a.title,a.message,
  case when a.alert_type like '%stock%' then 'inventory' else 'vision' end,a.reference_id,a.created_at
 from public.alerts a where a.business_id=business and (
  (a.alert_type like '%stock%' and inventory_access and private.subscription_entitled(business,'low_stock_alerts')) or
  (a.alert_type not like '%stock%' and application='owner' and owner_actor))
 union all
 select 'inventory_review:'||r.id::text,'Inventory discrepancy requires review',
  'Review the original movement before making a separate approved stock correction.','inventory',r.id,null::timestamptz
 from public.inventory_reconciliation_reviews r where r.business_id=business and r.status='pending' and inventory_access
 union all
 select 'cash_review:'||s.id::text,'Closed drawer requires review',
  'Review the recorded count and variance. Historical closure totals remain unchanged.','cash',s.id,s.closed_at
 from public.cash_shifts s where s.business_id=business and s.status='closed' and s.review_status='pending' and cash_access
 union all
 select 'staff:'||a.id::text,'Employee access changed',
  'Review current employee access. This event does not grant a new permission.','employees',a.target_id,a.created_at
 from public.audit_logs a where a.business_id=business and a.action in ('employee_updated','employee_permission_changed','employee_status_changed') and staff_access;
end $$;
revoke all on function private.trexven_visible_notifications(uuid,text) from public,anon,authenticated;

create function public.get_trexven_notifications(p_business_id uuid,p_application text default 'pos',p_offset integer default 0)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if p_offset is null or p_offset<0 or p_offset>100000 then raise exception 'Invalid notification page';end if;
 select coalesce(jsonb_agg(to_jsonb(t) order by t.occurred_at desc nulls last,t.alert_key),'[]'::jsonb) into result from (
  select n.*,r.read_at from private.trexven_visible_notifications(p_business_id,p_application) n
  left join public.trexven_notification_reads r on r.business_id=p_business_id and r.user_id=auth.uid() and r.alert_key=n.alert_key
  order by n.occurred_at desc nulls last,n.alert_key limit 100 offset p_offset
 ) t;
 return result;
end $$;
create function public.mark_trexven_notification_read(p_business_id uuid,p_alert_key text,p_read boolean,p_application text default 'pos')
returns void language plpgsql security definer set search_path='' as $$
begin
 if p_read is null or not exists(select 1 from private.trexven_visible_notifications(p_business_id,p_application) n where n.alert_key=p_alert_key) then
  raise exception 'Current authorized notification required' using errcode='42501';end if;
 if p_read then
  insert into public.trexven_notification_reads(business_id,user_id,alert_key) values(p_business_id,auth.uid(),p_alert_key)
  on conflict(business_id,user_id,alert_key) do update set read_at=now();
 else delete from public.trexven_notification_reads where business_id=p_business_id and user_id=auth.uid() and alert_key=p_alert_key;
 end if;
end $$;
revoke all on function public.get_trexven_notifications(uuid,text,integer) from public,anon;
revoke all on function public.mark_trexven_notification_read(uuid,text,boolean,text) from public,anon;
grant execute on function public.get_trexven_notifications(uuid,text,integer) to authenticated;
grant execute on function public.mark_trexven_notification_read(uuid,text,boolean,text) to authenticated;
notify pgrst,'reload schema';
insert into supabase_migrations.schema_migrations(version,name,statements) values ('20261009184148','batch_9_role_scoped_in_app_alerts',array[$trexven_release_source$begin;
-- Reuse existing alerts/audits/review records. Only read acknowledgements are
-- new; no historical notification, financial or inventory record is rewritten.
create table public.trexven_notification_reads(
 business_id uuid not null references public.businesses(id),
 user_id uuid not null references auth.users(id),
 alert_key text not null check(length(alert_key) between 1 and 120),
 read_at timestamptz not null default now(),
 primary key(business_id,user_id,alert_key)
);
alter table public.trexven_notification_reads enable row level security;
revoke all on public.trexven_notification_reads from public,anon,authenticated;
grant select on public.trexven_notification_reads to authenticated;
create policy "Own current business notification acknowledgements" on public.trexven_notification_reads
 for select to authenticated using(user_id=(select auth.uid()) and public.is_business_member(business_id));

create function private.trexven_visible_notifications(business uuid,application text)
returns table(alert_key text,title text,message text,route text,reference_id uuid,occurred_at timestamptz)
language plpgsql stable security definer set search_path='' as $$
declare owner_actor boolean; employee_role text; inventory_access boolean; staff_access boolean; cash_access boolean;
begin
 if auth.uid() is null or not public.is_business_member(business) or application is null or application not in ('owner','pos') then
  raise exception 'Active business notification access required' using errcode='42501';end if;
 owner_actor:=public.user_owns_business(business);
 if application='owner' and not owner_actor then raise exception 'Verified owner required' using errcode='42501';end if;
 if exists(select 1 from public.businesses b where b.id=business and b.branches_enabled) then
  raise exception 'Branch notifications require an approved branch-scoped contract' using errcode='42501';end if;
 select e.role into employee_role from public.employees e where e.business_id=business and e.user_id=auth.uid() and e.status='active';
 if application='pos' and not owner_actor and not coalesce(employee_role in ('manager','sales_employee','inventory_employee'),false) then
  raise exception 'Authorized POS role required' using errcode='42501';end if;
 inventory_access:=(owner_actor or employee_role in ('manager','inventory_employee')) and private.has_business_permission(business,'view_inventory');
 staff_access:=(owner_actor or employee_role='manager') and private.has_business_permission(business,'manage_employees');
 cash_access:=(owner_actor or employee_role='manager') and private.has_business_permission(business,'review_cash_shifts');
 return query
 select 'alert:'||a.id::text,a.title,a.message,
  case when a.alert_type like '%stock%' then 'inventory' else 'vision' end,a.reference_id,a.created_at
 from public.alerts a where a.business_id=business and (
  (a.alert_type like '%stock%' and inventory_access and private.subscription_entitled(business,'low_stock_alerts')) or
  (a.alert_type not like '%stock%' and application='owner' and owner_actor))
 union all
 select 'inventory_review:'||r.id::text,'Inventory discrepancy requires review',
  'Review the original movement before making a separate approved stock correction.','inventory',r.id,null::timestamptz
 from public.inventory_reconciliation_reviews r where r.business_id=business and r.status='pending' and inventory_access
 union all
 select 'cash_review:'||s.id::text,'Closed drawer requires review',
  'Review the recorded count and variance. Historical closure totals remain unchanged.','cash',s.id,s.closed_at
 from public.cash_shifts s where s.business_id=business and s.status='closed' and s.review_status='pending' and cash_access
 union all
 select 'staff:'||a.id::text,'Employee access changed',
  'Review current employee access. This event does not grant a new permission.','employees',a.target_id,a.created_at
 from public.audit_logs a where a.business_id=business and a.action in ('employee_updated','employee_permission_changed','employee_status_changed') and staff_access;
end $$;
revoke all on function private.trexven_visible_notifications(uuid,text) from public,anon,authenticated;

create function public.get_trexven_notifications(p_business_id uuid,p_application text default 'pos',p_offset integer default 0)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if p_offset is null or p_offset<0 or p_offset>100000 then raise exception 'Invalid notification page';end if;
 select coalesce(jsonb_agg(to_jsonb(t) order by t.occurred_at desc nulls last,t.alert_key),'[]'::jsonb) into result from (
  select n.*,r.read_at from private.trexven_visible_notifications(p_business_id,p_application) n
  left join public.trexven_notification_reads r on r.business_id=p_business_id and r.user_id=auth.uid() and r.alert_key=n.alert_key
  order by n.occurred_at desc nulls last,n.alert_key limit 100 offset p_offset
 ) t;
 return result;
end $$;
create function public.mark_trexven_notification_read(p_business_id uuid,p_alert_key text,p_read boolean,p_application text default 'pos')
returns void language plpgsql security definer set search_path='' as $$
begin
 if p_read is null or not exists(select 1 from private.trexven_visible_notifications(p_business_id,p_application) n where n.alert_key=p_alert_key) then
  raise exception 'Current authorized notification required' using errcode='42501';end if;
 if p_read then
  insert into public.trexven_notification_reads(business_id,user_id,alert_key) values(p_business_id,auth.uid(),p_alert_key)
  on conflict(business_id,user_id,alert_key) do update set read_at=now();
 else delete from public.trexven_notification_reads where business_id=p_business_id and user_id=auth.uid() and alert_key=p_alert_key;
 end if;
end $$;
revoke all on function public.get_trexven_notifications(uuid,text,integer) from public,anon;
revoke all on function public.mark_trexven_notification_read(uuid,text,boolean,text) from public,anon;
grant execute on function public.get_trexven_notifications(uuid,text,integer) to authenticated;
grant execute on function public.mark_trexven_notification_read(uuid,text,boolean,text) to authenticated;
notify pgrst,'reload schema';
commit;
$trexven_release_source$]::text[]);
commit;
