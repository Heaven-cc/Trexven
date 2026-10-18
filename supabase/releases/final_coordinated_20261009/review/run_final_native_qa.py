"""Fresh schema-only replay on the owned final-qa9 loopback stack.

No production credentials, URLs or customer records enter this test runner.
"""
from pathlib import Path
import hashlib
import json
import os
import subprocess
import sys
import uuid
import atexit
import re
sys.path.insert(0,str(Path(__file__).resolve().parents[2] / 'supabase/releases'))
from render_final_guarded_migration import render

ROOT = Path(__file__).resolve().parents[2]
PG = '/var/tmp/trexven-batch3-native/cache/stack/slim-services/postgres/17.11.0.004-r1/linux-amd64/bin/psql'
if os.environ.get('SUPABASE_DB_URL'):
    raise SystemExit('Remote database configuration is prohibited')
raw = (ROOT / '.batch3-tools/final_qa9_start.log').read_bytes()
log = raw.decode('utf-16' if raw.startswith(b'\xff\xfe') else 'utf-8-sig')
metadata = json.loads(next(line for line in log.splitlines() if line.startswith('{')))
assert metadata['runtime'] == 'native' and metadata['endpoints']['database.sql']['port'] == 54402
stack = metadata['id']
assert len(stack) == 64 and all(c in '0123456789abcdef' for c in stack)
state = subprocess.run(['wsl.exe', '-d', 'Ubuntu', '--exec', 'cat',
  '/var/tmp/trexven-batch3-native/stacks/' + stack + '/state.json'], capture_output=True)
assert state.returncode == 0 and b'trexven-final-qa9' in state.stdout
args = ['wsl.exe', '-d', 'Ubuntu', '--exec', 'env', 'PGPASSWORD=postgres', 'PGCONNECT_TIMEOUT=10',
  PG, '-X', '-q', '-w', '-h', '127.0.0.1', '-p', '54402', '-U', 'postgres', '-d', 'postgres',
  '-v', 'ON_ERROR_STOP=1', '-A', '-t']
probe = subprocess.run(args, input=b"select current_setting('cluster_name')||'|'||current_database();", capture_output=True)
assert probe.returncode == 0 and probe.stdout.strip() == b'main|postgres'
baseline = ROOT / 'supabase/tests/baseline/TREXVEN_PRE_BATCH_2_BASELINE.sql'
assert hashlib.sha256(baseline.read_bytes()).hexdigest() == '5eb2ee5437911b21eab424a05abf21eb7cc7945bc805e5a41d58459e21b3e21e'
results = []
def execute(name, sql, **evidence):
    completed = subprocess.run(args, input=sql.encode(), capture_output=True, timeout=240)
    (ROOT / '.batch3-tools' / ('final_qa9_' + name + '.log')).write_bytes(completed.stdout + completed.stderr)
    results.append({'step': name, 'exit_code': completed.returncode, **evidence})
    (ROOT / 'docs/implementation/evidence/batch_9_native_replay_results.json').write_text(json.dumps(results, indent=2))
    print(name, 'exit', completed.returncode, flush=True)
    if completed.returncode: raise SystemExit(1)
    if name in ('fresh_empty_prerequisites', 'empty_after_tests'):
        assert completed.stdout.strip() == b't', 'Disposable fixture emptiness check failed'

# Create an API-unexposed, empty database using schema-only Supabase platform
# prerequisites from the owned local stack. Application schemas/history and
# every row are excluded; existing stack and production remain unchanged.
# Replace only the PostgreSQL user, retaining source database postgres.
admin_args = list(args); admin_args[admin_args.index('-U') + 1] = 'supabase_admin'
base_args = list(args)
database = 'trexven_final_replay_' + uuid.uuid4().hex[:12]
platform_dump = subprocess.run([*base_args[:base_args.index(PG)], PG.replace('psql','pg_dump'),
 '-h','127.0.0.1','-p','54402','-U','supabase_admin','-d','postgres','-Fc','--schema-only',
 '--exclude-schema=public','--exclude-schema=private','--exclude-schema=supabase_migrations'],capture_output=True)
assert platform_dump.returncode == 0, 'Local platform prerequisite export failed'
create = subprocess.run(admin_args, input=('create database '+database+' owner postgres template template0;').encode(),capture_output=True)
assert create.returncode == 0, 'Fresh isolated replay database could not be created'
cleaned = False
def cleanup_owned_database():
    global cleaned
    if cleaned: return
    assert re.fullmatch(r'trexven_final_replay_[0-9a-f]{12}',database)
    cleanup = subprocess.run(admin_args,input=('drop database '+database+' with(force);').encode(),capture_output=True)
    cleaned = cleanup.returncode == 0
    results.append({'step':'isolated_replay_database_cleanup','exit_code':cleanup.returncode})
    (ROOT/'docs/implementation/evidence/batch_9_native_replay_results.json').write_text(json.dumps(results,indent=2))
    print('isolated_replay_database_cleanup exit',cleanup.returncode,flush=True)
    return cleaned
