# Batch 2 migration rehearsal

<!-- BATCH_2_FINAL_STATUS -->

8 October 2026 final completion phase: **BLOCKED**, staging-only. This section supersedes the historical checkpoint statements below. Production remains read-only and no release is authorized.

Four required Edge Functions are deployed and integration-tested. Current results: 73 SQL checks plus four older suites; 36 main REST/RPC, 32 main Edge and 10 boundary named checks have final passing outcomes. Owner 64/POS 34 Flutter tests pass. Analysis: zero errors/warnings, Owner 209/POS 4 infos, exit 1 each. All 30 staging catalog groups match after cleanup; only 11 permission definitions and five migration-history entries remain alongside the four deployments.

Fresh replay and actual restore remain blocked by the missing approved disposable environment. Cost-price visibility needs an owner-approved reader contract. Device/persistent pending-sale recovery and controlled-clock midnight/DST HTTP lifecycle remain unverified; no later-phase offline engine or UI redesign was started. See [final completion report](BATCH_2_FINAL_COMPLETION_REPORT.md) and [acceptance matrix](BATCH_2_FINAL_ACCEPTANCE_MATRIX.md).


## Historical checkpoint record — superseded by final status above

# Batch 2 migration rehearsal

8 October 2026. Checkpoint B completed in staging only, after rechecking the 30
baseline catalog groups, empty application/Auth records and migration history.
No standard linked migration push was used. Explicit project inventory verified
`qysspzlfiysekvxnlzsh` and its database host before each migration/test write target.
The workspace's production CLI link remained unused and unchanged.

| Actual staging order | Recorded version | Name / local source |
| --- | --- | --- |
| Checkpoint A bootstrap | 20261007235400 | trexven_pre_batch_2_baseline_checkpoint_a |
| Permission initialization (untracked configuration DML) | None | CHECKPOINT_B_PERMISSION_DEFINITIONS.sql; seven IDs only |
| Migration 1 | 20261008001547 | batch_2_authorization_price_enforcement; local 20261007215736 |
| Migration 2 | 20261008001556 | batch_2_branch_assignment_foundation; local 20261007215743 |
| Migration 3 | 20261008001958 | batch_2_branch_checkout_compatibility; local 20261007215831 |
| Documented forward correction | 20261008002214 | batch_2_staging_security_recovery; local 20261008002119 |

All four tracked Batch 2 applications returned `{"success":true}`,
`isError=false`. No migration execution error occurred. Connector calls do not
supply shell exit codes. The tool generated newer staging history identifiers;
the three reviewed source filenames/checksums were preserved, not falsely renamed
or recorded as having their original timestamps. Nine incorporated historical
production migrations were not replayed or marked independently executed.

Original source SHA-256:
- Authorization: `55a69cd97eb1fbbd2a034467e9cda93d5551c7fcd415f6ea4d778f53d2a1b8e7`
- Branches: `2537fb48a9c7fc77088a30f2158f917d45bed39126d670fff3d5dfed4358f34a`
- Checkout: `86feacc6be132aedb1a2999500a633e9a433f41c0965dbb7bb51a2f931278283`

The baseline SHA-256 remains
`5eb2ee5437911b21eab424a05abf21eb7cc7945bc805e5a41d58459e21b3e21e`.

Initial authorization testing exposed recursive membership/employee policies.
The failed transaction rolled back, leaving a clean data baseline. The separate
versioned correction avoids recursive RLS expansion and explicitly revokes
PostgreSQL 17 MAINTAIN from client table grants/defaults. It does not widen access
or modify records. Test retries passed; no unrecorded schema patch concealed the
failure and no reset was needed. Full fresh bootstrap-plus-four-migration replay
has not been performed and remains a rollout gate.

Final catalog: 34 tables, 339 columns, 131 constraints, 108 indexes, 43 functions,
121 policies and 15 application triggers. The final capture excludes temporary
HTTP test helpers. Nullable branch references and NOT VALID historical foreign
keys remain staged; no historical allocation/backfill or zero-price rewrite occurred.

Synthetic-only branch activation/stock insertion was used for tests and removed
with all synthetic records. No real branch was activated. Only permission
definitions remain. Storage buckets and Edge Functions were not deployed.

Recovery: retain the forward fix; do not restore the recursive policy. On a real
rollout, pause writes through a reviewed administrative procedure and forward-fix
authorization while retaining transaction/receipt ledgers. Do not drop data-bearing
branch fields/tables or revert pending products to arbitrary prices. See
MIGRATION_AND_ROLLBACK_PLAN.md. Backup/PITR restoration and production constraint
validation are not certified by this staging run.
