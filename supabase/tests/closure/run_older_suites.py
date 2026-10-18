from pathlib import Path
import subprocess,json
result=[]
for name in ['readiness_access_tests.sql','sale_submission_tests.sql','native_camera_limit_tests.sql','employee_rbac_tests.sql']:
 p=Path('supabase/tests')/name
 if not p.exists():print('Missing',name);continue
 r=subprocess.run(['python','.batch2-tools/native_sql.py',str(p)],capture_output=True,text=True)
 Path('docs/implementation/evidence/batch_2_closure_'+name+'.log').write_text(r.stdout+r.stderr);result.append({'suite':name,'exit':r.returncode});print(name,r.returncode)
 if r.returncode:print(r.stderr)
Path('docs/implementation/evidence/batch_2_closure_older_sql_results.json').write_text(json.dumps(result,indent=2))
