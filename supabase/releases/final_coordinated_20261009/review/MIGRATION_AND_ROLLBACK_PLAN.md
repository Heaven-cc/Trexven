# Current coordinated Batch 4–9 recovery addendum — 9 October 2026

The [frozen candidate](../../supabase/releases/final_coordinated_20261009/manifest.json)
contains **16 pending migrations**: the original 14 unchanged candidates followed
by the Batch 8 Owner/payment/context correction and Batch 9 role-scoped personal
notification acknowledgements. Deployed Batch 2/3 history remains unchanged.

Fresh isolated pre-Batch-2 baseline +23 migration replay and 13 rollback suites
passed. The pending execution wrappers were also replayed, producing 32 simulated
history entries. Each uses an advisory lock and exact predecessor-history guard;
DDL and its history insertion commit together. An unexpected history was also
rejected before DDL in an isolated negative test. Never reapply the baseline to main.

The protected main database snapshot was restored successfully in an
API-unexposed isolated database; schema and 84 table fingerprints matched.
Current freshness evidence shows no changed tables. Recheck immediately before
deployment and refresh/re-prove restore if necessary. DPAPI needs the original
Windows profile; automated/offsite/Edge-secret recovery is not implied.

The [exact rollout and recovery procedure](COORDINATED_FINAL_ROLLOUT_AND_RECOVERY.md)
requires final Android build/device validation, refreshed preflight/backup and
explicit approval before any main write. No provider/branch activation, historical
sale rewrite, arbitrary price or app publication is included.

Failed individual migration transactions roll back; earlier committed versions
need a reviewed forward correction. Retain financial/inventory/cash/billing
ledgers and personal notification acknowledgements. Do not drop populated
structures, revert the deletion Edge to destructive behavior, weaken RLS, clear
device queues or change retained RPC payload names. Production archive restore
requires separate approval and reconciliation of later genuine transactions.

---

# Current Batch 4–7 migration and recovery addendum — 9 October 2026

The [current handover](BATCHES_4_7_IMPLEMENTATION_HANDOVER.md) and generated
`supabase/releases/batches_4_7_development_20261009/manifest.json` define the new
local candidate. Its 14 migrations are additive and **not approved or applied**
to production. Keep the frozen, deployed seven-migration Batch 2/3 package intact.

Execute new migrations in ascending filename order, not grouped by batch number.
The last `20261009122632_batch_4_transaction_recovery_boundaries.sql` intentionally
depends on the cash and subscription foundations created earlier in that order.
No default branch, historical transaction rewrite, arbitrary product price,
subscription enrollment, provider enabling or data redistribution is included.

Before production: final isolated schema replay and financial/RLS/concurrency QA,
Flutter/device upgrade checks, revised Edge JWT tests, fresh main-project schema
preflight, protected fresh backup plus proved isolated recovery, frozen hashes
and one consolidated explicit deployment approval. Current SQL/body parsing is
syntax validation only. Local PostgreSQL/WSL recovery and C: scratch capacity
remain prerequisites for final QA. Never use the rejected D: backup or drive.

Rollback is a reviewed forward correction. Pause new POS writes using the
existing guard; retain pending journals and financial/cash/inventory/billing
ledgers; keep providers disabled and legacy subscription enforcement inactive.
Never drop newly populated ledgers, loosen RLS, erase receipts or reverse money
automatically. A backup restore requires a separate recovery procedure accounting
for transactions since capture. Backup status rows are evidence metadata, not
proof of recovery. The account lifecycle path must retain financial history;
review and deploy the non-destructive legacy endpoint replacement separately.

Production timezone Africa/Lagos was configured externally and read-only
verified after Batch 2/3; older unset-timezone statements below are historical.
No app publication or branch activation is part of this candidate.

---

# Production deployment executed — 9 October 2026

The [execution report](PRODUCTION_DEPLOYMENT_EXECUTION_REPORT.md) supersedes earlier undeployed/approval-blocked status below. Under the user's final explicit authorization, all seven migrations committed (CLI exit 0, history now 16); Batch 2 and Batch 3 are DEPLOYED. Reviewed Edge Functions are DEPLOYED: employee-login v6 (JWT false), create-employee v7, manage-employee v4 and angel v12 (JWT true). Retrieved sources match the frozen package; unrelated functions remain unchanged. Main backend integration for the approved scope is COMPLETE.

