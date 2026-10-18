-- Staging-discovered forward recovery. Apply after all three Batch 2 migrations.
-- No data rewrite; preserve original migration checksums and failed-test evidence.
begin;
create or replace function private.can_read_membership(business uuid,member_user uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select public.user_owns_business(business) or member_user=auth.uid() or
 exists(select 1 from public.employees e where e.business_id=business and e.user_id=member_user
        and private.can_read_staff(e.business_id,e.id))
$$;
revoke all on function private.can_read_membership(uuid,uuid) from public,anon;
grant execute on function private.can_read_membership(uuid,uuid) to authenticated;
alter policy "Membership read scope" on public.business_members
 using(private.can_read_membership(business_id,user_id));
-- PostgreSQL 17 MAINTAIN is inherited from the recovered broad table grants.
-- Clients have no application need for maintenance; remove it explicitly.
do $$ declare t text; begin
 for t in select c.relname from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
 where n.nspname='public' and c.relkind in ('r','p') loop
 execute format('revoke maintain on public.%I from anon,authenticated',t);
 end loop;
end $$;
alter default privileges in schema public revoke maintain on tables from anon,authenticated;
notify pgrst,'reload schema';
commit;
