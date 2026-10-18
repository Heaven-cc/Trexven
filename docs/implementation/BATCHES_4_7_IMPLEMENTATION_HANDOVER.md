# Batch 4–7 implementation handover — 9 October 2026

Status: local source implementation; current database and application behavior
remain **unverified**. Batch 2/3 deployment is preserved. No Batch 4–7 migration,
Edge Function, charging, branch activation or app publication was executed.

## Source implemented

| Batch | Backend and Owner/POS source |
| --- | --- |
| 4 | Confirmed cash/bank/card and split payments; per-sale approved credit, partial repayments/reversals, inspected returns/refunds, original immutable receipts, request replay, business-local summaries, signed cash-only offline scopes, encrypted offline queue and operation intents, reconciliation review and interrupted checkout recovery. |
| 5 | Online physical counts, versioned counters/reassignment, barcode/bulk counting, delta reconciliation preserving later movements, nonsellable conditions/restoration/write-off, supplier returns, movement history and low-stock entitlements. Transfers remain behind dormant business/branch flags. |
| 6 | Assigned registers with one open shared drawer and multiple employees, actual opening/counts, actor-attributed cash movements, expected/count variance, handover confirmation, immutable closure/history/review, late cash reconciliation and owner/explicit-manager orphaned-shift recovery. |
| 7 | START/CORE/PRO server entitlements, subscription states/history, configurable commercial fields and quotas, owner plan/cancellation requests, provider-independent verification and payment/invoice deduplication, billing UI and POS status refresh, reviewed account lifecycle requests, backup/error/health metadata foundations. |

The existing checkout core and membership IDs are retained. Old and new online
checkout contracts share the original receipt record and scoped request lock;
retries must not create a second sale. Legacy noncash recovery checks the server
receipt first, then requires explicit verification of the original method and
amount before atomic enrichment of the same version-1 journal. It must never
collect payment again. Rejected payments remain journaled; only a receipt or a
server-verified cancellation with an explicit no-money-moved acknowledgement may
clear a request. Cancelled keys are rejected through both contracts.

Cash configuration is determined server-side even when an employee cannot see
the register. Only joined, active assigned drawers are offered for cash; bank
and card-only checkout can continue without receiving cash. Monetary summaries
and drawer expected amounts are calculated in PostgreSQL and returned as exact
decimal text. Original offline payment occurrence time controls its reporting
day. Late cash and inventory discrepancies require review, without rewriting a
closed count or closure; any physical stock correction uses its own approved
Batch 3 adjustment ledger entry.

Deletion is now a reviewed owner request in the local Flutter UI and replacement
`delete-account` source. The replacement never calls Auth-user deletion. The
existing production endpoint has not been changed by this batch; its legacy
destructive behavior is a deployment-review concern, not a completed fix there.

## Validation truth

Minimal offline validation executed: all **14 migration files** passed PostgreSQL
SQL syntax parsing and **91 PL/pgSQL function/DO bodies** passed body parsing,
exit 0. Six SQL-language helper bodies also passed syntax parsing. Dart
formatting/parser checks succeeded on 25 selected source/test files (exit 0);
this is not Flutter analysis or a type/integration test. Dynamic SQL dependency
resolution, RLS, triggers, grants and runtime compatibility still require a real
isolated full replay.

Earlier, before testing was deferred and before the latest source refinements,
five native offline queue tests and one Owner operation-journal test passed.
Historical Batch 4 SQL evidence applies to its earlier source only. Existing
Batch 2/3 suite counts and APKs must not be presented as current Batch 4–7 passes.

Six SQL suites and billing-provider/legacy journal regressions are prepared for
final QA. New SQL suites and new/modified application and Edge tests have **not
been executed**. No routine Flutter analysis/test/build/run, device installation
or application launch was performed after the user's deferral instruction.
See [the final QA instructions](../../supabase/tests/BATCHES_4_7_FINAL_QA.md).

## Remaining configuration and QA gates

- Local WSL/PostgreSQL replay is blocked by the previously observed filesystem
  I/O/startup failures. Recover that runtime and adequate C: scratch space before
  final QA. The rejected D: backup/storage must not be used.
- Prices, currency, billing intervals, trial/grace durations and employee/camera
  limits remain nullable/configurable. No real provider adapter, webhook endpoint,
  payment credentials or live charging is enabled. This is the approved billing
  foundation, not a functioning live payment integration.
- Do not uninstall or clear data on a test installation with pending sales.
  Same-ID/same-signature updates and secure-storage key retention still need
  actual device verification. Reinstallation cannot be claimed lossless.
- New confirmed payment entry supports cash, bank transfer and external card
  terminals. Committed legacy `mobile_money`/`other` receipts remain recoverable;
  an uncommitted legacy request with those ambiguous methods is retained for
  reviewed resolution, without automatic relabeling or a second payment.
- Backend authorization, concurrent revocation/count/checkout/close/webhook
  tests, Owner/POS full suites and analysis, Edge JWT tests and Android update
  checks are deferred. Detailed warnings/info/error counts must be recorded then.
- No Admin dashboard or production database copy to Admin; recovery and backup
  metadata alone never proves recovery. No branch creation, activation, mapping
  or redistribution of historical stock/sales is included.

## Coordinated deployment preparation

The reproducible [candidate generator](../../supabase/releases/prepare_batches_4_7_manifest.py)
produces a hash manifest for 14 chronological migrations and two revised Edge
sources. It is a local **unapproved** candidate; it does not execute deployment.
Do not change or reuse the frozen, already-deployed Batch 2/3 package as if it
were the new release. The late Batch 4 recovery migration depends on Batch 6/7
and must remain last despite its batch number.

After final QA: verify main project identity and unchanged predecessor history;
run fresh read-only drift/compatibility preflight; capture an access-controlled
fresh backup and prove isolated restore; freeze and review exact candidate
hashes; obtain one explicit production approval. Apply approved migrations in
manifest order, verify contracts/RLS/grants and intact original records, then
deploy only reviewed `camera-ai` and non-destructive `delete-account` sources
with authenticated JWT settings. Recheck backend behavior before coordinated
in-place test-app updates. No real provider activation, subscriptions assigned to
legacy businesses, branch workflow activation or public app release is implied.

Recovery is forward-only: pause new POS writes using the existing maintenance
guard, retain journals and all financial/inventory/cash/billing ledgers, leave
provider configuration disabled, and apply reviewed corrective migrations.
Never drop ledgers, restore permissive RLS, delete receipts or automatically
reverse genuine money movements as a rollback. Backup restoration is a separately
reviewed recovery operation with preservation/reconciliation of later transactions.
