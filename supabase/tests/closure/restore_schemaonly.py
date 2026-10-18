from pathlib import Path
import json,subprocess,os
s=json.loads(Path('supabase/tests/baseline/BATCH_2_CLOSURE_STAGING_CATALOG.json').read_text());p=Path('.batch2-tools/schemaonly_prepare.sql')
admin={**os.environ,'BATCH2_DISPOSABLE_USER':'supabase_admin'}
p.write_text('create database trexven_b2_schemaonly template trexven_b2_replay2 owner postgres;');r=subprocess.run(['python','.batch2-tools/native_sql.py',str(p)],env=admin,capture_output=True,text=True);assert r.returncode==0,r.stderr
q="begin; do $$ begin if current_database()<>'trexven_b2_schemaonly' or exists(select 1 from auth.users) or exists(select 1 from public.businesses) then raise exception 'Empty disposable schema recovery target required'; end if; end $$; drop schema private cascade; drop schema public cascade; drop schema supabase_migrations cascade; create schema public authorization pg_database_owner; grant usage on schema public to postgres,anon,authenticated,service_role;"
for d in s['acl']['defaults']:
 if d['owner']!='supabase_admin':continue
 category={'r':'TABLES','f':'FUNCTIONS','S':'SEQUENCES'}[d['kind']]
 for v in d['privileges']:
  q+=f"alter default privileges for role supabase_admin in schema public grant {v['privilege']} on {category} to {v['role']};"
q+='commit;';p.write_text(q)
target={**admin,'BATCH2_DISPOSABLE_DATABASE':'trexven_b2_schemaonly'};r=subprocess.run(['python','.batch2-tools/native_sql.py',str(p)],env=target,capture_output=True,text=True);Path('docs/implementation/evidence/batch_2_closure_schemaonly_prepare.log').write_text(r.stdout+r.stderr);assert r.returncode==0,r.stderr
source=Path('supabase/tests/baseline/BATCH_2_CLOSURE_RECOVERY_CHECKPOINT.sql').read_text();source=source.replace("current_setting('trexven.staging_project_ref', true) IS DISTINCT FROM 'qysspzlfiysekvxnlzsh'", "current_database() IS DISTINCT FROM 'trexven_b2_schemaonly'")
p.write_text(source);r=subprocess.run(['python','.batch2-tools/native_sql.py',str(p)],env={**os.environ,'BATCH2_DISPOSABLE_DATABASE':'trexven_b2_schemaonly'},capture_output=True,text=True);Path('docs/implementation/evidence/batch_2_closure_schemaonly_restore.log').write_text(r.stdout+r.stderr);print('Schema-only checkpoint actual restore',r.returncode)
if r.returncode:print(r.stderr)
assert r.returncode==0
