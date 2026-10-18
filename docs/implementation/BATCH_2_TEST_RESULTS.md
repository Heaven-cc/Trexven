<!-- BATCH_2_CLOSURE_STATUS -->
8 October 2026 — final closure verification. **BATCH 2 — COMPLETE, STAGING VERIFIED.** Latest counts, six-migration replay order and recovery results are in [final closure report](BATCH_2_FINAL_COMPLETION_REPORT.md) and [updated migration plan](MIGRATION_AND_ROLLBACK_PLAN.md). Prior material below is historical and superseded where it describes resolved blockers.

---

# Batch 2 test results

<!-- BATCH_2_FINAL_STATUS -->

8 October 2026 final completion phase: **BLOCKED**, staging-only. This section supersedes the historical checkpoint statements below. Production remains read-only and no release is authorized.

Four required Edge Functions are deployed and integration-tested. Current results: 73 SQL checks plus four older suites; 36 main REST/RPC, 32 main Edge and 10 boundary named checks have final passing outcomes. Owner 64/POS 34 Flutter tests pass. Analysis: zero errors/warnings, Owner 209/POS 4 infos, exit 1 each. All 30 staging catalog groups match after cleanup; only 11 permission definitions and five migration-history entries remain alongside the four deployments.

Fresh replay and actual restore remain blocked by the missing approved disposable environment. Cost-price visibility needs an owner-approved reader contract. Device/persistent pending-sale recovery and controlled-clock midnight/DST HTTP lifecycle remain unverified; no later-phase offline engine or UI redesign was started. See [final completion report](BATCH_2_FINAL_COMPLETION_REPORT.md) and [acceptance matrix](BATCH_2_FINAL_ACCEPTANCE_MATRIX.md).

Current executable environment: Windows PowerShell; Flutter 3.44.9/Dart 3.12.2; Node 22.20.0; workspace Deno 2.9.6/TypeScript 6.0.3; Supabase staging PostgreSQL 17.11.0.003. No device was connected. All database calls used explicit staging references; connector SQL responses provide isError rather than a shell exit code.

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

## Historical checkpoint record — superseded by final status above

# Batch 2 test results

Checkpoint B, 8 October 2026: refreshed Owner 64/POS 33 tests passed; analysis
still reports 210/10 infos, zero errors/warnings, exit 1 each. Edge helper/mocks
and three staff syntax checks passed. Real staging SQL/REST/concurrency now has
final passing outcomes with documented limitations; see
BATCH_2_DATABASE_TEST_RESULTS.md for exact counts, failures/retries and blockers.
The earlier database-blocked section below is historical local-batch evidence.

Date: 7 October 2026. Local workspaces only; no production deployment or adversarial
production testing. Synthetic fixtures/mocks were used. Client/parser results do
not certify database migrations or production security.

| Executed check | Result | Exit code |
| --- | --- | --- |
| Owner `flutter test --no-pub --reporter expanded` | 64 passed | 0 |
| POS `flutter test --no-pub --reporter expanded` | 33 passed | 0 |
| Owner `flutter analyze --no-pub` | 0 errors, 0 warnings, 210 informational findings | 1 |
| POS `flutter analyze --no-pub` | 0 errors, 0 warnings, 10 informational findings | 1 |
| `python supabase/tests/batch_2_static_check.py` | 8 SQL files, 21 PL/pgSQL functions, 9 SQL function bodies, 5 DO blocks parsed | 0 |
| `node --experimental-strip-types --test supabase/tests/batch_2_edge_helpers_test.mts` | 8 helper/mirror tests passed | 0 |
| `node supabase/tests/create_employee_test.cjs` | 9 mock scenarios passed | 0 |
| `node supabase/tests/manage_employee_test.cjs` | 6 mock scenarios passed | 0 |
| `node supabase/tests/angel_test.cjs` | Mock script passed, including employee/forged-business denial | 0 |
| `node supabase/tests/camera_native_test.cjs` | Existing mock script passed | 0 |
| Node `--experimental-strip-types --check` on staff/login/helpers, both login mirrors and Angel | 8 TypeScript syntax checks passed; not Deno type checks | 0 |
| `python supabase/tests/run_batch_2_isolated.py` | BLOCKED before connection; no isolated DSN/runtime; no SQL tests executed | 1 |
| Owner workspace `git diff --check` | Existing trailing whitespace in other modified files; not cleaned as unrelated work | 2 |
| Scoped `git diff --check` on Batch 2 tracked Owner Flutter/Edge files | No whitespace errors; Git emitted line-ending conversion notices | 0 |

Analysis retains informational/deprecation findings and is not clean; nonzero exit
codes are intentional here. Node printed its experimental type-stripping warning.
Workspace-local pglast 8.5 checks syntax, not PostgreSQL 17 schema semantics,
RLS, grants, constraints, RPC behavior or transaction execution.

## Corrected intermediate failures

An intermediate POS run had 24 passes and 1 failure from a mock response missing
its request field. A subsequent run had 18 passes and 3 test-load failures; analysis
reported 2 errors and 10 infos because history referenced `AuthState.business`
instead of `activeBusiness`. Both were corrected. Final POS results are 33 passing
tests and no analysis errors/warnings. Failed runs are not claimed as passes.

## Database suites written, not executed

`batch_2_authorization_tests.sql`, `batch_2_price_security_tests.sql`,
`batch_2_branch_isolation_tests.sql`, `batch_2_checkout_compatibility_tests.sql`
share a marker-guarded synthetic fixture and rollback their transactions. Written
assertions cover ownership/cross-business denial, employee Owner boundary, manager
escalation, explicit manager pricing grants/revocation, direct price insert/update/
upsert/bulk/cost restrictions, pending products/valid zero, assigned/inactive/forged
branches, membership checkout, receipt replay/idempotency and recovery pause.
All database outcomes are UNKNOWN. None is claimed to have passed.

Flutter and mocked Angel checks also cover the app boundary; actual Owner policies
and authenticated HTTP authorization remain untested. Existing backend transaction,
readiness, sale submission and native-camera SQL suites were not executed either.

Docker, Podman, local PostgreSQL/psql and Deno were unavailable; no isolated staging
connection was configured. Original schema predates the migration history; a
complete reviewed schema-only baseline has not been reconstructed. See
`../../supabase/tests/BATCH_2_ISOLATED_TESTING.md` for the guarded loopback runner.
It does not load production project configuration or credentials.

Still required: baseline/migration replay; live RLS/RPC/REST adversarial tests;
last-stock/idempotency/price-change/revocation concurrency; stale-token and local
midnight/DST tests; Deno type/runtime tests; schema drift/advisors; NOT VALID
constraint validation; backup/forward-recovery rehearsal; real stock allocation
and legacy retry acceptance. These checks are blocked or not performed, not
replaced with parser/mock claims.
