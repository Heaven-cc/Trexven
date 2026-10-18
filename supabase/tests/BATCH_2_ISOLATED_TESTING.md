# Batch 2 isolated testing

Checkpoint B update: real staging verification has now run against the restored
schema. Five new rollback suites (73 checks), four older suites, real synthetic
Auth/REST and concurrency passed with documented limitations. See
docs/implementation/BATCH_2_DATABASE_TEST_RESULTS.md. The original loopback
runner remains unchanged; prepare_batch_2_staging.py renders psql commands for
an independently verified MCP executor targeting qysspzlfiysekvxnlzsh only.
checkpoint_b_rest.cjs pins that staging URL and uses ignored synthetic credentials
and a staging publishable key. Its setup expects separately prepared synthetic
Auth fixtures and no service-role key. Concurrency additionally requires temporary
owner-only hold/readiness helpers; these were removed after verification, as were
all synthetic records and local credentials. Do not run it against production or
reuse production configuration. The older blocked notes below are historical.

No database tests ran during this batch. Local PostgreSQL/psql, Docker/Podman and Deno were unavailable; no isolated Supabase database was configured. The database test runner exited 1 with a BLOCKED message before connecting anywhere.

The repository's original schema predates its delta migrations. An empty Supabase project cannot be assumed to reproduce it. Provision a separate PostgreSQL 17/Supabase environment, reconstruct a reviewed schema-only baseline without production records/secrets, compare baseline definitions to the audit, and rehearse existing migrations before the three Batch 2 migrations. Baseline reconstruction and application have not been performed here.

In that isolated database only, explicitly create a private marker table:

```sql
create table private.batch_2_test_environment(marker text primary key);
insert into private.batch_2_test_environment values('TREXVEN_SYNTHETIC_ONLY');
```

Set `BATCH_2_ISOLATED_DSN` to a dedicated loopback PostgreSQL URI and run `python supabase/tests/run_batch_2_isolated.py`. The runner rejects remote hosts, production project identifiers, DSN query overrides and a missing marker; it never loads project environment files, links or credentials. It does not install/apply migrations. Keep test credentials out of committed files and terminal output. Do not forward production through a local tunnel or create the marker on production.

Each new SQL suite includes `batch_2_fixture.sql`, creates only synthetic `.invalid` identities/businesses, switches between real database roles and synthetic JWT subject claims, asserts allow/deny behavior, and rolls everything back. The branch suite deliberately activates a synthetic business to exercise branch stock and request replay; that is not an activation or allocation procedure for real businesses.

The harness requires the actual Auth schema, existing functions, constraints, grants, RLS and triggers. It is not a minimal substitute schema. Run the existing backend transaction, readiness, sale submission and camera-limit SQL suites in the same isolated environment after the new suites. Existing SQL suites do not themselves carry the new marker guard: execute them only with the verified isolated connection, never production.

Additional acceptance still required: actual Supabase REST upsert/bulk/RPC tests; Deno type/runtime tests; concurrent stock/retry/revocation/branch-activation sessions; stale JWT and business-local midnight/DST cases; migration replay/drift/advisors; backup restore and forward-recovery rehearsal. SQL roles/claims do not substitute for a real authenticated HTTP integration test.

Static SQL validation: install workspace-local `pglast==8.5` into `.batch2-tools`, then run `python supabase/tests/batch_2_static_check.py`. This parses statements, SQL function bodies, PL/pgSQL and DO blocks. It does not resolve actual database types, columns, constraints, grants, RLS, function execution or PostgREST behavior. A syntax pass is not a database security pass.

Node 22 mock/helper tests run entirely with synthetic clients and no external network:

```text
node --experimental-strip-types --test supabase/tests/batch_2_edge_helpers_test.mts
node supabase/tests/create_employee_test.cjs
node supabase/tests/manage_employee_test.cjs
node supabase/tests/angel_test.cjs
node supabase/tests/camera_native_test.cjs
```

The Owner source is canonical for employee-login. POS keeps a byte-identical deployment mirror plus its permission helper; the Node mirror test detects divergence. Deploy only the canonical shared-project function after separate production authorization, never two independently diverging copies.
