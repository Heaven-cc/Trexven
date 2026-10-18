"""Local documentation update only; no database/network/credentials."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOCS = ROOT / 'docs' / 'implementation'
SUMMARY = '''8 October 2026 final completion phase: **BLOCKED**, staging-only. This section supersedes the historical checkpoint statements below. Production remains read-only and no release is authorized.

Four required Edge Functions are deployed and integration-tested. Current results: 73 SQL checks plus four older suites; 36 main REST/RPC, 32 main Edge and 10 boundary named checks have final passing outcomes. Owner 64/POS 34 Flutter tests pass. Analysis: zero errors/warnings, Owner 209/POS 4 infos, exit 1 each. All 30 staging catalog groups match after cleanup; only 11 permission definitions and five migration-history entries remain alongside the four deployments.

Fresh replay and actual restore remain blocked by the missing approved disposable environment. Cost-price visibility needs an owner-approved reader contract. Device/persistent pending-sale recovery and controlled-clock midnight/DST HTTP lifecycle remain unverified; no later-phase offline engine or UI redesign was started. See [final completion report](BATCH_2_FINAL_COMPLETION_REPORT.md) and [acceptance matrix](BATCH_2_FINAL_ACCEPTANCE_MATRIX.md).
'''
EXTRA = {
    'BATCH_2_PRODUCTION_READINESS.md': '''Production recommendation: **NOT READY**. Before requesting rollout approval, complete disposable replay/restore, resolve cost visibility, obtain pending-sale/clock evidence or explicit non-blocking deferrals, and configure owner-approved business timezones. Production has no timezone column yet; migration 2 adds NULL, so ordinary staff history fails closed until configured.

Production execution must target ufehcfrlygqvminfjumf explicitly only after separate approval. Do not apply the staging bootstrap to production, fabricate earlier migration history, create optional buckets, activate real branches or redistribute historical stock. Proposed ordered production steps and forward recovery are in the final completion report.
''',
    'FEATURE_GAP_MATRIX.md': '''| Current Batch 2 area | Final status |
| --- | --- |
| Backend owner/role/business/branch/price-write enforcement | Verified in staging |
| Edge login/create/manage/Angel authorization | Deployed and verified; external AI response unavailable |
| Historical production aggregate integrity | Assessed read-only; 60 FK orphan checks zero |
| Cost-price read visibility | Decision/enforcement gap; existing inventory reads expose the field |
| Legacy/branch checkout and live-process idempotent retry | Verified; serialization preserved |
| App restart durable cart/request/branch recovery | Missing current capability; master Phase 3 boundary retained |
| Today visibility | Real HTTP current-day and missing/invalid timezone verified; frozen-clock DST unverified |
| Fresh migration replay / actual restore | Blocked: no approved disposable target/runtime |
| Real branch inventory allocation/activation, variants, billing, UI/KPIs | Deferred to separately approved phases |
''',
    'MIGRATION_AND_ROLLBACK_PLAN.md': '''Final recovery addendum: archived pre-Batch-2 baseline hash and all four migration hashes are unchanged (batch_2_final_recovery_manifest.json). New BATCH_2_FINAL_RECOVERY_CHECKPOINT.sql preserves seven NOT VALID constraints and current grants/functions; SHA-256 020aee18499cc5d392f023ae86d23377aa1a1649684068bf40903c996b5bdb46. Its guarded empty-schema restore has NOT been executed. It contains all four migrations already; never replay them on top of it.

Companion configuration/history snapshots preserve 11 trusted permission definitions and five actual staged version/name records. They are provenance, not proof those versions were restored. Review a target-specific guard adapter for a separately approved empty disposable environment; do not spoof staging or reset existing staging. Fresh baseline order is permission-only initialization, authorization, branch foundation, branch checkout, portable security correction.

One actual aborted private-table DDL transaction raised P0001 and left no object. This does not replace a clean replay or failure/forward-recovery/restore rehearsal. Retain security guards, deny rows, nullable branch history and original request/receipt/member IDs; use reviewed forward fixes, not reopening old grants. See [clean replay](BATCH_2_CLEAN_MIGRATION_REPLAY.md) and [recovery results](BATCH_2_BACKUP_RECOVERY_RESULTS.md).
''',
    'BATCH_2_TEST_RESULTS.md': '''Current executable environment: Windows PowerShell; Flutter 3.44.9/Dart 3.12.2; Node 22.20.0; workspace Deno 2.9.6/TypeScript 6.0.3; Supabase staging PostgreSQL 17.11.0.003. No device was connected. All database calls used explicit staging references; connector SQL responses provide isError rather than a shell exit code.

| Current command / transport | Exact final outcome | Evidence |
| --- | --- | --- |
| execute_sql staging: five translated rollback-only Batch 2 suites | 73 assertions passed; isError=false | ../../supabase/tests/baseline/batch_2_final_sql_results.json |
| execute_sql staging: four older SQL regressions | All final passing; cached readiness first attempt failed | Same evidence; corrected retry retained |
| node supabase/tests/checkpoint_b_rest.cjs tests, branch, concurrent_revocation, concurrent_price | 36 latest-passing names; final commands exit 0 | batch_2_final_rest_results.json under baseline; prior failed attempts retained |
| node supabase/tests/batch_2_final_edge.cjs | 32/32; exit 0 | batch_2_final_edge_results.json |
| node supabase/tests/batch_2_final_boundaries.cjs | 10/10 final; exit 0 | batch_2_final_boundary_results.json |
| deno check: four function entrypoints | Types pass; exit 0 | [Deno check log](batch_2_final_deno_check.log) |
| deno test --allow-read supabase/tests/batch_2_edge_helpers_test.mts | 8/8; exit 0 | [Deno runtime log](batch_2_final_deno_runtime_tests.log) |
| node --test angel_test.cjs create_employee_test.cjs manage_employee_test.cjs batch_2_edge_helpers_test.mts (all under supabase/tests) | 11 TAP tests; exit 0 | [Node log](batch_2_final_node_regressions.log) |
| node --test supabase/tests/camera_native_test.cjs | 1 TAP wrapper; exit 0 | [Camera mock log](batch_2_final_camera_mock.log) |
| Owner flutter test --reporter expanded after final edit | 64 passed; exit 0 | [Owner test log](batch_2_final_owner_after_cleanup_test.log) |
| POS flutter test --reporter expanded | 34 passed; exit 0 | [POS test log](batch_2_final_pos_flutter_test.log) |
| Separate POS flutter test test/offline_restart_characterization_test.dart --dart-define=RESTART_PHASE=before/after --reporter expanded | One passing negative characterization each; exit 0 | [Before](batch_2_final_restart_before.log), [after](batch_2_final_restart_after.log); not durable recovery acceptance |
| Owner/POS flutter analyze | 209/4 infos, zero errors/warnings; exit 1 each | [Owner](batch_2_final_owner_after_cleanup_analyze.log), [POS](batch_2_final_pos_analyze.log) |
| python supabase/tests/batch_2_static_check.py | 10 files, 21 PL/pgSQL, 10 SQL bodies, six DO blocks; exit 0 | [Static log](batch_2_final_sql_static.log) |
| python supabase/tests/baseline/build_baseline.py --check | Immutable SHA matches; exit 0 | [Baseline log](batch_2_final_baseline_hash.log) |
| Same normalization as compare_checkpoint_a.py, final start/end catalogs | 30/30 semantic groups match; exit 0 | batch_2_final_parity.json |
| Scoped git diff --check on touched tracked gate/Edge sources | Exit 0 | Tool execution; POS has no Git metadata |

Main REST recording has 43 attempts (39 pass, four fail), 36 distinct checks with all latest results passing. Boundary recording has 28 attempts (26 pass, two fail), 10 distinct checks with all latest results passing. Edge recording has 32 attempts, all passing. The total 78 named checks includes cost-field exposure characterization, which documents a privacy policy gap. Top-level readiness/timeout setup failures are also recorded narratively in the final completion report.

Adversarial production testing, fresh full replay, actual restore, device recovery and frozen-clock HTTP/Auth DST transitions were NOT executed. Real production checks were limited to metadata/aggregate SELECTs. Earlier results below are historical, not newly executed claims.
''',
}
targets = [
    'BATCH_2_PRODUCTION_READINESS.md', 'FEATURE_GAP_MATRIX.md',
    'MIGRATION_AND_ROLLBACK_PLAN.md', 'BATCH_2_TEST_RESULTS.md',
    'BATCH_2_DATABASE_TEST_RESULTS.md', 'BATCH_2_MIGRATION_REHEARSAL.md',
    'BATCH_2_SECURITY_VERIFICATION.md', 'BATCH_2_COMPLETION_REPORT.md',
    'BATCH_2_BASELINE_MIGRATION_SEQUENCE.md',
]
marker = '<!-- BATCH_2_FINAL_STATUS -->'
for name in targets:
    path = DOCS / name
    original = path.read_text(encoding='utf-8')
    if marker in original:
        raise RuntimeError('Final status already added: ' + name)
    title = original.splitlines()[0]
    updated = title + '\n\n' + marker + '\n\n' + SUMMARY + '\n' + EXTRA.get(name, '')
    updated += '\n## Historical checkpoint record — superseded by final status above\n\n'
    updated += original
    path.write_text(updated, encoding='utf-8')
    print('Updated ' + name)
