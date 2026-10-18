"""Negative release-history test on owned loopback only; no application data."""
from pathlib import Path
import json
import subprocess
import sys
import uuid

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'supabase/releases'))
from render_final_guarded_migration import render

raw=(ROOT/'.batch3-tools/final_qa9_start.log').read_bytes()
text=raw.decode('utf-16' if raw.startswith(b'\xff\xfe') else 'utf-8-sig')
metadata=json.loads(next(line for line in text.splitlines() if line.startswith('{')))
assert metadata['runtime']=='native' and metadata['endpoints']['database.sql']['port']==54402
stack=metadata['id'];assert len(stack)==64 and all(c in '0123456789abcdef' for c in stack)
state=subprocess.run(['wsl.exe','-d','Ubuntu','--exec','cat',
 '/var/tmp/trexven-batch3-native/stacks/'+stack+'/state.json'],capture_output=True)
assert state.returncode==0 and b'trexven-final-qa9' in state.stdout
pg='/var/tmp/trexven-batch3-native/cache/stack/slim-services/postgres/17.11.0.004-r1/linux-amd64/bin/psql'
base=['wsl.exe','-d','Ubuntu','--exec','env','PGPASSWORD=postgres',pg,
 '-X','-q','-w','-h','127.0.0.1','-p','54402','-U','supabase_admin','-v','ON_ERROR_STOP=1','-A','-t']
def run(sql,database='postgres'):
    return subprocess.run(base+['-d',database],input=sql.encode(),capture_output=True,timeout=30)
deployed=json.loads((ROOT/'supabase/releases/main_backend_alignment_20261009/manifest.json').read_text())
expected=sorted(deployed['original_history_versions']+[m['version'] for m in deployed['pending_migrations']])
database='trexven_guard_test_'+uuid.uuid4().hex[:12]
assert run('create database '+database+' template template0;').returncode==0
evidence={'target':'owned API-unexposed loopback 54402','production_writes':0,'customer_data_used':False,'passed':False}
try:
    history=expected+['99999999999999']
    setup='create schema supabase_migrations;create table supabase_migrations.schema_migrations(version text primary key,name text,statements text[]);insert into supabase_migrations.schema_migrations(version) values '+','.join("('"+v+"')" for v in history)+';'
    assert run(setup,database).returncode==0
    first=ROOT/'supabase/migrations/20261009070338_batch_4_financial_operations.sql'
    denied=run(render(first,expected),database)
    assert denied.returncode!=0 and b'predecessor history mismatch' in denied.stderr
    unchanged=run("select (select count(*) from supabase_migrations.schema_migrations)=17 and to_regclass('public.sales') is null;",database)
    assert unchanged.returncode==0 and unchanged.stdout.strip()==b't'
    evidence.update({'passed':True,'unexpected_history_denied':True,
      'ddl_not_executed':True,'history_not_changed':True,'expected_rejection_exit_code':denied.returncode})
finally:
    cleanup=run('drop database '+database+' with(force);')
    evidence['isolated_cleanup_exit']=cleanup.returncode
    (ROOT/'docs/implementation/evidence/batch_9_release_history_guard.json').write_text(json.dumps(evidence,indent=2))
    assert cleanup.returncode==0
print(json.dumps(evidence))
