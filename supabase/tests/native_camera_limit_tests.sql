begin;
select set_config('test.camera_limit_user',gen_random_uuid()::text,true);
insert into auth.users(id,email) values(current_setting('test.camera_limit_user')::uuid,'native-camera-limit@example.invalid');
set local role service_role;
do $$ declare i integer; actor uuid:=current_setting('test.camera_limit_user')::uuid; begin
 for i in 1..20 loop
  if not public.consume_camera_explanation_request(actor) then raise exception 'Camera request incorrectly blocked'; end if;
 end loop;
 if public.consume_camera_explanation_request(actor) then raise exception 'Camera rate limit bypassed'; end if;
 if not public.consume_angel_request(actor) then raise exception 'Camera requests throttled Angel'; end if;
 if has_function_privilege('anon','public.consume_camera_explanation_request(uuid)','EXECUTE')
 or has_function_privilege('authenticated','public.consume_camera_explanation_request(uuid)','EXECUTE') then
  raise exception 'Internal camera limiter exposed to clients';
 end if;
 if public.consume_camera_explanation_request(null) then raise exception 'Missing user accepted'; end if;
end $$;
select 'PASS: independent camera and Angel budgets, service-only RPC and missing-user rejection' as verification;
rollback;
