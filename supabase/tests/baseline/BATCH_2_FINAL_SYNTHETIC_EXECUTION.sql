-- Historical execution evidence, not a migration or replay-ready fixture.
-- Staging qysspzlfiysekvxnlzsh ONLY. All listed synthetic identities were removed.
-- Fresh runs require fresh identities; never use these statements on production.
create or replace function public.batch_2_test_hold_product(p_change_price boolean) returns void language plpgsql security definer set search_path='' as $$ begin
if auth.uid() is distinct from '42e9a313-0a26-4221-8e82-98c8ce841cec'::uuid or not public.user_owns_business('d6010483-3796-44e6-b553-63cbb93ebaa4') then raise exception 'Synthetic owner required' using errcode='42501'; end if;
perform id from public.products where id='c18897a0-6d30-4c17-b838-46b9e4549d49' and business_id='d6010483-3796-44e6-b553-63cbb93ebaa4' for update;
if p_change_price then update public.products set selling_price=11 where id='c18897a0-6d30-4c17-b838-46b9e4549d49'; end if;
perform pg_catalog.pg_sleep(2);
end $$; revoke all on function public.batch_2_test_hold_product(boolean) from public,anon; grant execute on function public.batch_2_test_hold_product(boolean) to authenticated; notify pgrst,'reload schema';

create function public.batch_2_test_hold_ready() returns boolean language sql security definer set search_path='' as $$
select auth.uid()='42e9a313-0a26-4221-8e82-98c8ce841cec'::uuid and exists(select 1 from pg_catalog.pg_stat_activity where pid<>pg_catalog.pg_backend_pid() and wait_event='PgSleep' and query like '%batch_2_test_hold_product%')
$$; revoke all on function public.batch_2_test_hold_ready() from public,anon; grant execute on function public.batch_2_test_hold_ready() to authenticated; notify pgrst,'reload schema';

begin;
set local request.jwt.claim.sub='';
update public.businesses set branches_enabled=true where id='d6010483-3796-44e6-b553-63cbb93ebaa4' and business_name='Synthetic Checkpoint B REST';
insert into public.inventory(business_id,branch_id,product_id,quantity) values('d6010483-3796-44e6-b553-63cbb93ebaa4','f74a79f9-2a10-4227-bbb5-a10764557f81','c18897a0-6d30-4c17-b838-46b9e4549d49',5);
select set_config('request.jwt.claim.sub','42e9a313-0a26-4221-8e82-98c8ce841cec',true);
select public.set_trexven_branch_assignment('46ca02e6-b70f-4d7d-8b53-ca1032d5a804','f74a79f9-2a10-4227-bbb5-a10764557f81',true);
select public.set_trexven_branch_assignment('84690c60-dabe-482c-b0af-1308acbc0809','b6b805fd-44c2-4c33-bdc2-8a108d91c1e8',true);
select public.set_trexven_branch_assignment('ad6eb639-e6d6-43d7-859c-9a6f5d506fb5','f74a79f9-2a10-4227-bbb5-a10764557f81',true);
commit;

begin;set local request.jwt.claim.sub='';
update public.businesses set timezone='America/New_York' where id='d6010483-3796-44e6-b553-63cbb93ebaa4';
create temporary table final_boundaries(tag text,id uuid,sold_at timestamptz);
insert into final_boundaries select tag,gen_random_uuid(),(date_trunc('day',current_timestamp at time zone 'America/New_York') at time zone 'America/New_York') + delta from (values('previous',interval '-1 microsecond'),('current',interval '0 seconds'),('next',interval '1 day')) t(tag,delta);
insert into public.sales(id,business_id,employee_id,total_amount,total,quantity,unit_price,payment_method,sold_at,created_at,branch_id) select id,'d6010483-3796-44e6-b553-63cbb93ebaa4','ed2d16a0-6857-4422-aa71-6b863a6480a1',10,10,1,10,'cash',sold_at,sold_at,'b6b805fd-44c2-4c33-bdc2-8a108d91c1e8' from final_boundaries;
select jsonb_object_agg(tag,id) as ids from final_boundaries;
commit;

