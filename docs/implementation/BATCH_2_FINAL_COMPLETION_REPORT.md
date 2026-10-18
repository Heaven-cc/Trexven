# Production deployment executed — 9 October 2026

The [execution report](PRODUCTION_DEPLOYMENT_EXECUTION_REPORT.md) supersedes earlier undeployed/approval-blocked status below. Under the user's final explicit authorization, all seven migrations committed (CLI exit 0, history now 16); Batch 2 and Batch 3 are DEPLOYED. Reviewed Edge Functions are DEPLOYED: employee-login v6 (JWT false), create-employee v7, manage-employee v4 and angel v12 (JWT true). Retrieved sources match the frozen package; unrelated functions remain unchanged. Main backend integration for the approved scope is COMPLETE.

All original values across 78 existing non-history tables were preserved. Four canonical permission reference rows were added exactly as approved; the original seven permission rows are unchanged. Postflight verified 39 reviewed functions, RLS/grants/catalog, valid indexes and dormant empty branches. The protected C pre-deployment backup passed immediate checksum/freshness checks; no refresh was required. The timezone remains unset per explicit exclusion, so daily-sales flows need a separate clock configuration decision. No apps were installed/published, no local data cleared, no branches activated and no production synthetic records created. Device verification was explicitly waived for this backend execution and remains an app-update limitation.

---

<!-- BATCH_2_CLOSURE_STATUS -->
# TREXVEN Batch 2 final closure

8 October 2026 — final closure verification. **BATCH 2 — COMPLETE, STAGING VERIFIED.**

The purchase-cost contract, native pending-sale recovery, business-local day enforcement, two clean migration replays and actual backup/restore rehearsals are implemented and verified. This supersedes the earlier blocked report preserved below. No production deployment or app release occurred. Staging `qysspzlfiysekvxnlzsh` was preserved; production `ufehcfrlygqvminfjumf` received read-only metadata inspection only.

## Implemented and tested

- Two new additive migrations restrict purchase-cost exposure while retaining the database column/data, and supply an authenticated business-day RPC with IANA timezone boundaries. The four previously applied migrations remain byte-for-byte unchanged.
- Owner/POS product reads use explicit non-cost projections. Owner Realtime invalidates/refetches that projection. Product models and CSV export exclude cost. Pending/null selling prices remain null through serialization; existing valid zero prices are preserved. Obsolete `view_profit` grants are rejected; explicitly granted `view_finance` remains supported.
- Installed POS saves one sale intent to disk before dispatch, restores it after process restart, preserves actor/business/membership/branch/request identity, retries the original RPC and acknowledges only after receipt display. A delayed response after an actor change cannot display or acknowledge another actor's receipt. This is one interrupted online submission, not the future encrypted offline cash queue.
- Server-derived UTC day bounds replace device-day calculations. Missing/invalid timezone fails closed for staff; no arbitrary location/timezone or branch activation was introduced.
- Two isolated fresh baseline-plus-six-migration replays passed. Schema-only restore and operational synthetic-data backup restore passed. Intentional migration failure rolled back; forward recovery preserved committed sales/receipts/stock.

## Exact final results

| Executed check | Result | Exit/status |
| --- | --- | --- |
| Original five SQL suites plus new cost suite | 84/84 assertions (21/17/11/14/10/11) | Staging connector isError=false; disposable psql exit 0 |
| Four older SQL suites | Four passed | Connector succeeded; local psql exit 0 |
| Real staging REST/RPC | 36 distinct latest-passing checks | Harness exits 0 |
| Real deployed Edge main checks | 32/32 | Exit 0 |
| Real boundary checks | 10/10 latest passing | Exit 0; earlier five expired-session failures retained |
| Combined staging HTTP checks | 78 distinct latest passing | Not inflated by retries |
| Native Auth/REST cost and controlled-clock checks | 18 distinct latest passing | Exit 0; seven earlier receipt-parser failures retained |
| Deno entrypoint checks / runtime helpers | Four entrypoints / 9 tests passed | Exit 0 |
| Node helper and employee/camera wrappers | 12 TAP tests passed | Exit 0; internal scenarios not added to TAP count |
| Owner Flutter full suite | 66 passed | Exit 0 |
| POS Flutter full suite | 37 passed, 1 explicit-live test skipped | Exit 0 |
| Separate disk restart phases | 2 tests before / 2 after | Exit 0 each; different process IDs |
| Separate actual RPC restart phases | 1 before / 1 after | Exit 0 each; same receipt, sale once, stock once |
| Owner / POS analysis | 209 / 4 infos; 0 errors, 0 warnings | Exit 1 each; analysis is not clean |
| Clean migration replays | Two successful baseline + six migration executions | Exit 0 |
| Semantic catalog parity | 30/30 groups in each of four disposable databases | Comparator exit 0 |
| Operational pg_dump/pg_restore; schema-only restore | Both actual restore paths passed | Exit 0 on corrected/final runs |

