from pathlib import Path
import hashlib
p=Path('supabase/tests/baseline/TREXVEN_PRE_BATCH_2_BASELINE.sql')
assert hashlib.sha256(p.read_bytes()).hexdigest()=='5eb2ee5437911b21eab424a05abf21eb7cc7945bc805e5a41d58459e21b3e21e'
s=p.read_text()
s=s.replace("current_setting('trexven.staging_project_ref', true) IS DISTINCT FROM 'qysspzlfiysekvxnlzsh'", "current_setting('trexven.disposable_stack_id', true) IS DISTINCT FROM '2d308235459edaa3b9677651ce39251abedc7cff860fea7ab71021e94e88063e'")
s="set trexven.disposable_stack_id='2d308235459edaa3b9677651ce39251abedc7cff860fea7ab71021e94e88063e';\n"+s
Path('.batch2-tools/disposable_baseline.sql').write_text(s)
print('Baseline hash verified; only executor identity guard adapted.')
