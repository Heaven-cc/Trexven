<!-- BATCH_2_CLOSURE_STATUS -->
# Batch 2 production approval readiness

8 October 2026 — final closure verification. **BATCH 2 — COMPLETE, STAGING VERIFIED.** Production remains **not deployed**. Staging verification does not authorize production rollout.

## Concrete changes awaiting separate approval

1. Four original authorization/price/branch/checkout/PG17 recovery migrations and two new additive cost/day contracts. Review against actual current production metadata before execution; never apply staging baseline/bootstrap or rewrite production history.
2. Updated four Edge Functions with pinned dependencies and shared permissions, plus Owner/POS clients using explicit non-cost product projections and native durable submission.
3. Owner-approved valid IANA business timezones. Null legacy configuration has no invented fallback and fails closed for staff day reads/Owner day stats until configured.
4. Coordinated client/API rollout: the restricted column grants intentionally deny older `SELECT *` product requests. Updated clients must be available and obsolete clients retired before cost enforcement. Review minimum-client/update controls without inventing subscription rules.
5. Production operational backup/restore target and credentials/retention verification; local pg_dump restore is proven, hosted PITR is not.

The order actually rehearsed is baseline, four original migrations, cost contract, day contract, reviewed permission initialization, tests. A production rollout might install day RPC before cost restriction so new clients can ship first, but that alternative order has **not been rehearsed here** and requires an isolated rehearsal/review before production approval. Do not silently adopt it.

Production already contains the original application schema and incorporated historical deltas. The recovered immutable baseline is a reconstruction/recovery reference, not a production migration. Preserve existing membership IDs, request keys, receipt IDs, sale items and historical inventory. Source filename versions and staging connector versions differ and are documented; do not blindly push old timestamps behind staging's bootstrap.

Branch creation/activation, historical mapping, stock distribution and NOT VALID constraint validation remain separately approved steps after data auditing. No real branch was activated. Legacy branch-null transactions remain compatible while the business has branches disabled. Explicit branch operations always verify membership/assignment.

Remaining operational items: informational Flutter analysis (209 Owner/4 POS, exit 1), advisor performance warnings, real-device regression, provider configuration for Angel if later required, full offline engine and browser persistence. No unresolved critical/high Batch 2 security defect is known from executed tests; no production release is claimed.

Evidence ready for review: [final acceptance](BATCH_2_FINAL_ACCEPTANCE_MATRIX.md), [migration/recovery plan](MIGRATION_AND_ROLLBACK_PLAN.md), [baseline replay](BATCH_2_CLEAN_MIGRATION_REPLAY.md), [backup restore](BATCH_2_BACKUP_RECOVERY_RESULTS.md). Stop for review; no production command is implied by this document.

---

## Historical report — superseded by the closure update above

# Batch 2 production readiness

<!-- BATCH_2_FINAL_STATUS -->

8 October 2026 final completion phase: **BLOCKED**, staging-only. This section supersedes the historical checkpoint statements below. Production remains read-only and no release is authorized.

Four required Edge Functions are deployed and integration-tested. Current results: 73 SQL checks plus four older suites; 36 main REST/RPC, 32 main Edge and 10 boundary named checks have final passing outcomes. Owner 64/POS 34 Flutter tests pass. Analysis: zero errors/warnings, Owner 209/POS 4 infos, exit 1 each. All 30 staging catalog groups match after cleanup; only 11 permission definitions and five migration-history entries remain alongside the four deployments.

Fresh replay and actual restore remain blocked by the missing approved disposable environment. Cost-price visibility needs an owner-approved reader contract. Device/persistent pending-sale recovery and controlled-clock midnight/DST HTTP lifecycle remain unverified; no later-phase offline engine or UI redesign was started. See [final completion report](BATCH_2_FINAL_COMPLETION_REPORT.md) and [acceptance matrix](BATCH_2_FINAL_ACCEPTANCE_MATRIX.md).

Production recommendation: **NOT READY**. Before requesting rollout approval, complete disposable replay/restore, resolve cost visibility, obtain pending-sale/clock evidence or explicit non-blocking deferrals, and configure owner-approved business timezones. Production has no timezone column yet; migration 2 adds NULL, so ordinary staff history fails closed until configured.

Production execution must target ufehcfrlygqvminfjumf explicitly only after separate approval. Do not apply the staging bootstrap to production, fabricate earlier migration history, create optional buckets, activate real branches or redistribute historical stock. Proposed ordered production steps and forward recovery are in the final completion report.

## Historical checkpoint record — superseded by final status above

# Batch 2 production readiness

8 October 2026. **Checkpoint B backend acceptance: PASSED WITH DOCUMENTED LIMITATIONS.
Production rollout: BLOCKED pending the gates below and separate authorization.**

Completed in staging: baseline identity/hash/parity gate, seven permission
definitions, three migrations plus versioned RLS/MAINTAIN correction, 73 new SQL
checks across five suites, four older SQL regressions, five real Auth sessions,
36 distinct final-passing HTTP checks including real concurrency, refreshed
Flutter/Edge mocks/syntax and final advisors. Production is unchanged.

Required before recommending production deployment:

1. Review and authorize the complete four-migration rollout, trusted permission
   initialization and exact target/history provenance. Never push from the current
   production-linked workspace without an explicit rollout procedure.
2. Rehearse a fresh complete baseline-plus-four-migration run and verify backup/
   PITR restoration, write pause and forward recovery. This run applied forward
   recovery on staging after a rolled-back test, not a full reset/replay or backup.
3. Audit real historical employee-code uniqueness and composite FK consistency
   read-only; resolve validated mapping discrepancies without rewriting history.
   NOT VALID constraints still require a staged production validation plan.
4. Obtain staging Edge deployment authorization and run actual employee-login,
   creation, reset/management and compensation integration with staging secrets.
   Deno type/runtime checks remain unavailable. Node mocks are not deployment proof.
5. Review 12 definer endpoints, 34 FK index findings, 16 RLS initplan warnings,
   61 permissive-policy findings, 9 duplicate index groups and platform defaults.
   These are documented findings, not automatically removed or accepted performance.
6. Validate device-level offline/restart recovery and representative clock-controlled
   local-midnight/DST HTTP cases. Existing queue/request serialization was preserved;
   no real offline reconciliation or historical-transition Auth clock test ran.
7. Keep branches disabled for real businesses until stock allocation/mapping,
   adjustment/movement APIs and consolidated owner reporting are implemented and
   separately approved. Do not redistribute legacy stock/sales to a default branch.

Each production schema/configuration migration, Edge deployment, app release,
real branch allocation/activation and Storage bucket creation requires separate
explicit authorization. Optional recordings/event-snapshots buckets were not
created, and none is implied by Checkpoint B approval. No unrelated UI/master-plan
batch was started. Stop here for review.
