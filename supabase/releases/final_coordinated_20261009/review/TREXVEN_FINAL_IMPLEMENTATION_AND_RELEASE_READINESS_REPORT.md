# TREXVEN final implementation and release readiness report

9 October 2026. **Local/staging implementation and source candidate verified;
production release readiness is blocked by final Android build/device checks.**
No new production migration, Edge replacement, charging, branch activation or
application publication was executed. The deployed Batch 2/3 foundation remains
intact. This report supersedes the earlier Batch 4–7 source-only QA status.

## Implementation completed and exercised

Batch 8 integrates the existing Owner and POS architecture with the combined
backend: trusted POS sessions and business selection; owner-only business
selection; shared confirmed cash/bank/card/split payment input; fractional Owner
quantities; retained original request/payment recovery; actual subscription
display; compact secondary KPI variants with hero preservation; role-scoped POS
Home/Sales/Inventory/More navigation; employee permission review using trusted
database definitions; own profile/password/appearance; and role-filtered in-app
notifications with personal read/unread and authorized destinations.

Previously incomplete integration was repaired: POS uncertain checkout no longer
opens a new payment dialog; cached/offline access is bound to the original signed
identity/scope and used only for transport failure; manager defaults do not grant
sensitive permissions; Owner permission screens no longer show hardcoded grants;
payment confirmation fits a narrow viewport at large text scale; late business
profile responses cannot overwrite a newer selection; and cached/in-flight
notifications are hidden when the authenticated account changes.

The existing Batch 4 financial/recovery ledgers, Batch 5 inventory/count/condition
workflows, Batch 6 shared drawers and Batch 7 entitlement/billing foundations are
retained and now exercised in isolated PostgreSQL/staging tests. Multiple
employees share one drawer as approved. No purchase-cost feature, arbitrary
selling price, zero-price conversion, historical branch assignment, subscription
enrollment or provider activation was introduced.

Account deletion is a **reviewed request**, not automatic deletion. Its revised
UI/RPC/Edge retains Auth users and business/financial records. The legacy
production `delete-account` endpoint has not yet received that replacement.

## Exact validation results

| Executed check | Actual result |
| --- | --- |
| Owner `flutter test --no-pub` | **85 passed**, zero skipped, exit **0** |
| POS `flutter test --no-pub --concurrency=1` | **76 passed, 1 skipped**, exit **0** |
| Separate POS actual-RPC persisted restart, before/after in distinct processes | **1 passed each**, both exit **0**; original request/receipt, one retry dispatch, stock 5 → 4 once |
| Owner `flutter analyze --no-pub` | **0 errors, 0 warnings, 253 informational findings**, exit **1** |
| POS `flutter analyze --no-pub` | **0 errors, 0 warnings, 65 informational findings**, exit **1** |
| Node reviewed Edge/helper tests | **38 passed, 0 failed**, exit **0** |
| Deno billing-provider verification helper | **10 passed, 0 failed**, exit **0** |
| Fresh isolated baseline replay | Reviewed pre-Batch-2 baseline + **23 Batch 2–9 migrations**, every step exit **0** |
| Guarded pending release execution | **16** migrations with atomic history insertion; final simulated history **32**, exit **0**; unexpected history rejected before DDL, negative-test exit **0** |
| Rollback SQL suites | **13 suites** passed, every exit **0**: Batch 2 authorization/branches/prices/checkout, Batch 3 catalog/variants/barcodes/decimal stock/zero-price compatibility, plus finance, offline cash, transaction recovery, inventory, shared drawer, subscriptions, Owner/session integration, notifications |
| Local financial concurrency | 8 identical-key clients → 1 receipt/payment; 8 clients competing for 1 stock → 1 committed sale/7 rejections; no negative stock; revoked permission denied |
| Genuine JWT native handler tests | Passed using actual Auth/PostgREST; this alone does not prove hosted gateway behavior |
| Hosted staging gateway/Edge JWT/RLS tests | Passed: missing/malformed/tampered/anon JWT rejected, forged IDs and revoked grants denied; Owner lifecycle request idempotent and non-destructive |
| Staging notifications | Passed with a strict allowlist of the known synthetic fixtures; all test writes rolled back |
| Protected backup recovery and freshness | Restore exit **0**, zero schema mismatch groups, **84/84** table fingerprints match; latest read-only freshness check has zero changed tables |
| Final Android APK builds / actual device update | **Not executed / blocked**, not a pass |

The routine POS skip requires the dedicated live-restart flags; the separate
two-process supplement actually executed it. Host file persistence and actual
database idempotency do **not** prove Android keystore or in-place update safety.
Selected Dart formatting completed successfully. Current analysis is not clean;
the informational findings include deprecations and style findings.

