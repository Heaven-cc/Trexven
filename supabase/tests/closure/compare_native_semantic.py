from pathlib import Path
import sys,json,subprocess,os
sys.path.insert(0,str(Path('.batch2-tools').resolve()));sys.path.insert(0,str(Path('supabase/tests/baseline').resolve()))
from compare_checkpoint_a import canon,structure,functions,security,compare_group
stage=json.loads(Path('supabase/tests/baseline/BATCH_2_CLOSURE_STAGING_CATALOG.json').read_text());stage_rel=json.loads(Path('.batch2-tools/staging_relation_map.json').read_text())
results=[]
def groups(meta,relations):
 out={};st=structure(meta)
 for original,transformed in zip(meta['structure']['constraints'],st['constraints']):
  transformed['index']=relations.get(str(original['index']),transformed['index'])
 for key,value in st.items():out['structure.'+key]=value
 out['functions']=functions(meta)
 for key,value in security(meta).items():out['security.'+key]=value
 for section in ['acl','dependencies','extras']:
  for key,value in meta[section].items():out[section+'.'+key]=value
 return out
expected=groups(stage,stage_rel)
for db in ['postgres','trexven_b2_replay2','trexven_b2_restored','trexven_b2_schemaonly']:
 p=Path('.batch2-tools/relations_step.sql');p.write_text("select jsonb_object_agg(c.oid::text,n.nspname||'.'||c.relname) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in('public','private','auth','storage');")
 r=subprocess.run(['python','.batch2-tools/native_sql.py',str(p)],env={**os.environ,'BATCH2_DISPOSABLE_DATABASE':db},capture_output=True,text=True);assert r.returncode==0,r.stderr
 relations=json.loads(r.stdout)
 meta=json.loads(Path('supabase/tests/baseline/BATCH_2_CLOSURE_'+db.upper()+'_CATALOG.json').read_text());actual=groups(meta,relations)
 for name,value in expected.items():results.append({'database':db,**compare_group(name,value,actual[name])})
 print(db,sum(x['match']for x in results if x['database']==db),'of',sum(x['database']==db for x in results))
for r in results:
 if not r['match']:print(json.dumps(r,indent=2)[:1800])
Path('docs/implementation/evidence/batch_2_closure_catalog_semantic_parity.json').write_text(json.dumps({'normalization':['OIDs resolved to actual qualified relation/function identities including managed Auth indexes','Reviewed function/trigger SQL AST normalization','Row ordering ignored; column ordinals, owners, grants and validation state retained'],'groups':results,'match':all(x['match']for x in results)},indent=2))
