"""Restore pre-task source in a disposable copy, never in the active checkout."""
import json
import os
from pathlib import Path
import shutil
import tempfile

root = Path(__file__).resolve().parents[4]
evidence = Path(__file__).resolve().parent
target = Path(tempfile.mkdtemp(prefix='trexven-pre-task-')) / 'Trexven'
target.mkdir()
for name in ['lib', 'test', 'packages', 'assets']:
    shutil.copytree(root / name, target / name,
                    ignore=shutil.ignore_patterns('build', '.dart_tool', '.git'))
for name in ['pubspec.yaml', 'pubspec.lock', 'analysis_options.yaml']:
    shutil.copy2(root / name, target / name)
(target / '.dart_tool').mkdir()
for name in ['package_config.json', 'package_graph.json']:
    shutil.copy2(root / '.dart_tool' / name, target / '.dart_tool' / name)
baseline = json.loads((evidence / 'baseline.json').read_text(encoding='utf-8'))
for relative in baseline:
    source = evidence / 'baseline' / relative
    if source.suffix in ['.dart', '.yaml']:
        source = Path(str(source) + '.source')
    if not source.exists():
        raise RuntimeError(f'Missing captured baseline: {relative}')
    shutil.copy2(source, target / relative)
# Exclude new task sources from this pre-task copy.
for prefix in ['lib', 'test', 'packages/trexven_operations/lib']:
    for candidate in (target / prefix).rglob('*.dart'):
        relative = candidate.relative_to(target).as_posix()
        if relative not in baseline:
            candidate.unlink()
(evidence / 'baseline_workspace.json').write_text(
    json.dumps({'path': str(target)}, indent=2), encoding='utf-8')
print(target)
