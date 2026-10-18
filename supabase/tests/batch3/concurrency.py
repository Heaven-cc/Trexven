from pathlib import Path
import subprocess,json,uuid,concurrent.futures
root=Path('.');helper=root/'.batch3-tools/native_sql.py'
fixture=(root/'supabase/tests/batch_2_fixture.sql').read_text(encoding='utf-8').replace("insert into public.products(business_id,name,selling_price,quantity) values(business,'Synthetic product',10,100) returning id into p;", "p:=(public.import_trexven_catalog(business,gen_random_uuid(),'[{\"name\":\"Synthetic product\",\"selling_price\":10,\"initial_quantity\":100}]')->>0)::uuid;")
def sql(source):
 r=subprocess.run(['python',str(helper)],input=source,text=True,capture_output=True)
 if r.returncode:raise RuntimeError(r.stderr)
 return r.stdout
out=sql("begin;create table if not exists private.batch_2_test_environment(marker text primary key);insert into private.batch_2_test_environment values('TREXVEN_SYNTHETIC_ONLY') on conflict do nothing;"+fixture+"\nreset role;select jsonb_object_agg(key,id)::text from batch2_ids;commit;")
ids=json.loads(next(line for line in out.splitlines() if line.startswith('{')))
def adjust(request):
 return sql(f"begin;set local request.jwt.claim.sub='{ids['owner']}';set local role authenticated;select public.adjust_trexven_catalog_stock('{ids['business']}','{ids['product']}',1,'Concurrent receipt','{request}');commit;")
try:
 with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
  list(pool.map(adjust,[str(uuid.uuid4()) for _ in range(12)]))
 same=str(uuid.uuid4())
 with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:list(pool.map(adjust,[same]*6))
 quantity=sql(f"select quantity from public.products where id='{ids['product']}';").strip()
 movements=sql(f"select count(*) from public.inventory_movements where product_id='{ids['product']}' and reason='Concurrent receipt';").strip()
 assert float(quantity)==113,quantity
 assert movements=='13',movements
 result={'distinct_concurrent_adjustments':12,'same_request_concurrent_retries':6,'final_quantity':quantity,'new_movement_count':13,'passed':True,'target':'disposable loopback only'}
 (root/'docs/implementation/evidence/batch_3_concurrency_results.json').write_text(json.dumps(result,indent=2))
 print(json.dumps(result))
finally:
 # The entire owned disposable stack is retained until evidence and fresh replay finish.
 pass
