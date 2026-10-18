from pathlib import Path
import subprocess,os,json,hashlib,re,sys
assert os.environ.get('BATCH3_REPLAY_RUN')=='6'
root=Path('.').resolve();e=root/'docs/implementation/evidence'
baseline=root/'supabase/tests/baseline/TREXVEN_PRE_BATCH_2_BASELINE.sql'
assert hashlib.sha256(baseline.read_bytes()).hexdigest()=='5eb2ee5437911b21eab424a05abf21eb7cc7945bc805e5a41d58459e21b3e21e'
def sql(source):
 r=subprocess.run(['python','.batch3-tools/native_sql.py'],input=source,text=True,capture_output=True)
 assert r.returncode==0,r.stderr
 return r.stdout
resume='--resume-prepared' in sys.argv
if not resume:
 assert sql('select count(*) from information_schema.tables where table_schema in (\'public\',\'private\');').strip()=='0'
 sql("set trexven.staging_project_ref='trexven-batch3-disposable';\n"+baseline.read_text(encoding='utf-8').replace("'qysspzlfiysekvxnlzsh'","'trexven-batch3-disposable'"))
# Restore only verified migration version/name metadata into this owned local copy.
# No customer records or migrations are executed by this metadata insertion.
versions=['20260819180000','20260823100000','20261002014604','20261002015419','20261002123039','20261002124738','20261003224001','20261004025120','20261005004045']
files=sorted((root/'supabase/migrations').glob('*.sql'))
historical=[p for p in files if p.name[:14] in versions];assert len(historical)==9
if not resume:
 sql("create schema if not exists supabase_migrations;create table if not exists supabase_migrations.schema_migrations(version text primary key,statements text[],name text);"+''.join("insert into supabase_migrations.schema_migrations(version,name,statements) values('%s','%s',array[]::text[]);"%(p.name[:14],p.stem[15:]) for p in historical))
assert json.loads(sql('select json_agg(version order by version) from supabase_migrations.schema_migrations;'))==versions
expected=[p.name for p in files if p.name[:14] not in versions];assert len(expected)==7
command=['supabase.cmd','db','push','--db-url','postgresql://postgres:postgres@127.0.0.1:54372/postgres?sslmode=disable','--yes']
results=[]
for label,extra in [('dry_run',['--dry-run']),('apply',[]),('second_dry_run',['--dry-run'])]:
 # This fixed loopback URL cannot be replaced by a production connection.
 assert sql('select 1;').strip()=='1'
 r=subprocess.run(command+extra,capture_output=True,text=True)
 text=r.stdout+r.stderr
 (e/f'main_alignment_cli_{label}.log').write_text(text,encoding='utf-8')
 assert r.returncode==0,text
 if label=='dry_run':assert all(name in text for name in expected),text
 if label=='second_dry_run':assert not any(name in text for name in expected),text
 results.append({'step':label,'exit':r.returncode});print(label,'exit',r.returncode)
history=sql('select json_agg(version order by version) from supabase_migrations.schema_migrations;')
assert json.loads(history)==[p.name[:14] for p in files]
result={'target':'sixth owned loopback schema copy only','historical_metadata_versions_restored':versions,'pending_files':expected,'results':results,'final_history_versions':json.loads(history),'old_migrations_reexecuted':False,'production_writes':0}
(e/'main_alignment_cli_replay.json').write_text(json.dumps(result,indent=2),encoding='utf-8')
print('Exactly seven new migrations applied; final local history has 16 entries')
