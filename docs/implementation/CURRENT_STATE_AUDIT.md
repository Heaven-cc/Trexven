# TREXVEN implementation audit — 7 October 2026

Scope: Owner Flutter app in `Trexven`, POS Flutter app in `../trexvenpos`, and
connected Heaven-cc's Project (`ufehcfrlygqvminfjumf`). Admin Project is outside
this implementation. This is an initial source/schema audit, not a completed
device, performance, deployment, or security certification.

The user's instruction to begin implementation authorizes local implementation.
The documents' audit-first workflow informs sequencing. Proposed dimensions,
undecided drawer policy, pricing/quotas, and production deployment remain separate
decisions. This batch changes local app code only.

## Architecture and preserved work

| Area | Evidence | Current state |
| --- | --- | --- |
| Owner entry/auth | `lib/main.dart`, `lib/screens/auth/account_gate.dart` | Supabase Flutter; email, Google and restored-session gate |
| Owner state/navigation | `lib/core/user_provider.dart`, `lib/screens/main_screen.dart` | Provider; Home/Inventory/Finance/Intelligence/Me already present |
| POS entry/auth | `../trexvenpos/lib/main.dart`, `lib/src/features/auth/auth_provider.dart` in POS | Riverpod; employee-login Edge Function; refresh-token session |
| Online sale | Owner `lib/services/database_service.dart`; POS `sales_repository.dart` | Shared `submit_trexven_sale` RPC; preserve request replay and saved receipt |
| Backend | Connected table inventory and migration history | 29 public tables, all reported RLS-enabled; nine recorded migrations match local history through `20261005004045` |
| Vision | Owner `lib/services/vision_service.dart`, intelligence screens | Existing Owner integration; separate workstream |
| Prior repairs | `SALE_FLOW_REPAIR.md`, `UI_DENSITY_REPAIR.md`, `UI_FREEZING_REPAIR.md`, tests | Preserve existing sale retries, loading handling, layout and Vision tests |

Owner repository contains extensive staged/unstaged changes predating this batch.
No resets, cleanup, commits or deletions were performed. POS directory has no Git
repository at its current location; local rollback must use an explicit patch or
file backup rather than assuming Git history.

## First implementation batch

- Owner business lookup refuses employee membership instead of opening Owner UI
  or treating an employee as a new owner. Gate explains the correct POS app.
- POS maps `inventory_employee` distinctly and round-trips canonical role names.
- Active owners alone have unrestricted local permissions; legacy admin no longer
  implies all permissions. Managers receive basic sales/inventory defaults.
- Inventory staff cannot obtain local price-edit permissions through stale grants.
- Product creation, add-to-cart and checkout check local permission/context;
  sales staff without an explicit grant cannot open the product creation form.
- POS business selection rejects businesses outside the current assignment.

These checks improve client behavior. They do not replace RLS/RPC authorization
and do not establish that every backend requirement has been enforced.

## Backend gaps requiring follow-up

No public branch, branch-assignment, product-variant, sale-payment-line, credit,
refund, transfer, stocktake or shift tables appeared in the connected inventory.
`products.quantity`, selling price and threshold remain product/business scoped.
`sales` has no branch reference. Existing movement quantities are numeric but
current POS quantities are integer domain values.

The current `testing_readiness_access_controls` migration grants inventory staff
`edit_products` and the update policy does not distinguish price columns. Live
product trigger inventory contains only `products_updated_at`. Therefore a
server-side price guard is still needed; the local role restriction is insufficient.
Manager defaults in that migration include finance/camera access and must be
reconciled with the new requirements. Sales reads are not today/branch limited.

## Verification and limits

Baseline before this batch: Owner 61 passing tests; POS 10 passing tests.
New regressions reproduced the Owner membership bypass and POS role defects
before fixes. See `IMPLEMENTATION_PROGRESS.md` for final results.

Live inspection was limited to schema metadata, function definitions, trigger
metadata, table inventory and migration history. No business/customer records
were fetched for this audit and no production mutations were issued.

No physical device screenshots, current app binaries, release signing, backup
restore rehearsal, SQL adversarial suite, real transfer verification, or runtime
profiling were verified in this batch. Source absence is not proof of absence in
external services. Vision, Angel/GROQ and Google deployment configuration require
separate scoped verification.
