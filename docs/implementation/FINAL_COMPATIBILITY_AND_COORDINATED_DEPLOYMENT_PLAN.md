# Production deployment executed — 9 October 2026

The [execution report](PRODUCTION_DEPLOYMENT_EXECUTION_REPORT.md) supersedes earlier undeployed/approval-blocked status below. Under the user's final explicit authorization, all seven migrations committed (CLI exit 0, history now 16); Batch 2 and Batch 3 are DEPLOYED. Reviewed Edge Functions are DEPLOYED: employee-login v6 (JWT false), create-employee v7, manage-employee v4 and angel v12 (JWT true). Retrieved sources match the frozen package; unrelated functions remain unchanged. Main backend integration for the approved scope is COMPLETE.

All original values across 78 existing non-history tables were preserved. Four canonical permission reference rows were added exactly as approved; the original seven permission rows are unchanged. Postflight verified 39 reviewed functions, RLS/grants/catalog, valid indexes and dormant empty branches. The protected C pre-deployment backup passed immediate checksum/freshness checks; no refresh was required. The timezone remains unset per explicit exclusion, so daily-sales flows need a separate clock configuration decision. No apps were installed/published, no local data cleared, no branches activated and no production synthetic records created. Device verification was explicitly waived for this backend execution and remains an app-update limitation.

---

# Final compatibility and coordinated deployment plan

9 October 2026. Target: **ufehcfrlygqvminfjumf**. Production remains unchanged; integration is not complete. Both applications are private development/test applications according to the user. Automated preparation passed. Actual installed-device verification and explicit deployment approval remain outstanding. This report supersedes earlier statements that credentials, JWT gateway tests or an operational backup were unavailable.

## Executed checks

| Check | Actual result |
| --- | --- |
| Owner complete Flutter suite | 75 passed, exit 0 |
| POS complete Flutter suite | 47 passed, 1 live-backend test explicitly skipped, exit 0 |
| Owner analysis | 208 informational findings; 0 warnings, 0 errors; exit 1 |
| POS analysis | 4 informational findings; 0 warnings, 0 errors; exit 1 |
| Deno authorization helpers | 9 passed, 0 failed, exit 0 |
| Five isolated SQL suites | 105 assertion calls, each suite exit 0 |
| Staging Edge HTTP/session checks | 54/54 passed using genuine ES256 sessions |
| Production CLI dry-run | Exit 0; exactly seven pending migrations; TLS verify-full and server read-only connection |
| Current production catalog preflight | Six catalog groups and original nine history entries match |
| Replacement C-drive database recovery | Fresh full restore exit 0; 79 table fingerprints and 30 schema groups match |
| Backup freshness | 2026-10-09T06:31:57.804355+00:00: 79 tables unchanged, encrypted checksum valid |
| Owner/POS ARM64 debug APK builds | Both exit 0; actual version 1.0.0, version code 2 |
| Actual installed test-device preservation | Not executed: zero online devices |

Evidence: [SQL suites](evidence/batch_3_sql_results.json), [analysis](evidence/final_flutter_analysis_counts.json), [JWT checks](evidence/final_edge_jwt_gateway_results.json), [dry-run](evidence/final_production_migration_dry_run.json), [backup recovery](evidence/production_operational_backup.json), [freshness](evidence/final_production_backup_freshness.json), [Owner APK](evidence/final_owner_candidate_apk.json), [POS APK](evidence/final_pos_candidate_apk.json). Raw Flutter/Deno/build logs remain in local ignored tool directories. No production adversarial tests or customer records were used in authorization tests.

## Application preparation and data retention

Both sources retain checkout request/idempotency keys, receipt IDs, sale-item relationships and employee membership IDs. Branch context remains optional for legacy requests and branches remain dormant. Batch 3 catalog writes use the new RPC contract; narrow legacy read projections support pre-migration reads. Permission-denied responses are not treated as missing-schema fallback. Existing zero-priced products are not silently repriced. Purchase-cost UI/functionality is not reintroduced.

POS now declares Android INTERNET permission in the main manifest (previously only debug/profile declared it). Two added journal regression tests prove legacy version-1 journal preservation through receipt recovery and explicit matching acknowledgement, and fail-closed retention for unknown future journal versions. No pending-journal format migration was introduced. Owner source required no additional Dart changes for this preparation.

POS persists `trexven_pending_sale_v1.json` in the application's support directory. Original user, business, membership, optional branch and request IDs must be retained; successful receipt recovery and matching acknowledgement are required before clearing it. Login changes or permission failures do not authorize deletion. Cart contents and some Owner drafts/unconfirmed requests are memory-held: finish/confirm them before closing or updating. There is no claim that all screen drafts survive process termination or that POS has a general offline queue.

Candidate artifacts on C:

| App | Application ID | Actual APK version | SHA-256 |
| --- | --- | --- | --- |
| Owner | com.ODT.odt | 1.0.0+2 | 06cec27d4f5743a6dd8f106d83532a58c18b08791fd4b0eaf9f607e7da68d746 |
| POS | odtweb.com.trexvenpos | 1.0.0+2 | 131295ab02b084f88823c5a74ef83e368e5ca0e8de5c0fde6ff8a9ebf0206fe9 |