Exact parsed counts, log hashes and failure disposition are in
[application evidence](evidence/batch_9_final_application_results.json).
[Replay evidence](evidence/batch_9_native_replay_results.json),
[concurrency evidence](evidence/batch_9_concurrency_results.json) and
[hosted JWT evidence](evidence/batch_9_staging_edge_gateway_results.json)
describe the executable checks and their practical limits. These are synthetic
test environments; no customer records or production credentials were used for
adversarial testing.

## Failures investigated and resolved

- The first final POS full run failed copying a generated kernel with OS error
  112 (disk full). It was interrupted; only unused, verified generated test
  directories were removed. The subsequent sequential complete run passed.
- Native bootstrap needed application-dependent Storage policies excluded from
  platform prerequisites, reviewed managed default grants, and migration
  ownership matching the original `postgres` contracts. Fresh reconstruction
  succeeded; failed attempts were not hidden by altering production/staging data.
- The first backup restore role could not set `supabase_admin`; only the isolated
  recovery role was corrected. A fresh protected snapshot was then restored and
  fully compared successfully.
- Runtime replay exposed the shared cash alias conflict, an Owner numeric RPC
  signature/quantity compatibility issue, and notifications referencing a
  nonexistent inventory-review timestamp. These were corrected in still-pending
  Batch 8/9 candidates and replayed. Missing/NULL notification application now
  fails closed. The staging forward rehearsal correction is recorded separately.
- A new widget-test harness initially stalled in fake asynchronous Auth startup.
  The real SDK initialization was moved into the test's real asynchronous scope;
  both cached and in-flight account-change regressions subsequently passed.
- Package creation initially could not compare POS against a usable Git HEAD.
  Its inventory now honestly records that unavailable comparison and freezes
  every included source path/hash. It does not invent a POS diff or initialize Git.
- Extending prior-batch SQL regressions exposed two test-conversion defects:
  multiline psql variables and a JSON text ID compared with an injected UUID cast.
  Only the compiler was corrected; original assertions were preserved. The final
  immutable test compilation and fresh replay passed all thirteen suites. Failed
  local attempts are retained in logs; disposable replay cleanup is now automatic.

## Security and production state

Main `ufehcfrlygqvminfjumf` is **Heaven-cc's Project**, ACTIVE_HEALTHY; staging
`qysspzlfiysekvxnlzsh` is **Trexven-Staging**, ACTIVE_HEALTHY. Main connection is
bound to its linked ref, reviewed pooler host/user and `PGPASSFILE` with TLS
`verify-full`. Read-only preflight confirms exactly the expected **16** existing
migration-history entries and the legacy checkout signature. None of the new
sixteen migrations has been applied to production by this work.

Server access derives from current trusted membership/owner identity, not
editable JWT metadata or client permission objects. Executed tests cover
cross-business access, role-sensitive operations, missing authorization,
permission revocation and payment/receipt replay. The reviewed two Edges are
ACTIVE on staging with `verify_jwt=true`; they remain pending for production.
Retrieved staging sources match the reviewed local files after newline
normalization. Staging has 27 rehearsal-history entries, intentionally different
from main: its baseline/B2 checkpoint timestamps and three forward rehearsal
corrections are retained (`owner_payment_variable_correction`,
`owner_numeric_quantity_compatibility`, `notifications_null_contract_fix`).
Those fixes are folded into the still-unapplied final Batch 8/9 source candidates;
main retains its own sixteen deployed versions. No staging history is copied to
main. [Exact staging source/history evidence](evidence/batch_9_staging_source_and_history.json)
records these differences rather than concealing them.

Staging security advisors report **9 INFO** entries for deliberately policy-free
private RLS tables, **67 WARN** entries for authenticated callable security-definer
RPCs, and **1 WARN** for leaked-password protection disabled; zero ERROR entries.
The privileged RPC warning is retained, with explicit identity/permission checks
and restricted execution reviewed; it is not suppressed or described as clean.
Password protection remains a platform configuration review before public
launch. No platform settings were changed. The executed checks identified no
remaining critical/high defect in their covered contracts; they are not a
certification of untested devices or unavailable external services.

Five synthetic Auth users/two synthetic businesses remain in cloud staging for
the hosted Edge audit. They are labelled synthetic, use `example.invalid`, and
contain no production customer/Storage data. Immutable audit relationships are
preserved rather than deleted to make the environment appear empty. Fresh local
replay uses a separate API-unexposed database and verifies emptiness explicitly.

## Backup and recovery

