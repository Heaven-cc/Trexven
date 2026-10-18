# Production deployment executed — 9 October 2026

The [execution report](PRODUCTION_DEPLOYMENT_EXECUTION_REPORT.md) supersedes earlier undeployed/approval-blocked status below. Under the user's final explicit authorization, all seven migrations committed (CLI exit 0, history now 16); Batch 2 and Batch 3 are DEPLOYED. Reviewed Edge Functions are DEPLOYED: employee-login v6 (JWT false), create-employee v7, manage-employee v4 and angel v12 (JWT true). Retrieved sources match the frozen package; unrelated functions remain unchanged. Main backend integration for the approved scope is COMPLETE.

All original values across 78 existing non-history tables were preserved. Four canonical permission reference rows were added exactly as approved; the original seven permission rows are unchanged. Postflight verified 39 reviewed functions, RLS/grants/catalog, valid indexes and dormant empty branches. The protected C pre-deployment backup passed immediate checksum/freshness checks; no refresh was required. The timezone remains unset per explicit exclusion, so daily-sales flows need a separate clock configuration decision. No apps were installed/published, no local data cleared, no branches activated and no production synthetic records created. Device verification was explicitly waived for this backend execution and remains an app-update limitation.

---

# Current final compatibility status — 9 October 2026

This section supersedes earlier readiness statements below. The [final coordinated plan](FINAL_COMPATIBILITY_AND_COORDINATED_DEPLOYMENT_PLAN.md) records exact evidence, changes, migration order and deployment gates. Owner tests: 75 passed; POS: 47 passed + 1 explicit skip; Deno: 9 passed; isolated SQL: 105 assertions across five passing suites; staging JWT: 54/54 checks. Analysis exits 1 with 208 Owner / 4 POS informational findings and no errors/warnings. Both ARM64 debug candidate APKs built at actual 1.0.0+2 and match previous local artifact signing identities; installed-device identity remains unverified.

Production's unchanged main schema and exact seven pending files passed read-only preflight/dry-run. The original D backup failed a later checksum and is rejected. A protected replacement on C passed fresh full recovery (79 table fingerprints, 30 schema groups), DPAPI encryption/decryption and latest unchanged-data verification. Same-profile recovery and Storage-object/offsite limits are documented. This replaces earlier credential/backup/JWT blockers; do not use the older D copy.

Remaining: connect actual test installations to verify signature/ABI/version and resolve/preserve pending requests/drafts, then obtain explicit approval for the seven migrations and four reviewed Edge Functions. Guarded Africa/Lagos configuration requires its own explicit inclusion. No production write, branch activation, app installation/publication or production Edge deployment occurred. Unsynced persisted POS requests must survive in-place replacement; uninstall/data clear is not approved. Owner in-memory drafts must be resolved before restart.

---

# Batch 2 final deployment manifest — review only — 9 October 2026

Status: BLOCKED; no deployment command is authorized. Only future approved production target: `ufehcfrlygqvminfjumf`. `qysspzlfiysekvxnlzsh` is excluded. Verify account/project name/region/ref and secure database hostname before every future write. Abort on baseline/migration/catalog hash drift, unexpected installed clients or missing backup.

Required gates: protected operational production backup with recovery acceptance; actual installed/distributed Owner/POS inventory and compatible frozen client candidate; authenticated Edge gateway smoke acceptance plan; approved timezone mapping; owner-authorized change window and separate explicit deployment approval. Quiescing writers, restoring a customer backup or rolling back production also needs authorization, not assumed here.

Exact migration order (only these six deltas, not the recovered baseline or staging bootstrap/reference seed):

1. `20261007215736_batch_2_authorization_price_enforcement.sql` — SHA-256 `55a69cd97eb1fbbd2a034467e9cda93d5551c7fcd415f6ea4d778f53d2a1b8e7`
2. `20261007215743_batch_2_branch_assignment_foundation.sql` — SHA-256 `2537fb48a9c7fc77088a30f2158f917d45bed39126d670fff3d5dfed4358f34a`
3. `20261007215831_batch_2_branch_checkout_compatibility.sql` — SHA-256 `86feacc6be132aedb1a2999500a633e9a433f41c0965dbb7bb51a2f931278283`
4. `20261008002119_batch_2_staging_security_recovery.sql` — SHA-256 `4f9a93633d401ad9e66b55870e5720c1081c0151408e2d31f8b082303fdb0ca3`
5. `20261008020234_batch_2_purchase_cost_contract.sql` — SHA-256 `497f6cccce70b51454747d29b5ea61b49e89d00f8f549dc2d3ac9d2bbcbae61b`
6. `20261008021428_batch_2_business_day_contract.sql` — SHA-256 `26003a9e8d16241a47140c48fca7422381aed607f6d948d73c949025a38a37aa`

