-- Enrich the existing authorized feed without changing recipients, routes,
-- pagination, alert keys, or per-user read acknowledgements.
create or replace function public.get_trexven_notifications(
  p_business_id uuid,
  p_application text default 'pos',
  p_offset integer default 0
) returns jsonb
language plpgsql stable security definer set search_path = ''
as $function$
declare result jsonb;
begin
  if p_offset is null or p_offset < 0 or p_offset > 100000 then
    raise exception 'Invalid notification page';
  end if;
  select coalesce(jsonb_agg(t.payload order by t.occurred_at desc nulls last, t.alert_key), '[]'::jsonb)
    into result
  from (
    select n.occurred_at, n.alert_key,
      to_jsonb(n) || jsonb_build_object('read_at', r.read_at) ||
      case when p_application = 'owner' and a.id is not null then
        jsonb_build_object(
          'employee_name', coalesce(e.name, 'Former employee'),
          'actor_name', case when a.actor_id = b.owner_id then 'Business owner'
            else coalesce(actor.name, 'Team member') end,
          'action', a.action,
          'details', jsonb_strip_nulls(jsonb_build_object(
            'permission', a.metadata -> 'permission',
            'granted', a.metadata -> 'granted',
            'role', a.metadata -> 'role',
            'old_role', a.metadata -> 'old_role',
            'status', a.metadata -> 'status'
          ))
        )
      else '{}'::jsonb end as payload
    -- This function remains the sole authority for notification visibility.
    from private.trexven_visible_notifications(p_business_id, p_application) n
    left join public.trexven_notification_reads r
      on r.business_id = p_business_id and r.user_id = auth.uid()
      and r.alert_key = n.alert_key
    left join public.audit_logs a
      on p_application = 'owner' and a.business_id = p_business_id
      and n.alert_key = 'staff:' || a.id::text
      and a.action in ('employee_updated', 'employee_permission_changed', 'employee_status_changed')
    left join public.employees e on e.business_id = p_business_id and e.id = a.target_id
    left join public.businesses b on b.id = p_business_id
    left join lateral (
      select staff.name from public.employees staff
      where staff.business_id = p_business_id and staff.user_id = a.actor_id
      order by staff.id limit 1
    ) actor on a.id is not null
    order by n.occurred_at desc nulls last, n.alert_key
    limit 100 offset p_offset
  ) t;
  return result;
end
$function$;

revoke all on function public.get_trexven_notifications(uuid, text, integer) from public, anon;
grant execute on function public.get_trexven_notifications(uuid, text, integer) to authenticated;