The protected operational snapshot was taken **2026-10-09 14:40:50 UTC**.
Encrypted archive SHA-256:
`fe39bfd54d0c11a128e38a437408fdc11ebd64e5d93878eb2189d4f45faf6a48`.
It is outside the repositories, USER-only ACL, encrypted using Windows DPAPI
CurrentUser. Decrypt/hash/archive listing and isolated restore succeeded.
Schema matched and all **84** table fingerprints matched; the recovery database
was removed. The latest freshness check at **19:37:52 UTC** found no schema or
table changes. No refresh was needed at that check; recheck immediately before
deployment. Do not treat this as permanently fresh or independent offsite recovery.

[Backup evidence](evidence/batch_9_production_backup_recovery.json) and
[freshness evidence](evidence/batch_9_backup_freshness.json) contain sanitized
metadata. Recovery requires the original Windows profile/DPAPI keys. At the
snapshot Storage objects and Vault secrets were empty; platform settings, Edge
secrets and future Storage blobs require separate recovery coverage. Automated
server-side/offsite backups are not established merely by this operational backup.

## Frozen coordinated candidate

[Manifest](../../supabase/releases/final_coordinated_20261009/manifest.json) and
its adjacent `manifest.sha256` freeze the exact source candidate. The verifier
passed: the sixteen deployed predecessor file hashes and fourteen original
Batch 4–7 candidate hashes are unchanged; all sixteen pending migration hashes
match successful replay. The candidate contains frozen Owner/POS/shared source,
test sources, resolved Flutter dependencies, Android source/configuration,
two reviewed Edges/lockfile and sanitized evidence. It contains no database
archive, passfile, customer records, signing key or generated token fixture.
Current-source Android artifacts are explicitly absent, not mislabelled old APKs.

Exact paths/hashes are in `manifest.files`; combined source-change inventory is
`source_change_inventory.json`. Principal integration files are:

- Owner: `lib/core/user_provider.dart`, `lib/services/database_service.dart`,
  `lib/screens/main_screen.dart`, dashboard/Record Sale/Me/permissions/employee
  details/notifications screens, `lib/widgets/stat_card.dart`, and related tests.
- POS: Auth/session/permission/offline context, checkout/pending recovery,
  four-tab home/More/settings/theme integration and relevant repository/tests.
- Shared: `packages/trexven_operations/lib/src/metric_content.dart`,
  `payment_confirmation_dialog.dart`, `employee_access_screen.dart`,
  `notification_center_screen.dart`, existing operation/financial/inventory/cash/
  billing clients and retained encrypted journal contracts.

Migration order is the original fourteen candidates, unchanged, followed by:

1. `20261009135919_batch_8_owner_payment_and_session_integration.sql`
2. `20261009184148_batch_9_role_scoped_in_app_alerts.sql`

The late Batch 4 recovery migration stays after its Batch 6/7 dependencies.
Production must not receive the reconstructed baseline. The exact ascending
sixteen-file order and generated per-migration history guards are in the manifest.
Only `camera-ai` and non-destructive `delete-account` are pending Edge replacements.
Employee-login/create/manage/Angel deployed Batch 2/3 sources are not redeployed
indiscriminately. See the [rollout/recovery procedure](COORDINATED_FINAL_ROLLOUT_AND_RECOVERY.md).

## Genuine remaining gates

1. **Build capacity:** after safe cleanup/final tests C has approximately 1.3 GB
   free. At least 8 GB of safe C scratch space has been requested; the rejected
   D drive remains unused. Current APK builds are not claimed as executed.
2. **Device:** ADB lists zero devices. Need a connected test device/emulator to
   verify actual installed package/version/signer, startup/OAuth/scanner, offline
   secure-key retention and lossless in-place update with pending transactions.
   Uninstall/reinstall is not a safe substitute. Old debug artifacts are inspected
   evidence only, not this candidate or proof of installed versions.
3. **External configuration:** live Google redirect/device sign-in, actual Vision/
   Angel providers, optional push and automated/offsite backup service are not
   verified here. Billing commercial values/provider and lawful account purge
   automation remain unconfigured. No fabricated AI/provider/charging success.
4. **Final authorization:** after build/device gates and agreed external release
   scope are resolved, refresh preflight/backup evidence, freeze artifact hashes
   and request one explicit production approval. This source candidate is not
   authorization to write production.

Batch 8's described integrations are implemented/tested. Batch 9's executable
local/staging checks passed after the documented fixes; its Android/live-service
checks remain blocked. Batch 4–9 is **prepared but not deployed**. A complete
public release or all-master-features operational status is **not claimed**.
