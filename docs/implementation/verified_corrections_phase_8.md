# Verified corrections — Phase 8: authoritative migration history and NULL validation

Status: seven historical sources restored without replay; current NULL-validation replacement deployed under explicit approval as 20261021020444_current_null_input_validation. Device acceptance remains pending.

## Authoritative sources and provenance

Source: supabase_migrations.schema_migrations on production ufehcfrlygqvminfjumf.
Each missing migration contains exactly one stored statement. Copy that statement unchanged into supabase/migrations/<version>_<name>.sql; do not reconstruct it from current function definitions, prepend comments, append a new statement, alter its original version, mark it applied again or execute it. These sources include historical implementations superseded by later production migrations.

| Production version | Name | Characters | Source MD5 |
|---|---|---:|---|
| 20261016034243 | production_admin_reporting | 6108 | 4c2eebcd7bb77f5985dfb50844c16f9c |
| 20261016035329 | production_reporting_currency_normalization | 5461 | 012738ba5f346b495cc5fb8f38524b91 |
| 20261016035847 | production_reporting_currency_labels | 5469 | 36bc2e82ec6f130a38d283fbb120db9a |
| 20261017003211 | production_business_controls | 81785 | a10a3b339364c1ba2e5dd4d174d2aeb5 |
| 20261017035929 | credit_returns_branch_sellable_return | 7554 | a3f7a236604a68a20106872063a6529a |
| 20261017035937 | credit_returns_owner_branch_financial_summary | 3544 | 68448ca920c28da88f07031b28e8b05e |
| 20261017052445 | branch_inventory_operations | 59789 | 661061343cb5ab137550342cb6713e1b |

Files restored:
- supabase/migrations/20261016034243_production_admin_reporting.sql
- supabase/migrations/20261016035329_production_reporting_currency_normalization.sql
- supabase/migrations/20261016035847_production_reporting_currency_labels.sql
- supabase/migrations/20261017003211_production_business_controls.sql
- supabase/migrations/20261017035929_credit_returns_branch_sellable_return.sql
- supabase/migrations/20261017035937_credit_returns_owner_branch_financial_summary.sql
- supabase/migrations/20261017052445_branch_inventory_operations.sql

Owner is the existing canonical backend-migration repository. POS currently has no supabase/migrations tree, so no second migration copy or shared Flutter package was introduced there. Restoring these records changes GitHub source only, not either app's runtime API or production history.

## Unrecorded 20261013005127

Production has no schema_migrations row for 20261013005127. The repository file therefore cannot be called deployed.
Move its exact existing 2070-character SQL from supabase/migrations/20261013005127_backend_null_input_validation.sql to supabase/changes/unrecorded_20261013005127_backend_null_input_validation.sql. This preserves source provenance while removing an unrecorded old migration from automatic push/replay. It is a move, not a backup or applied-history repair.

No version was inserted/deleted/renamed in production migration history. No supabase db push, migration repair, historical rollout, local rebuild or test database was run.

## Current defect confirmation

Read all five live target definitions and their ACLs. All six old validation clauses remain present exactly once. SQL three-valued logic means an absent SQL value can make a <> / NOT IN condition unknown rather than true, allowing an IF validation branch to be skipped. Valid arrays/payment methods/conditions must retain their current behavior.

Approved source: supabase/migrations/20261021020444_current_null_input_validation.sql:
- Reject missing stocktake counts, checkout payment lines, return items and return inspection conditions with IS DISTINCT FROM array.
- Explicitly reject missing repayment method and missing per-line return condition before their existing enum validation.
- Guard the full current definition MD5 and ACL of each of the five live functions before any replacement.
- Then perform only the six exact clause replacements using pg_get_functiondef, with a one-occurrence guard for each.
- Preserve current branch inventory logic, completed-receipt replay order, business/employee/branch authorization, confirmed-payment logic, role grants and signatures. No historical row, RLS policy or function grant is changed.
- Two changes target inspect_trexven_return; baseline guards run once before the replacement loop, so the second replacement does not compare against an obsolete intermediate hash.
- It does not reuse the unrecorded timestamp. The exact approved SQL was deployed once under the actual version 20261021020444 and promoted to canonical migration source.

