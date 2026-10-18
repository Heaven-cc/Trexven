from pathlib import Path
import re,subprocess,json
seed=Path('supabase/tests/baseline/TREXVEN_STAGING_REFERENCE_SEED.sql').read_text()
start=seed.index('INSERT INTO public.permissions');end=seed.index('INSERT INTO storage.buckets')
Path('.batch2-tools/disposable_permissions.sql').write_text(seed[start:end]);r=subprocess.run(['python','.batch2-tools/native_sql.py','.batch2-tools/disposable_permissions.sql'],capture_output=True,text=True);assert r.returncode==0,r.stderr
suites=json.loads(subprocess.check_output(['python','supabase/tests/prepare_batch_2_staging.py'],text=True));results=[]
for suite in suites:
 p=Path('.batch2-tools/disposable_suite.sql');p.write_text(suite['sql']);r=subprocess.run(['python','.batch2-tools/native_sql.py',str(p)],capture_output=True,text=True)
 Path('docs/implementation/evidence/batch_2_closure_'+suite['file']+'.log').write_text(r.stdout+r.stderr)
 row={k:v for k,v in suite.items() if k!='sql'};row['exit']=r.returncode;results.append(row)
 print(suite['file'],r.returncode,suite['assertions'])
 if r.returncode:print(r.stderr)
Path('docs/implementation/evidence/batch_2_closure_sql_results.json').write_text(json.dumps(results,indent=2))
