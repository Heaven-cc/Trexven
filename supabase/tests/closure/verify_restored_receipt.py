import json,os,subprocess
from pathlib import Path
f=json.loads(Path('.batch2-tools/native_http_fixture.json').read_text());e=json.loads(Path('../trexvenpos/.batch2-tools/live-restart/evidence.json').read_text());m=f['m'];u=f['users']['sales']['id'];items=json.dumps(e['receipt']['items'],separators=(',',':'))
checksum="select jsonb_build_object('sales',(select count(*)from public.sales),'receipts',(select count(*)from private.sale_requests),'stock',(select md5(string_agg(row_to_json(i)::text,',' order by id))from public.inventory i));"
p=Path('.batch2-tools/restore_receipt_replay.sql');p.write_text(checksum+f"begin; select set_config('request.jwt.claim.sub','{u}',true); set local role authenticated; select public.submit_trexven_branch_sale('{e['request_id']}','{m['business']}','{m['sales_member']}',10,'cash','{items}'::jsonb,false,'{m['branch_a']}')->>'id'='{e['receipt']['id']}' as original_receipt_recovered; reset role; commit;"+checksum)
r=subprocess.run(['python','.batch2-tools/native_sql.py',str(p)],env={**os.environ,'BATCH2_DISPOSABLE_DATABASE':'trexven_b2_restored'},capture_output=True,text=True);Path('docs/implementation/evidence/batch_2_closure_restored_receipt_replay.log').write_text(r.stdout+r.stderr);print('Restored receipt replay exit',r.returncode);print(r.stdout if r.returncode==0 else r.stderr)
assert r.returncode==0 and '\nt\n' in r.stdout
rows=[line for line in r.stdout.splitlines()if line.startswith('{')];assert rows[0]==rows[-1]
