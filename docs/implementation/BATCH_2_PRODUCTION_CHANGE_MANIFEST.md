# TREXVEN Batch 2 production change manifest

9 October 2026, Africa/Lagos. **PREPARED — NOT EXECUTABLE.** Production remains unchanged. Explicit deployment approval and the recovery/client/configuration prerequisites below are pending. This is the concrete artifact required by Part 3 of the new request, not a deployment authorization.

## Verified target and starting state

Production: `ufehcfrlygqvminfjumf`, Heaven-cc's Project, ACTIVE_HEALTHY, eu-west-3, PostgreSQL 17.6.1.155. Staging: `qysspzlfiysekvxnlzsh`, Trexven-Staging, ACTIVE_HEALTHY, eu-west-1, PostgreSQL 17.11.0.003. All calls used explicit project IDs. The CLI default is linked to production and is deliberately not used for implicit database mutation/dump/push.

Fresh production metadata matches the approved recovered baseline in all six raw catalog sections: 32 application tables, 22 functions; no schema drift/conflicting Batch 2 objects detected. Production history has nine existing migrations through `20261005004045_sale_submission_reliability`, no Batch 2 migrations/bootstrap. Staging retains snapshot plus six migrations, four required ACTIVE v2 functions. [Environment evidence](evidence/batch_2_production_environment_verification_20261009.json), [fresh production catalog](evidence/batch_2_production_preparation_catalog_20261009.json).

Read-only preflight: one business, one manager, two Auth users, two memberships, two products, two sales, two sale items and two cached receipts. All 60 existing foreign-key checks found zero orphans; employee/membership identity/role/status mismatches and cross-business inventory/sale links are zero. Duplicate employee codes, duplicate business barcodes and invalid prices/quantities are zero. One existing zero-selling-price product remains valid and must be preserved. No customer/Auth rows were exported. [Aggregate snapshot](evidence/batch_2_production_preflight_20261009.json).

## Exact immutable migration order proposed for approval

| Reviewed source file | SHA-256 |
| --- | --- |
| 20261007215736_batch_2_authorization_price_enforcement.sql | `55a69cd97eb1fbbd2a034467e9cda93d5551c7fcd415f6ea4d778f53d2a1b8e7` |
| 20261007215743_batch_2_branch_assignment_foundation.sql | `2537fb48a9c7fc77088a30f2158f917d45bed39126d670fff3d5dfed4358f34a` |
| 20261007215831_batch_2_branch_checkout_compatibility.sql | `86feacc6be132aedb1a2999500a633e9a433f41c0965dbb7bb51a2f931278283` |
| 20261008002119_batch_2_staging_security_recovery.sql | `4f9a93633d401ad9e66b55870e5720c1081c0151408e2d31f8b082303fdb0ca3` |
| 20261008020234_batch_2_purchase_cost_contract.sql | `497f6cccce70b51454747d29b5ea61b49e89d00f8f549dc2d3ac9d2bbcbae61b` |
| 20261008021428_batch_2_business_day_contract.sql | `26003a9e8d16241a47140c48fca7422381aed607f6d948d73c949025a38a37aa` |

The JSON manifest includes exact affected CREATE/ALTER/GRANT/REVOKE/DROP-owned-trigger statement headers and file hashes: [machine-readable manifest](evidence/batch_2_production_change_manifest_20261009.json). Full immutable files retain dynamic policy/ACL blocks and exact function bodies; no applied migration is edited. Source timestamps are after the nine production historical deltas. Record actual production application versions truthfully; never copy staging bootstrap/history or pretend historical deltas ran again.

Affected objects include employee permission `granted`; centralized membership/role helpers; owner/staff/settings/financial/sales RLS; product price guards/audit and nullable pending selling price; `branches`, `employee_branch_assignments`; disabled-by-default business branch flags plus nullable timezone/compatibility branch; nullable branch references and NOT VALID compound foreign keys on stock/sales/movements/receipt requests; checkout implementation cores and optional branch RPC; recursion recovery; PG17 MAINTAIN/default-privilege revocation; non-cost product column grants and audit filtering; trusted clock/day RPC. Existing request/membership/receipt IDs and table data remain. Cost column/data/default remain stored securely. No table/column drop, historical rewrite or real branch activation is proposed. Only an owned Batch 2 price trigger is replaced.

## Exact Edge changes after database compatibility

| Function | Current production version | Current gateway verify_jwt | Tested staging version | Proposed gateway verify_jwt |
| --- | ---: | --- | ---: | --- |
| employee-login | 4 | false | 2 | false |
| create-employee | 5 | true | 2 | false |
| manage-employee | 2 | true | 2 | false |
| angel | 10 | true | 2 | false |

Deploy only the reviewed four bundles/shared modules, pinned supabase-js 2.117.2, current Deno lockfile. Preserve other four Vision/account functions and all existing secrets. New version numbers must be read back after actual deployment, not invented in this manifest. Explicit custom getUser/trusted-membership authorization protects the authenticated handlers; employee-login is presession. The three true-to-false gateway configuration changes require review as part of this manifest. Current production source/config is preserved in [Edge recovery evidence](evidence/batch_2_production_edge_recovery_sources_20261009.json); all proposed source hashes and tested staging bundle hashes are in the JSON manifest.

