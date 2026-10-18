alter function public.update_updated_at() set search_path = public;
alter function public.update_businesses_updated_at() set search_path = public;
alter function public.get_camera_dashboard(uuid) set search_path = public;
alter function public.get_camera_activity_summary(uuid,timestamptz,timestamptz) set search_path = public;

revoke execute on function public.complete_trexven_onboarding(text,text,text,text,text,text) from anon;
revoke execute on function public.record_trexven_sale(uuid,uuid,integer,numeric) from anon;
revoke execute on function public.complete_pos_sale(uuid,uuid,numeric,text,jsonb) from anon;
revoke execute on function public.update_trexven_employee(uuid,text,text,text,text,text) from anon;
revoke execute on function public.set_trexven_employee_status(uuid,text) from anon;
revoke execute on function public.camera_event_to_alert() from public, anon, authenticated;

create policy "Owners and employees can read assigned permissions"
on public.employee_permissions
for select
to authenticated
using (
  exists (
    select 1
    from public.employees e
    where e.id = employee_permissions.employee_id
      and (
        public.user_owns_business(e.business_id)
        or e.user_id = auth.uid()
      )
  )
);
