"""Read-only package and repository verification. Does not connect or deploy."""
from pathlib import Path
import hashlib
import json
import sys
import base64
import re
sys.path.insert(0,str(Path(__file__).resolve().parent.parent))
from render_final_guarded_migration import render

PACKAGE = Path(__file__).resolve().parent
ROOT = PACKAGE.parents[2]
POS = ROOT.parent/'trexvenpos'
def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()
manifest = json.loads((PACKAGE/'manifest.json').read_text())
assert sha(PACKAGE/'manifest.json') == (PACKAGE/'manifest.sha256').read_text().split()[0]
assert manifest['production_project'] == 'ufehcfrlygqvminfjumf'
assert not manifest['production_approved'] and not manifest['production_applied']
assert (ROOT/'supabase/.temp/project-ref').read_text().strip() == manifest['production_project']
for row in manifest['files'] + manifest['evidence']:
    assert sha(PACKAGE/row['package']) == row['sha256'], 'Packaged file differs: '+row['package']
    source_root = ROOT if row['root']=='owner' else POS
    assert sha(source_root/row['source']) == row['sha256'], 'Source changed after freeze: '+row['source']
    if row['package'].startswith('sources/') and '/lib/' in row['package'] and row['package'].endswith('.dart'):
        text = (PACKAGE/row['package']).read_text(encoding='utf-8-sig')
        assert not re.search(r'sb_secret_[A-Za-z0-9_-]{8,}',text), 'Secret API key found in client source'
        for token in re.findall(r'eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+',text):
            payload = token.split('.')[1]
            claims = json.loads(base64.urlsafe_b64decode(payload+'='*((-len(payload))%4)))
            assert claims.get('role') != 'service_role', 'Privileged JWT found in client source'
for name, value in manifest['predecessor_migration_hashes'].items():
    assert sha(ROOT/'supabase/migrations'/name)==value, 'Deployed migration modified'
assert sha(PACKAGE/manifest['package_config']) == manifest['package_config_sha256']
assert sha(PACKAGE/'source_change_inventory.json') == manifest['source_change_inventory_sha256']
assert len(manifest['migration_order']) == 16
history = list(manifest['expected_predecessor_history'])
for row,execution in zip(manifest['migration_order'],manifest['guarded_execution'],strict=True):
    assert sha(PACKAGE/execution['package']) == execution['sha256']
    assert (PACKAGE/execution['package']).read_text() == render(ROOT/row['source'],history)
    history.append(Path(row['source']).name.split('_')[0])
versions = [Path(row['source']).stem.split('_')[0] for row in manifest['migration_order']]
assert versions == sorted(versions) and len(set(versions)) == 16
assert all(edge['verify_jwt'] for edge in manifest['edges'])
assert not manifest['charging_enabled'] and not manifest['branch_activation_authorized']
print(json.dumps({'package_integrity_verified':True, 'linked_project_verified':True,
 'deployed_predecessor_files_verified':16,'pending_migrations_verified':16,
 'production_writes':0,'client_embedded_privileged_key_scan_passed':True,
 'ready_for_production':False,'remaining_gates':manifest['remaining_gates']}))