All original values across 78 existing non-history tables were preserved. Four canonical permission reference rows were added exactly as approved; the original seven permission rows are unchanged. Postflight verified 39 reviewed functions, RLS/grants/catalog, valid indexes and dormant empty branches. The protected C pre-deployment backup passed immediate checksum/freshness checks; no refresh was required. The timezone remains unset per explicit exclusion, so daily-sales flows need a separate clock configuration decision. No apps were installed/published, no local data cleared, no branches activated and no production synthetic records created. Device verification was explicitly waived for this backend execution and remains an app-update limitation.

---

# Current final compatibility status — 9 October 2026

This section supersedes earlier readiness statements below. The [final coordinated plan](FINAL_COMPATIBILITY_AND_COORDINATED_DEPLOYMENT_PLAN.md) records exact evidence, changes, migration order and deployment gates. Owner tests: 75 passed; POS: 47 passed + 1 explicit skip; Deno: 9 passed; isolated SQL: 105 assertions across five passing suites; staging JWT: 54/54 checks. Analysis exits 1 with 208 Owner / 4 POS informational findings and no errors/warnings. Both ARM64 debug candidate APKs built at actual 1.0.0+2 and match previous local artifact signing identities; installed-device identity remains unverified.

Production's unchanged main schema and exact seven pending files passed read-only preflight/dry-run. The original D backup failed a later checksum and is rejected. A protected replacement on C passed fresh full recovery (79 table fingerprints, 30 schema groups), DPAPI encryption/decryption and latest unchanged-data verification. Same-profile recovery and Storage-object/offsite limits are documented. This replaces earlier credential/backup/JWT blockers; do not use the older D copy.

Remaining: connect actual test installations to verify signature/ABI/version and resolve/preserve pending requests/drafts, then obtain explicit approval for the seven migrations and four reviewed Edge Functions. Guarded Africa/Lagos configuration requires its own explicit inclusion. No production write, branch activation, app installation/publication or production Edge deployment occurred. Unsynced persisted POS requests must survive in-place replacement; uninstall/data clear is not approved. Owner in-memory drafts must be resolved before restart.

---

# Operational prerequisite update ? 9 October 2026

Production database backup/recovery is now verified for the documented local scope: encrypted protected archive, two full isolated restores, 79 matching table fingerprints and 30 matching application catalog groups. Earlier backup/access blockers below are superseded by [the actual recovery report](PRODUCTION_OPERATIONAL_BACKUP_RECOVERY_REPORT.md). Installed/distributed client compatibility, authenticated Edge replacement acceptance and explicit rollout approval remain gates. No production migration, configuration change or Edge deployment occurred. DPAPI requires the original Windows profile/keys; Storage object bytes and independent offsite recovery are not covered.

---

<!-- BATCH_2_CLOSURE_STATUS -->
# Batch 2 migration/recovery plan — final closure update

8 October 2026 — final closure verification. **BATCH 2 — COMPLETE, STAGING VERIFIED.** Staging only; production execution requires separate approval.

## Immutable source sequence and staging history

| Source file prefix | Purpose | Staging applied version |
| --- | --- | --- |
| Pre-Batch-2 baseline snapshot | Reviewed schema reconstruction, not historical-delta replay | 20261007235400 |
| 20261007215736 | Authorization and selling-price enforcement | 20261008001547 |
| 20261007215743 | Additive branches/assignments | 20261008001556 |
| 20261007215831 | Compatible branch checkout/idempotency | 20261008001958 |
| 20261008002119 | PG17 MAINTAIN/RLS recursion recovery | 20261008002214 |
| 20261008020234 | Purchase-cost API exclusion, data retained | 20261008022607 |
| 20261008021428 | Trusted business-local day RPC/policy | 20261008022611 |

The original baseline and first four migration hashes remain unchanged. Native replays record one snapshot row plus the six **actually executed source versions**; staging records actual connector application timestamps. Original historical deltas incorporated in the snapshot are not falsely marked executed. [Source hashes/execution](evidence/batch_2_closure_replay_steps_run2.json).

## Additive correction rollback/forward recovery