-- Exact synthetic whitelist; execute only after independent target/data verification.
begin;
set local request.jwt.claim.sub='';
do $$ begin
if (select count(*) from auth.users)<>7 or exists(select 1 from auth.users where id not in ('42e9a313-0a26-4221-8e82-98c8ce841cec','db515925-79c7-4479-b080-4cd9bd73928d','fb147513-f822-44f5-a408-2d0b3c3d17e0','ead9e444-7f29-4fbb-a7c4-d5e4fd7b3318','9e133b5b-e88e-4af9-b4c0-f10272d303d1','e34d6cc3-2675-4ad7-97eb-758359fb0dce','26c37d18-7572-4102-9fcd-b6363ab99afa')) or exists(select 1 from public.businesses where id not in ('d6010483-3796-44e6-b553-63cbb93ebaa4','acfca674-6605-45d3-b6d2-9b968d7a5fd0')) then raise exception 'Unexpected staging records; cleanup refused'; end if;
end $$;
delete from auth.sessions where user_id in ('42e9a313-0a26-4221-8e82-98c8ce841cec','db515925-79c7-4479-b080-4cd9bd73928d','fb147513-f822-44f5-a408-2d0b3c3d17e0','ead9e444-7f29-4fbb-a7c4-d5e4fd7b3318','9e133b5b-e88e-4af9-b4c0-f10272d303d1','e34d6cc3-2675-4ad7-97eb-758359fb0dce','26c37d18-7572-4102-9fcd-b6363ab99afa');
drop trigger batch_2_final_forced_failure on public.employees;
drop function private.batch_2_final_force_employee_failure();
drop function public.batch_2_test_hold_ready();
drop function public.batch_2_test_hold_product(boolean);
delete from private.sale_requests where business_id in ('d6010483-3796-44e6-b553-63cbb93ebaa4','acfca674-6605-45d3-b6d2-9b968d7a5fd0');
delete from public.sale_items where sale_id in(select id from public.sales where business_id in ('d6010483-3796-44e6-b553-63cbb93ebaa4','acfca674-6605-45d3-b6d2-9b968d7a5fd0'));
delete from public.sales where business_id in ('d6010483-3796-44e6-b553-63cbb93ebaa4','acfca674-6605-45d3-b6d2-9b968d7a5fd0');
delete from public.inventory_movements where business_id in ('d6010483-3796-44e6-b553-63cbb93ebaa4','acfca674-6605-45d3-b6d2-9b968d7a5fd0');
delete from public.inventory where business_id in ('d6010483-3796-44e6-b553-63cbb93ebaa4','acfca674-6605-45d3-b6d2-9b968d7a5fd0');
delete from public.employee_permissions where employee_id in(select id from public.employees where business_id in ('d6010483-3796-44e6-b553-63cbb93ebaa4','acfca674-6605-45d3-b6d2-9b968d7a5fd0'));
delete from public.employee_branch_assignments where business_id in ('d6010483-3796-44e6-b553-63cbb93ebaa4','acfca674-6605-45d3-b6d2-9b968d7a5fd0');
delete from public.audit_logs where business_id in ('d6010483-3796-44e6-b553-63cbb93ebaa4','acfca674-6605-45d3-b6d2-9b968d7a5fd0');
delete from public.products where business_id in ('d6010483-3796-44e6-b553-63cbb93ebaa4','acfca674-6605-45d3-b6d2-9b968d7a5fd0');
delete from public.employees where business_id in ('d6010483-3796-44e6-b553-63cbb93ebaa4','acfca674-6605-45d3-b6d2-9b968d7a5fd0');
delete from public.business_members where business_id in ('d6010483-3796-44e6-b553-63cbb93ebaa4','acfca674-6605-45d3-b6d2-9b968d7a5fd0');
update public.businesses set compatibility_branch_id=null where id in ('d6010483-3796-44e6-b553-63cbb93ebaa4','acfca674-6605-45d3-b6d2-9b968d7a5fd0');
delete from public.branches where business_id in ('d6010483-3796-44e6-b553-63cbb93ebaa4','acfca674-6605-45d3-b6d2-9b968d7a5fd0');
delete from public.business_settings where business_id in ('d6010483-3796-44e6-b553-63cbb93ebaa4','acfca674-6605-45d3-b6d2-9b968d7a5fd0');
delete from public.businesses where id in ('d6010483-3796-44e6-b553-63cbb93ebaa4','acfca674-6605-45d3-b6d2-9b968d7a5fd0');
delete from auth.users where id in ('42e9a313-0a26-4221-8e82-98c8ce841cec','db515925-79c7-4479-b080-4cd9bd73928d','fb147513-f822-44f5-a408-2d0b3c3d17e0','ead9e444-7f29-4fbb-a7c4-d5e4fd7b3318','9e133b5b-e88e-4af9-b4c0-f10272d303d1','e34d6cc3-2675-4ad7-97eb-758359fb0dce','26c37d18-7572-4102-9fcd-b6363ab99afa');
notify pgrst,'reload schema';
commit;