The recovered baseline checksum remains `5eb2ee5437911b21eab424a05abf21eb7cc7945bc805e5a41d58459e21b3e21e`. It is evidence/reconstruction input only. Never replay the nine historical migrations blindly onto production. Do not import Auth users/customer data or alter platform schemas/buckets/reference seed.

Reviewed Edge replacement bundle hashes and currently deployed versions:

| Slug | Current production | Proposed gateway | Reviewed staging EZBR SHA-256 |
|---|---|---|---|
| employee-login | v4, false | false | ada78e17bf947d7e7f4a7670c20ae1c5fb675f39b327fe5e9cba35a5645712eb |
| create-employee | v5, true | true | 8e2046bfe1598e7548f8d5488ca0e424c1091e57cd1fdadb5417a68b43843e81 |
| manage-employee | v2, true | true | 5fe9748e171487768b45ff79d6fd54107b28159a5ac2adec3525f1970aa1017c |
| angel | v10, true | true | 5e3efa10ecd998ff59af3755ee0fa3ffd7820671c3e44aa1033c54082d6c046e |

The hashes identify the reviewed staging provider EZBR bundles; exact corresponding local source-file hashes were reverified and are recorded in evidence/batch_2_final_deployment_manifest_20261009.json. They are not promised hashes or versions of a future production deployment. Recompute source/bundle hashes and stop on differences. Record the actual returned versions after a separately approved deployment. Keep existing production bundle sources protected for recovery; do not expose service-role keys. Do not replace camera-ai/camera-ingest/camera-worker-ingest/delete-account in this batch.

After migration 6, a separately approved conditional update may map only business `7de5d490-6883-45d5-b3fd-e9b85b3832bc`, country Nigeria, to Africa/Lagos. No historical timestamp rewrite. No branch activation, stock redistribution, subscription changes or arbitrary product pricing.

Client coordination: current local APK hashes/versions are recorded in the preparation update, but installed/distributed versions are unknown. Current source contains Batch 3 writes, so choose a reviewed frozen Batch-2-only client or explicitly coordinate Batch 2 plus the separately approved Batch 3 migration/client release. Do not release current source against only Batch 2 and assume catalog writes work.

Batch 3 is a SEPARATE production change: `20261009003200_batch_3_catalog_inventory_foundation.sql`, SHA-256 `1045d82c16082f519af78e379a54b53fe9f4955da39d9455bfb123a423424823`. Its isolated tests do not authorize deployment. Its compatibility/forward-recovery constraints are in BATCH_3_PRODUCTION_SCHEMA_COMPATIBILITY.md and MIGRATION_AND_ROLLBACK_PLAN.md. The final local source hash inventory is recorded separately; application release builds/signatures/distribution are pending.

Acceptance after future approved execution: record each exact migration/function result; repeat identity and schema/grant/policy checks; genuine authorized user/role JWT smoke checks with gateway true; permission revocation; owner-only access; existing receipt/idempotency replay with approved non-adversarial procedure; non-cost explicit product projections and business-local day boundary. Synthetic/adversarial tests remain outside production.

Recovery: rollback the currently uncommitted transaction on failure; committed security/data changes require a reviewed forward fix. Do not restore permissive grants or integer-only sale logic. Operational restore is a last-resort separately approved procedure using the protected backup, preserving transaction/request/receipt identities and reconciling writes after backup. No production backup exists yet, so this manifest cannot be executed safely.

Main-backend alignment update: see [MAIN_BACKEND_ALIGNMENT_REPORT.md](MAIN_BACKEND_ALIGNMENT_REPORT.md) and the guarded release package in supabase/releases/main_backend_alignment_20261009. Fresh live metadata matches all six baseline sections; the supported CLI applied exactly seven pending files to a new disposable with nine original history metadata entries, recorded history 16 and returned an empty second dry-run. Post-push 105 SQL assertions and 27 local HTTP checks passed. No production history repair, baseline restore or additional Flutter fix is required. Production backup, client/Edge acceptance and explicit approval gates remain pending.
