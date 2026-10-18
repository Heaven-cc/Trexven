<!-- BATCH_2_CLOSURE_STATUS -->
# Batch 2 final database results

8 October 2026 — final closure verification. **BATCH 2 — COMPLETE, STAGING VERIFIED.**

The actual PostgreSQL/hosted checks supersede earlier parser-only and unavailable-runtime gaps. Staging was the only hosted write/test target; native SQL was guarded to loopback port 54322 and the owned disposable identity. No production adversarial tests were performed.

| Suite | Assertions | Staging | Both native replays |
| --- | ---: | --- | --- |
| batch_2_authorization_tests.sql | 21 | Passed | Exit 0 |
| batch_2_branch_isolation_tests.sql | 17 | Passed | Exit 0 |
| batch_2_checkout_compatibility_tests.sql | 11 | Passed | Exit 0 |
| batch_2_price_security_tests.sql | 14 | Passed | Exit 0 |
| batch_2_temporal_security_tests.sql | 10 | Passed | Exit 0 |
| batch_2_cost_contract_tests.sql | 11 | Passed | Exit 0 |
| Total | 84 | Passed | Passed |

Assertion-helper name `fails` denotes an expected failure assertion, not a failed test. Actual helper invocations and source hashes are in [SQL results](evidence/batch_2_closure_sql_results.json); staging successes and initial render errors are in [connector execution](evidence/batch_2_closure_staging_sql_execution.json). Each fixture transaction rolls back. The four older suites `backend_transaction_tests.sql`, `sale_submission_tests.sql`, `readiness_access_tests.sql` and `native_camera_limit_tests.sql` also passed ([exact executions](evidence/batch_2_closure_older_sql_results.json)); no invented assertion total is assigned to them.

Real staging HTTP covers owner/business isolation, role restrictions, price insert/update/upsert/RPC denial, explicit manager grants, stale permission revocation, multi-branch isolation, forged IDs, legacy checkout, receipt/idempotency and held concurrent last-stock/price/revocation scenarios: [36 REST checks](evidence/batch_2_closure_staging_rest.json), [concurrency price log](evidence/batch_2_closure_concurrent_price.log), [revocation log](evidence/batch_2_closure_concurrent_revocation.log). The Edge and boundary harnesses supply the remaining 42 checks; together 78 distinct latest-passing checks.

The new migration retains `products.cost_price` and existing numeric/default constraints. Authenticated table-wide product access is replaced by grants on 20 non-cost columns. Direct cost selection, wildcard reads, inserts/updates and legacy cost-bearing audit rows fail closed. Active product, sale receipt and Angel projections exclude cost. No service-role key is supplied to Flutter. Zero selling prices are preserved; only null/pending products are non-sellable.

The native HTTP run adds 18 distinct checks (9 cost contracts, 7 controlled-clock scenarios, forged business and missing timezone). These are additional named checks, not extra SQL assertions. [API attempt record](evidence/batch_2_closure_native_http.json) preserves 36 attempts: 29 pass, 7 fail, with all 18 names passing on the final run.

Commands: `python supabase/tests/prepare_batch_2_staging.py` renders rollback-only fixtures; guarded `psql -X -v ON_ERROR_STOP=1` executes them. Hosted execution uses explicit-project connector SQL, whose successful result has no numeric shell exit. Native harness commands and guard prerequisites are in [closure harness instructions](../../supabase/tests/closure/README.md).

Schema parity compares 34 tables, 339 columns, 131 constraints, 108 indexes, 45 functions, 15 triggers, 122 policies, ACL/default grants/extensions and 7 Realtime registrations. All 30 semantic groups match staging for replay 1, replay 2, operational restore and schema-only restore ([comparison](evidence/batch_2_closure_catalog_semantic_parity.json)). Database-local OIDs, SQL line endings and unordered rows explain retained raw differences; column order, ownership, grants, function settings and 7 NOT VALID constraints remain checked.

Failures retained: malformed local renderer output sent as SQL was rejected with 42601; corrected fixtures passed. Boundary fixture owner impersonation was correctly rejected with 42501, then the actual sales identity succeeded. Initial staging cleanup FK failure rolled back; child-first scoped cleanup succeeded. No failure was hidden with an undocumented staging schema alteration.

---

## Historical report — superseded by the closure update above

# Batch 2 database test results

<!-- BATCH_2_FINAL_STATUS -->

