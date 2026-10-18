import sys, subprocess, os, json
from pathlib import Path
pg='/var/tmp/trexven-batch3-native/cache/stack/slim-services/postgres/17.11.0.004-r1/linux-amd64/bin/psql'
# This executor is deliberately bound to the new disposable loopback stack.
# It cannot accept a hosted URL or another database name.
assert os.environ.get('SUPABASE_DB_URL') is None
run=os.environ.get('BATCH3_REPLAY_RUN','2' if os.environ.get('BATCH3_REPLAY2')=='1' else '1')
assert run in ('1','2','3','4','5','6')
second=run!='1'
port={'1':'54322','2':'54332','3':'54342','4':'54352','5':'54362','6':'54372'}[run]
identity='trexven-batch3-replay'+run if second else 'trexven-batch3-disposable'
stack_id='d679da5c367607e6f91c25b65286a52b96b08b8fe72ceaa382333ed91ef49159'
if second:
 raw=Path('.batch3-tools/start'+run+'.log').read_bytes()
 log=raw.decode('utf-16' if raw.startswith(b'\xff\xfe') else 'utf-8-sig')
 metadata=json.loads(next(line for line in log.splitlines() if line.startswith('{')))
 assert metadata['runtime']=='native' and metadata['endpoints']['database.sql']['port']==int(port)
 stack_id=metadata['id']
 assert len(stack_id)==64 and all(c in '0123456789abcdef' for c in stack_id)
args=['wsl.exe','-d','Ubuntu','--','env','PGPASSWORD=postgres',pg,'-X','-h','127.0.0.1','-p',port,'-U','postgres','-d','postgres','-v','ON_ERROR_STOP=1','-A','-t']
sql=Path(sys.argv[1]).read_text() if len(sys.argv)>1 else sys.stdin.read()
probe=subprocess.run(args+['-c',"select current_setting('cluster_name'),inet_server_addr(),current_database();"],capture_output=True,text=True)
assert probe.returncode==0 and probe.stdout.strip()=='main||postgres', probe.stderr
state=subprocess.run(['wsl.exe','-d','Ubuntu','--','cat',f'/var/tmp/trexven-batch3-native/stacks/{stack_id}/state.json'],capture_output=True,text=True)
assert state.returncode==0 and identity in state.stdout
r=subprocess.run(args,input=sql,capture_output=True,text=True)
print(r.stdout,end='');print(r.stderr,end='',file=sys.stderr);sys.exit(r.returncode)