- **Cost contract:** retains `cost_price`, default/constraint and all values. Replaces only owned product authorization/price audit contracts and grants on non-cost columns; filters legacy cost-bearing audit metadata without deleting it. Do not restore broad product SELECT/UPDATE or obsolete `view_profit` merely to make older clients work. Pause affected client workflow, retain restrictions and forward-fix explicit projections. Future cost reintroduction requires a separately approved permission/API design and new migration. No destructive data rollback is required/permitted.
- **Business-day contract:** new gated RPC/private trusted clock, additive policy/function replacements. Keep historical timestamptz values and receipt contents. Forward-fix an implementation/configuration issue through a new migration or owner-approved valid IANA setting, never a device-time/client-clock bypass. Missing configuration deliberately fails closed. No automatic timezone backfill.
- **Original foundation:** preserve columns/tables/RPC signatures and historical receipts. Owner-controlled write-pause mechanisms can suspend affected checkout pending recovery; use documented guarded forward corrections. Never drop branches/assignments/price state or rewrite applied source files. Seven NOT VALID constraints require audited mapping before future validation.

Before any deployment: verify actual project identity/history/catalog, immutable hashes, supported backup/restore target, compatible clients and reviewed owner configuration. All writes here targeted staging or loopback disposable identity only. Production schema is already populated: do **not** apply any baseline or staging bootstrap over it.

## Rehearsed recovery evidence

Two clean baseline-plus-six-migration replays passed 84 SQL assertions and all 30 schema groups. Operational synthetic pg_dump/restore preserved Auth references, seven history rows, five sales/receipts and stock; replay returned the original receipt once. Separate schema-only recovery file restored with zero application/Auth records. Intentional migration failure exited 3/P0001 and rolled back DDL/stock changes; forward correction left committed checksums unchanged. [Replay](BATCH_2_CLEAN_MIGRATION_REPLAY.md), [recovery](BATCH_2_BACKUP_RECOVERY_RESULTS.md).

Final checkpoint SHA-256 `d5b246667730156bcdc5e903cc555f6b969a85cdfaa38b17c9a145529cefcca0`; original baseline SHA-256 `5eb2ee5437911b21eab424a05abf21eb7cc7945bc805e5a41d58459e21b3e21e`. Checkpoint guards require empty application/Auth schemas and correct managed platform defaults. It is not an operational data backup or a production upgrade script.

Column restriction intentionally breaks old wildcard product clients. The tested order is cost then day; any alternate staged production sequence must be separately rehearsed. See [production readiness](BATCH_2_PRODUCTION_READINESS.md). No automatic branch activation, historical inventory redistribution, paid resource provisioning or production backup setting changes occurred.

---

## Historical report — superseded by the closure update above

# Migration and rollback plan

<!-- BATCH_2_FINAL_STATUS -->

8 October 2026 final completion phase: **BLOCKED**, staging-only. This section supersedes the historical checkpoint statements below. Production remains read-only and no release is authorized.

Four required Edge Functions are deployed and integration-tested. Current results: 73 SQL checks plus four older suites; 36 main REST/RPC, 32 main Edge and 10 boundary named checks have final passing outcomes. Owner 64/POS 34 Flutter tests pass. Analysis: zero errors/warnings, Owner 209/POS 4 infos, exit 1 each. All 30 staging catalog groups match after cleanup; only 11 permission definitions and five migration-history entries remain alongside the four deployments.

Fresh replay and actual restore remain blocked by the missing approved disposable environment. Cost-price visibility needs an owner-approved reader contract. Device/persistent pending-sale recovery and controlled-clock midnight/DST HTTP lifecycle remain unverified; no later-phase offline engine or UI redesign was started. See [final completion report](BATCH_2_FINAL_COMPLETION_REPORT.md) and [acceptance matrix](BATCH_2_FINAL_ACCEPTANCE_MATRIX.md).

Final recovery addendum: archived pre-Batch-2 baseline hash and all four migration hashes are unchanged (batch_2_final_recovery_manifest.json). New BATCH_2_FINAL_RECOVERY_CHECKPOINT.sql preserves seven NOT VALID constraints and current grants/functions; SHA-256 020aee18499cc5d392f023ae86d23377aa1a1649684068bf40903c996b5bdb46. Its guarded empty-schema restore has NOT been executed. It contains all four migrations already; never replay them on top of it.

Companion configuration/history snapshots preserve 11 trusted permission definitions and five actual staged version/name records. They are provenance, not proof those versions were restored. Review a target-specific guard adapter for a separately approved empty disposable environment; do not spoof staging or reset existing staging. Fresh baseline order is permission-only initialization, authorization, branch foundation, branch checkout, portable security correction.

