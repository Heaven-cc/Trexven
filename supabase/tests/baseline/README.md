# Recovered TREXVEN pre-Batch-2 baseline — review only

Checkpoint A update: the approved baseline hash was restored to staging
`qysspzlfiysekvxnlzsh` and catalog parity verified (30 groups, no semantic mismatch).
See `docs/implementation/BATCH_2_CHECKPOINT_A_RESTORE_REPORT.md` in the Owner root.
The original SQL/header are retained unchanged to preserve the approved hash;
their review-only comments describe the recovery checkpoint, not current restore
status. The reference seed and Batch 2 migrations remain unapplied.

Recovered 8 October 2026 through approved, read-only Supabase catalog access.
No artifact here has been applied to a database. No customer/Auth rows or secrets
were exported. This is the current production application structure before Batch 2,
not an invented reconstruction of its undocumented historical initial state.

Files:

- `TREXVEN_PRE_BATCH_2_BASELINE.sql`: schema-only application reconstruction.
- `recovered_catalog.json`: definitions, source ownership/ACL grantors and dependency metadata.
- `metadata_queries.sql`: reproducible read-only extraction queries; no connection settings.
- `migration_history_metadata.json`: recorded migration SQL, not application table data.
- `staging_prerequisites.json`: read-only managed staging dependency inspection.
- `build_baseline.py`: deterministic offline renderer; `--check` detects output changes.
- `validate_baseline.py`: local syntax/coverage/body/security checks and history comparison.
- `validation_and_drift.json`: counts, hashes and normalized comparison findings.
- `TREXVEN_STAGING_REFERENCE_SEED.sql`: separate proposed staging config from
  repository-defined permissions/private bucket constants; NOT production-exported rows.

Validation commands make no database connection:

```text
python supabase/tests/baseline/build_baseline.py --check
python supabase/tests/baseline/validate_baseline.py
```

The validators use workspace-local pglast 8.5 for syntax only. Restore/catalog parity,
real RLS/RPC/REST and concurrency remain untested. Do not deploy this baseline to
production or place it in the existing production-linked migration directory.

After separate approval, an executor must independently verify project
`qysspzlfiysekvxnlzsh`, reject production and other references, confirm empty staging,
and supply `trexven.staging_project_ref` in the same transaction as the baseline.
The SQL guard rejects a missing/mismatched setting or a populated application/Auth
schema. The setting is a procedural guard, not proof of database identity; connector
project identity/explicit targeting is mandatory. Never use the existing linked CLI
workspace or rely on a previous tool call's session setting.

Managed Supabase Auth/Storage/Vault schemas and roles are prerequisites, not dumped.
Auth foreign keys reference staging's own `auth.users`; its users are never copied.
Required extensions already match staging. Platform-owned supabase_admin default
grants are checked instead of altered because staging postgres cannot assume that
role. Application grants and postgres defaults are rendered; source grantors remain
in metadata. No Vault secrets, JWT settings, passwords, webhooks, scheduled jobs,
Storage objects/bucket rows, API keys or environment files are copied into baseline SQL.

The schema preserves the pre-Batch-2 security gaps deliberately so the later migrations
can be tested against a faithful starting point. Restrict staging access during the
baseline-to-migration window. A schema snapshot contains no permissions rows; the
separate reference seed restores the seven repository-defined IDs and private bucket
definitions without replaying historical DDL. Batch 2 migration 1 adds its own four
permission definitions. Do not infer defaults/prices/branch assignments from rows.

Proposed order: fresh managed staging -> recovered schema -> reviewed reference
seed -> three Batch 2 migrations -> synthetic fixtures/security tests. Historical
deltas are already incorporated in the snapshot and must not be replayed. Preserve
their coverage as provenance; do not falsely mark nine migrations as executed in
staging. An isolated migration set is required before any future tracked application.
# Checkpoint B current status

8 October 2026: seven permission definitions only were initialized through
CHECKPOINT_B_PERMISSION_DEFINITIONS.sql; the combined optional seed was NOT run
and no buckets were created. The three migrations plus versioned security
recovery were applied and verified in staging. Evidence is checkpoint_b_*.json;
reports are under docs/implementation. All synthetic records/Auth users/test
helpers were removed. The approved baseline SQL is unchanged; its earlier review
status/header and Checkpoint A notes are historical. Production remains unchanged.