Both are debug ARM64-only APKs signed with SHA-256 `66278e148f4a1ac8ef448ab6af2c3a78507981be76f1d7fb8f5e7472725b6285`, matching the previously inspected local code-1 artifacts. Pubspec still declares 1.0.0+1; build flags produced code 2. Previously inspected artifacts are not proof of installed-device identity. No APK was installed or published.

For each actual test installation, before rollout:

1. Connect the device with USB debugging. Record its serial, supported ABI, installed package version and installed APK signing certificate; compare against candidate metadata. Refuse incompatible signatures, unsupported ABI or version downgrade. The offline emulator entry does not satisfy this check.
2. Resolve Owner uncertain requests against receipts using their original keys, and finish/export any important screen drafts before closing. For POS record whether a pending journal exists without logging its contents; retain it if it cannot yet be recovered. Do not uninstall or clear app data to resolve authentication or installation errors.
3. During the approved maintenance window, stop further business writes, deploy/verify the complete backend, then use in-place `adb -s <verified-serial> install -r <verified-candidate.apk>`. This command is documented here and has NOT been executed. In-place replacement preserves persisted app data when Android accepts package/signature/version compatibility. Uninstall followed by reinstall does not offer that guarantee.
4. On the same authorized account/context, recover any pending request with its original key, inspect its receipt and acknowledge only that request. Verify the journal disappeared only after acknowledgement. If denied, retain the journal and investigate permissions; do not forge ownership or replay as another user.

Physical installation and preservation verification is still required; unit tests cannot prove device-local data state. The smallest remaining action is connecting the existing test devices (or supplying a controlled device-inventory and pending-data confirmation). An ARM64 candidate cannot be installed on an x86-only test device; build a matching candidate if required.

## Edge verification

Only staging `qysspzlfiysekvxnlzsh` received the reviewed replacements: create-employee v3, manage-employee v3, angel v3 with gateway JWT verification enabled, and unchanged employee-login v2 with the pre-session gateway flag disabled. Application handlers validate server Auth and trusted database membership. Actual HTTP checks cover missing/malformed/tampered/API-key bearer rejection, genuine owner/manager/sales/inventory sessions, cross-business access, permission escalation, password reset, login, and immediate revocation with a still-valid token. The Angel authorized path returned the configured unavailable response; no paid-provider inference was exercised. Valid signed expired-token behavior was not separately tested.

All six synthetic Auth users were deleted; verified staging counts for Auth users, businesses, employees, memberships, branches, sales, audit logs and Angel windows returned zero. Temporary staging key material was removed. No production Edge Function was deployed. The exact eight source-file hashes and gateway flags are frozen in the release manifest; future production version numbers are assigned at deployment, not assumed.

## Backup custody and recovery limits

The original D-drive encrypted archive later failed checksum verification; 39 copied source files also differed. Those D copies are rejected, with [storage-integrity evidence](evidence/production_backup_storage_integrity_failure.json). No drive repair, formatting or production alteration was attempted. Original repository sources remained on C. Initial universal-APK builds failed for disk space; subsequent C-drive ARM64 builds passed. The failed emulator attempt on D is not a passed installation test.

The replacement backup was created read-only at 2026-10-09T05:51:52.975947+00:00 using PGPASSFILE and verify-full TLS, in a USER-only protected folder outside repositories on C. The new archive was fully restored into a fresh unexposed local database, compared, encrypted with Windows DPAPI CurrentUser, decrypted and hash-checked. Plaintext, clone database and its owned runtime were removed. Encrypted SHA-256: `d780083e12483367a5628a7b813984e9c36f330b9a0e52afcce40b6ba93086d0`. Latest freshness check above shows no changed tables. This backup satisfies the tested local database recovery prerequisite.

Recovery requires the original Windows profile and DPAPI keys. It includes application/Auth/database and Storage metadata, not Storage object bytes, external secrets, global role passwords or independent offsite disaster recovery. Do not restore a whole managed database over a live Supabase project: any actual incident requires a reviewed managed-platform recovery/forward repair procedure, secure decryption and isolated verification first. No provider PITR or hosted backup was inferred from API access.

## Exact approved-scope deployment sequence (NOT executed)