One actual aborted private-table DDL transaction raised P0001 and left no object. This does not replace a clean replay or failure/forward-recovery/restore rehearsal. Retain security guards, deny rows, nullable branch history and original request/receipt/member IDs; use reviewed forward fixes, not reopening old grants. See [clean replay](BATCH_2_CLEAN_MIGRATION_REPLAY.md) and [recovery results](BATCH_2_BACKUP_RECOVERY_RESULTS.md).

## Historical checkpoint record — superseded by final status above

# Migration and rollback plan

## Checkpoint B current recovery procedure — 8 October 2026

Staging only: bootstrap 20261007235400, then recorded migrations 20261008001547,
20261008001556, 20261008001958 and forward correction 20261008002214. The seven
permission definitions were separate idempotent configuration DML. No standard
linked migration push or production change occurred. Actual provenance/source
hashes are in BATCH_2_MIGRATION_REHEARSAL.md; original filenames are unchanged.

The new local 20261008002119_batch_2_staging_security_recovery.sql must follow the
three original Batch 2 files in any future approved rollout. It replaces a
recursive membership-policy lookup with a private definer lookup reusing the
staff guard and revokes MAINTAIN from client grants/defaults. Do not undo it by
restoring the recursive policy; that would make legitimate queries fail. The
original failed SQL transaction rolled back; correction was tracked, not a hidden
manual schema patch. No full reset/replay was necessary or performed.

Rollback/disable: pause sale writes with the separately reviewed trusted admin
procedure (client writes to pos_writes_paused remain prohibited), retain saved
receipts and request keys for recovery, and forward-fix authorization/RPC behavior.
Do not drop branch data/columns or revert NULL pending prices to arbitrary values.
For an unused isolated stage, a fresh baseline/replay may be reviewed separately;
never run the non-idempotent baseline over the populated schema or falsify history.
Record backups and exact target before any reset. Backup/PITR recovery and full
fresh bootstrap-plus-four-migration replay are still unexecuted rollout gates.

Synthetic-only teardown succeeded after global logout and exact identifier/target
verification: removed test helpers, five Auth users and all synthetic records.
Only 11 permission definitions remain. No real branch activation or stock/sales
allocation occurred; optional Storage buckets remain prohibited/uncreated.
NOT VALID historical FKs and employee-code uniqueness need read-only production
data audits and a staged validation plan before production migration approval.

All production SQL, settings, Edge deployment, app releases and branch allocation
require separate explicit approval. Earlier checkpoint notes below are history.

Checkpoint A: one successful staging bootstrap (`20261007235400`) with no restore
errors or recovery actions. Do not rerun the non-idempotent baseline on populated
staging or falsely replay incorporated history. Any reset/repair requires exact
target/recovery review. Optional seed/Batch 2 remain unapplied; Checkpoint B needs
new approval. See the Checkpoint A restore report for parity and recorded advisors.

Baseline recovery update: see `BATCH_2_BASELINE_MIGRATION_SEQUENCE.md`. The current
schema snapshot already incorporates nine deployed historical deltas; do not replay
them or falsely record them as executed in staging. Bootstrap in a separate
staging-only context, compare recovered/restored catalogs, apply the reviewed
repository reference seed, then the three Batch 2 files. No import is approved
yet. Forward recovery and no-production/activation/data-copy boundaries remain.

8 October staging checkpoint: verified `qysspzlfiysekvxnlzsh`, distinct from
prohibited production `ufehcfrlygqvminfjumf`. Staging has no application baseline
or migration history; no migration application/rehearsal occurred. Follow
`BATCH_2_STAGING_SETUP_REPORT.md` after baseline source approval. Never use the
workspace's existing production link for staging commands, and do not reset or
import an uncertain baseline without target/recovery review.

## Batch 1 history

No SQL migrations, Edge deployment, production writes or dependency changes.
Rollback only this batch's access/model/guard hunks and its tests. Do not use
`git reset` or restore whole files: Owner files contain extensive prior work, and
POS currently has no Git metadata. No production data rollback is needed.

## Earlier foundation proposal (superseded by Batch 2 details below)

1. Preserve current business, product, membership, sale and movement IDs. Reconcile
   deployed function/policy definitions with migration sources and contract tests.
2. Add backend price enforcement and restrict manager finance/Vision defaults;
   test direct REST/RPC and inactive/cross-business actors in an isolated database.
   Exact grant mapping and owner-only Vision policies must be consistent with both
   employee-login function copies and stored employee overrides.
3. Add branches and employee-branch assignments with composite business foreign
   keys; explicit active branch context in both clients. No cart/queue should be
   silently reassigned on context change.
