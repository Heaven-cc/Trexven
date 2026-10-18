"""Freeze reviewed sources and evidence; performs no database or deployment action."""
from pathlib import Path
import datetime
import hashlib
import json
import shutil
import subprocess
from render_final_guarded_migration import render

ROOT = Path(__file__).resolve().parents[2]
POS = ROOT.parent / 'trexvenpos'
OUT = ROOT / 'supabase/releases/final_coordinated_20261009'
OUT.mkdir(exist_ok=True)

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def read(path):
    return json.loads(path.read_text(encoding='utf-8-sig'))

def freeze(path, destination, root='owner'):
    target = OUT / destination
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(path, target)
    return {'root': root, 'source': path.relative_to(ROOT if root == 'owner' else POS).as_posix(),
            'package': destination, 'sha256': digest(path)}

deployed = read(ROOT/'supabase/releases/main_backend_alignment_20261009/manifest.json')
predecessor = dict(deployed['original_history_file_hashes'])
for migration in deployed['pending_migrations']:
    predecessor[Path(migration['file'].replace('\\','/')).name] = migration['sha256']
assert len(predecessor) == 16
for name, sha in predecessor.items():
    assert digest(ROOT/'supabase/migrations'/name) == sha, 'Deployed migration changed'
original = read(ROOT/'supabase/releases/batches_4_7_development_20261009/manifest.json')
migrations = []
for item in original['migration_order']:
    path = ROOT/item['path']
    assert digest(path) == item['sha256'], 'Original Batch 4–7 candidate changed'
    migrations.append(path)
migrations += sorted((ROOT/'supabase/migrations').glob('*_batch_[89]_*.sql'))
assert len(migrations) == 16 and migrations == sorted(migrations)
assert set(p.name for p in (ROOT/'supabase/migrations').glob('*.sql')) == set(predecessor) | {p.name for p in migrations}
replay = read(ROOT/'docs/implementation/evidence/batch_9_native_replay_results.json')
assert all(row['exit_code'] == 0 for row in replay)
replayed = {row['step']:row.get('source_sha256') for row in replay}
assert all(replayed[p.stem] == digest(p) for p in migrations)
assert len([row for row in replay if row.get('rolled_back')]) == 13
assert read(ROOT/'docs/implementation/evidence/batch_9_release_history_guard.json')['passed']

files = [freeze(p, 'migrations/'+p.name) for p in migrations]
execution = []
history = sorted(name.split('_')[0] for name in predecessor)
for path in migrations:
    target = OUT/'execution'/path.name
    target.parent.mkdir(exist_ok=True)
    target.write_text(render(path, history),encoding='utf-8')
    execution.append({'package':target.relative_to(OUT).as_posix(),'sha256':digest(target)})
    history.append(path.name.split('_')[0])
for name in ['camera-ai','delete-account']:
    files.append(freeze(ROOT/f'supabase/functions/{name}/index.ts', f'supabase/functions/{name}/index.ts'))
files.append(freeze(ROOT/'supabase/functions/deno.lock', 'supabase/functions/deno.lock'))
config = OUT/'supabase/config.toml'
config.write_text('project_id = "trexven-final-coordinated"\n\n'+''.join(
    f'[functions.{name}]\nverify_jwt = true\nentrypoint = "./functions/{name}/index.ts"\n\n'
    for name in ['camera-ai','delete-account']), encoding='utf-8')

# Freeze Android application source, shared package, assets and resolved Flutter
# dependencies. No generated builds, secrets, signing keys or local journals.
for root, label in [(ROOT,'owner'),(POS,'pos')]:
    paths = []
    for tree in ['lib','assets'] + (['packages/trexven_operations/lib'] if label=='owner' else []):
        if (root/tree).exists():
            paths.extend(p for p in (root/tree).rglob('*') if p.is_file())
    for name in ['pubspec.yaml','pubspec.lock','analysis_options.yaml',
                 'android/app/build.gradle.kts','android/app/build.gradle',
                 'android/build.gradle.kts','android/settings.gradle.kts',
                 'android/build.gradle','android/settings.gradle', '.metadata',
                 'android/gradlew','android/gradlew.bat',
                 'android/gradle/wrapper/gradle-wrapper.jar',
                 'android/gradle.properties','android/gradle/wrapper/gradle-wrapper.properties']:
        if (root/name).is_file(): paths.append(root/name)
    paths += [p for p in (root/'android/app/src').rglob('*') if p.is_file()]
    if label=='owner':
        paths += [root/'packages/trexven_operations/pubspec.yaml']
    for path in sorted(set(paths)):
        rel = path.relative_to(root).as_posix()
        assert not any(word in rel.lower() for word in ['pgpass','keystore','.jks','.env'])
        files.append(freeze(path, f'sources/{root.name}/{rel}', label))
    for path in sorted((root/'test').glob('*.dart')):
        files.append(freeze(path, f'sources/{root.name}/test/{path.name}',label))

