from pathlib import Path
import subprocess,re,json
root=Path('.');target=root/'.batch3-tools/test.sql';e=root/'docs/implementation/evidence'
fixture=(root/'supabase/tests/batch_2_fixture.sql').read_text(encoding='utf-8')
fixture=fixture.replace("insert into public.products(business_id,name,selling_price,quantity) values(business,'Synthetic product',10,100) returning id into p;", "p:=(public.import_trexven_catalog(business,gen_random_uuid(),'[{\"name\":\"Synthetic product\",\"selling_price\":10,\"initial_quantity\":100}]')->>0)::uuid;")
head="begin;create table if not exists private.batch_2_test_environment(marker text primary key);insert into private.batch_2_test_environment values('TREXVEN_SYNTHETIC_ONLY') on conflict do nothing;\n"
helper="create function pg_temp.reject(statement text,expected text,label text) returns void language plpgsql as $$begin begin execute statement;exception when others then if sqlstate=expected then return; end if;raise;end;raise exception 'Expected denial missing: %',label;end $$;\n"
# Refresh function definitions from the current local migration, never tables.
m=(root/'supabase/migrations/20261009003200_batch_3_catalog_inventory_foundation.sql').read_text(encoding='utf-8')
functions=re.findall(r'create (?:or replace )?function [\s\S]*?end \$\$;',m)
target.write_text('begin;\n'+'\n'.join(f.replace('create function','create or replace function',1) for f in functions)+'\ncommit;')
r=subprocess.run(['python','.batch3-tools/native_sql.py',str(target)],capture_output=True,text=True)
assert r.returncode==0,r.stderr
seed=(root/'supabase/tests/baseline/TREXVEN_STAGING_REFERENCE_SEED.sql').read_text(encoding='utf-8')
seed=seed[seed.index('INSERT INTO public.permissions'):seed.index('INSERT INTO storage.buckets')]
target.write_text(seed)
r=subprocess.run(['python','.batch3-tools/native_sql.py',str(target)],capture_output=True,text=True)
assert r.returncode==0,r.stderr
results=[]
for name in ['batch_3_catalog_inventory_tests','batch_2_authorization_tests','batch_2_branch_isolation_tests','batch_2_price_security_tests','batch_2_checkout_compatibility_tests']:
 sql=(root/'supabase/tests'/f'{name}.sql').read_text(encoding='utf-8')
 if name.startswith('batch_3'):sql=head+fixture+helper+sql+'\nrollback;'
 else:
  sql=sql.replace('begin;',head,1).replace('\\ir batch_2_fixture.sql',fixture)
  # B3 requires reasoned stock RPCs; preserve the B2 zero-price assertion.
  sql=sql.replace("insert into public.products(business_id,name,selling_price,quantity) values((select id from batch2_ids where key='business'),'Synthetic free',0,5);", "select public.import_trexven_catalog((select id from batch2_ids where key='business'),gen_random_uuid(),'[{\"name\":\"Synthetic free\",\"selling_price\":0,\"initial_quantity\":5}]');")
 target.write_text(sql)
 r=subprocess.run(['python','.batch3-tools/native_sql.py',str(target)],capture_output=True,text=True)
 (e/(name+'_batch_3.log')).write_text(r.stdout+r.stderr)
 results.append({'suite':name,'exit':r.returncode,'assertion_calls':len(re.findall(r'(?im)^\s*select\s+pg_temp\.(?:assert_true|denied|fails|reject)\(',sql))})
 print(name,'exit',r.returncode)
 if r.returncode: print(r.stderr)
(e/'batch_3_sql_results.json').write_text(json.dumps(results,indent=2))