4. Add one compatibility/default branch per existing business only under reviewed
   backfill rules. Historical unknown branch information must be identified as
   legacy, not fabricated as an actual observed location.
5. Add variants and branch stock/price/threshold ledger while retaining product IDs
   and legacy RPC adapters. Backfill deterministic single variants; compare totals
   before and after. Snapshot prices on sales and enforce quantity precision.
6. Version checkout RPC contracts; stage compatibility clients before rollout.
   Old clients must not bypass new branch/variant enforcement or create duplicate
   stock movements. Define deprecation/feature gating before cutover.
7. Test last-stock races, retry keys, actor scoping, price changes, rollback and
   pending offline compatibility before production activation.

Use Supabase CLI migration creation after discovering its installed command help.
Rehearse on isolated/local staging, run adversarial RLS/transaction tests and
advisors. A production migration or deployment is a separate reviewable action.

Rollback strategy: additive schema + versioned RPC + feature flags; disable new
flows before reverting clients. Never drop new financial/stock ledgers containing
real transactions. Forward-fix data-bearing migrations; retain mappings/audits.
Record snapshots, migration checksums, application versions and restore rehearsal
results before rollout. Backups/restore capability has not been verified here.

Open product decisions: shared drawer/handovers, plan pricing/limits/entitlements,
alert delivery infrastructure, detailed KPI dimensions. No values chosen in this
batch.

## Batch 2 local implementation — 7 October 2026

No production changes. Apply nothing until isolated rehearsal and separate
production approval. Three transactional migrations were written, not applied:

1. `20261007215736_batch_2_authorization_price_enforcement.sql`: existing trusted
   authorization helpers, explicit grant denial, owner-only permission RPC,
   restricted staff mutation, selling/cost price and sale-item guards, price audit,
   nullable missing selling price without numeric default, closed excessive grants
   and owner-only intelligence policies.
2. `20261007215743_batch_2_branch_assignment_foundation.sql`: branch/assignment
   schema and RLS, composite business keys, nullable references, disabled branch
   mode, timezone/compatibility context, recovery pause flag, staff-scope and
   atomic employee-finalization RPCs, restrictive sales/stock/financial access.
3. `20261007215831_batch_2_branch_checkout_compatibility.sql`: request-ledger branch
   metadata added atomically with explicit INSERT columns; one private sale core
   behind unchanged public signatures, verified branch checkout and shared replay
   ledger. New writes honor the recovery pause; authorized saved receipts remain
   recoverable. No historical migration or transaction was rewritten.

### Rehearsal and release prerequisites

Reconstruct a reviewed complete schema-only PostgreSQL 17/Supabase baseline;
existing migrations are deltas, not a fresh schema. No baseline reconstruction or
database execution occurred. Follow `../../supabase/tests/BATCH_2_ISOLATED_TESTING.md`.
Run new/existing SQL suites, actual REST/RPC, concurrency/revocation and recovery
tests on synthetic data only. Reconcile drift, policies, helper signatures, column
grants and deployed Edge source; run advisors and verify backups/restore capability.

Preflight employee-code/identity duplicates and legacy relationships. New unique
indexes fail closed on duplicates; never rename identities automatically. NOT VALID
foreign keys constrain new writes; validate old relationships through reviewed
repair. Review relational grants and explicit denials without trusting client JSON.
Configure an owner-approved IANA business timezone before staff history rollout;
missing timezone fails closed and no configuration UI was added.

Rehearse the complete stack before deploying canonical employee-login,
create-employee, manage-employee and Angel. Old functions may conflict with the
stronger authorization contract. Release compatible Owner/POS clients after
rehearsal; all production steps require separate approval.

### Separate branch activation procedure

No branches/assignments/default mappings or stock allocations are auto-created.
Branch mode remains false. Historical NULL branch IDs remain unknown and accessible
to authorized owners. Never assign old sales to an arbitrary new location.

Before activation, implement/review branch stock allocation, adjustment/movement
workflows and compatible Owner stock/consolidated readers. Owner's legacy product
quantity reader is not a branch stock report. Review physical totals, retain
explicit mapping/allocation audits, and do not redistribute historical inventory.
No real activation/allocation API was implemented in this batch.

