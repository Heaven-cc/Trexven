"""Package the reviewed sources; does not deploy, query a database, or test."""
import hashlib
import json
from pathlib import Path

destination = Path(__file__).resolve().parent
root = Path(__file__).resolve().parents[5]
shared = 'supabase/functions/_shared/account-deletion.ts'
manifest = {'project_id': 'ufehcfrlygqvminfjumf', 'deployment_status': 'awaiting_explicit_production_approval', 'files': {}}
for name, verify_jwt in [('delete-account', True), ('account-deletion-recovery', False)]:
    entry = f'supabase/functions/{name}/index.ts'
    payload = {'project_id': manifest['project_id'], 'name': name,
               'entrypoint_path': entry, 'verify_jwt': verify_jwt,
               'files': [{'name': path, 'content': (root / path).read_text(encoding='utf-8')} for path in [entry, shared]]}
    (destination / f'{name}_payload.json').write_text(json.dumps(payload, indent=2), encoding='utf-8')
    for path in [entry, shared]:
        manifest['files'][path] = hashlib.sha256((root / path).read_bytes()).hexdigest()
migration = 'supabase/migrations/20261013055042_account_deletion_with_history_preservation.sql'
manifest['migration_file'] = migration
manifest['files'][migration] = hashlib.sha256((root / migration).read_bytes()).hexdigest()
(destination / 'deployment_manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
print('Prepared two Edge payloads and migration hash. No deployment performed.')