Full-definition baselines:
- public.complete_trexven_transaction(uuid,uuid,uuid,numeric,jsonb,jsonb,jsonb,uuid,uuid): 392c26da300d934bf68c8a8eda784f9f
- public.count_trexven_stock(uuid,uuid,jsonb): 739907e0a679143b935e0d4032d6709f
- public.inspect_trexven_return(uuid,uuid,jsonb): b3954579cf36311c1f6c4b1be1b3eee9
- public.repay_trexven_credit(uuid,uuid,numeric,text,boolean,text,uuid): b37a714b72babad334f0714ddecf1afb
- public.request_trexven_return(uuid,uuid,jsonb,text): 4b4ab090b7fe2737f1d9e71d99426646

The source review matched all six current clauses and computed the proposed five definitions without executing them. No malformed payment, stocktake, repayment, return or auth call was sent to production. This is not runtime acceptance.

## Compatibility and boundaries

All five functions are existing shared backend contracts used by Owner/POS workflows. Only missing/invalid input rejection changes; no frontend API or valid payload shape changes. Later branch-operations source is retained because the patch applies to the live definition, rather than replaying the older full function body.

Current source comparison and production catalog reads are the evidence. Device acceptance remains pending. No unrelated SQL migration, index, policy, Edge Function, credential, price, provider or entitlement setting is deployed as part of Phase 8 preparation.

## Manual acceptance after deployment (user; not executed)

Valid checkout and original-request receipt recovery; valid branch/global stock counts; confirmed repayment; return item selection and inspection must retain prior outcomes. Missing collections/method/condition must reject atomically and leave financial/inventory rows unchanged. No fabricated production records were used to exercise these paths.

## Remaining performance work

Advisor read after Phase 7 still reports 123 missing-FK-index notices, 20 RLS initplan warnings, 69 permissive-policy findings and 9 duplicate-index pairs. Read-only index catalog inspection found candidates for a separate carefully guarded duplicate-index change, but no index/policy modification is prepared or deployed by this Phase 8 work. That remains Phase 9. Security advisors still include intentionally exposed bounded account admission and the separate leaked-password configuration recommendation.

## Approved deployment evidence — 2026-10-21

Applied exact approved SQL once as 20261021020444_current_null_input_validation. Before/after comparison found exactly the six approved clause changes in five functions; all five complete definitions match the precomputed expected definitions. Their signatures, grants, definer attributes and search_path values stayed unchanged. The other 181 public/private functions, all 298 RLS policies, grant/RLS attributes on 83 tables and all role settings stayed unchanged.

All 20 checked counts stayed unchanged: auth.users 2; sales 4; expenses 0; inventory 0; sale_items 4; return_items 0; sale_returns 0; sale_payments 3; private.sale_requests 4; credit_entries 1; billing_invoices 0; billing_payments 0; billing_sessions 0; stocktake_counts 0; private.catalog_requests 7; stocktake_sessions 0; inventory_movements 5; subscription_events 0; business_subscriptions 0; private.account_deletion_state 1.

Post-deployment function MD5 values:
- complete_trexven_transaction: bfe24a389cadeea4c421a4eeccd011fb
- repay_trexven_credit: dd11802ceeea19710c08446ccd6da420
- request_trexven_return: 2f668471675355611686edf24bd37845
- inspect_trexven_return: 498ff0e3afa2d6210112c2166cb55b8c
- count_trexven_stock: 37de30cf1156b785467e828ef0758910

No invalid/valid transaction probe, auth mutation, stock count, repayment, return, application build or test suite was run. Catalog/source evidence is not runtime acceptance. No index or policy change was included.

Before this deployment, the actual GitHub tree's 50 canonical migration names/versions matched production's 50 recorded entries. The seven restored statement bodies, moved unrecorded source, prepared replacement and Phase 7 deployment record were fetched back and compared exactly. The new approved deployment adds one canonical version and one production record; the unrecorded old timestamp remains outside the migration history.
