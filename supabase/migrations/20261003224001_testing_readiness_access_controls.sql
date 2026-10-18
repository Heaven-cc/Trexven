-- Restrictive policies add permission boundaries to the existing permissive
-- membership policies. Service-role ingestion is unaffected.
create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated, service_role;

create or replace function private.has_business_permission(business uuid, permission text)
returns boolean language sql stable security definer set search_path = '' as $$
 select auth.uid() is not null and (
   exists(select 1 from public.businesses b where b.id=business and b.owner_id=auth.uid())
   or exists(select 1 from public.employees e
     join public.business_members m on m.business_id=e.business_id and m.user_id=e.user_id
     where e.business_id=business and e.user_id=auth.uid() and e.status='active' and m.status='active'
     and (exists(select 1 from public.employee_permissions p where p.employee_id=e.id and p.permission_id=permission)
       or (e.role='manager' and permission in ('pos_access','complete_sales','view_inventory','add_products','edit_products','manage_employees','view_camera_events','view_finance'))
       or (e.role='sales_employee' and permission in ('pos_access','complete_sales','view_inventory'))
       or (e.role='inventory_employee' and permission in ('view_inventory','add_products','edit_products')))))
$$;
revoke all on function private.has_business_permission(uuid,text) from public;
grant execute on function private.has_business_permission(uuid,text) to authenticated;

-- Conversations are private to their author, even within the same business.
create policy "Angel author boundary" on public.angel_conversations as restrictive
for all to authenticated using (user_id=auth.uid() and public.is_business_member(business_id))
with check (user_id=auth.uid() and public.is_business_member(business_id));
create policy "Angel message author boundary" on public.angel_messages as restrictive
for all to authenticated using (exists(select 1 from public.angel_conversations c
where c.id=conversation_id and c.user_id=auth.uid() and public.is_business_member(c.business_id)))
with check (exists(select 1 from public.angel_conversations c
where c.id=conversation_id and c.user_id=auth.uid() and public.is_business_member(c.business_id)));

create policy "Product read permission" on public.products as restrictive for select to authenticated
using (private.has_business_permission(business_id,'view_inventory') or private.has_business_permission(business_id,'pos_access'));
create policy "Product create permission" on public.products as restrictive for insert to authenticated
with check (private.has_business_permission(business_id,'add_products'));
create policy "Product edit permission" on public.products as restrictive for update to authenticated
using (private.has_business_permission(business_id,'edit_products'))
with check (private.has_business_permission(business_id,'edit_products'));
create policy "Product delete permission" on public.products as restrictive for delete to authenticated
using (public.user_owns_business(business_id));

create policy "Sales read permission" on public.sales as restrictive for select to authenticated
using (private.has_business_permission(business_id,'pos_access'));
-- Clients use transactional POS RPCs; direct writes cannot bypass stock accounting.
revoke insert,update,delete on public.sales,public.sale_items from authenticated,anon;

do $$ declare t text; begin
 foreach t in array array['cameras','camera_events','camera_detections','camera_zones','recordings'] loop
   execute format('create policy "Camera read permission" on public.%I as restrictive for select to authenticated using (private.has_business_permission(business_id,''view_camera_events''))',t);
   execute format('create policy "Camera owner write boundary" on public.%I as restrictive for insert to authenticated with check (public.user_owns_business(business_id))',t);
   execute format('create policy "Camera owner update boundary" on public.%I as restrictive for update to authenticated using (public.user_owns_business(business_id)) with check (public.user_owns_business(business_id))',t);
   execute format('create policy "Camera owner delete boundary" on public.%I as restrictive for delete to authenticated using (public.user_owns_business(business_id))',t);
 end loop;
end $$;

create policy "Authorized staff read recordings" on public.recordings for select to authenticated
using(private.has_business_permission(business_id,'view_camera_events'));
create policy "Authorized staff read recording objects" on storage.objects for select to authenticated
using(bucket_id='recordings' and exists(select 1 from public.recordings r
where r.storage_path=name and private.has_business_permission(r.business_id,'view_camera_events')));

create policy "Inventory evidence permission" on public.inventory_movements as restrictive
for all to authenticated using (private.has_business_permission(business_id,'view_inventory'))
with check (private.has_business_permission(business_id,'edit_products'));

do $$ declare t text; begin
 foreach t in array array['expenses','cash_transactions','financial_transactions'] loop
   execute format('create policy "Finance permission boundary" on public.%I as restrictive for all to authenticated using (private.has_business_permission(business_id,''view_finance'')) with check (private.has_business_permission(business_id,''view_finance''))',t);
 end loop;
 foreach t in array array['camera_ai_jobs','camera_event_links','camera_health_logs'] loop
   execute format('create policy "Camera evidence boundary" on public.%I as restrictive for all to authenticated using (private.has_business_permission(business_id,''view_camera_events'')) with check (public.user_owns_business(business_id))',t);
 end loop;
