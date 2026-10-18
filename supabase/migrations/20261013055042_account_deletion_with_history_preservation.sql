-- Source only. Do not apply to a shared environment without deployment approval.
-- No existing account is changed by installing this migration.
begin;

create table private.account_deletion_state (
  user_id uuid primary key,
  request_id uuid not null unique,
  recovery_hash text not null check (recovery_hash ~ '^[0-9a-f]{64}$'),
  status text not null default 'prepared' check (status in ('prepared','deleted')),
  lease_id uuid,
  lease_until timestamptz,
  prepared_at timestamptz not null default now(),
  deleted_at timestamptz
);
alter table private.account_deletion_state enable row level security;
revoke all on private.account_deletion_state from public,anon,authenticated,service_role;

create function public.trexven_account_access_allowed()
returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid() is null or (
   not exists(select 1 from private.account_deletion_state d where d.user_id=auth.uid())
   and not exists(select 1 from auth.users u where u.id=auth.uid() and u.deleted_at is not null)
 )
$$;
revoke all on function public.trexven_account_access_allowed() from public;
grant execute on function public.trexven_account_access_allowed() to anon,authenticated,service_role;

-- Preserve the complete existing permission bodies; wrap rather than substitute
-- role defaults, branch checks or owner/employee grants.
do $guard_helpers$
declare signature text; original text; clone_name text; original_name text;
begin
 foreach signature in array array[
   'public.user_owns_business(uuid)',
   'public.is_business_member(uuid)',
   'private.has_business_permission(uuid,text)'
 ] loop
   select pg_get_functiondef(signature::regprocedure) into original;
   original_name:=split_part(signature,'(',1);
   clone_name:='private.account_deletion_previous_'||split_part(original_name,'.',2);
   if position('CREATE OR REPLACE FUNCTION '||original_name||'(' in original)<>1 then
     raise exception 'Account deletion helper signature drift: %',signature;
   end if;
   execute replace(original,'CREATE OR REPLACE FUNCTION '||original_name||'(',
                   'CREATE OR REPLACE FUNCTION '||clone_name||'(');
 end loop;
end
$guard_helpers$;
revoke all on function private.account_deletion_previous_user_owns_business(uuid),
 private.account_deletion_previous_is_business_member(uuid),
 private.account_deletion_previous_has_business_permission(uuid,text)
 from public,anon,authenticated,service_role;

