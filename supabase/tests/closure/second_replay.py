from pathlib import Path
import subprocess,json
s=json.loads(Path('.batch2-tools/native_status_windows.json').read_text());assert s['runtime']=='native'
p=Path('.batch2-tools/second_replay_prepare.sql');p.write_text('create database trexven_b2_replay2 template trexven_b2_restored owner postgres;')
import os
admin={**os.environ,'BATCH2_DISPOSABLE_USER':'supabase_admin'}
r=subprocess.run(['python','.batch2-tools/native_sql.py',str(p)],env=admin,capture_output=True,text=True);Path('docs/implementation/evidence/batch_2_closure_replay2_create.log').write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr
q='''begin;
do $$ begin
 if current_database()<>'trexven_b2_replay2' then raise exception 'Disposable database mismatch'; end if;
 if exists(select 1 from public.businesses where business_name not like 'Synthetic Closure%') then raise exception 'Unexpected business data'; end if;
 if exists(select 1 from auth.users where email not like '%@example.invalid') then raise exception 'Unexpected Auth data'; end if;
end $$;
drop schema private cascade;
drop schema public cascade;
drop schema supabase_migrations cascade;
create schema public authorization pg_database_owner;
grant usage on schema public to postgres,anon,authenticated,service_role;
alter default privileges for role supabase_admin in schema public grant all on tables to postgres,anon,authenticated,service_role;
alter default privileges for role supabase_admin in schema public grant all on sequences to postgres,anon,authenticated,service_role;
alter default privileges for role supabase_admin in schema public grant all on functions to postgres,anon,authenticated,service_role;
delete from auth.sessions; delete from auth.users;
commit;
'''
p.write_text(q);target={**admin,'BATCH2_DISPOSABLE_DATABASE':'trexven_b2_replay2'}
r=subprocess.run(['python','.batch2-tools/native_sql.py',str(p)],env=target,capture_output=True,text=True);Path('docs/implementation/evidence/batch_2_closure_replay2_clean_platform.log').write_text(r.stdout+r.stderr);print('New replay database prepare',r.returncode)
if r.returncode:print(r.stderr);raise SystemExit(r.returncode)
r=subprocess.run(['python','.batch2-tools/native_sql.py','.batch2-tools/native_preflight.sql'],env=target,capture_output=True,text=True);Path('docs/implementation/evidence/batch_2_closure_replay2_preflight.log').write_text(r.stdout+r.stderr);print(r.stdout)
r=subprocess.run(['python','.batch2-tools/native_sql.py','.batch2-tools/disposable_baseline.sql'],env={**os.environ,'BATCH2_DISPOSABLE_DATABASE':'trexven_b2_replay2'},capture_output=True,text=True);Path('docs/implementation/evidence/batch_2_closure_replay2_baseline.log').write_text(r.stdout+r.stderr);print('Second clean baseline',r.returncode)
if r.returncode:print(r.stderr);raise SystemExit(r.returncode)