test_sources = list((ROOT/'supabase/tests').glob('batch_[3456789]_*tests.sql'))
test_sources += [ROOT/'supabase/tests'/('batch_2_'+name+'_tests.sql') for name in
                ['authorization','branch_isolation','price_security','checkout_compatibility']]
for path in sorted(test_sources):
    files.append(freeze(path,'verification/'+path.name))
files.append(freeze(ROOT/'supabase/tests/batch_2_fixture.sql','verification/batch_2_fixture.sql'))
for relative in ['supabase/tests/run_final_native_qa.py','supabase/tests/prepare_staging_final_qa.py',
                 'supabase/tests/test_final_release_history_guard.py',
                 'supabase/releases/render_final_guarded_migration.py',
                 'docs/implementation/TREXVEN_FINAL_IMPLEMENTATION_AND_RELEASE_READINESS_REPORT.md',
                 'docs/implementation/BATCH_8_9_OUTSTANDING_WORK_REGISTER.md',
                 'docs/implementation/COORDINATED_FINAL_ROLLOUT_AND_RECOVERY.md',
                 'docs/implementation/FEATURE_GAP_MATRIX.md',
                 'docs/implementation/MIGRATION_AND_ROLLBACK_PLAN.md',
                 'docs/implementation/KPI_COMPONENT_AUDIT.md']:
    path = ROOT/relative
    files.append(freeze(path,'review/'+path.name))
source_changes = {}
for root,label in [(ROOT,'owner'),(POS,'pos')]:
    tracked = subprocess.run(['git','diff','--name-only','HEAD','--','lib','packages','assets','android','pubspec.yaml','pubspec.lock','test'],
                             cwd=root,capture_output=True,text=True)
    untracked = subprocess.run(['git','ls-files','--others','--exclude-standard','--','lib','packages','assets','android','pubspec.yaml','pubspec.lock','test'],
                               cwd=root,capture_output=True,text=True)
    if tracked.returncode==0 and untracked.returncode==0:
        source_changes[label] = {'baseline_available':True,
          'changed_paths':sorted(set(tracked.stdout.splitlines()+untracked.stdout.splitlines()))}
    else:
        source_changes[label] = {'baseline_available':False,
          'reason':'No usable Git HEAD comparison; exact frozen source inventory is in manifest.files',
          'frozen_paths':sorted(row['source'] for row in files if row['root']==label and row['package'].startswith('sources/'))}
inventory = OUT/'source_change_inventory.json'
inventory.write_text(json.dumps({'comparison':'Combined working tree versus current repository HEAD; includes previously implemented changes',
 'files':source_changes},indent=2)+'\n')

evidence = []
for path in sorted((ROOT/'docs/implementation/evidence').glob('batch_9_*.json')):
    if 'attempt' not in path.name:
        evidence.append(freeze(path, 'evidence/'+path.name))
manifest = {
    'candidate':'final_coordinated_20261009', 'frozen_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'status':'SOURCE_CANDIDATE_VERIFIED_ANDROID_RELEASE_GATES_BLOCKED',
    'production_project':'ufehcfrlygqvminfjumf', 'staging_project':'qysspzlfiysekvxnlzsh',
    'production_approved':False, 'production_applied':False, 'charging_enabled':False,
    'branch_activation_authorized':False, 'applications_published':False,
    'predecessor_migration_hashes':predecessor,
    'expected_predecessor_history':sorted(name.split('_')[0] for name in predecessor),
    'migration_order':[row for row in files if row['package'].startswith('migrations/')],
    'edges':[{'name':name,'verify_jwt':True} for name in ['camera-ai','delete-account']],
    'files':files, 'evidence':evidence, 'guarded_execution':execution,
    'package_config':'supabase/config.toml', 'package_config_sha256':digest(config),
    'source_change_inventory_sha256':digest(inventory),
    'android_artifacts':{'owner':None,'pos':None,'installed_versions_verified':False},
    'remaining_gates':['Adequate safe C build scratch space and final Android APK builds',
      'Connected test device: package/signer, startup, update, secure key and pending-sale retention',
      'Fresh production identity/history/catalog and backup fingerprint check immediately before deployment',
      'Explicit approval of the frozen complete candidate'],
}
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2)+'\n',encoding='utf-8')
(OUT/'manifest.sha256').write_text(digest(OUT/'manifest.json')+'  manifest.json\n',encoding='utf-8')
print(json.dumps({'pending_migrations':len(migrations),'source_files':len(files),
 'evidence_files':len(evidence),'manifest_sha256':digest(OUT/'manifest.json'),'production_writes':0}))