Detailed evidence and commands are in [database results](BATCH_2_DATABASE_TEST_RESULTS.md), [Edge results](BATCH_2_EDGE_INTEGRATION_RESULTS.md), [restart verification](BATCH_2_OFFLINE_RESTART_TEST_RESULTS.md), [timezone verification](BATCH_2_TIMEZONE_TEST_RESULTS.md), [clean replay](BATCH_2_CLEAN_MIGRATION_REPLAY.md) and [backup recovery](BATCH_2_BACKUP_RECOVERY_RESULTS.md). Final analyzer logs and all failed attempts are retained in `evidence/`.

## Cleanup and limits

Staging has zero synthetic application/Auth/session/Storage rows, except the 11 approved permission definitions; seven truthful migration entries and four ACTIVE version-2 Edge Functions remain. Temporary test helpers and fixture credentials were removed. Local fixture databases have no users/sessions/businesses/sales/receipts; the owned loopback stack is stopped and its synthetic backup removed after hashing/restoring it. [Cleanup evidence](evidence/batch_2_closure_credential_cleanup.json), [staging verification](evidence/batch_2_closure_cleanup_and_failures.json), [local verification](evidence/batch_2_closure_native_audit_cleanup.json).

Production's six recovered metadata sections match the original catalog ([read-only comparison](evidence/batch_2_closure_production_unchanged.json)). This is schema verification, not a newly executed customer-record export or exhaustive production-data audit.

No unresolved critical/high Batch 2 defect was identified in the exercised contracts. Advisor findings remain; see [security review](BATCH_2_FINAL_SECURITY_REVIEW.md). Native host-process persistence is verified; Android device instrumentation, browser durable storage, full offline cash engine, AI-provider operation, real branch activation and historical mapping are not claimed. No Batch 3 or UI/KPI redesign began.

## Requires separate production approval

All six Batch 2 migrations, coordinated Owner/POS/Edge rollout, owner-approved timezone configuration, historical constraint validation and any real branch activation require separate review/authorization. Older `SELECT *` product clients will fail after column grants are restricted: retire/update them before enforcement. Do not apply a staging bootstrap or recovery snapshot over production. See [production readiness](BATCH_2_PRODUCTION_READINESS.md).

---

## Historical report — superseded by the closure update above

# Batch 2 final completion and release readiness

8 October 2026. **Final Batch 2 status: BLOCKED. Not ready for production approval.** Work completed only within the approved local/staging scope. Production ufehcfrlygqvminfjumf remained read-only; no production schema, settings, Edge or app release occurred. Existing staging qysspzlfiysekvxnlzsh was preserved.

## Implemented and verified this phase

- Pinned Supabase Edge dependencies and Deno lockfile; real Deno type checks of all four functions and eight shared-helper runtime tests passed.
- Deployed employee-login, create-employee, manage-employee and Angel to staging; all four remain ACTIVE. Owner/POS login mirror compatibility verified.
- Corrected Angel authorization ordering so missing AI-provider configuration cannot mask employee/forged-business rejection.
- Verified actual creation/status/password reset, role restrictions, cross-business/branch denial and forced Auth-creation compensation. Numeric credential compatibility was tested through the password pathway.
- Re-executed all five Batch 2 SQL suites and four older regressions; verified actual Auth/REST/RPC/checkout/concurrency behavior.
- Added HTTP local-day/missing/invalid timezone tests with an unchanged employee JWT, plus source-based restart characterization in separate Flutter processes.
- Saved a screened schema recovery checkpoint preserving NOT VALID constraints; verified original baseline and four migration hashes.
- Performed authorized production metadata/aggregate historical integrity assessment: 60 FK checks all zero orphans, no employee identity/code/member mismatch.
- Reviewed advisors/grants/definers and ran a rollback-only 1,000-product RLS benchmark.
- Removed six Batch 2 POS context-screen infos and one Owner gate info without changing design/navigation/KPI sizing.

