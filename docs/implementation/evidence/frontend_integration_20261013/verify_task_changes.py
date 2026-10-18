"""Compare captured dirty-worktree source with current source, not with HEAD."""
import difflib
import hashlib
import json
from pathlib import Path
import re
import subprocess

evidence = Path(__file__).resolve().parent
root = Path(__file__).resolve().parents[4]
baseline = json.loads((evidence / 'baseline.json').read_text(encoding='utf-8'))
current = {}
for folder in ['lib', 'test', 'packages/trexven_operations/lib']:
    for p in (root / folder).rglob('*.dart'):
        current[p.relative_to(root).as_posix()] = hashlib.sha256(p.read_bytes()).hexdigest()
for name in ['pubspec.yaml', 'pubspec.lock']:
    current[name] = hashlib.sha256((root / name).read_bytes()).hexdigest()
modified = sorted(k for k in baseline if k in current and baseline[k] != current[k])
new = sorted(set(current) - set(baseline))
deleted = sorted(set(baseline) - set(current))
protected = ['lib/main.dart', 'lib/screens/welcome_screen.dart',
             'lib/screens/auth/login_screen.dart', 'lib/screens/auth/register_screen.dart',
             'lib/screens/auth/account_gate.dart', 'lib/services/auth_service.dart']
manifest = {'modified': modified, 'new': new, 'deleted': deleted,
            'protected_auth_unchanged': {p: baseline[p] == current[p] for p in protected}}
(evidence / 'modified_files.json').write_text(json.dumps(manifest, indent=2), encoding='utf-8')
patch = []
for relative in modified + new:
    original = evidence / 'baseline' / relative
    if original.suffix in ['.dart', '.yaml']:
        original = Path(str(original) + '.source')
    before = original.read_text(encoding='utf-8').splitlines(keepends=True) if relative in modified else []
    after = (root / relative).read_text(encoding='utf-8').splitlines(keepends=True)
    patch.extend(difflib.unified_diff(before, after, fromfile='pre-task/' + relative,
                                     tofile='current/' + relative))
(evidence / 'task_source.diff').write_text(''.join(patch), encoding='utf-8')
def failures(name):
    value = (evidence / name).read_text(encoding='utf-8', errors='replace')
    return set(re.findall(r'^.*[\\/]test[\\/]([^:]+\.dart): (.+) \[E\]$', value, re.M))
previous = failures('baseline_failures.txt')
final = failures('owner_final_tests.txt')
comparison = {'baseline_failures': sorted(previous), 'final_failures': sorted(final),
              'new_failures': sorted(final - previous), 'resolved_failures': sorted(previous - final)}
(evidence / 'baseline_comparison.json').write_text(json.dumps(comparison, indent=2), encoding='utf-8')
for args, output in [(['status', '--short'], 'git_status_after.txt'),
                     (['diff', '--name-status'], 'git_diff_after.txt')]:
    result = subprocess.run(['git', *args], cwd=root, capture_output=True, text=True, encoding='utf-8')
    (evidence / output).write_text(result.stdout, encoding='utf-8')
print(json.dumps({'modified': len(modified), 'new': len(new), 'deleted': len(deleted),
                  'protected_auth_unchanged': all(manifest['protected_auth_unchanged'].values()),
                  'baseline_failures': len(previous), 'final_failures': len(final),
                  'new_failures': len(final - previous)}, indent=2))
