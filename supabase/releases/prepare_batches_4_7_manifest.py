"""Hash the local candidate only. No database connection or deployment commands."""
from pathlib import Path
import hashlib
import json

ROOT = Path(__file__).resolve().parents[2]
TARGET = ROOT / 'supabase/releases/batches_4_7_development_20261009'
TARGET.mkdir(exist_ok=True)
def entry(path):
    return {'path': path.relative_to(ROOT).as_posix(),
            'sha256': hashlib.sha256(path.read_bytes()).hexdigest()}
migrations = sorted((ROOT / 'supabase/migrations').glob('*_batch_[4567]_*.sql'))
if len(migrations) != 14:
    raise SystemExit('Migration set changed; review dependencies before updating candidate.')
edges = [ROOT / 'supabase/functions/camera-ai/index.ts',
         ROOT / 'supabase/functions/delete-account/index.ts']
manifest = {
    'status': 'LOCAL_IMPLEMENTATION_UNVERIFIED',
    'production_project': 'ufehcfrlygqvminfjumf',
    'isolated_staging_project': 'qysspzlfiysekvxnlzsh',
    'production_approved': False, 'production_applied': False,
    'database_behavior_verified': False, 'charging_enabled': False,
    'branch_activation_authorized': False, 'applications_published': False,
    'required_predecessor': 'deployed main_backend_alignment_20261009 (16 migration-history entries)',
    'migration_order': [entry(path) for path in migrations],
    'edge_sources_requiring_review': [entry(path) for path in edges],
    'billing_library_not_deployed_endpoint': entry(ROOT / 'supabase/functions/_shared/billing-provider.ts'),
    'gates': ['fresh isolated full migration replay and authorization/financial/concurrency QA',
              'Owner/POS analysis, tests, signing and durable-data upgrade verification',
              'revised Edge JWT gateway tests and source review',
              'fresh read-only production drift/idempotency preflight',
              'protected fresh backup with verified isolated recovery',
              'one explicit coordinated production deployment approval'],
}
(TARGET / 'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
print('Prepared local candidate:', len(migrations), 'ordered migrations; 2 Edge sources. Not approved/deployed.')
