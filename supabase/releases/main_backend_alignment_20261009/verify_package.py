from pathlib import Path
import json,hashlib
root=Path(__file__).resolve().parents[3]
release=Path(__file__).resolve().parent
m=json.loads((release/'manifest.json').read_text(encoding='utf-8'))
assert (root/'supabase/.temp/project-ref').read_text().strip()==m['production_project'],'Wrong linked project'
assert hashlib.sha256((release/'preflight.sql').read_bytes()).hexdigest()==m['preflight_sha256']
expected=set(m['original_history_file_hashes'])|{Path(r['file']).name for r in m['pending_migrations']}
assert {p.name for p in (root/'supabase/migrations').glob('*.sql')}==expected,'Migration set changed'
for name,h in m['original_history_file_hashes'].items():assert hashlib.sha256((root/'supabase/migrations'/name).read_bytes()).hexdigest()==h,name
for r in m['pending_migrations']:assert hashlib.sha256((root/r['file']).read_bytes()).hexdigest()==r['sha256'],r['file']
for f in m.get('edge_source_files',[]):assert hashlib.sha256((root/f['file']).read_bytes()).hexdigest()==f['sha256'],f['file']
assert m.get('edge_gateway_flags')=={'create-employee':True,'manage-employee':True,'angel':True,'employee-login':False},'Edge gateway contract drift'
print('Package hashes and linked production identity verified; '+('approved production deployment recorded' if m.get('production_integrated') else 'deployment remains gated'))