8 October 2026 final completion phase: **BLOCKED**, staging-only. This section supersedes the historical checkpoint statements below. Production remains read-only and no release is authorized.

Four required Edge Functions are deployed and integration-tested. Current results: 73 SQL checks plus four older suites; 36 main REST/RPC, 32 main Edge and 10 boundary named checks have final passing outcomes. Owner 64/POS 34 Flutter tests pass. Analysis: zero errors/warnings, Owner 209/POS 4 infos, exit 1 each. All 30 staging catalog groups match after cleanup; only 11 permission definitions and five migration-history entries remain alongside the four deployments.

Fresh replay and actual restore remain blocked by the missing approved disposable environment. Cost-price visibility needs an owner-approved reader contract. Device/persistent pending-sale recovery and controlled-clock midnight/DST HTTP lifecycle remain unverified; no later-phase offline engine or UI redesign was started. See [final completion report](BATCH_2_FINAL_COMPLETION_REPORT.md) and [acceptance matrix](BATCH_2_FINAL_ACCEPTANCE_MATRIX.md).


## Historical checkpoint record — superseded by final status above

# Batch 2 database test results

8 October 2026. **Checkpoint B backend acceptance: PASSED WITH DOCUMENTED LIMITATIONS.**
Target: `qysspzlfiysekvxnlzsh` only. Production `ufehcfrlygqvminfjumf`
received no SQL, tests, migrations, settings changes or deployments in this checkpoint.
This report supersedes the earlier blocked staging results.

## Executed database checks

Checkpoint A was reverified before any write: all 30 catalog groups matched, all
32 application tables were empty, Auth/Storage were empty, and only bootstrap
`20261007235400` was recorded. The approved baseline hash still matches.

| Real PostgreSQL suite | Checks | Final result |
| --- | ---: | --- |
| batch_2_authorization_tests.sql | 21 (16 true, 5 denial) | PASS after versioned RLS correction |
| batch_2_price_security_tests.sql | 14 (3 true, 10 denial, 1 invalid-operation) | PASS |
| batch_2_branch_isolation_tests.sql | 17 (12 true, 3 denial, 2 invalid-operation) | PASS |
| batch_2_checkout_compatibility_tests.sql | 11 (6 true, 3 denial, 2 invalid-operation) | PASS |
| batch_2_temporal_security_tests.sql | 10 (8 true, 2 denial) | PASS |
| backend_transaction_tests.sql | Existing DO-block assertions; not separately counted | PASS |
| sale_submission_tests.sql | Existing DO-block assertions; not separately counted | PASS |
| readiness_access_tests.sql | Existing DO-block assertions; not separately counted | PASS after fixture actor correction |
| native_camera_limit_tests.sql | Existing DO-block assertions; not separately counted | PASS |

The original four suites contain **63** checks; the supplemental suite adds **10**.
All suites execute real roles, JWT subject settings, constraints, RLS, triggers and
RPCs on the recovered schema, and roll back synthetic records. No shell exit code
is assigned to MCP SQL calls: final calls returned `isError=false` with success
summaries. The old loopback runner remains unchanged. `prepare_batch_2_staging.py`
only translates psql include/gset/binds to typed temporary variables and an
in-transaction temporary marker; independent project verification occurs at execution.

## Real Auth, REST/RPC and concurrency

Five freshly generated synthetic accounts signed in through staging Auth with
real issued access tokens. Auth fixtures were inserted only in this verified empty
staging project, including synthetic email identities and bcrypt passwords.
No Auth schema/configuration or service-role key was used/changed.

`node supabase/tests/checkpoint_b_rest.cjs setup` exited 0.
`tests` exited 0: 29 checks; `branch` exited 0: 5 checks.
Final `concurrent_revocation` and `concurrent_price` each exited 0.
**36 distinct HTTP checks have final passing outcomes.** The retained attempt log
contains 42 entries: 39 successful attempts and 3 failed attempts, including repeated
concurrency checks; do not report 39 distinct tests or erase intermediate failures.
Five successful Auth sign-ins are recorded separately from those 36 checks.

Coverage includes direct price PATCH/INSERT/UPSERT, mixed bulk atomicity, cost-price
denial, permission metadata mutation, manager escalation, explicit manager pricing,
stale-token revocation, cross-business and branch denial, private/anonymous RPC
denial, pending creation/non-sale, legacy checkout, exact receipt/request replay,
wrong-total atomicity and branch receipt isolation/recovery. The HTTP check named
owner legacy receipt recovery verifies owner visibility of an existing employee
receipt; the SQL checkout suite separately verifies exact same-actor saved-receipt
RPC replay during a recovery pause.

