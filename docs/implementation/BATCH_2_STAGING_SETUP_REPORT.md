# Batch 2 staging setup report

Checkpoint A update: staging baseline restored successfully, one bootstrap history
record, 30 catalog comparison groups match. All application/Auth/Storage data stays
empty; no reference seed, Batch 2 migration or Edge deploy. See
`BATCH_2_CHECKPOINT_A_RESTORE_REPORT.md`; older empty-state checkpoints below are
historical. Stop before Checkpoint B approval.

Recovery update, 8 October 2026: approved read-only schema recovery is complete.
The generated current-catalog baseline, drift report and ordered staging proposal
are available in `BATCH_2_BASELINE_RECOVERY_REPORT.md`,
`BATCH_2_SCHEMA_DRIFT_REPORT.md` and `BATCH_2_BASELINE_MIGRATION_SEQUENCE.md`.
Approval to apply is still pending; staging remains empty. Earlier checkpoint
statements below describe the situation before recovery approval.

Checkpoint: 8 October 2026 (Africa/Lagos). Staging identity verified; baseline
blocked. No database writes, migration application, synthetic data creation,
function deployment or production SQL was performed at this checkpoint.

## Verified target

The connected Supabase project inventory reports:

| Environment | Project reference | Database endpoint | Status |
| --- | --- | --- | --- |
| Trexven-Staging | `qysspzlfiysekvxnlzsh` | `db.qysspzlfiysekvxnlzsh.supabase.co` | ACTIVE_HEALTHY |
| Prohibited production target, Heaven-cc's Project | `ufehcfrlygqvminfjumf` | `db.ufehcfrlygqvminfjumf.supabase.co` | ACTIVE_HEALTHY |

References differ. Staging SQL was routed through the connector with the explicit
staging project_id, checked against the production denylist before invocation.
No CLI linked command was used: the Owner workspace's existing
`supabase/.temp/project-ref` still points to production and was left unchanged.
No production credentials, environment files or Auth/customer rows were loaded.
The connector provides staging SQL access without a database password; a raw
PostgreSQL connection and staging REST/Auth test configuration are not yet set up.
The endpoint above contains no credentials and is not a tested direct connection.

Read-only staging catalog checks returned PostgreSQL 17.11, database `postgres`,
role `postgres`, zero public/private application tables/views/functions, zero
Auth users and an empty migration history. Extensions: plpgsql 1.0,
pg_stat_statements 1.11, uuid-ossp 1.1, pgcrypto 1.3, supabase_vault 0.3.1.
Admin-role catalog inspection is not an authenticated RLS acceptance test.

## Documentation and baseline audit

All nine requested documents were found and inspected: both master specs in
Downloads, six Batch 2/gap/recovery documents in this directory, and
`supabase/tests/BATCH_2_ISOLATED_TESTING.md`. No requested document was missing.

The repository has nine pre-Batch-2 delta migrations and three Batch 2 migrations.
The earliest migration explicitly states the initial mature schema was never
captured. Staging lacks businesses/products/sales and their dependent objects;
neither historical deltas nor the Batch 2 fixture can create a faithful baseline.
No complete approved schema-only export was found in the inspected workspace.
The earlier audit records 29 public and 3 private production tables; it is an
inventory, not an executable schema snapshot. No fresh production drift check
has been performed here. Baseline fidelity is unverified, not assumed.

Section 4 of the user's staging request requires approval if reliable baseline
reconstruction is unavailable. A request is pending to authorize either a
read-only production schema/catalog export with all data/users/secrets excluded,
or an approved schema-only export supplied by the owner. No baseline is guessed.

## Proposed execution plan before migration application

1. Resolve approved baseline source. Review tables/types/sequences, defaults,
   constraints/indexes, RLS, table/column/default grants, functions/signatures,
   triggers, extension and Auth/Storage dependencies. Screen definitions for
   embedded secrets and omit data, Auth identities, Vault values and secret configs.
2. Decide whether the approved export represents the original schema plus deltas
   or the current pre-Batch-2 schema. Never replay already incorporated deltas
   blindly. Record source/version/checksums and differences before importing.
3. Construct staging baseline only after review, verify catalog parity and empty
   business/Auth data, record migration history without fabricating application
   results, and establish an exact-target synthetic-only environment marker.
4. Configure a separate staging-only execution path. Existing loopback runner
   rejects remote hosts; do not weaken it to accept arbitrary connections. Pin
   `qysspzlfiysekvxnlzsh`, reject production identifiers in every runner, verify
   connection identity, isolate credentials from inherited production variables,
   and never print secrets. Use explicit project targets, not the production link.
5. Apply the three Batch 2 files in order using tracked migrations, record results
   and checksums, stop on any failure. Correct defects locally and rehearse against
   a fresh verified isolated baseline; never conceal failures with table edits.
6. Execute four SQL suites and relevant existing suites with synthetic users and
   actual authenticated/anon roles. Run real Auth/PostgREST/RPC, last-stock/retry/
   revocation concurrency, timezone/DST, constraints/indexes and recovery checks.
7. Proposed staging Edge verification: deploy only create-employee, manage-employee,
   canonical employee-login and Angel after explicit staging deployment authorization.
   Use staging-only secrets; reject employee/forged-business requests before any
   external AI operation. Do not copy production AI keys. Without a staging provider
   key, distinguish authorization tests from successful AI response integration.
8. Rerun both Flutter suites/analysis and Edge tests, update all acceptance reports.
   No Batch 3, UI redesign, client release, real branch activation or production
   mutation is included.

## Tooling prerequisites

CLI 2.113.0 and its db/dump help were inspected. psql, Docker, Podman and Deno
remain unavailable on PATH. MCP staging metadata access works, but the psql suites
contain includes/bind commands and cannot be sent unmodified as SQL. A reviewed
adapter or dedicated staging connection/client is needed; concurrent integration
requires independently controlled sessions. No infrastructure was installed.

Staging is 17.11 while the earlier production audit reported 17.6. Review restore
compatibility, including relevant extensions/operators, against the
[Supabase minor-release notes](https://supabase.com/changelog/postgres-15-19-17-11-breaking-changes).
Do not run data scans or upgrade production as part of this task.