Secret-name metadata confirms SUPABASE URL/service/anon keys and GROQ_API_KEY exist. No values were retrieved, reset or transferred. GROQ_MODEL is optional; existing provider configuration is preserved. Provider health and real production auth/function requests remain untested before the gate. No Anthropic dependency. Authorized missing-provider behavior was tested in staging; production actually has a provider secret, whose validity is not established by presence. [Presence evidence](evidence/batch_2_production_secret_presence_20261009.json).

## Mandatory prerequisites — deployment cannot start yet

1. **Usable operational recovery reference:** explicit-project supported backup listing succeeded (CLI exit 0) but returns backups `[]`, PITR false, physical_backup_data empty; walg_enabled true does not establish a usable restore point. No new production backup has been created or validated. Do not substitute the schema-only baseline or synthetic local dump. A supported protected logical operational backup through a secure direct/pooler connection, or an existing validated provider backup, must include application/Auth dependencies and truthful history. No usable database connection secret or protected recovery destination was supplied for this task. Do not request keys/passwords in chat, generate credentials, enable paid PITR, or copy production records into test environments. [Backup API evidence](evidence/batch_2_production_backups_cli_20261009.log). Official [backup documentation](https://supabase.com/docs/guides/platform/backups) distinguishes database backup from Storage object recovery; secure Storage recovery must be reviewed separately if objects exist.
2. **Installed client compatibility/coordinated update:** both repositories declare 1.0.0+1, which does not identify the installed source. Updated source uses safe product projections and passes local tests, but old SELECT-star builds will fail under cost-column revocation. No backward-compatibility adapter can return the restricted column while honoring cost exclusion. Identify actual installed APK/build hashes and pending intents, or explicitly approve a coordinated private app update/maintenance procedure. No publication/distribution is authorized. The Owner source also requires the new day RPC/config, so it must not be installed before those are ready.
3. **Owner-approved timezone mapping:** production has no timezone column yet; migration 2 leaves it null, not an arbitrary fallback. Existing country Nigeria supports proposing Africa/Lagos, but no value is assigned until owner confirmation. Without configuration staff current-day reads fail closed and Owner today stats error explicitly. Include the exact business mapping in the executable manifest; no historical timestamp changes.
4. **Explicit approval of the final executable manifest:** this request only authorizes preparation/verification. Its Part 3 says: “Show this manifest and obtain my explicit approval before executing the first production write or deployment.” No production migration, secret/setting change, smoke write, user creation/reset or Edge deployment can run until that gate is satisfied. Approval alone does not waive prerequisites 1–3.

## Controlled execution once all gates are satisfied

Reverify target/history/catalog and file/source hashes immediately before execution. Confirm the reviewed recovery artifact/time and support restore procedure. Use the approved private maintenance/client coordination window; never infer a write-pause or active-user signout authorization from this preparation. Apply exactly the six reviewed migrations in the tested order above, with their existing transaction boundaries, recording each actual result/history entry. Stop on first failure; no blind db push, baseline import or history repair.

Configure only the separately approved timezone mapping; verify branches_enabled remains false, branch tables unactivated, historical branch IDs null and original inventory unchanged. Verify aggregate integrity, price/cost/receipt fingerprints and new catalog after each phase; distinguish legitimate new live transactions from unexpected rewrites. Deploy the four reviewed Edge bundles only after database compatibility, retain settings/secrets and verify actual returned versions. Confirm updated clients privately under the approved coordination procedure; no public release.

Read-only post-integration checks cover schema/history, owner/employee/business records, retained prices/stock/receipts/settings, cost grants, RPC signatures, branch defaults, timezone and function configuration/advisors. Production write-based employee creation/reset/sale tests are **not approved** here; propose exact disposable smoke identities/cleanup and seek approval separately. Existing staging synthetic suites provide adversarial coverage and must not run against production.

## Recovery procedure and stop conditions

Uncommitted migration failure rolls back its transaction. Preserve error, actual history and catalog; do not retry blindly. Committed security corrections use forward recovery, retaining cost restrictions and historical data; do not drop tables/branches, re-enable permissive policies, rewrite receipts, or restore over newly committed live sales. If a serious regression occurs, stop subsequent writes/deployments and follow the approved availability/coordination procedure. Review preserved previous Edge source/config for a compatible forward correction; restoring an older insecure handler is not automatic authorization. Operational backup restoration is a last-resort separately approved intervention with explicit downtime/reconciliation, never a destructive checkout rollback.

Two synthetic fresh replays and operational/schema-only restores were proven on 8 October; they validate migration/recovery mechanics, not a production backup that does not exist yet. An alternate day-before-cost production order is not included or implicitly rehearsed. Batch 3 implementation remains conditional on successful production integration.
