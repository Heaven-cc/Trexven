-- ============================================================================
-- Delta migration against the ALREADY-EXISTING production schema.
--
-- This project's live Supabase database already has a full, mature schema
-- (businesses, employees, products, sales, cameras, camera_events, alerts,
-- inventory, financial_transactions, angel_conversations, etc.) that was
-- never captured in this repo's migrations. This file does NOT recreate any
-- of that — it only adds what's genuinely missing and fixes two concrete
-- bugs discovered while wiring the vision backend + camera-ai to it:
--
-- 1. `alerts.severity` only allowed ('info','warning','critical'), but
--    get_camera_activity_summary() already filters on severity IN
--    ('high','critical') — i.e. 'high' was always the intended vocabulary
--    for elevated camera_events, the alerts table just hadn't caught up.
--    Left as-is, any 'high' severity event (loitering, restricted-zone
--    entry) would fail the alerts insert inside trg_camera_event_alert and
--    roll back the whole camera_events insert.
-- 2. Storage buckets for recordings/snapshots never existed, so the vision
--    backend's upload calls were failing silently (best-effort try/except).
-- 3. Realtime was only enabled for camera_events/camera_detections, so
--    every `.stream()` call in the Flutter app on cameras/alerts/products/
--    sales was silently never receiving updates.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. Widen alerts.severity to also accept 'low' / 'medium' / 'high', and
--    make the camera_events -> alerts trigger fire on 'high' too (not just
--    'warning'/'critical'), matching get_camera_activity_summary()'s
--    existing convention.
-- ----------------------------------------------------------------------------
alter table public.alerts drop constraint if exists alerts_severity_check;
alter table public.alerts add constraint alerts_severity_check
  check (severity = any (array['info', 'low', 'medium', 'warning', 'high', 'critical']));

create or replace function public.camera_event_to_alert()
returns trigger
language plpgsql
security definer
as $function$
begin
  if new.severity in ('warning', 'high', 'critical') then
    insert into public.alerts(
      business_id,
      alert_type,
      title,
      message,
      severity,
      source,
      reference_id
    ) values (
      new.business_id,
      new.event_type,
      coalesce(new.event_type, 'AI Event'),
      coalesce(new.description, 'AI detected an event on your camera.'),
      new.severity,
      'camera_ai',
      new.id
    );
  end if;
  return new;
end;
$function$;

-- ----------------------------------------------------------------------------
-- 2. Storage buckets the vision backend and camera-ai need. Private —
--    recordings/snapshots are only ever shared via short-lived signed URLs
--    generated server-side with the service role key.
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
values ('recordings', 'recordings', false)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('event-snapshots', 'event-snapshots', false)
on conflict (id) do nothing;

-- ----------------------------------------------------------------------------
-- 3. Realtime: add the tables the Flutter app subscribes to via `.stream()`
--    that weren't already in the publication.
-- ----------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array['public.cameras', 'public.alerts', 'public.products', 'public.sales']
  loop
    begin
      execute format('alter publication supabase_realtime add table %s', t);
    exception when duplicate_object then
      null;
    end;
  end loop;
end $$;
