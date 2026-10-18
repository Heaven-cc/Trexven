# Batch 2 baseline recovery report

8 October 2026, Africa/Lagos. Recovery complete for review; restore untested.
Production and staging remain unchanged. The user's latest instruction prohibits
baseline/Batch 2 application until this concrete result is approved.

## Recovered artifact

`supabase/tests/baseline/TREXVEN_PRE_BATCH_2_BASELINE.sql` is a deterministic,
transactional schema-only reconstruction of the current pre-Batch-2 TREXVEN schema.
It is not the lost chronological initial schema. Its nine deployed historical
deltas are already incorporated. SHA-256:

`5eb2ee5437911b21eab424a05abf21eb7cc7945bc805e5a41d58459e21b3e21e`

| Captured definition | Count |
| --- | ---: |
| Application tables: public / private | 29 / 3 |
| Columns / NOT NULL attributes / default expressions | 319 / 192 / 126 |
| Constraints | 115 |
| Indexes, including constraint-backed indexes | 96 |
| Non-constraint CREATE INDEX statements | 61 |
| Application functions/RPCs | 22 |
| RLS-enabled application tables | 32 |
| Application policies / related Storage policies | 106 / 2 |
| Non-internal application triggers | 8 |
| Realtime application registrations | 7 |
| Schema ACLs / table ACLs / function ACLs / default ACL records | 2 / 32 / 22 / 6 |
| Auth foreign-key references | 8 |

No custom application types/domains/enums, sequences, partitions/inheritance,
views, foreign tables, custom operators/casts/collations/aggregates, custom event
triggers, extended statistics, column ACLs or unusual column storage settings were
found. No Auth-side application trigger was found. Two camera tables retain
REPLICA IDENTITY FULL. All recorded indexes are valid/ready and constraints validated.
Counts are catalog observations, not a restore or security-test pass.

Source metadata and source grantor identities are retained in
`recovered_catalog.json`; a generator and read-only query file make reconstruction
reproducible. Migration SQL metadata and local file hashes support drift comparison.
Extraction used explicit production project_id `ufehcfrlygqvminfjumf` only for
approved metadata SELECTs, wrapped in READ ONLY transactions. No application,
Auth-user, Storage-object or secret-bearing data table was queried for records.
No server-side files, OS commands, tests or production DDL were executed.

Catalog extraction required multiple read-only calls. A final repeat capture of
structure, functions, security, ACLs, extras, dependencies and history matched
the initial capture. This detects observed changes during export; it is not one
shared cross-call MVCC snapshot. Recapture if deployment changes before rehearsal.

## Target and dependencies

The connected inventory again identifies healthy staging `qysspzlfiysekvxnlzsh`
as distinct from production. Read-only staging inspection confirms PostgreSQL
17.11 and zero application tables/functions. Production reports 17.6.
Staging migration history was previously empty; no writes followed that checkpoint.

Staging supplies Auth users.id uuid, email and raw_user_meta_data, auth.uid()/jwt()/
role(), Storage objects/buckets and folder/filename/extension helpers, required
roles, public schema ownership and the managed supabase_realtime publication.
Do not rebuild managed schemas or export managed identities. The five extension
names/versions/schemas match: plpgsql 1.0 in pg_catalog; pg_stat_statements 1.11,
uuid-ossp 1.1 and pgcrypto 1.3 in extensions; supabase_vault 0.3.1 in vault.
Vault contents were not queried/exported.

The staging postgres role cannot assume supabase_admin. Its three platform-owned
public default ACLs already match production; the baseline checks them rather
than issuing unauthorized ALTER DEFAULT PRIVILEGES. It restores application
effective grants and postgres-owned defaults; managed platform role grants are
prerequisites. The original grantor metadata is retained for catalog reconciliation.

## Data and secret review

The baseline has no top-level INSERT/UPDATE/DELETE/COPY/TRUNCATE, no role/password
creation, and no DROP. DML inside unchanged RPC bodies defines future behavior;
it does not copy or execute production records. The Auth guard reads only an
existence condition when a future approved staging import runs.

Automated screening of recovered catalogs, recorded migration SQL and baseline
found no production reference, URLs/credential DSNs, email literals, JWTs, recognized
API-key prefixes, hardcoded UUID literals or literal password/token assignments.
Function/default/policy review found no embedded production endpoints or secret
configuration. Names such as encrypted_password in Auth dependency metadata are
column definitions, not password values. No production environment file/API key
was read. Pattern checks alone cannot certify arbitrary secret formats; scope and
manual definition review complement them.

No business/user/products/sales/request receipts or bucket/object rows were copied.
The separate `TREXVEN_STAGING_REFERENCE_SEED.sql` is a proposed configuration seed
from existing repository constants (seven permission definitions and two private
buckets). It is not included in the schema-only baseline and is not applied.

## Validation actually performed

- Offline deterministic regeneration: exit 0, output matches reviewed SQL/hash.
- Baseline validator: exit 0; 1,690 statements, 12 PL/pgSQL function bodies,
  10 SQL function bodies and 3 guard blocks parsed; coverage/body contracts and
  secret screening passed.
- Existing Batch 2 static check: exit 0; 8 files, 21 PL/pgSQL functions,
  9 SQL bodies and 5 DO blocks parsed. No database tests executed.
- Read-only production/staging metadata calls returned isError=false after one
  ACL query cast was corrected (`char` versus PostgreSQL internal `"char"`).
  Initial local generation failed on a string OID comparison; the validator initially
  failed to join recorded statements lacking terminators. Both were corrected and
  the final commands above passed. No staging edits concealed these failures.

No schema restore, migrations, SQL suites, real REST/RPC, concurrent tests, Edge
deployment, Flutter rerun or production security acceptance occurred in recovery.
See `BATCH_2_SCHEMA_DRIFT_REPORT.md` and `BATCH_2_BASELINE_MIGRATION_SEQUENCE.md`
for drift, proposed execution order and approval requirements.
