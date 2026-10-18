# Main backend deployment execution report

Target **ufehcfrlygqvminfjumf**, Heaven-cc's Project, eu-west-3. Final authorization: user's attachment `dff55470-2053-48fe-978e-bdd92027d1c2/Pasted text.txt`, authorizing exactly seven reviewed migrations and four reviewed Edge replacements, expressly excluding timezone changes and waiving the physical-device gate for this backend execution.

| Result | Status |
| --- | --- |
| Batch 2 | DEPLOYED |
| Batch 3 | DEPLOYED |
| Edge Functions | DEPLOYED |
| Main Supabase integration, approved deployment scope | COMPLETE |

Actual SQL execution completed at 2026-10-09T06:44:35.197747+00:00; supported CLI 2.120.0 returned exit 0. All sixteen expected version/name entries are present: nine original entries plus the seven below. No old migration replay, baseline restore, reset, seed, history repair or staging data import occurred.

## Migration versions actually deployed

| Version | Name |
| --- | --- |
| 20261007215736 | batch_2_authorization_price_enforcement |
| 20261007215743 | batch_2_branch_assignment_foundation |
| 20261007215831 | batch_2_branch_checkout_compatibility |
| 20261008002119 | batch_2_staging_security_recovery |
| 20261008020234 | batch_2_purchase_cost_contract |
| 20261008021428 | batch_2_business_day_contract |
| 20261009003200 | batch_3_catalog_inventory_foundation |

## Edge versions actually deployed and verified

| Function | Version | Gateway verify_jwt | Verification |
| --- | --- | --- | --- |
| employee-login | 6 | false | ACTIVE, source match |
| create-employee | 7 | true | ACTIVE, source match |
| manage-employee | 4 | true | ACTIVE, source match |
| angel | 12 | true | ACTIVE, source match |

Retrieved entrypoints, shared dependencies and import maps match the exact frozen source contents. No unrelated Edge Function metadata changed and no production secrets were changed. Real-session authentication acceptance was previously run in staging (54 checks); no production Auth fixtures, synthetic customers, password resets or transactions were created for this deployment. Production verification used read-only metadata/data comparisons; no claim of production live-account functional acceptance is made.

## Safeguards and data preservation

Immediately before writing, project identity, linked reference, all package hashes, six production catalog preflight groups and original nine history entries passed. The C-drive encrypted archive checksum passed; repeatable-read comparisons found all 79 backup tables unchanged at 2026-10-09T06:41:30.842513+00:00. Thus no refresh was required. The verified archive remains a **pre-deployment recovery backup**; it is not a post-migration schema snapshot. Its already-executed full isolated recovery matched 79 table fingerprints and 30 schema groups. Original D copies remain rejected. Recovery requires the original Windows DPAPI profile; Storage object bytes and independent offsite recovery are outside its scope.

Private pre/post comparisons covered all 78 original non-migration-history tables and every original column, with numeric scale normalized for the approved integer-to-numeric quantity transition. Businesses, Auth records, employees/memberships, subscriptions, products, stock values, sales, sale items, receipt/request identifiers and all other original customer records matched. New columns are excluded from this preservation comparison so additive schema changes do not create false differences. Records and row-level fingerprints were kept outside repositories/logs in the protected backup folder.

The first postflight returned exit 1 because the permissions reference table increased from seven to eleven rows. Execution correctly paused before Edge deployment. Investigation proved the four additions were exactly `override_price`, `apply_discount`, `adjust_stock`, and `view_finance`, with descriptions specified by migration 20261007215736. The original seven rows matched their pre-deployment fingerprint, and the other 77 original tables were unchanged. This expected approved reference-data addition was recorded; no data was manually changed to conceal the result, and migrations were not rerun. The follow-up postflight returned exit 0.

Database postflight verified 39 latest reviewed function bodies/languages/security modes and search-path configuration, with no mismatch and no anonymous execution on those functions. Catalog snapshots record 37 application tables, 121 policies and 19 noninternal application triggers. All application tables have RLS enabled; checked purchase-cost SELECT, authenticated MAINTAIN, direct branch/group mutations and private catalog reads are denied. All application indexes are valid. Tables, columns, constraints, policies, triggers, grants, dependencies and functions were captured through supported read-only catalog queries into protected evidence.

Branches and assignments remain empty, all businesses have branches disabled, and no inventory was redistributed. Timezones remain unset as explicitly instructed. No historical record or receipt rewrite, price backfill, subscription change, credential reset, application installation/uninstall/data-clear or application publication occurred. POS pending journals and original transaction keys were untouched.

## Remaining issues

- Business-local day RPCs intentionally fail closed while timezone is unset. Choosing/configuring the Nigeria business timezone remains a separate owner decision; no timezone write was authorized or performed.
- Existing private installations may require compatible in-place updates using the prepared ARM64 1.0.0+2 candidates. Actual installed signing identities, ABI and pending-data state remain unverified; that gate was expressly waived for backend execution. Never uninstall or clear data while pending work exists, and resolve memory-held drafts before restarting.
- This deployment did not activate branch workflows, publish applications, execute unrelated master batches or test paid Angel-provider availability.

Evidence: [migration execution](evidence/production_approved_migration_execution.json), [database postflight](evidence/production_approved_database_postflight.json), [Edge verification](evidence/production_approved_edge_execution.json), [immediate backup freshness](evidence/final_production_backup_freshness.json). The frozen seven SQL files and eight Edge source hashes remain unchanged.