## Exact final results

| Executed check | Final result | Exit/status |
| --- | --- | --- |
| Five Batch 2 SQL suites | 73/73 assertions: 21 authorization, 17 branch, 11 checkout, 14 price, 10 temporal | All connector calls isError=false; no shell exit supplied |
| Four earlier SQL suites | All passed after corrected readiness adapter retry | Connector isError=false; first cached-adapter failure retained |
| Staging REST/RPC main harness | 36 distinct final-passing named checks | Final phase commands exit 0; 43 recorded attempts include four failed assertions |
| Deployed Edge main harness | 32/32 named checks | Exit 0 |
| Live boundary harness | 10/10 named checks on final run | Exit 0; 28 attempts include two earlier response-parser failures |
| Combined named HTTP checks | 78 latest-passing checks | Includes cost-field exposure characterization, not privacy acceptance |
| Deno check | Four entrypoints/imported helpers pass | Exit 0 |
| Deno helper runtime | 8 passed, 0 failed | Exit 0 |
| Node helper/employee/Angel mock runner | 11 TAP tests passed | Exit 0; internal creation/reset scenarios 9/6 |
| Existing camera mock | 1 TAP wrapper passed | Exit 0; no camera deployment |
| Owner full Flutter suite after final edit | 64 passed | Exit 0 |
| POS full Flutter suite | 34 passed | Exit 0 |
| Separate restart before/after processes | One characterization check each passed | Exit 0 each; does not certify durable recovery |
| Owner analysis | 0 errors, 0 warnings, 209 infos | Exit 1 |
| POS analysis | 0 errors, 0 warnings, 4 infos | Exit 1 |
| SQL static validation | 10 files, 21 PL/pgSQL functions, 10 SQL bodies, six DO blocks parsed | Exit 0; separate from runtime SQL |
| Approved baseline regeneration/hash | Unchanged SHA-256 | Exit 0 |
| Start versus final staging schema | 30/30 groups match | Comparator exit 0 |
| Aborted synthetic DDL transaction | P0001 expected; subsequent probe absent | Expected connector failure, independent verification succeeded |
| Synthetic RLS benchmark | 1,003 rows; planning 0.123 ms, execution 328.585 ms | Connector succeeded; fixture rolled back |

Logs/artifacts are linked from BATCH_2_TEST_RESULTS.md and the eight final reports. Historical Checkpoint A/B test totals remain historical. Analyzer output is not clean; PowerShell stderr wrappers are retained in raw logs and do not represent extra Flutter warning/error findings.

## Failed attempts retained

The cached legacy readiness adapter omitted owner identity restoration before protected staff updates; the corrected adapter passed (the repository fixture already includes the owner identity switches). Concurrency setup omitted its readiness helper, producing PGRST202; the cached eight-second hold exceeded the API timeout (57014) and rolled back its simulated price update, invalidating that assertion. Restoring the readiness helper and using a two-second hold produced passing overlap checks.

The first branch fixture used nonexistent businesses.name instead of business_name and rolled back. Running its dependent checks before the corrected fixture produced three failed expectations; all five branch checks passed after correcting setup/restoring the test assignment. The boundary harness initially parsed successful empty PATCH bodies as JSON; two checks failed parsing, then the corrected harness passed all ten. Cleanup's first generated DO delimiter was collapsed by JavaScript replacement-string escaping and caused a syntax error with no committed deletion; corrected guarded cleanup succeeded.

Initial post-Batch-2 rendering rejected unvalidated constraints; an explicit renderer option preserved their actual state. Local parser invocation initially omitted its workspace import path, and analyzer counting initially used UTF-8 for UTF-16 PowerShell logs; both tooling invocations were corrected. Dependency-age protection rejected 2.117.3; older 2.117.2 was pinned without bypass. These failures are not counted as passes.

## Blocked, unverified, proposed and deferred

Essential blocker: no approved separate disposable Supabase/PostgreSQL environment for fresh baseline-plus-four-migration replay, migration lifecycle/forward recovery and actual restore. Existing staging was not destroyed to manufacture this evidence.

