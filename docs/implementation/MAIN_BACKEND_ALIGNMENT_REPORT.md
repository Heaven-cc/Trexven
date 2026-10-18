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

# Main backend alignment — 9 October 2026

The seven existing Batch 2/Batch 3 migration files are compatible with the actual main schema. No replacement database, new reconciliation migration, historical migration replay or migration-history repair is required. Production `ufehcfrlygqvminfjumf` remains unchanged and is not integrated yet.

The concrete release package is [supabase/releases/main_backend_alignment_20261009](../../supabase/releases/main_backend_alignment_20261009/README.md). It contains the exact seven-file order/checksums, all nine historical source checksums, a package verifier, and a read-only SQL preflight that already passed against production. It deliberately excludes the recovered baseline, staging seeds, platform schema reconstruction and branch activation.

| Contract | Main backend already supports | Missing changes |
|---|---|---|
| Business/identity | businesses, owner_id, employees, business_members, employee_permissions, Auth references, ownership/member helpers | Stronger trusted active-role/grant checks, explicit revocation, immutable administrative identities |
| Catalog | Existing products with retained IDs, SKU/barcode, selling price, quantity, units, active flags and thresholds | Backend field/price guards, optional groups/attributes, uniqueness indexes, pending null-price enforcement |
| Inventory | inventory/inventory_movements tables, existing global product stock | Reasoned atomic delta RPC, identity-bound request replay, movement/price history triggers and alert latches |
| Checkout | complete_pos_sale, record_trexven_sale, submit_trexven_sale; sale_requests, sales and sale_items | Reviewed trusted checkout checks, dormant compatible branch transition, fractional measured-unit processing |
| Receipts/retry | Existing request UUID and receipt identity/cached response contracts | Security/recovery refinements; public RPC arguments and existing identities remain compatible |
| Branches | No Batch 2 branch foundation installed | Dormant branch/assignment structures and nullable compatible identifiers; no activation/mapping |
| Reporting day | Existing timestamps and sales data | get_trexven_business_day, explicit business IANA timezone; Nigeria mapping remains proposed |
| Purchase cost | Historical cost column exists | Exclude it from current client/grant/audit exposure without deleting historical values |
| Auth/Edge | Existing login/staff/Angel functions and Auth users | Four reviewed replacement handlers, with retained authenticated gateway settings and acceptance |
| Subscriptions | No dedicated public subscription table was found | No subscription changes proposed; settings/business records retained |

Fresh metadata comparison matched all six recovered catalog sections exactly: structure, functions, security (RLS/policies/triggers), ACL/default grants, dependencies and platform references. There are 32 application tables, 22 application functions and 108 policies. The nine production migration version/name entries match the nine prior repository files. The baseline captures original application definitions that predate the incremental migration history; it is reconstruction input only, never a production restore.

Read-only index/unit preconditions found zero duplicate nonempty trimmed business barcodes, zero duplicate SKUs, zero fractional countable stock and zero negative stock. One existing zero-priced product remains valid. No customer/Auth/subscription records were exported or used as fixtures. The preflight fails on catalog/history drift or duplicate manufacturer identifiers rather than repairing data silently.

Actual alignment verification:

- Fifth new disposable: schema baseline plus all seven reviewed migration files replayed successfully; five SQL suites passed and concurrency passed.
- Sixth new disposable: reconstructed the matched original schema and restored only the nine verified history version/name metadata entries. Supported CLI dry-run listed exactly the seven pending files. CLI push applied only those seven and recorded their versions; final local history has 16 entries. Second dry-run was empty. Original migrations were not reexecuted.
- After the actual CLI push: 105 executed SQL assertions across five suites passed; 27 real local Auth/REST checks passed; twelve concurrent stock changes plus six same-key retries produced thirteen movements; in-flight revocation blocked until completion and then denied the next request.
- Initial CLI loopback attempt failed because the native proxy does not support TLS. The retry used sslmode=disable only for the fixed loopback test URL after verifying the unchanged nine-entry local history. Production TLS/settings were not altered. No staging manual repair hid a failure.

Owner/POS production URLs, explicit non-cost projections and narrowly scoped legacy-column fallback remain aligned. Current source requires Batch 2's business-day RPC and Batch 3's catalog write RPCs; it must be coordinated with all seven files. Existing integer checkout/offline request formats and membership/receipt/product IDs are preserved. Direct stock writes and SELECT-star including cost are intentionally incompatible with the tightened backend; installed/distributed old builds are unconfirmed, so current source compatibility alone cannot authorize rollout. No further Flutter changes were needed for the freshly unchanged schema. Final source suites already executed: Owner 75 passed; POS 45 passed plus one explicit live-backend skip; analysis Owner 208/POS 4 informational findings, zero errors/warnings, exit 1. These suites were not rerun in this alignment turn because application code did not change.

All six Batch 2 and the Batch 3 migration hashes remain unchanged. Existing businesses, Auth users, staff, products, stock, sales, receipts, timestamps and cost values are not overwritten by a baseline. New branches stay dormant; new catalog mutations fail closed when a business activates unfinished branch workflows. The package does not publish either Flutter application or deploy Edge Functions.

The smallest remaining access action is to make the **existing production PostgreSQL credential** available securely. The CLI is already linked to the correct main project and the pooler host is `aws-1-eu-west-3.pooler.supabase.com:5432`. No production DB password/connection or PG service/passfile is configured in the inspected secure locations. A process-only `SUPABASE_DB_PASSWORD` enables the linked CLI; a protected external PostgreSQL service/passfile or process-only `SUPABASE_DB_URL` can supply the read-only operational dump connection. Provide the location/variable name only. Do not paste, reset, rotate or generate credentials.

The supported backup listing still reports zero backups, PITR false and empty physical backup metadata. No recoverable production backup was created. Schema export, CLI/MCP access and synthetic restore drills do not substitute for one. [Supabase documents](https://supabase.com/docs/guides/platform/backups) supported logical backup and provider recovery methods, and notes that database backups do not include Storage object bytes. Any real dump must stay protected outside Git/chat/test fixtures, with recovery acceptance and separate Storage retention considered.

Remaining deployment gates after connection access: protected operational backup/recovery evidence; confirmed installed/distributed clients or approved coordinated replacement; valid-session acceptance for the four authenticated Edge replacements with gateway true where applicable; separate explicit approval of this concrete seven-migration/Edge rollout. The exact Nigeria timezone update is separately proposed and not applied. No production push or deployment occurred.

Evidence: [catalog parity](evidence/main_backend_alignment_parity.json), [actual CLI replay](evidence/main_alignment_cli_replay.json), [dry-run](evidence/main_alignment_cli_dry_run.log), [apply](evidence/main_alignment_cli_apply.log), [empty second dry-run](evidence/main_alignment_cli_second_dry_run.log), [SQL](evidence/main_alignment_batch_3_sql_results.json), [HTTP](evidence/main_alignment_http_results.json), [revocation](evidence/main_alignment_revocation_race.json). The versioned production files are the executable changes; the recovered baseline is excluded. Production integration can only be reported after approved application and resulting-backend verification.