create or replace function public.user_owns_business(target_business_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select public.trexven_account_access_allowed()
 and private.account_deletion_previous_user_owns_business(target_business_id)
$$;
create or replace function public.is_business_member(target_business_id uuid)
returns boolean language sql stable security definer set search_path='' as $$
 select public.trexven_account_access_allowed()
 and private.account_deletion_previous_is_business_member(target_business_id)
$$;
create or replace function private.has_business_permission(business uuid,permission text)
returns boolean language sql stable security definer set search_path='' as $$
 select public.trexven_account_access_allowed()
 and private.account_deletion_previous_has_business_permission(business,permission)
$$;

-- Supplement existing policies without granting new access or disabling RLS.
-- Direct table reads, Storage and Realtime cannot reuse the closed account JWT.
do $restrict_tables$
declare item record;
begin
 for item in select n.nspname,c.relname from pg_class c join pg_namespace n on n.oid=c.relnamespace
   where (n.nspname='public' or (n.nspname='storage' and c.relname in ('objects','buckets')))
   and c.relrowsecurity and c.relkind in ('r','p')
 loop
   execute format('create policy "TREXVEN closed account boundary" on %I.%I as restrictive for all to authenticated using ((select public.trexven_account_access_allowed())) with check ((select public.trexven_account_access_allowed()))',item.nspname,item.relname);
 end loop;
end
$restrict_tables$;

-- REST SECURITY DEFINER RPCs can bypass row policies. Guard their entry too,
-- preserving any already configured pre-request hook in its original role.
create table private.account_deletion_api_hook(previous_hook text);
alter table private.account_deletion_api_hook enable row level security;
revoke all on private.account_deletion_api_hook from public,anon,authenticated,service_role;
create function public.trexven_previous_api_hook()
returns text language sql stable security definer set search_path='' as $$
 select previous_hook from private.account_deletion_api_hook limit 1
$$;
create function public.trexven_guard_account_access()
returns void language plpgsql security invoker set search_path='' as $$
declare previous text;
begin
 if auth.uid() is not null then
   -- Hold admission until the entire REST transaction finishes. Preparation's
   -- exclusive lock waits for admitted writes before checking business blockers.
   perform pg_advisory_xact_lock_shared(hashtextextended(auth.uid()::text||':account-deletion',0));
 end if;
 if not public.trexven_account_access_allowed() then
   raise exception 'This account has been deleted or is completing deletion.' using errcode='42501';
 end if;
 previous:=public.trexven_previous_api_hook();
 if previous is not null and previous<>'' then
   execute format('select %s()', (previous||'()')::regprocedure::regproc);
 end if;
end
$$;
revoke all on function public.trexven_previous_api_hook(),public.trexven_guard_account_access() from public;
grant execute on function public.trexven_previous_api_hook(),public.trexven_guard_account_access() to anon,authenticated,service_role;
do $configure_api$
declare previous text;
begin
 select substr(setting,length('pgrst.db_pre_request=')+1) into previous
 from pg_db_role_setting s cross join lateral unnest(s.setconfig) setting
 where s.setrole=(select oid from pg_roles where rolname='authenticator')
 and s.setdatabase in (0,(select oid from pg_database where datname=current_database()))
 and setting like 'pgrst.db_pre_request=%'
 order by s.setdatabase desc limit 1;
 if previous='public.trexven_guard_account_access' then raise exception 'Account deletion hook already installed';end if;
 if previous is not null and previous<>'' and to_regprocedure(previous||'()') is null then
   raise exception 'Existing API hook cannot be preserved';
 end if;
 insert into private.account_deletion_api_hook values(previous);
 execute format('alter role authenticator in database %I set pgrst.db_pre_request = %L',current_database(),'public.trexven_guard_account_access');
end
$configure_api$;

-- Only the authenticated server handler receives these RPC grants. The caller
-- cannot submit another user ID directly or inspect the recovery hashes.
create function public.begin_trexven_account_deletion(p_user_id uuid,p_request_id uuid,p_recovery_hash text)
returns void language plpgsql security definer set search_path='' as $$
declare prior private.account_deletion_state%rowtype; businesses uuid[]; b uuid;
begin
 if p_user_id is null or p_request_id is null or p_recovery_hash is null
 or p_recovery_hash!~'^[0-9a-f]{64}$' then raise exception 'ACCOUNT_DELETION_INVALID_INPUT';end if;
 perform pg_advisory_xact_lock(hashtextextended(p_user_id::text||':account-deletion',0));
 select * into prior from private.account_deletion_state where user_id=p_user_id for update;
 if found then
   if prior.request_id<>p_request_id or prior.recovery_hash<>p_recovery_hash then raise exception 'ACCOUNT_DELETION_CONFLICT';end if;
   return;
 end if;
 if not exists(select 1 from auth.users where id=p_user_id and deleted_at is null) then
   raise exception 'ACCOUNT_DELETION_INVALID_USER';
 end if;
 -- Serialize preparation with existing operations that take business locks.
 perform id from public.businesses where owner_id=p_user_id order by id for update;
 select coalesce(array_agg(id),'{}'::uuid[]) into businesses from public.businesses where owner_id=p_user_id;
 if exists(select 1 from public.business_members where business_id=any(businesses) and user_id is distinct from p_user_id and status='active')
 or exists(select 1 from public.employees where business_id=any(businesses) and user_id is distinct from p_user_id and status='active') then
   raise exception 'ACCOUNT_DELETION_ACTIVE_USERS';
 end if;
 if exists(select 1 from public.cash_shifts where business_id=any(businesses) and (status='open' or review_status='pending'))
 or exists(select 1 from public.cash_shifts s where s.status='open' and (s.opened_by=p_user_id or exists(
   select 1 from public.cash_shift_members sm join public.business_members m on m.id=sm.member_id
   where sm.shift_id=s.id and m.user_id=p_user_id))) then
   raise exception 'ACCOUNT_DELETION_OPEN_SHIFT';
 end if;
 if exists(select 1 from public.credit_approvals where business_id=any(businesses) and status='pending')
 or exists(select 1 from public.sale_returns where business_id=any(businesses) and status in ('requested','inspected'))
 or exists(select 1 from public.stocktake_sessions where business_id=any(businesses) and status in ('open','review'))
 or exists(select 1 from public.cash_handovers where (business_id=any(businesses) or requested_by=p_user_id) and status='pending')
 or exists(select 1 from public.inventory_reconciliation_reviews where business_id=any(businesses) and status='pending')
 or exists(select 1 from public.supplier_stock_returns where business_id=any(businesses) and status='dispatched') then
   raise exception 'ACCOUNT_DELETION_PENDING_REVIEW';
 end if;
 if exists(select 1 from public.credit_accounts where business_id=any(businesses) and outstanding>0) then
   raise exception 'ACCOUNT_DELETION_OUTSTANDING_CREDIT';
 end if;
 insert into private.account_deletion_state(user_id,request_id,recovery_hash) values(p_user_id,p_request_id,p_recovery_hash);
 foreach b in array businesses loop
   insert into public.audit_logs(business_id,actor_id,action,metadata)
   values(b,p_user_id,'account_deletion_prepared',jsonb_build_object('request_id',p_request_id,'financial_records_preserved',true));
 end loop;
end
$$;

create function public.claim_trexven_account_deletion(p_request_id uuid,p_recovery_hash text,p_lease uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare d private.account_deletion_state%rowtype;
begin
 if p_lease is null then raise exception 'ACCOUNT_DELETION_INVALID_INPUT';end if;
 select * into d from private.account_deletion_state where request_id=p_request_id and recovery_hash=p_recovery_hash for update;
 if not found then raise exception 'ACCOUNT_DELETION_NOT_FOUND';end if;
 if d.status='deleted' then return jsonb_build_object('status','deleted');end if;
 if d.lease_until>now() then return jsonb_build_object('status','processing');end if;
 update private.account_deletion_state set lease_id=p_lease,lease_until=now()+interval '90 seconds' where user_id=d.user_id;
 return jsonb_build_object('status','prepared','user_id',d.user_id);
end
$$;

create function public.release_trexven_account_deletion(p_request_id uuid,p_lease uuid)
returns void language sql security definer set search_path='' as $$
 update private.account_deletion_state set lease_id=null,lease_until=null
 where request_id=p_request_id and lease_id=p_lease and status='prepared'
$$;

create function public.finish_trexven_account_deletion(p_request_id uuid,p_lease uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare d private.account_deletion_state%rowtype; b uuid;
begin
 select * into d from private.account_deletion_state where request_id=p_request_id for update;
 if not found then raise exception 'ACCOUNT_DELETION_NOT_FOUND';end if;
 if d.status='deleted' then return jsonb_build_object('status','deleted');end if;
 if d.lease_id is distinct from p_lease or not exists(select 1 from auth.users where id=d.user_id and deleted_at is not null) then
   raise exception 'ACCOUNT_DELETION_AUTH_UNCONFIRMED';
 end if;
 -- These are personal account fields/content, not financial transaction data.
 update public.business_members set full_name='Deleted account',email=null,phone=null,status='inactive',updated_at=now() where user_id=d.user_id;
 update public.employees set name='Deleted account',email=null,phone=null,status='inactive',updated_at=now() where user_id=d.user_id;
 delete from public.angel_conversations where user_id=d.user_id;
 for b in select id from public.businesses where owner_id=d.user_id loop
   insert into public.audit_logs(business_id,actor_id,action,metadata)
   values(b,d.user_id,'account_deleted',jsonb_build_object('request_id',p_request_id,'financial_records_preserved',true));
 end loop;
 update private.account_deletion_state set status='deleted',deleted_at=now(),lease_id=null,lease_until=null where user_id=d.user_id;
 return jsonb_build_object('status','deleted');
end
$$;

revoke all on function public.begin_trexven_account_deletion(uuid,uuid,text),
 public.claim_trexven_account_deletion(uuid,text,uuid),public.release_trexven_account_deletion(uuid,uuid),
 public.finish_trexven_account_deletion(uuid,uuid) from public,anon,authenticated;
grant execute on function public.begin_trexven_account_deletion(uuid,uuid,text),
 public.claim_trexven_account_deletion(uuid,text,uuid),public.release_trexven_account_deletion(uuid,uuid),
 public.finish_trexven_account_deletion(uuid,uuid) to service_role;

notify pgrst,'reload config';
notify pgrst,'reload schema';
commit;
