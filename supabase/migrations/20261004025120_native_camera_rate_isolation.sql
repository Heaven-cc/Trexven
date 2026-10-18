-- Camera explanations have a separate budget; Angel remains unchanged.
create table private.camera_explanation_request_windows (
 user_id uuid primary key references auth.users(id) on delete cascade,
 window_start timestamptz not null, requests integer not null
);
alter table private.camera_explanation_request_windows enable row level security;
revoke all on private.camera_explanation_request_windows from public,anon,authenticated;
grant usage on schema private to service_role;

create function private.consume_camera_explanation_request(p_user_id uuid)
returns boolean language plpgsql security definer set search_path='' as $$
declare request_count integer; begin
 if p_user_id is null then return false; end if;
 insert into private.camera_explanation_request_windows as w values(p_user_id,clock_timestamp(),1)
 on conflict(user_id) do update set
 requests=case when w.window_start<clock_timestamp()-interval '1 minute' then 1 else w.requests+1 end,
 window_start=case when w.window_start<clock_timestamp()-interval '1 minute' then clock_timestamp() else w.window_start end
 returning requests into request_count;
 return request_count<=20;
end $$;
revoke all on function private.consume_camera_explanation_request(uuid) from public,anon,authenticated;
grant execute on function private.consume_camera_explanation_request(uuid) to service_role;

create function public.consume_camera_explanation_request(p_user_id uuid)
returns boolean language sql security invoker set search_path='' as $$
select private.consume_camera_explanation_request(p_user_id)
$$;
revoke all on function public.consume_camera_explanation_request(uuid) from public,anon,authenticated;
grant execute on function public.consume_camera_explanation_request(uuid) to service_role;