Parallel last-stock requests yielded exactly one sale and zero remaining stock;
parallel duplicate request keys returned identical receipts with one decrement.
Final revocation/price overlap tests confirmed a sleeping stock-row holder through
`pg_stat_activity` via an owner-only synthetic readiness RPC and asserted at least
1,000 ms of checkout wait. An already authorized in-flight sale completed before
revocation; the next stale-token request was denied. A price change committed ahead
of a waiting checkout caused rejection with unchanged stock/sale count.

Temporary test-only hold/readiness functions were removed. They were never added
to production migrations. No platform timeout setting was changed.

## Failures retained and corrected

1. Initial authorization SQL failed with PostgreSQL `42P17`: recursive membership/
   employee RLS. The transaction rolled back. Versioned
   `20261008002119_batch_2_staging_security_recovery.sql` replaces the recursive
   membership policy expression with a protected definer lookup that reuses staff
   authorization. All four suites passed afterward.
2. Existing readiness fixture failed `42501: Staff administration denied` because
   an employee claim remained active during owner administration. Its local source
   now sets owner/staff subjects explicitly around those updates; retry passed.
3. Concurrency attempts using independently scheduled MCP/command calls did not
   establish overlap. An 8-second HTTP hold also exceeded the Data API statement
   timeout (`57014`). These are harness failures, not successful race coverage.
   Final tests run all competing HTTP requests within Node, use a 2-second hold
   and confirm readiness before checkout. Three failed check attempts remain in
   `checkpoint_b_rest_results.json`; the first unverified overlap success is not
   used as acceptance evidence.
4. PowerShell rejected the `supabase.ps1` wrapper by execution policy. The supported
   `supabase.cmd migration new` command created the local recovery file, exit 0.
   The first analyzer-log counter read UTF-16 as UTF-8; corrected decoding confirms
   the severity counts below.

## Refreshed local regressions

| Command/check | Result | Exit |
| --- | --- | ---: |
| Owner flutter test --no-pub --reporter expanded | 64 passed | 0 |
| POS flutter test --no-pub --reporter expanded | 33 passed | 0 |
| Owner flutter analyze --no-pub | 0 errors, 0 warnings, 210 infos | 1 |
| POS flutter analyze --no-pub | 0 errors, 0 warnings, 10 infos | 1 |
| Node helper test --experimental-strip-types --test | 8 passed | 0 |
| create_employee_test.cjs | 9 mock scenarios | 0 |
| manage_employee_test.cjs | 6 mock scenarios | 0 |
| angel_test.cjs / camera_native_test.cjs | Both mock scripts passed; no invented counts | 0 each |
| Node --experimental-strip-types --check staff login/create/manage | 3 syntax checks passed | 0 each |
| python batch_2_static_check.py | 10 files, 21 PL/pgSQL functions, 10 SQL bodies, 6 DO blocks parsed | 0 |
| node --check checkpoint_b_rest.cjs / Python adapter compilation | Syntax passed | 0 |

Flutter analysis is not clean; its informational/deprecation findings produce
nonzero exit codes. Node syntax/mocks do not substitute for Deno runtime/type tests.

## Cleanup, evidence and limitations

All five synthetic sessions were globally signed out (HTTP 204 each). The exact
synthetic user/business whitelist was verified before transactional cleanup.
Temporary helpers, five users and all synthetic application records were removed.
Final 34 application tables are empty except **11 permission definitions**
(seven approved references plus four Batch 2 definitions). Auth users, Storage
buckets/objects, branches/assignments and temporary helpers are zero. Local ignored
password/JWT and public-config files were deleted.

Evidence: `supabase/tests/baseline/checkpoint_b_execution_results.json`, preflight
catalog/comparison, final catalog/counts, HTTP attempt log and final advisor JSON;
Flutter output logs are under `docs/implementation/`.

Not executed: deployed staging employee-login/create/manage/Angel integration,
Deno type/runtime checks, device-level offline/restart reconciliation, controlled
clock HTTP sessions at historical DST transitions, production-data constraint
validation, load benchmarking, backup restoration or fresh full reset/replay.
Current local-day helper boundaries and PostgreSQL 23/25-hour DST arithmetic pass;
this is not a frozen-clock end-to-end DST test. No production readiness is claimed.
