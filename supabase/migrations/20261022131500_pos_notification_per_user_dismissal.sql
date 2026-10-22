-- Prepared only. Review and approve before production deployment.
-- Hiding a notification is per-user; no business alert, event, sale or
-- operational request is removed. Existing read receipts are preserved.
set lock_timeout = '5s';
set statement_timeout = '30s';

alter table public.trexven_notification_reads
  add column if not exists dismissed_at timestamptz;

-- Keep existing POS feed authorization, order, pagination and read behavior.
-- Exclude only the current user's dismissed keys.
create or replace function public.get_pos_notifications(
  p_business_id uuid,
  p_branch_id uuid default null,
  p_offset integer default 0
) returns jsonb
language plpgsql security definer
set search_path to ''
as $$
declare result jsonb;
begin
 if p_offset is null or p_offset < 0 or p_offset > 100000 then
   raise exception 'Invalid notification page' using errcode='22023';
 end if;
 select coalesce(jsonb_agg(to_jsonb(t) order by t.occurred_at desc nulls last,t.alert_key),'[]'::jsonb)
 into result from (
  select n.*,r.read_at
  from private.pos_notification_feed(p_business_id,p_branch_id) n
  left join public.trexven_notification_reads r
    on r.business_id=p_business_id and r.user_id=auth.uid()
   and r.alert_key=n.alert_key
  where r.dismissed_at is null
  order by n.occurred_at desc nulls last,n.alert_key
  limit 100 offset p_offset
 ) t;
 return result;
end
$$;

create function public.dismiss_pos_notification(
  p_business_id uuid,
  p_alert_key text,
  p_branch_id uuid default null
) returns void
language plpgsql security definer
set search_path to ''
as $$
begin
  if auth.uid() is null or p_business_id is null
    or p_alert_key is null or length(p_alert_key) < 1
    or length(p_alert_key) > 120 then
    raise exception 'Active authorized notification required' using errcode='42501';
  end if;

  -- Feed verifies the active POS context and the current branch/permissions.
  -- An arbitrary notification ID is never sufficient to obtain access.
  if not exists (
    select 1 from private.pos_notification_feed(p_business_id,p_branch_id) n
     where n.alert_key=p_alert_key
  ) then
    raise exception 'Current authorized notification required' using errcode='42501';
  end if;

  insert into public.trexven_notification_reads(
    business_id,user_id,alert_key,read_at,dismissed_at
  ) values (
    p_business_id,auth.uid(),p_alert_key,private.business_timestamp(),
    private.business_timestamp()
  )
  on conflict (business_id,user_id,alert_key)
    do update set dismissed_at=excluded.dismissed_at;
end
$$;

revoke all on function public.dismiss_pos_notification(uuid,text,uuid)
from public,anon,authenticated;
grant execute on function public.dismiss_pos_notification(uuid,text,uuid)
to authenticated;

comment on function public.dismiss_pos_notification(uuid,text,uuid) is
  'Hides an authorized POS notification for the current authenticated user only; does not delete its underlying event or any other users read state.';
