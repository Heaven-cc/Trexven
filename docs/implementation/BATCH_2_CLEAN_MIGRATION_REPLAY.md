<!-- BATCH_2_CLOSURE_STATUS -->
# Batch 2 clean migration replay — verified

8 October 2026 — final closure verification. **BATCH 2 — COMPLETE, STAGING VERIFIED.**

Two clean application-schema replays executed against a free native Supabase stack under WSL Ubuntu, official CLI 2.120.0 and PostgreSQL 17.11.0.004-r1. Docker was unavailable; the supported experimental native runtime resolved the earlier external blocker. API/DB endpoints were verified as `127.0.0.1:54321/54322`; stack `trexven-batch2-closure`, identity `2d308235459edaa3b9677651ce39251abedc7cff860fea7ab71021e94e88063e`, unlinked workdir `.batch2-tools/disposable`. No hosted resets, paid provisioning or production credentials were used.

## Execution order actually tested

1. Verify managed Auth/Storage infrastructure, empty application schema/Auth users/history and required extensions. Preserve managed infrastructure.
2. Verify recovered baseline SHA-256 `5eb2ee5437911b21eab424a05abf21eb7cc7945bc805e5a41d58459e21b3e21e`. Make a disposable executor copy changing only its identity guard, using the verified local stack ID; never impersonate the staging project reference. Apply baseline transaction.
3. Record one truthful snapshot history row, not nine individually executed historical deltas.
4. Apply source files in this order: `20261007215736` authorization/price; `20261007215743` branches; `20261007215831` checkout; `20261008002119` PG17/recursion recovery; `20261008020234` cost contract; `20261008021428` business day.
5. Initialize only the reviewed seven base permission rows. Migrations add four, yielding 11. Optional Storage bucket definitions were not seeded.
6. Execute all six rollback-only SQL suites: 84 assertions passed. Execute four older suites. Verify schema, history, column privileges, MAINTAIN restrictions and parity.

Source version identifiers differ from staging apply timestamps; this is intentional. Staging history has bootstrap plus six actual connector applications. Native history records bootstrap snapshot plus six actual source executions. Neither falsely marks incorporated original migrations as individually replayed.

Replay 1 used the new native stack database `postgres`. Replay 2 used a separately created `trexven_b2_replay2` database with platform schemas retained, no application/Auth/history rows, reviewed fresh-platform default privileges restored, then baseline and all six migrations independently executed. Schema reconstruction of that new disposable database did not reset existing staging. All baseline/migration commands exited 0. Run 1 applied the first five in its ordered harness, then the day migration separately; its exact successful execution/history are retained in evidence/batch_2_closure_business_day_apply.log and evidence/batch_2_closure_business_day_history.log. Run 2 applied all six in the ordered harness: [run 1 migration log](evidence/batch_2_closure_replay_steps.json), [run 2](evidence/batch_2_closure_replay_steps_run2.json), [second preflight](evidence/batch_2_closure_replay2_preflight.log), [SQL results](evidence/batch_2_closure_sql_results.json).

Both replay catalogs match staging in all 30 semantic groups. Raw OID/format/order differences are retained alongside the reviewed normalization, which preserves meaningful schema state. Required extensions: plpgsql 1.0, uuid-ossp 1.1, pgcrypto 1.3, pg_stat_statements 1.11 and supabase_vault 0.3.1. Managed Auth references remain intact; no production users were exported.

Intentional DDL/data error produced psql exit 3/P0001, rolled back the probe and stock write, and preserved sale/receipt/stock/history checksums. A corrected additive probe executed and was removed with checksums unchanged ([recovery record](evidence/batch_2_closure_failure_recovery.json)). This verifies transactional recovery, not arbitrary destructive rollback.

Official checksums verified CLI download. Initial native process UID setup was rejected; a dedicated non-login `trexven-b2-pg` system account resolved it. Reproducible guarded harnesses and environment requirements are in [README](../../supabase/tests/closure/README.md). The native stack was stopped after scoped fixture cleanup; generated credentials and backup were removed. Reprovision a fresh free stack for another run rather than using the preserved staging environment.

---

## Historical report — superseded by the closure update above

# Batch 2 clean migration replay

8 October 2026. **BLOCKED: fresh replay not executed.** Existing staging was preserved and not reset. No separate disposable Supabase project was identified or approved. Windows and WSL Ubuntu have no PostgreSQL/psql/pg_ctl/pg_dump or Docker/Podman runtime. The inactive Admin Project is outside scope and was not used.

## Verified source and sequence

The immutable pre-Batch-2 baseline SHA-256 remains 5eb2ee5437911b21eab424a05abf21eb7cc7945bc805e5a41d58459e21b3e21e. Deterministic regeneration passed. All four original migration hashes match the recovery manifest.

Fresh disposable sequence after independent target verification:

1. Restore the reviewed pre-Batch-2 schema-only baseline into an empty compatible Supabase environment. Review a guard-only executor adaptation for that explicitly approved disposable reference; never spoof the existing staging reference or change the archived baseline hash.
2. Compare all 30 baseline catalog groups and managed Auth/Storage/extension/Realtime dependencies.
3. Initialize only the seven approved permission definitions. Do not run the optional combined seed or create buckets.
4. Apply 20261007215736_batch_2_authorization_price_enforcement.sql.
5. Apply 20261007215743_batch_2_branch_assignment_foundation.sql.
6. Apply 20261007215831_batch_2_branch_checkout_compatibility.sql.
7. Apply 20261008002119_batch_2_staging_security_recovery.sql.
8. Compare the result against cleaned accepted staging, execute all security/compatibility suites, rehearse an interrupted migration and forward fix, then restore the recovery checkpoint independently.

The fourth file is portable: it uses schema-qualified database objects, a protected existing authorization contract and PostgreSQL 17 MAINTAIN revocation; it contains no staging reference, customer mapping, credentials or data rewrite. It must follow the first three and remains part of any production proposal.

## History exception

Checkpoint A restored a schema snapshot incorporating nine earlier production migration versions. Those nine were not independently replayed or falsely marked executed. Staging's five actual tracked versions are 20261007235400, 20261008001547, 20261008001556, 20261008001958 and 20261008002214. The connector generated versions differ from archived source timestamps; configuration initialization is untracked DML. The current snapshot records names/versions without inventing history.

Do not use an implicit linked CLI push: the Owner workspace remains linked to production. Production already contains the baseline and must never receive this restore file or a blind replay of earlier deltas.

## Current evidence and limits

Static validation parsed all four migrations, five suites and fixture: 10 SQL files, 21 PL/pgSQL functions, 10 SQL bodies, six DO blocks, exit 0. Staging source/start/end catalog comparison matches 30/30 groups. All 73 checks pass on the already-migrated staging schema.

A deliberately aborted transaction created a private probe then raised P0001; a separate metadata query confirmed the probe did not survive. This verifies one transaction's DDL rollback, not a complete four-migration failure/recovery lifecycle. Earlier staged forward correction was historically applied and is still regression-tested; no new migration was applied in this final phase.

Required prerequisite: an approved empty disposable Supabase project or compatible local Supabase/PostgreSQL runtime with managed dependencies. Fresh replay, target parity and failure/forward recovery remain unverified until that environment exists.
