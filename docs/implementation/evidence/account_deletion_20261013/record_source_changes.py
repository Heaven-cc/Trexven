"""Record source-only changes. Does not invoke tests, Auth or any database."""
import difflib
import hashlib
import json
from pathlib import Path
import subprocess

evidence = Path(__file__).resolve().parent
root = Path(__file__).resolve().parents[4]
baseline = evidence / 'baseline'
old_files = {p.relative_to(baseline).as_posix()[:-7]: p for p in baseline.rglob('*.source')}
new_files = [
    'lib/services/account_deletion_service.dart',
    'lib/screens/auth/account_deletion_recovery_screen.dart',
    'supabase/functions/_shared/account-deletion.ts',
    'supabase/functions/account-deletion-recovery/index.ts',
    'supabase/migrations/20261013055042_account_deletion_with_history_preservation.sql',
]
modified, deleted, patch = [], [], []
before_hashes, after_hashes = {}, {}
for relative, original in old_files.items():
    before_hashes[relative] = hashlib.sha256(original.read_bytes()).hexdigest()
    target = root / relative
    if not target.exists():
        deleted.append(relative)
        continue
    after_hashes[relative] = hashlib.sha256(target.read_bytes()).hexdigest()
    if before_hashes[relative] != after_hashes[relative]:
        modified.append(relative)
        patch.extend(difflib.unified_diff(original.read_text(encoding='utf-8').splitlines(keepends=True),
            target.read_text(encoding='utf-8').splitlines(keepends=True),
            fromfile='before/' + relative, tofile='after/' + relative))
for relative in new_files:
    target = root / relative
    after_hashes[relative] = hashlib.sha256(target.read_bytes()).hexdigest()
    patch.extend(difflib.unified_diff([], target.read_text(encoding='utf-8').splitlines(keepends=True),
        fromfile='/dev/null', tofile='after/' + relative))
manifest = {'modified': sorted(modified), 'new': new_files, 'deleted': deleted,
    'tests_run': False, 'migration_applied': False, 'deployed': False,
    'before_sha256': before_hashes, 'after_sha256': after_hashes}
(evidence / 'source_manifest.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
(evidence / 'task_source.diff').write_text(''.join(patch), encoding='utf-8')
result = subprocess.run(['git', 'status', '--short'], cwd=root, capture_output=True, text=True, encoding='utf-8')
(evidence / 'git_status_after.txt').write_text(result.stdout, encoding='utf-8')
print(json.dumps({'modified': len(modified), 'new': len(new_files), 'deleted': deleted,
                  'tests_run': False, 'deployed': False}))
