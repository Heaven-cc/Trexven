import json,subprocess,sys,urllib.parse,os
from pathlib import Path
status=json.loads(Path('.batch2-tools/native_status_windows.json').read_text())
assert status['runtime']=='native' and status['identity']['name']=='trexven-batch2-closure'
u=urllib.parse.urlparse(status['env']['DB_URL'])
assert u.hostname in ('127.0.0.1','localhost') and u.port==54322 and u.path=='/postgres'
pg='/tmp/trexven-batch2-closure-native/cache/stack/slim-services/postgres/17.11.0.004-r1/linux-amd64'
database=os.environ.get('BATCH2_DISPOSABLE_DATABASE','postgres')
assert database in ('postgres','trexven_b2_restored','trexven_b2_replay2','trexven_b2_schemaonly')
user=os.environ.get('BATCH2_DISPOSABLE_USER',u.username)
assert user in ('postgres','supabase_admin')
args=['wsl.exe','-d','Ubuntu','--','env','PGPASSWORD='+urllib.parse.unquote(u.password or ''),pg+'/bin/psql','-X','-h','127.0.0.1','-p','54322','-U',user,'-d',database,'-v','ON_ERROR_STOP=1','-A','-t']
sql=Path(sys.argv[1]).read_text() if len(sys.argv)>1 else sys.stdin.read()
r=subprocess.run(args,input=sql,text=True,capture_output=True)
print(r.stdout,end='');print(r.stderr,end='',file=sys.stderr);sys.exit(r.returncode)