1. Complete the actual device/pending-data gate above. Obtain explicit approval naming this main project, these seven migrations, four reviewed Edge replacements, and any separately approved timezone write. No app publication or branch activation is included.
2. Pause all test installations and other business writers. Confirm production identity through the connector and linked project file immediately before work. Run `python supabase/releases/main_backend_alignment_20261009/verify_package.py`; abort on any source/history/target drift.
3. Repeat reviewed read-only `preflight.sql`, backup encrypted checksum and private 79-table freshness comparison. If anything changed, stop; refresh and fully recover-verify a protected backup before writing. Freshness verification is required inside this maintenance window as data may change after this report.
4. Using the protected passfile, official CA and verify-full TLS, repeat supported CLI v2.120.0 `db push --db-url <nonsecret-guarded-main-url> --dry-run --yes`. The tested wrapper uses WSL `--exec` so URL query ampersands are not shell commands. Its read-only server option must remain on for preflight/dry-run. Inspect the exact seven-file list below. No include-all, seeds, roles, reset, history repair or baseline restore.
5. Only after approval, use the same verified target and secure environment for `db push --db-url <nonsecret-guarded-main-url> --yes`, with the read-only connection option removed specifically for this approved write. Never put a password in the URL or command/log. The deployment runner must be reviewed against the proven read-only wrapper before execution; the wrapper shipped now executes dry-run ONLY. Record each migration/history result and stop on any partial failure. Do not retry all files blindly or manually make staging-like production adjustments.
6. Separately, if approved, set the existing verified Nigeria business `7de5d490-6883-45d5-b3fd-e9b85b3832bc` to `Africa/Lagos` only when its new timezone is NULL, with an exact business/country predicate and one-row result assertion. Abort if country/context differs; preserve any existing valid setting. No historical timestamps are rewritten. This is an additional explicit production write, not part of the seven SQL files. Business-day RPCs fail closed without a configured timezone; do not release day-based flows with an unset clock.
7. Deploy only the frozen reviewed Edge sources to `ufehcfrlygqvminfjumf`: employee-login (`verify_jwt=false`), create-employee, manage-employee, angel (all three `verify_jwt=true`; correct import maps retained). Record actual versions, gateway flags and deployed source checksums. Do not deploy unrelated functions, change project secrets or weaken gateways.
8. Read-only postflight: expect exactly the original nine plus seven version/name entries (16 total), approved resulting catalog/RLS/grants/triggers/RPC signatures, unchanged IDs and legacy sale/receipt relationships, dormant branch feature flags, no inserted/activated branches or stock redistribution. Compare preserved values semantically: new columns/numeric types can legitimately change whole-row fingerprints, so a naive pre/post whole-row hash is not the preservation test. Review totals, original quantities/price values, request/receipt keys and references. Any mismatch halts rollout for reviewed forward recovery.
9. Perform only approved non-adversarial acceptance on genuine test accounts after metadata checks. No fake customers or adversarial fixtures in production. Reopen with refreshed repository/cache context and replace private test APKs in place, preserving pending requests as described above. Do not resume business testing until backend/Edge/client acceptance is complete.

Exact migration order (unchanged, hashes verified):

1. `20261007215736_batch_2_authorization_price_enforcement.sql` — SHA-256 `55a69cd97eb1fbbd2a034467e9cda93d5551c7fcd415f6ea4d778f53d2a1b8e7`
2. `20261007215743_batch_2_branch_assignment_foundation.sql` — SHA-256 `2537fb48a9c7fc77088a30f2158f917d45bed39126d670fff3d5dfed4358f34a`
3. `20261007215831_batch_2_branch_checkout_compatibility.sql` — SHA-256 `86feacc6be132aedb1a2999500a633e9a433f41c0965dbb7bb51a2f931278283`
4. `20261008002119_batch_2_staging_security_recovery.sql` — SHA-256 `4f9a93633d401ad9e66b55870e5720c1081c0151408e2d31f8b082303fdb0ca3`
5. `20261008020234_batch_2_purchase_cost_contract.sql` — SHA-256 `497f6cccce70b51454747d29b5ea61b49e89d00f8f549dc2d3ac9d2bbcbae61b`
6. `20261008021428_batch_2_business_day_contract.sql` — SHA-256 `26003a9e8d16241a47140c48fca7422381aed607f6d948d73c949025a38a37aa`
7. `20261009003200_batch_3_catalog_inventory_foundation.sql` — SHA-256 `1045d82c16082f519af78e379a54b53fe9f4955da39d9455bfb123a423424823`

The first six add trusted authorization/pricing, dormant branches, checkout compatibility, grant recovery, cost exclusion and local-day contracts. The seventh adds catalog/inventory controls. No recovered baseline is applied to production and none of the nine existing migrations is replayed. The isolated CLI replay applied seven and then reported an empty second dry-run; five isolated suites subsequently passed. A first production dry-run launcher attempt failed because WSL shell parsing split a URL; history remained nine and no new branch/catalog tables appeared. Direct-exec correction passed. This failure is recorded rather than counted as success.

## Recovery and remaining gates

Use per-file transaction failure rollback where applicable. For already committed changes or later fractional stock/sales, stop and use reviewed forward recovery; do not restore permissive authorization/grants, narrow numeric quantities, delete histories or replay old migrations. Recoverable database backup is available, but restoring real customer records is an incident operation requiring a separate reviewed plan.

Implemented/tested: application persistence regression tests, POS network permission, candidate APKs, 105 SQL assertions, 54 staging HTTP checks, seven-file dry-run, current encrypted backup recovery. Implemented but not device-tested: in-place APK update/data-preservation path. Proposed/not applied: production seven-file execution, four Edge deployments and guarded timezone setting. Blocked: installed-device signature/ABI/pending-data confirmation. Deferred: branch activation/workflows, unrelated UI/KPI batches, public application release and independent offsite/Storage-object recovery. No production integration is claimed.
