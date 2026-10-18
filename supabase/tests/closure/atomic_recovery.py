from pathlib import Path
import subprocess,json
p=Path('.batch2-tools/atomic_recovery_step.sql'); results=[]
def run(label,sql,expected=0):
 p.write_text(sql);r=subprocess.run(['python','.batch2-tools/native_sql.py',str(p)],capture_output=True,text=True);Path('docs/implementation/evidence/batch_2_closure_'+label+'.log').write_text(r.stdout+r.stderr);results.append({'step':label,'exit':r.returncode,'expected':expected});print(label,r.returncode);assert (r.returncode==0)==(expected==0)
 return r.stdout
checksum="select jsonb_build_object('sales',(select md5(string_agg(row_to_json(s)::text,',' order by id)) from public.sales s),'receipts',(select md5(string_agg(row_to_json(s)::text,',' order by request_id)) from private.sale_requests s),'stock',(select md5(string_agg(row_to_json(s)::text,',' order by id)) from public.inventory s),'history',(select count(*) from supabase_migrations.schema_migrations));"
a=run('failure_before',checksum)
run('intentional_migration_failure',"begin; create table private.batch_2_atomic_probe(id int); update public.inventory set quantity=999; do $$ begin raise exception 'Expected synthetic migration failure'; end $$; commit;",1)
b=run('failure_after',checksum+"select to_regclass('private.batch_2_atomic_probe') is null as probe_rolled_back;")
assert a.splitlines()[0]==b.splitlines()[0]
run('forward_recovery',"begin; create table private.batch_2_atomic_probe(id int primary key); revoke all on private.batch_2_atomic_probe from public,anon,authenticated; insert into private.batch_2_atomic_probe values(1); commit; select count(*)=1 from private.batch_2_atomic_probe; begin; drop table private.batch_2_atomic_probe; commit;")
c=run('forward_recovery_after',checksum);assert a==c
Path('docs/implementation/evidence/batch_2_closure_failure_recovery.json').write_text(json.dumps(results,indent=2))
