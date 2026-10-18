# Final production backend deployment — SUCCESS

Completed **9 October 2026, 21:36 UTC**. Production:
**ufehcfrlygqvminfjumf**, **Heaven-cc's Project**, eu-west-3, ACTIVE_HEALTHY.
The user's explicit authorization of the dormant camera subscription database
guard resolved the prior migration-12 conflict. No further approval was requested.

## Deployment result

- **16/16 migrations applied**, every process exit 0 and every commit verified.
  History now contains **32** entries in the exact expected chronological order.
  Frozen wrappers commit DDL and history together using an advisory lock and an
  exact predecessor-history check. No statement or dependency was skipped.
- **delete-account deployed**, CLI exit **0**, ACTIVE **version 4**, JWT verification
  enabled. Retrieved source matches the frozen reviewed source after line-ending
  normalization. It requests owner-reviewed account lifecycle action without
  deleting Auth users or financial records.
- **camera-ai preserved**, ACTIVE **version 7**, JWT verification enabled,
  bundle SHA-256
  `745ec69f76f9ab97fdf1824cd007b712c25c13fdfce5dfe2893830624d6fa0c8`.
  All seven other Edge Functions' complete before/after metadata are identical.
- **ODT Vision untouched**: no access or changes to its server, processing,
  pipelines, models, streaming, tracking or recording systems.
- **Camera guard installed and dormant**: `private.guard_subscription_camera()`
  and enabled `batch_7_camera_entitlements` trigger exist exactly as reviewed.
  No new business-subscription enrollments exist; all existing businesses pass
  `basic_vision` entitlement and plan camera limits remain unset. Existing camera
  data, policies, grants and original triggers remain unchanged. Dormant Vision
  feature metadata and read-only alert routing are retained.
- **Production data preserved**: **83 original tables**, same original columns
  before/after, **zero mismatches**. Original permission rows were compared
  separately from approved new reference permissions. History additions are
  expected and verified. These checks cover business, employee, product, stock,
  sale, receipt, Auth, subscription and camera records without printing them.
- Branches remain disabled; branch and assignment tables remain empty. Providers
  remain disabled, plan charging values and intervals remain unset, and lifecycle
  requests remain empty. No historical inventory was redistributed. No app
  builds, installation, publication or Google sign-in tests were performed.

## Backup and frozen-package safeguards

Linked database and management API project identities were rechecked before
writes. The intended `PGPASSFILE` connection used TLS **verify-full**; credential
contents were not inspected or printed. Fresh read-only preflight at
**21:27:13 UTC** confirmed the 16 expected predecessor versions, **zero schema
drift groups**, and **84/84** fingerprints matching the protected backup.

The DPAPI CurrentUser encrypted backup outside the repositories, protected by
USER-only access, remains the verified **pre-deployment recovery point**. Both
encrypted/decrypted checksums and prior isolated recovery evidence were checked:
restore exit **0**, **84/84** fingerprints matched, zero schema mismatch groups.
No refresh was necessary because production schema and data still matched before
deployment. Archive SHA-256:
`fe39bfd54d0c11a128e38a437408fdc11ebd64e5d93878eb2189d4f45faf6a48`.
Recovery requires the original Windows user profile and DPAPI key. External
provider secrets and the separate Vision infrastructure are outside that backup.

Original frozen `final_coordinated_20261009` manifest SHA-256 remains:
`9d7ed348a6b31a02200e9fe3ff6e93a11dcb14125d7c2b6fb6f22de31f8ea328`.
Package verifier exit **0** before and after deployment. No migration, hash,
dependency, frozen snapshot or preparation evidence was changed. The immutable
manifest's historical `production_applied: false` and Android gates describe its
preparation state; this separate execution evidence records subsequent approval
and deployment. Its verifier's `production_writes: 0` describes that read-only
verifier only.

## Exact migration sequence

