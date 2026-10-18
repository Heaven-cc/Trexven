from pathlib import Path
import subprocess,json,hashlib,re,os
root=Path('.')
suffix='_'+os.environ.get('B2_REPLAY_RUN','run1')
files=[root/'supabase/migrations'/x for x in ['20261007215736_batch_2_authorization_price_enforcement.sql','20261007215743_batch_2_branch_assignment_foundation.sql','20261007215831_batch_2_branch_checkout_compatibility.sql','20261008002119_batch_2_staging_security_recovery.sql','20261008020234_batch_2_purchase_cost_contract.sql','20261008021428_batch_2_business_day_contract.sql']]
setup="create schema supabase_migrations; create table supabase_migrations.schema_migrations(version text primary key,statements text[],name text); insert into supabase_migrations.schema_migrations values('20261007235400',array['Reviewed pre-Batch-2 snapshot, not individually replayed historical deltas'],'trexven_pre_batch_2_baseline_snapshot');"
p=Path('.batch2-tools/replay_step.sql');p.write_text(setup)
r=subprocess.run(['python','.batch2-tools/native_sql.py',str(p)],capture_output=True,text=True);assert r.returncode==0,r.stderr
results=[]
for f in files:
 sql=f.read_text();sql=re.sub(r'(?mi)^begin;\s*','',sql,count=1);sql=re.sub(r'(?mi)^commit;\s*','',sql,count=1)
 version,name=f.stem.split('_',1)
 step="begin;\n"+sql+f"\ninsert into supabase_migrations.schema_migrations values('{version}',array[$history${f.read_text()}$history$],'{name}');\ncommit;"
 p.write_text(step);r=subprocess.run(['python','.batch2-tools/native_sql.py',str(p)],capture_output=True,text=True)
 Path('docs/implementation/evidence/'+f.stem+suffix+'.replay.log').write_text(r.stdout+r.stderr)
 results.append({'file':str(f),'sha256':hashlib.sha256(f.read_bytes()).hexdigest(),'exit':r.returncode})
 Path('docs/implementation/evidence/batch_2_closure_replay_steps'+suffix+'.json').write_text(json.dumps(results,indent=2))
 print(f.name, 'exit',r.returncode)
 if r.returncode:print(r.stderr);raise SystemExit(r.returncode)
