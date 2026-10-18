from pathlib import Path
import subprocess,json,os,time,concurrent.futures,uuid
assert os.environ.get('BATCH3_REPLAY_RUN')=='6'
root=Path('.');helper=root/'.batch3-tools/native_sql.py'
def sql(text):
 r=subprocess.run(['python',str(helper)],input=text,capture_output=True,text=True)
 return r
fixture=(root/'supabase/tests/batch_2_fixture.sql').read_text().replace("insert into public.products(business_id,name,selling_price,quantity) values(business,'Synthetic product',10,100) returning id into p;", "p:=(public.import_trexven_catalog(business,gen_random_uuid(),'[{\"name\":\"Synthetic product\",\"selling_price\":10,\"initial_quantity\":100}]')->>0)::uuid;")
r=sql("begin;create table if not exists private.batch_2_test_environment(marker text primary key);insert into private.batch_2_test_environment values('TREXVEN_SYNTHETIC_ONLY') on conflict do nothing;"+fixture+"\nreset role;select jsonb_object_agg(key,id)::text from batch2_ids;commit;")
assert r.returncode==0,r.stderr
ids=json.loads(next(x for x in r.stdout.splitlines() if x.startswith('{')))
pg='/var/tmp/trexven-batch3-native/cache/stack/slim-services/postgres/17.11.0.004-r1/linux-amd64/bin/psql'
args=['wsl.exe','-d','Ubuntu','--','env','PGPASSWORD=postgres',pg,'-X','-h','127.0.0.1','-p','54372','-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-A','-t']
active=subprocess.Popen(args,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,bufsize=1)
try:
 active.stdin.write(f"begin;set local request.jwt.claim.sub='{ids['manager_user']}';set local role authenticated;select public.adjust_trexven_catalog_stock('{ids['business']}','{ids['product']}',1,'In-flight manager stock','{uuid.uuid4()}');\n\\echo LOCKED\n")
 active.stdin.flush()
 for line in active.stdout:
  if line.strip()=='LOCKED':break
 else:raise RuntimeError(active.stderr.read())
 statement=f"set application_name='trexven-b3-revoker';begin;set local request.jwt.claim.sub='{ids['owner']}';set local role authenticated;select public.set_trexven_employee_permission('{ids['manager']}','adjust_stock',false);commit;"
 with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
  revoked=pool.submit(sql,statement)
  waiting=False
  for _ in range(10):
   probe=sql("select exists(select 1 from pg_stat_activity where application_name='trexven-b3-revoker' and wait_event_type='Lock');")
   if probe.returncode==0 and probe.stdout.strip()=='t':waiting=True;break
   time.sleep(0.1)
  assert waiting,'Revocation must wait on the in-flight authorization lock'
  active.stdin.write('commit;\n\\q\n');active.stdin.flush();active.wait(timeout=20)
  result=revoked.result(timeout=20);assert result.returncode==0,result.stderr
 denied=sql(f"begin;set local request.jwt.claim.sub='{ids['manager_user']}';set local role authenticated;select public.adjust_trexven_catalog_stock('{ids['business']}','{ids['product']}',1,'After revocation','{uuid.uuid4()}');commit;")
 assert denied.returncode==3 and 'Catalog permission denied' in denied.stderr,denied.stderr
 quantity=sql(f"select quantity from public.products where id='{ids['product']}';")
 assert quantity.stdout.strip()=='101',quantity.stdout
 evidence={'target':'sixth disposable loopback stack','revocation_waited_for_in_flight_authorization':True,'post_revocation_adjustment_denied':True,'final_stock':101,'passed':True}
 (root/'docs/implementation/evidence/main_alignment_revocation_race.json').write_text(json.dumps(evidence,indent=2))
 print(json.dumps(evidence))
finally:
 if active.poll() is None:
  active.stdin.close();active.wait(timeout=20)

