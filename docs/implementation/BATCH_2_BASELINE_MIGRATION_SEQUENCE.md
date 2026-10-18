<!-- BATCH_2_CLOSURE_STATUS -->
8 October 2026 — final closure verification. **BATCH 2 — COMPLETE, STAGING VERIFIED.** Latest counts, six-migration replay order and recovery results are in [final closure report](BATCH_2_FINAL_COMPLETION_REPORT.md) and [updated migration plan](MIGRATION_AND_ROLLBACK_PLAN.md). Prior material below is historical and superseded where it describes resolved blockers.

---

# Batch 2 baseline-to-migration sequence for approval

<!-- BATCH_2_FINAL_STATUS -->

8 October 2026 final completion phase: **BLOCKED**, staging-only. This section supersedes the historical checkpoint statements below. Production remains read-only and no release is authorized.

Four required Edge Functions are deployed and integration-tested. Current results: 73 SQL checks plus four older suites; 36 main REST/RPC, 32 main Edge and 10 boundary named checks have final passing outcomes. Owner 64/POS 34 Flutter tests pass. Analysis: zero errors/warnings, Owner 209/POS 4 infos, exit 1 each. All 30 staging catalog groups match after cleanup; only 11 permission definitions and five migration-history entries remain alongside the four deployments.

Fresh replay and actual restore remain blocked by the missing approved disposable environment. Cost-price visibility needs an owner-approved reader contract. Device/persistent pending-sale recovery and controlled-clock midnight/DST HTTP lifecycle remain unverified; no later-phase offline engine or UI redesign was started. See [final completion report](BATCH_2_FINAL_COMPLETION_REPORT.md) and [acceptance matrix](BATCH_2_FINAL_ACCEPTANCE_MATRIX.md).


## Historical checkpoint record — superseded by final status above

# Batch 2 baseline-to-migration sequence for approval

Checkpoint B update: the user approved and staging executed permission-only
initialization (CHECKPOINT_B_PERMISSION_DEFINITIONS.sql), then the three Batch 2
files and tracked forward security correction 20261008002119. The combined
optional seed below was NOT executed and buckets remain uncreated. Actual staged
versions/application order are in BATCH_2_MIGRATION_REHEARSAL.md. SQL/HTTP tests
and synthetic cleanup completed; Edge deployment and production remain prohibited.
Earlier approval/pending statements below are historical.

Checkpoint A update: steps 1–3 completed under the user's narrow restore approval;
baseline version `20261007235400` restored with catalog parity. Steps 4 onward are
NOT authorized/applied. The optional seed was reviewed separately but not run.
See `BATCH_2_CHECKPOINT_A_RESTORE_REPORT.md`. Do not treat the earlier broad
approval request below as authorization for Checkpoint B.

8 October 2026. Proposed only; no step below has been applied. Target must be
`qysspzlfiysekvxnlzsh`. Production `ufehcfrlygqvminfjumf` is prohibited for
all restore, seed, migration and test execution.

1. Independently verify connected project reference/endpoint, fresh application
   schemas and empty Auth. Use a separate staging migration/execution context,
   never the Owner workspace's production link. Check baseline/source hashes,
   managed dependencies, platform defaults and recovery implications. No reset
   or destructive operation is proposed without a separate exact-target review.
2. Apply the reviewed `supabase/tests/baseline/TREXVEN_PRE_BATCH_2_BASELINE.sql`
   as one tracked staging bootstrap. A verified executor must supply the staging
   setting in the same transaction; a setting from a previous call is insufficient.
   Its guards reject populated application/Auth schemas and changed platform
   prerequisites. Record that the snapshot incorporates nine historical versions;
   do not mark those nine as actually replayed in staging or blindly run them.
3. Compare restored columns/defaults/nullability, all constraints/indexes, RLS,
   grants/defaults, ownership, function bodies/signatures, triggers, Storage policies
   and Realtime registrations against recovered metadata. Stop on mismatches.
   Syntax/coverage checks are not a substitute for this runtime parity gate.
4. Apply the separate reviewed `TREXVEN_STAGING_REFERENCE_SEED.sql`: seven
   repository-defined permission IDs/descriptions and two private bucket configs.
   It contains no production-exported rows, customer/users/secrets or prices.
   Document this configuration seed separately from the schema-only import.
5. Apply in exact order, recording tracked results and checksums:
   `20261007215736_batch_2_authorization_price_enforcement.sql`,
   `20261007215743_batch_2_branch_assignment_foundation.sql`,
   `20261007215831_batch_2_branch_checkout_compatibility.sql`.
   No real business branch activation, stock allocation or history rewrite occurs.
6. Establish a staging-only synthetic test marker and guarded transport; adapt
   psql includes/binds only through reviewed tooling or provision an approved
   dedicated client. Existing loopback runner is unchanged and rejects remote.
   Never load production .env/credentials. Run four Batch 2 SQL suites and relevant
   existing suites, then real Auth/REST/RPC, price bypass, concurrency/revocation,
   local-day/DST, receipt/stock and recovery checks. Report actual outcomes.
7. Identify/obtain explicit staging Edge deployment approval before deploying
   canonical employee-login, create-employee, manage-employee or Angel for real
   integration. Use staging-only secrets. Rerun Flutter/Edge regressions and
   analysis after database verification; no app release is included.

Any failure stops the sequence. Correct locally and rehearse against a fresh
verified isolated baseline after reviewing reset/recovery implications. Never
manually patch staging tables to conceal an unsuccessful migration. Retain source
and executed migration hashes, baseline provenance and test evidence.

Approval requested: this current-catalog schema baseline, the separate repository
reference seed and the ordered staging-only reconstruction/hardening rehearsal.
Outstanding MAINTAIN/default-grant review and runtime parity/testing remain explicit;
baseline recovery is not Batch 2 acceptance or production deployment approval.
