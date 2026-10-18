import json,subprocess,urllib.parse
from pathlib import Path
s=json.loads(Path('.batch2-tools/native_status_windows.json').read_text());assert s['runtime']=='native' and s['identity']['name']=='trexven-batch2-closure';u=urllib.parse.urlparse(s['env']['DB_URL']);assert u.hostname=='127.0.0.1' and u.port==54322
pg='/tmp/trexven-batch2-closure-native/cache/stack/slim-services/postgres/17.11.0.004-r1/linux-amd64/bin/'
base=['wsl.exe','-d','Ubuntu','--','env','PGPASSWORD='+u.password]
connection=['-h','127.0.0.1','-p','54322','-U','supabase_admin']
backup='/tmp/trexven-batch2-closure-native/trexven_synthetic_operational.dump'
results=[]
run_suffix='_final'
def run(label,args,stdin=None):
 r=subprocess.run(base+args,input=stdin,capture_output=True,text=True);Path('docs/implementation/evidence/batch_2_closure_'+label+run_suffix+'.log').write_text(r.stdout+r.stderr);results.append({'step':label,'exit':r.returncode});print(label,r.returncode)
 if r.returncode:print(r.stderr);raise SystemExit(r.returncode)
run('pg_dump',[pg+'pg_dump',*connection,'-d','postgres','-Fc','-f',backup])
run('restore_create',[pg+'psql',*connection,'-d','postgres','-X','-v','ON_ERROR_STOP=1'],"drop database trexven_b2_restored; create database trexven_b2_restored owner postgres;")
run('pg_restore',[pg+'pg_restore',*connection,'-d','trexven_b2_restored','--exit-on-error',backup])
run('restore_identity',[pg+'psql',*connection,'-d','trexven_b2_restored','-X','-At','-v','ON_ERROR_STOP=1'],"begin read only; select jsonb_build_object('database',current_database(),'auth_users',(select count(*) from auth.users),'businesses',(select count(*) from public.businesses),'sales',(select count(*) from public.sales),'receipts',(select count(*) from private.sale_requests),'history',(select count(*) from supabase_migrations.schema_migrations),'cost_select',has_column_privilege('authenticated','public.products','cost_price','SELECT')); commit;")
Path('docs/implementation/evidence/batch_2_closure_backup_results.json').write_text(json.dumps(results,indent=2))
