-- EXECUTION EVIDENCE ONLY. Already removed from staging. Not a rollout migration.
-- Synthetic IDs from this completed test run; fresh fixtures require new IDs.
-- Verified staging qysspzlfiysekvxnlzsh only; no production execution permitted.
create function public.batch_2_test_hold_product(p_change_price boolean) returns void language plpgsql security definer set search_path='' as $$ begin
if auth.uid() is distinct from 'b937f252-b5d0-4a3e-aba0-3ff922a312f4'::uuid or not public.user_owns_business('92555bf0-4770-4494-a984-d5d0283c7e09') then raise exception 'Synthetic owner required' using errcode='42501'; end if;
perform id from public.products where id='0608e375-e316-49f9-9780-e7c1ea371f64' and business_id='92555bf0-4770-4494-a984-d5d0283c7e09' for update;
if p_change_price then update public.products set selling_price=11 where id='0608e375-e316-49f9-9780-e7c1ea371f64'; end if;
perform pg_catalog.pg_sleep(2);
end $$; revoke all on function public.batch_2_test_hold_product(boolean) from public,anon; grant execute on function public.batch_2_test_hold_product(boolean) to authenticated; notify pgrst,'reload schema';
create function public.batch_2_test_hold_ready() returns boolean language sql security definer set search_path='' as $$
 select auth.uid()='b937f252-b5d0-4a3e-aba0-3ff922a312f4'::uuid and exists(select 1 from pg_catalog.pg_stat_activity where pid<>pg_catalog.pg_backend_pid() and wait_event='PgSleep' and query like '%batch_2_test_hold_product%')
$$; revoke all on function public.batch_2_test_hold_ready() from public,anon; grant execute on function public.batch_2_test_hold_ready() to authenticated; notify pgrst,'reload schema';
