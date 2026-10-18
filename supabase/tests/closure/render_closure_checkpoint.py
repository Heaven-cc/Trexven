from pathlib import Path
import importlib.util,sys,json,hashlib
sys.path.insert(0,str(Path('.batch2-tools').resolve()))
p=Path('supabase/tests/baseline/build_baseline.py');spec=importlib.util.spec_from_file_location('closure_renderer',p);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
m.DATA=json.loads(Path('supabase/tests/baseline/BATCH_2_CLOSURE_STAGING_CATALOG.json').read_text());m.STRUCTURE=m.DATA['structure'];m.ACL=m.DATA['acl']
s=m.render(allow_unvalidated=True);s=s.replace('Recovered current pre-Batch-2 application schema','Recovered post-closure Batch-2 application schema').replace('No file in this directory has been applied to any database.','This is a new schema-only recovery artifact; reviewed baseline and migrations were executed separately.').replace('NOT the lost historical initial schema. Do not replay its nine incorporated deltas.','Schema-only recovery checkpoint, not production migration history or an authorized staging reset.')
from pglast import parse_sql
statements=parse_sql(s);p=Path('supabase/tests/baseline/BATCH_2_CLOSURE_RECOVERY_CHECKPOINT.sql');p.write_text(s,encoding='utf-8')
assert not any(type(x.stmt).__name__=='InsertStmt'for x in statements)
assert 'INSERT INTO auth.users' not in s and 'ufehcfrlygqvminfjumf' not in s
result={'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'statements':len(statements),'top_level_data_inserts':0,'auth_user_inserts':0,'production_project_refs':0,'not_valid_constraints':s.upper().count('NOT VALID'),'execution':'Not separately restored; full operational pg_dump restore and baseline-to-six-migration replay are separate executed evidence.'}
Path('docs/implementation/evidence/batch_2_closure_recovery_screening.json').write_text(json.dumps(result,indent=2));print(result)
