-- Business-local dates use trusted database time and configured IANA zones.
-- No timezone backfill and no historical timestamp rewrite.
begin;
create function private.business_timestamp()
returns timestamptz language sql stable security invoker set search_path='' as $$
 select current_timestamp
$$;
revoke all on function private.business_timestamp() from public,anon,authenticated;

create or replace function private.sales_history_access(business uuid,sold_at timestamptz)
returns boolean language sql stable security definer set search_path='' as $$
 select public.user_owns_business(business) or (private.has_business_permission(business,'pos_access') and
 (private.has_business_permission(business,'view_finance') or exists(select 1 from public.businesses b
 join pg_catalog.pg_timezone_names tz on tz.name=b.timezone where b.id=business
 and (sold_at at time zone b.timezone)::date=(private.business_timestamp() at time zone b.timezone)::date)))
$$;

create function public.get_trexven_business_day(p_business_id uuid)
returns jsonb language plpgsql stable security definer set search_path='' as $$
declare zone text; local_date date;
begin
 if auth.uid() is null or not (public.user_owns_business(p_business_id)
  or private.has_business_permission(p_business_id,'pos_access')) then
   raise exception 'Business access denied' using errcode='42501';
 end if;
 select b.timezone into zone from public.businesses b
 join pg_catalog.pg_timezone_names tz on tz.name=b.timezone where b.id=p_business_id;
 if zone is null then raise exception 'Configure a valid business timezone before requesting daily sales'; end if;
 local_date := (private.business_timestamp() at time zone zone)::date;
 return jsonb_build_object('timezone',zone,'local_date',local_date,
  'starts_at',local_date::timestamp at time zone zone,
  'ends_at',(local_date+1)::timestamp at time zone zone);
end $$;
revoke all on function public.get_trexven_business_day(uuid) from public,anon;
grant execute on function public.get_trexven_business_day(uuid) to authenticated;
notify pgrst,'reload schema';
commit;
