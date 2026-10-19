-- Operational device activity only; never an authorization source.
create table public.pos_device_activity(
 business_id uuid not null references public.businesses(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade,
 device_id uuid not null,
 member_id uuid not null references public.business_members(id) on delete cascade,
 branch_id uuid references public.branches(id) on delete set null,
 platform text not null,
 last_seen_at timestamptz not null default now(),
 primary key(business_id,user_id,device_id)
);
alter table public.pos_device_activity enable row level security;
revoke all on public.pos_device_activity from public,anon,authenticated;
grant select on public.pos_device_activity to authenticated;
create index pos_device_member_idx on public.pos_device_activity(member_id);
create index pos_device_user_idx on public.pos_device_activity(user_id);
create index pos_device_branch_idx on public.pos_device_activity(branch_id);
create policy "Own or owner device activity" on public.pos_device_activity for select to authenticated
using ((user_id=auth.uid() or public.user_owns_business(business_id))
 and private.has_business_permission(business_id,'view_inventory'));
create function public.register_pos_device(p_business_id uuid,p_device_id uuid,p_platform text,p_branch_id uuid default null)
returns void language plpgsql security definer set search_path='' as $fn$
declare member uuid;
begin
 if p_device_id is null or p_platform is null or p_platform not in ('android','iOS','windows','macOS','linux','fuchsia','web') then
  raise exception 'Valid device and platform required';
 end if;
 if private.has_business_permission(p_business_id,'pos_access') is true then
  perform private.operations_context(p_business_id,'pos_access',p_branch_id);
 elsif private.has_business_permission(p_business_id,'view_inventory') is true then
  perform private.operations_context(p_business_id,'view_inventory',p_branch_id);
 else raise exception 'Active POS authority required' using errcode='42501';
 end if;
 select m.id into member from public.business_members m where m.business_id=p_business_id and m.user_id=auth.uid() and m.status='active';
 if member is null then raise exception 'Active membership required' using errcode='42501'; end if;
 insert into public.pos_device_activity(business_id,user_id,device_id,member_id,branch_id,platform)
 values(p_business_id,auth.uid(),p_device_id,member,p_branch_id,p_platform)
 on conflict(business_id,user_id,device_id) do update set
  member_id=excluded.member_id,branch_id=excluded.branch_id,platform=excluded.platform,last_seen_at=now();
end $fn$;
revoke all on function public.register_pos_device(uuid,uuid,text,uuid) from public,anon;
grant execute on function public.register_pos_device(uuid,uuid,text,uuid) to authenticated;
notify pgrst,'reload schema';