| # | Version | Migration | Exit | Commit verified |
|---|---|---|---|---|
| 1 | 20261009070338 | batch_4_financial_operations | 0 | Yes |
| 2 | 20261009070340 | batch_4_offline_cash_reconciliation | 0 | Yes |
| 3 | 20261009075117 | batch_4_recovery_and_history | 0 | Yes |
| 4 | 20261009075318 | batch_5_inventory_operations | 0 | Yes |
| 5 | 20261009075612 | batch_5_inventory_review_controls | 0 | Yes |
| 6 | 20261009075911 | batch_6_shared_cash_drawers | 0 | Yes |
| 7 | 20261009080227 | batch_6_handover_and_access | 0 | Yes |
| 8 | 20261009080751 | batch_4_financial_audit_events | 0 | Yes |
| 9 | 20261009080842 | batch_5_dormant_transfer_foundation | 0 | Yes |
| 10 | 20261009081002 | batch_7_subscription_billing_foundation | 0 | Yes |
| 11 | 20261009081504 | batch_7_enforcement_and_operations | 0 | Yes |
| 12 | 20261009082051 | batch_7_verified_provider_and_entitlement_controls | 0 | Yes |
| 13 | 20261009082951 | batch_7_final_access_controls | 0 | Yes |
| 14 | 20261009122632 | batch_4_transaction_recovery_boundaries | 0 | Yes |
| 15 | 20261009135919 | batch_8_owner_payment_and_session_integration | 0 | Yes |
| 16 | 20261009184148 | batch_9_role_scoped_in_app_alerts | 0 | Yes |

SQL execution ran **21:31:16–21:32:42 UTC**. Preservation/dormancy verification
completed **21:33:01**, additional contract verification **21:34:59**, and final
Edge verification **21:36:36**. The sole Edge deployment command, run from the
frozen candidate directory, was:

```powershell
supabase functions deploy delete-account --project-ref ufehcfrlygqvminfjumf --use-api
```

## Post-deployment checks and errors

- **83 reviewed function contracts** match bodies, language, security settings,
  search paths and anonymous-execution restrictions. All 16 stored source literals
  match frozen wrapper contents after transport line-ending normalization.
- All application tables have RLS enabled; invalid application indexes: **0**.
  Direct branch writes and purchase-cost reads remain denied to authenticated
  clients. The camera guard cannot be called directly by client roles.
- Read-only anonymous lifecycle RPC call failed closed: SQLSTATE **42501**.
  Live missing-JWT and malformed-JWT deletion requests returned HTTP **401**.
  No production test users or lifecycle requests were created.
- **Migration errors: 0. Edge deployment errors: 0.** The supplementary local
  verification utility initially failed twice on the existing UTF-8 BOM, initially
  compared transport checksums incorrectly, and then had one read-only checksum
  query syntax failure. Explicit UTF-8 parsing and exact frozen embedded-source
  comparison with CRLF normalization corrected the verification utility. Its
  final exit was **0**; no production object or frozen file was manually altered
  to hide a difference. The first patch to replace the old report was rejected
  locally for using delete/add against one path; this separate report preserves
  the old blocked report as historical evidence instead.
- Genuine-user JWT authorization was previously exercised in isolated staging.
  No valid customer tokens or adversarial customer-data tests were used in main.
  Previously completed isolated SQL, Flutter and JWT suites were not rerun against
  production. Flutter analysis is not claimed clean. Android release/device and
  publication acceptance remain separate and were excluded by this directive.

## Recovery and remaining boundaries

Do not replay committed wrappers or fabricate history. Prefer a separately
reviewed forward fix preserving financial records, receipts and request keys;
do not drop new tables to undo an operational issue. Restoring the protected
backup returns to the pre-deployment schema and requires separate authorization,
writer coordination and reconciliation of later transactions. Do not revert
deletion handling to the legacy destructive endpoint.

This execution addendum supersedes the frozen gap matrix and migration plan's
pending-production status for these 16 migrations and the deletion endpoint.
Those documents remain immutable preparation snapshots. Provider activation,
real charging, branches, application distribution and device acceptance remain
outside this deployment. **No remaining blocker for the authorized backend scope.**

## Evidence

- [Fresh production preflight](evidence/final_backend_directive_preflight.json)
- [Per-migration commits and data preservation](evidence/final_backend_authorized_execution.json)
- [Read-only contracts and security](evidence/final_backend_readonly_postflight.json)
- [Edge source, JWT and preservation checks](evidence/final_backend_edge_verification.json)
- [Edge metadata before](evidence/final_backend_edges_before.json)
- [Edge metadata after](evidence/final_backend_edges_after.json)
- [Protected backup and isolated recovery](evidence/batch_9_production_backup_recovery.json)

Detailed catalog snapshots and data fingerprints remain private beside the
encrypted backup outside repositories. Public evidence contains no credentials
or customer records.
