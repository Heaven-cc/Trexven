-- PREPARED ONLY. Requires explicit production approval.
-- Hide hook metadata without elevating execution of a chained legacy hook.
do $guard$
declare baseline record;actual regprocedure;
begin
 for baseline in select * from (values
('trexven_account_access_allowed', '36eeecae6de42b7b5d04dbec9d35b910', '{postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}'),
('trexven_guard_account_access', '681728a9785ba0a831b32c8a167fbb76', '{postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}'),
('trexven_previous_api_hook', '738e277192bd92a9fff27ceb6698ba2b', '{postgres=X/postgres,anon=X/postgres,authenticated=X/postgres,service_role=X/postgres}')
 ) b(name,definition_md5,acl) loop
  actual:=to_regprocedure('public.'||baseline.name||'()');
  if actual is null or md5(pg_get_functiondef(actual))<>baseline.definition_md5
   or (select proacl::text from pg_proc where oid=actual) is distinct from baseline.acl then
   raise exception 'Account hook definition/ACL drift: %',baseline.name;
  end if;
 end loop;
 if to_regprocedure('public.trexven_prepare_account_request()') is not null then
  raise exception 'Request admission helper already exists; inspect its history';
 end if;
 if not exists(select 1 from pg_db_role_setting s
  join pg_database d on d.oid=s.setdatabase join pg_roles r on r.oid=s.setrole
  where d.datname=current_database() and r.rolname='authenticator'
  and 'pgrst.db_pre_request=public.trexven_guard_account_access'=any(s.setconfig)) then
  raise exception 'Configured REST pre-request hook changed';
 end if;
end $guard$;

create function public.trexven_prepare_account_request()
 returns void language plpgsql security definer set search_path='' as $fn$
begin
 if auth.uid() is not null then
   -- Hold admission until the entire REST transaction finishes. Preparation's
   -- exclusive lock waits for admitted writes before checking business blockers.
   perform pg_advisory_xact_lock_shared(hashtextextended(auth.uid()::text||':account-deletion',0));
 end if;
 if not public.trexven_account_access_allowed() then
   raise exception 'This account has been deleted or is completing deletion.' using errcode='42501';
 end if;

 -- Only a transaction-local handoff; no metadata is returned to the API caller.
 -- Always overwrite from trusted configuration before the invoker consumes it.
 perform pg_catalog.set_config('trexven.previous_api_hook',
  coalesce(public.trexven_previous_api_hook(),''),true);
end $fn$;
revoke all on function public.trexven_prepare_account_request() from public,anon,authenticated,service_role;
grant execute on function public.trexven_prepare_account_request() to anon,authenticated,service_role;

-- Keep chained legacy-hook dispatch in the SECURITY INVOKER wrapper.
CREATE OR REPLACE FUNCTION public.trexven_guard_account_access()
 RETURNS void
 LANGUAGE plpgsql
 SECURITY INVOKER
 SET search_path TO ''
AS $function$
declare previous text;
begin
 perform public.trexven_prepare_account_request();
 previous:=pg_catalog.current_setting('trexven.previous_api_hook',true);
 if previous is not null and previous<>'' then
   execute format('select %s()', (previous||'()')::regprocedure::regproc);
 end if;
end
$function$;

revoke execute on function public.trexven_previous_api_hook() from public,anon,authenticated;
-- Keep postgres/service_role administration. Do not revoke account_access_allowed,
-- change the authenticator setting, expand schema usage, or touch business data.
