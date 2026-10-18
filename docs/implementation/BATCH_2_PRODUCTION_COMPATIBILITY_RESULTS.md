# Batch 2 production compatibility results

9 October 2026, Africa/Lagos. **Source/staging compatibility verified; installed-production compatibility not established.**

| Fresh preparation check | Actual result |
| --- | --- |
| Production identity/history | Healthy explicit target; nine original migrations, no Batch 2 |
| Production vs recovered baseline | All six raw sections equal; 32 tables/22 functions |
| Six migration hashes | All six unchanged |
| Existing foreign keys | 60 checks; zero orphans |
| Employee/membership business/role/status | Zero mismatches |
| Cross-business inventory and sale links | Zero mismatches |
| Invalid price/stock and duplicate code/barcode groups | Zero |
| Zero-selling-price legacy product | One; preserved |
| Backup listing | Exit 0; no backups, PITR false; recovery gate blocked |
| Production secret presence | Required Supabase keys and GROQ_API_KEY names present; no values retrieved |
| Owner full local suite | 66 passed, exit 0 |
| POS full local suite | 37 passed, one explicit-live skip, exit 0 |
| Owner analysis | 209 infos, zero errors/warnings, exit 1 |
| POS analysis | Four infos, zero errors/warnings, exit 1 |

Commands executed locally: `flutter test --no-pub --reporter expanded` and `flutter analyze --no-pub` in each repository. [Owner tests](evidence/batch_2_production_prep_owner_tests_20261009.log), [POS tests](evidence/batch_2_production_prep_pos_tests_20261009.log), [Owner analysis](evidence/batch_2_production_prep_owner_analysis_20261009.log), [POS analysis](evidence/batch_2_production_prep_pos_analysis_20261009.log). Previous 84 SQL/78 hosted HTTP/18 native HTTP/restart/Deno/replay/restore results are historical 8 October evidence, **not rerun or production smoke checks this turn**.

Owner product stream/read/dashboard/CSV and POS barcode/search/pricing reads use explicit authorized projections; no active product cost model or product wildcard query was found. RLS continues to decide row scope. Updated Owner stats requires `get_trexven_business_day`, which is currently absent in production; after migration it also requires approved timezone configuration. Do not ship this source against the pre-Batch-2 backend prematurely. Existing Owner auth/business selection/stock/sale widgets and POS auth/permission/cart/checkout tests pass locally; this does not establish real production registration/login, hardware camera scan, provider health or installed APK compatibility.

Both repositories still declare 1.0.0+1. Source-file/build-input hashes are frozen in the [JSON manifest](evidence/batch_2_production_change_manifest_20261009.json); no artifact version uniquely identifies current installed builds. Old SELECT-star products cannot remain allowed while cost-price access is removed. A confirmed coordinated private update is required unless installed artifacts already match the tested non-cost contract. No new rollout/distribution was performed or authorized.

Production lacks branch/timezone columns until migration 2; branches stay disabled, legacy checkout stays branch-null-compatible, no automatic stock migration. Country Nigeria is observed, Africa/Lagos proposed only for confirmation. Missing zone fails closed rather than using phone time.

Subscription preservation scope: no dedicated subscription/billing table exists in the recovered app schema; business_settings has zero rows and no subscription-related top-level keys in the current read-only check. These six migrations do not delete/change subscription data or define entitlements. External billing/subscription systems were not audited and are not claimed verified. Vision/account handlers outside the four planned Edge functions remain unchanged.

Current production security advisors report 3 INFO private RLS-without-policy, 5 WARN authenticated SECURITY DEFINER and 1 WARN leaked-password protection disabled. Staging has the known 3 INFO/13 WARN contract findings. No setting was changed. See [raw advisor evidence](evidence/batch_2_production_security_advisors_20261009.json) and official [Auth protection guidance](https://supabase.com/docs/guides/auth/password-security), [definer lint](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable). These are disclosed findings, not a claim of clean advisors or provider validity.

Preparation tooling failures retained/described: initial PowerShell quoting error ran no commands; PowerShell shim execution policy prevented the first CLI help, corrected by supported supabase.cmd; an initial local catalog parser captured the prose boundary instead of JSON (all read-only queries succeeded), corrected from retained results; first manifest generator used a relative sibling path and failed before writing the manifest, corrected to resolved workspace. No production mutation resulted.