end $$;
create policy "Inventory read boundary" on public.inventory as restrictive for select to authenticated
using(private.has_business_permission(business_id,'view_inventory'));
create policy "Alert permission boundary" on public.alerts as restrictive for all to authenticated
using(public.user_owns_business(business_id) or
  (alert_type like '%stock%' and private.has_business_permission(business_id,'view_inventory')) or
  (alert_type not like '%stock%' and private.has_business_permission(business_id,'view_camera_events')))
with check(public.user_owns_business(business_id) or
  (alert_type like '%stock%' and private.has_business_permission(business_id,'view_inventory')) or
  (alert_type not like '%stock%' and private.has_business_permission(business_id,'view_camera_events')));

-- Harden the existing, already validated transaction bodies. Definer mode is
-- necessary because clients no longer have direct stock/sales write privileges.
-- The explicit permission guard is added before any business data is accessed.
do $$ declare signature text; definition text; private_signature text; begin
 foreach signature in array array['public.record_trexven_sale(uuid,uuid,integer,numeric)',
 'public.complete_pos_sale(uuid,uuid,numeric,text,jsonb)'] loop
   select pg_get_functiondef(signature::regprocedure) into definition;
   private_signature:=replace(signature,'public.','private.');
   definition:=replace(definition,'FUNCTION public.','FUNCTION private.');
   definition := regexp_replace(definition, E'\\mbegin\\M',
     E'begin\n if not private.has_business_permission(p_business_id,''complete_sales'') then raise exception ''Sale permission denied'' using errcode=''42501''; end if;', 'i');
   execute definition;
   execute format('alter function %s security definer',private_signature);
   execute format('alter function %s set search_path=public',private_signature);
   execute format('revoke all on function %s from public,anon',private_signature);
   execute format('grant execute on function %s to authenticated',private_signature);
 end loop;
end $$;

create or replace function public.record_trexven_sale(p_business_id uuid,p_product_id uuid,p_quantity integer,p_unit_price numeric)
returns uuid language sql security invoker set search_path='' as $$
select private.record_trexven_sale(p_business_id,p_product_id,p_quantity,p_unit_price)
$$;
create or replace function public.complete_pos_sale(p_business_id uuid,p_employee_id uuid,p_total numeric,p_payment_method text,p_items jsonb)
returns void language sql security invoker set search_path='' as $$
select private.complete_pos_sale(p_business_id,p_employee_id,p_total,p_payment_method,p_items)
$$;

-- Distributed fixed-window limiter; not exposed through the Data API.
create table private.angel_request_windows (
 user_id uuid primary key references auth.users(id) on delete cascade,
 window_start timestamptz not null, requests integer not null
);
alter table private.angel_request_windows enable row level security;
revoke all on private.angel_request_windows from public,anon,authenticated;
create or replace function public.consume_angel_request(p_user_id uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare count integer; begin
 insert into private.angel_request_windows as w values(p_user_id,clock_timestamp(),1)
 on conflict(user_id) do update set
 requests=case when w.window_start<clock_timestamp()-interval '1 minute' then 1 else w.requests+1 end,
 window_start=case when w.window_start<clock_timestamp()-interval '1 minute' then clock_timestamp() else w.window_start end
 returning requests into count;
 return count<=20;
end $$;
revoke all on function public.consume_angel_request(uuid) from public,anon,authenticated;
grant execute on function public.consume_angel_request(uuid) to service_role;

-- Exact aggregates complement bounded detail samples sent to Angel.
create or replace function public.angel_sales_summary(p_business_id uuid,p_day_start timestamptz)
returns jsonb language sql stable security invoker set search_path='' as $$
 select jsonb_build_object('sales_count_30d',count(*),
   'revenue_30d',coalesce(sum(coalesce(total,total_amount,0)),0),
   'sales_count_today',count(*) filter(where created_at>=p_day_start and created_at<p_day_start+interval '1 day'),
   'revenue_today',coalesce(sum(coalesce(total,total_amount,0)) filter(where created_at>=p_day_start and created_at<p_day_start+interval '1 day'),0))
 from public.sales where business_id=p_business_id and status='completed'
 and created_at>=now()-interval '30 days'
$$;
revoke all on function public.angel_sales_summary(uuid,timestamptz) from public,anon,authenticated;
grant execute on function public.angel_sales_summary(uuid,timestamptz) to service_role;
