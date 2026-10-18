from pathlib import Path
import subprocess,hashlib,json,os
root=Path('.'); baseline=root/'supabase/tests/baseline/TREXVEN_PRE_BATCH_2_BASELINE.sql'
assert hashlib.sha256(baseline.read_bytes()).hexdigest()=='5eb2ee5437911b21eab424a05abf21eb7cc7945bc805e5a41d58459e21b3e21e'
e=root/'docs/implementation/evidence'; e.mkdir(parents=True,exist_ok=True)
run=os.environ.get('BATCH3_REPLAY_RUN','2' if os.environ.get('BATCH3_REPLAY2')=='1' else '1')
prefix='batch_3_replay'+run+'_' if run!='1' else 'batch_3_'
step=root/'.batch3-tools/step.sql'
def run_step(name,sql):
 step.write_text(sql)
 r=subprocess.run(['python','.batch3-tools/native_sql.py',str(step)],capture_output=True,text=True)
 (e/(prefix+name+'.log')).write_text(r.stdout+r.stderr)
 print(name,'exit',r.returncode)
 if r.returncode: print(r.stderr);raise SystemExit(r.returncode)
files=sorted((root/'supabase/migrations').glob('*batch_2*.sql'))
assert len(files)==6
expected=[
 '55a69cd97eb1fbbd2a034467e9cda93d5551c7fcd415f6ea4d778f53d2a1b8e7',
 '2537fb48a9c7fc77088a30f2158f917d45bed39126d670fff3d5dfed4358f34a',
 '86feacc6be132aedb1a2999500a633e9a433f41c0965dbb7bb51a2f931278283',
 '4f9a93633d401ad9e66b55870e5720c1081c0151408e2d31f8b082303fdb0ca3',
 '497f6cccce70b51454747d29b5ea61b49e89d00f8f549dc2d3ac9d2bbcbae61b',
 '26003a9e8d16241a47140c48fca7422381aed607f6d948d73c949025a38a37aa']
for f,h in zip(files,expected): assert hashlib.sha256(f.read_bytes()).hexdigest()==h
assert hashlib.sha256((root/'supabase/migrations/20261009003200_batch_3_catalog_inventory_foundation.sql').read_bytes()).hexdigest()=='1045d82c16082f519af78e379a54b53fe9f4955da39d9455bfb123a423424823'
run_step('baseline',"set trexven.staging_project_ref='trexven-batch3-disposable';\n"+baseline.read_text(encoding='utf-8').replace("'qysspzlfiysekvxnlzsh'","'trexven-batch3-disposable'"))
for f in files:run_step(f.stem,f.read_text(encoding='utf-8'))
run_step('foundation',(root/'supabase/migrations/20261009003200_batch_3_catalog_inventory_foundation.sql').read_text(encoding='utf-8'))
(e/(prefix+'reconstruction.json')).write_text(json.dumps({'target':'separate disposable loopback stack','baseline_sha256':hashlib.sha256(baseline.read_bytes()).hexdigest(),'migrations':[{'file':f.name,'sha256':hashlib.sha256(f.read_bytes()).hexdigest()} for f in files],'batch_3_applied':True,'batch_3_sha256':hashlib.sha256((root/'supabase/migrations/20261009003200_batch_3_catalog_inventory_foundation.sql').read_bytes()).hexdigest()},indent=2))