Only use an explicitly reviewed compatibility branch. Older branchless checkout
in active mode requires unambiguous authorized assignment; no first branch is
guessed. After activation a staff replay of a saved NULL-branch receipt is denied
because branch authority cannot be established; an authorized owner can recover
their own request. Resolve legacy retries before activation without changing IDs
or retagging receipts. Unmapped financial rows become owner-only after activation.
Cart/queued sale branch context must stay immutable. Durable offline reconciliation
remains deferred.

### Rollback and forward recovery

Before application, withdraw local changes with scoped patches only. Owner has
mixed earlier staged/unstaged work and POS has no Git metadata; no wholesale reset.
An unsuccessful migration transaction rolls back; inspect/rehearse a forward fix.

No automatic down migration is provided. Reverting old authorization helpers
would ignore explicit denial rows, while reopening grants/removing price guards
would restore security gaps. Retain protections and repair their logic forward.
Keep additive branch tables/columns, assignments and audits once data exists.
Never disable branch mode after branch sales: global legacy quantity is then stale.
A separately reviewed root-maintenance update of `businesses.pos_writes_paused`
can stop new sale writes while authorized receipt recovery remains available.
This control requires migration 3, is inaccessible to ordinary clients and must
be rehearsed before production. No real flag was changed here.

Do not restore selling_price NOT NULL or an arbitrary zero default while pending
NULL products exist. Preserve pending status until an authorized user prices them.
Existing zero values/active states were not reclassified. Grant denials and new
branch receipts make wholesale function/client reversion unsafe; retain IDs,
audits, mappings and checksums, and release a compatible forward fix.

Auth creation/reset crosses Auth and SQL services, not one transaction. Creation
compensates only after confirming finalization did not commit; uncertain outcomes
need operator reconciliation, never blind Auth deletion. Reset audit intent
precedes the Auth call; completion failures are surfaced. In-flight reset/revocation
still needs integration acceptance and an operational recovery procedure.

Later variants/stock lifecycle/offline/financial/UI batches remain deferred.
No subscription prices, branch limits or minimum selling price were invented.


## Batch 3 additive catalog recovery — 9 October 2026

Migration `20261009003200_batch_3_catalog_inventory_foundation.sql`, SHA-256 `1045d82c16082f519af78e379a54b53fe9f4955da39d9455bfb123a423424823`, is local tested only. Requires the recovered baseline and six immutable Batch 2 migrations on a fresh disposable, or all six deltas on the unchanged reviewed production schema after explicit approval. Never apply the baseline to production. Current production has no B2/B3 applied. Protected production operational backup remains blocked by unavailable secure PostgreSQL connection.

Adds optional groups/attributes, private request/latch state, scoped RPCs, indexes and triggers; composite FK initially NOT VALID. It does not rewrite prices, zero active states, historical stock, product/sale-item IDs, Auth users or platform objects. Review uniqueness and historical unit validity before deployment; do not repair production silently. Branches remain inactive and unmapped.

Before COMMIT, transaction rollback is the safe schema recovery. After COMMIT and use, dropping new groups/request caches/movement or price audit history would lose user records and idempotency; do not automatically reverse it. Prefer forward recovery preserving optional columns, IDs, stock ledger, price history and request responses. Temporarily disable affected catalog mutation EXECUTE grants and client entry points if necessary through a separately reviewed fix while preserving tested checkout and permission enforcement. Never re-enable insecure direct stock/price writes.

Once measured quantities have sold or queued, do not restore integer-only checkout/cart logic or truncate historical quantities. A compatible forward fix must retain NUMERIC receipt and movement quantities and reconcile queues by unchanged request IDs. Existing price and stock audits are append-only to clients. Review any constraint validation as a separate staged action after mapping/legacy review.

Production operational backup must remain encrypted/access controlled outside source and test fixtures. Any production restore, writer quiescence or recovery deployment requires separate authorization and reconciliation of post-backup transactions. Current synthetic recovery drill proves the procedure only; it does not prove a real production backup exists. No branches are activated, historical inventory redistributed or reference seed automatically imported.

## Main schema/history alignment — 9 October 2026

The release package supabase/releases/main_backend_alignment_20261009 contains before-write catalog/history checks and exact immutable source hashes. A new disposable copy with nine recovered history version/name entries accepted a supported seven-file CLI push, recording history 16; second dry-run empty. No production migration repair, baseline restore, staging overwrite, seeds or roles are required. Each file is transactional; a later failure after prior file commits requires recording the partial state and forward recovery, not blind replay or history fabrication. The production backup/access and explicit approval gates remain unchanged. See MAIN_BACKEND_ALIGNMENT_REPORT.md.