atexit.register(cleanup_owned_database)
# Policies outside application schemas may reference application objects. Their
# original definitions are supplied by the reviewed baseline after those tables;
# omit only such application-dependent policies from the prerequisite TOC.
list_args = [*base_args[:base_args.index(PG)], PG.replace('psql','pg_restore'), '--list']
toc = subprocess.run(list_args,input=platform_dump.stdout,capture_output=True)
assert toc.returncode == 0
lines = [l for l in toc.stdout.decode().splitlines() if not (' POLICY storage ' in l)]
# pg_restore accepts its TOC from an owned temporary Linux file.
toc_path = '/tmp/' + database + '.toc'
written = subprocess.run(['wsl.exe','-d','Ubuntu','--exec','tee',toc_path],input=('\n'.join(lines)+'\n').encode(),capture_output=True)
assert written.returncode == 0
restore = subprocess.run([*base_args[:base_args.index(PG)], PG.replace('psql','pg_restore'),
 '-h','127.0.0.1','-p','54402','-U','supabase_admin','-d',database,'--exit-on-error','--use-list='+toc_path],
 input=platform_dump.stdout,capture_output=True)
(ROOT/'.batch3-tools/batch9_platform_prerequisite_restore.log').write_bytes(restore.stderr)
assert restore.returncode == 0, 'Schema-only local platform prerequisite restore failed'
args = list(admin_args); args[args.index('-d', args.index(PG)) + 1] = database
execute('fresh_empty_prerequisites', "select (select count(*) from auth.users)=0 and not exists(select from pg_tables where schemaname in ('public','private'));", api_exposed=False)
public_schema = subprocess.run([*base_args[:base_args.index(PG)], PG.replace('psql','pg_dump'),
 '-h','127.0.0.1','-p','54402','-U','supabase_admin','-d','postgres','--schema-only','--schema=public'],capture_output=True)
assert public_schema.returncode == 0
managed_defaults = [l for l in public_schema.stdout.decode().splitlines()
 if l.startswith('ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public ')]
assert len(managed_defaults) == 12, 'Reviewed managed defaults expected: four roles across three object types'
execute('reviewed_platform_public_defaults', '\n'.join(managed_defaults))
args[args.index('-U') + 1] = 'postgres'
execute('baseline', "set trexven.staging_project_ref='trexven-final-qa9';\n" +
        baseline.read_text(encoding='utf-8-sig').replace("'qysspzlfiysekvxnlzsh'", "'trexven-final-qa9'"),
        source_sha256=hashlib.sha256(baseline.read_bytes()).hexdigest())
migrations = sorted((ROOT / 'supabase/migrations').glob('*_batch_[23456789]_*.sql'))
assert len(migrations) == 23
deployed = json.loads((ROOT/'supabase/releases/main_backend_alignment_20261009/manifest.json').read_text())
history = sorted(deployed['original_history_versions']+[m['version'] for m in deployed['pending_migrations']])
for migration in migrations:
    if '_batch_4_financial_operations' in migration.stem:
        # Local migration metadata only; no production record is imported.
        execute('isolated_predecessor_history', 'create schema supabase_migrations;'
          'create table supabase_migrations.schema_migrations(version text primary key,name text,statements text[]);'
          'insert into supabase_migrations.schema_migrations(version) values '+
          ','.join("('"+v+"')" for v in history)+';')
    pending = migration.name.split('_')[0] > history[15]
    sql = render(migration,history) if pending else migration.read_text(encoding='utf-8-sig')
    execute(migration.stem, sql,
            source_sha256=hashlib.sha256(migration.read_bytes()).hexdigest())
    if pending: history.append(migration.name.split('_')[0])
execute('complete_guarded_history', "do $$ begin if (select count(*) from supabase_migrations.schema_migrations)<>32 then raise exception 'Expected guarded final history'; end if; end $$;")
for suite in sorted((ROOT / '.batch3-tools/staging-final-qa').glob('*.sql')):
    execute(suite.stem, suite.read_text(encoding='utf-8-sig'),
            assertion_calls=suite.read_text().count('pg_temp.assert_true('), rolled_back=True)
execute('empty_after_tests', "begin read only;select (select count(*) from public.businesses)=0 and (select count(*) from auth.users)=0 and (select count(*) from storage.objects)=0;commit;")

assert cleanup_owned_database(), 'Owned disposable replay cleanup failed'