Additional unresolved gates: cost-price read policy needs an owner-approved reader mapping and regression-tested enforcement; device/persistent pending-sale lifecycle is not verified; controlled-clock midnight/DST Auth/HTTP lifecycle remains unverified. Current-day real HTTP and SQL DST arithmetic do not replace the latter. Missing production business timezone configuration must be resolved by owner-approved values during a separate release plan.

Implemented but unverified: recovery artifact restoration, full clean replay, production-scale performance, external Angel response, SMTP/rate-limit behavior and distributed Auth-reset failure/revocation edge cases.

Proposed but not implemented: approved cost visibility contract, disposable replay/restore executor guard adaptation, production release/history reconciliation and operational recovery rehearsal. No new schema migration beyond the existing four was applied.

Intentionally deferred: real branch stock allocation/activation/history mapping, variants/branch price overrides, full offline reconciliation, financial/payment/credit/refund/cash-shift/subscription workflows and UI/KPI redesign, as assigned to later master phases. Batch 3 was not started.

## Cleanup and exact retained state

All 34 public/private application tables are empty except public.permissions (11 approved definitions). Auth users and sessions, Storage buckets/objects, businesses, branches, sales, request ledgers, employee assignments and temporary helpers are zero. Five actual migration-history entries and four required staging Edge deployments remain. Synthetic sessions were globally signed out where valid; an expired reset-session logout returned 403, and scoped session deletion then removed all remaining synthetic sessions before Auth deletion. Ignored password/JWT/Auth fixture/public-config files were removed.

## Changes for review

Owner: four required Edge entrypoints, supabase/functions/deno.lock, Angel mock regressions, baseline renderer's explicit unvalidated option, final HTTP harnesses/evidence/checkpoint and documentation, and the authorization gate's braces. POS: byte-identical employee-login dependency mirror, context-selection-screen deprecation/wildcard cleanup, and restart characterization test. Existing four migration files and checkout serializers were preserved. No mixed-workspace commit or production-linked push was performed.

## Proposed production sequence — requires separate approval

1. Complete the disposable replay/restore gates and obtain decisions/evidence for cost visibility, offline deferral and controlled-clock coverage.
2. Independently verify production reference/history/catalog, recheck aggregate readiness, and create/test an actual authorized recovery point covering application and Auth data.
3. Approve trusted permission initialization, timezone configuration and all four archived migration hashes. Do not restore the staging baseline into existing production.
4. Apply the four additive migrations in order using an explicit target; keep branch mode disabled and do not backfill unknown historical records. Validate staged historical constraints only after a reviewed integrity gate.
5. Separately approve/deploy the four compatible Edge bundles, review gateway verification, securely configure only approved providers and repeat role/checkout smoke tests.
6. Separately approve compatible Owner/POS releases. Monitor denies, checkout/idempotency and audit errors; rehearse the protected write-pause/forward fix before use.
7. Preserve additive security objects, IDs, receipts and ledgers during recovery. Never reopen old permissive pricing or revert active branch stock to legacy global quantity.

Separate explicit approval is required for every production migration/configuration change, constraint validation, Edge deployment/secret, Flutter release, real branch activation/allocation, platform backup/upgrade change or optional Storage bucket. None is authorized by this final staging task.

## Required final deliverables

| Deliverable | Report |
| --- | --- |
| Acceptance checklist | [Acceptance matrix](BATCH_2_FINAL_ACCEPTANCE_MATRIX.md) |
| Deployed function integration | [Edge results](BATCH_2_EDGE_INTEGRATION_RESULTS.md) |
| Migration lifecycle | [Clean replay](BATCH_2_CLEAN_MIGRATION_REPLAY.md) |
| Backup and restoration | [Recovery results](BATCH_2_BACKUP_RECOVERY_RESULTS.md) |
| Historical integrity | [Production aggregates](BATCH_2_HISTORICAL_COMPATIBILITY.md) |
| Authorization/advisors | [Security review](BATCH_2_FINAL_SECURITY_REVIEW.md) |
| Retry/restart boundaries | [Offline/restart results](BATCH_2_OFFLINE_RESTART_TEST_RESULTS.md) |
| Exact commands/logs | [Updated test report](BATCH_2_TEST_RESULTS.md) |

Stop after Batch 2. Essential missing evidence prevents COMPLETE—STAGING VERIFIED.
