# Batch 2 Checkpoint A restore report

8 October 2026, Africa/Lagos. **RESTORED AND MATCHING the recovered pre-Batch-2
application schema. Checkpoint A complete; stop before Checkpoint B.**

Production is unchanged. No production SQL was called during this checkpoint;
both project identities were verified through the connected project inventory.

## Approval and preflight

- Approved staging: `qysspzlfiysekvxnlzsh`, Trexven-Staging, ACTIVE_HEALTHY.
- Prohibited write/test target: `ufehcfrlygqvminfjumf`, Heaven-cc's Project.
- Approved baseline SHA-256 matches before and after restore:
  `5eb2ee5437911b21eab424a05abf21eb7cc7945bc805e5a41d58459e21b3e21e`.
- Read-only preflight: zero public/private application tables/views/sequences/
  foreign tables/functions; private schema absent; migration history empty;
  Auth users, Storage buckets/objects and application Realtime registrations zero;
  no Storage policies. Environment remained unchanged from the expected empty state.
- Reviewed baseline, drift report and migration sequence. Offline generator
  `--check` and baseline validator both exited 0.

## Restore execution

The connected Supabase `apply_migration` tool received explicit staging project_id
and name `trexven_pre_batch_2_baseline_checkpoint_a`. It returned
`{"success":true}`, `isError=false`. Connector tools do not expose a process exit
code; no shell exit code is invented for migration execution.

The approved file remained byte-for-byte unchanged. Execution supplied only its
documented guard setting immediately after BEGIN in the same transaction:
`SET LOCAL trexven.staging_project_ref = 'qysspzlfiysekvxnlzsh';`.
No other SQL-body changes, omitted statements or manual table edits were made.
The explicit connector reference verifies the target; the session setting alone
is not a trusted database identity check.

One bootstrap history record now exists: version `20261007235400`, name
`trexven_pre_batch_2_baseline_checkpoint_a`. The version is the tool-generated UTC
timestamp, not a local file rename. Nine historical production migrations were
not replayed or falsely recorded as executed in staging. The three Batch 2 files
are not applied. Future staging tracking must account for this later bootstrap
version rather than blindly pushing older file timestamps from the production link.

Restore errors: **none**. Recovery actions/reset/manual patches: **none**.
No reference seed, branch activation, Auth/customer records, Storage objects,
credentials or Edge deployment occurred.

## Catalog parity validation

Recovered source and post-restore staging catalogs were compared locally after
read-only extraction from staging. `compare_checkpoint_a.py` exited 0:
**30 comparison groups match; zero semantic mismatches.**

| Compared definitions | Result |
| --- | --- |
| 32 tables, ownership, RLS/force flags, replica identity and table settings | Match |
| 319 columns, ordinal/type/nullability/default/identity/collation/ACL attributes | Match |
| 115 constraints and 96 indexes, including 61 independent indexes | Match |
| 22 function bodies, signatures/returns, languages, owners, definer/search-path settings | Match |
| 108 policies, including two application Storage policies | Match |
| 8 triggers, enabled state and function links | Match |
| 7 Realtime registrations and existing publication settings | Match |
| Schema/table/function/column privileges, grantors/options and 6 default ACL records | Match |
| Auth references, managed helper signatures and external dependencies | Match |
| Application types/inheritance/rules/event triggers/custom operators/casts/statistics metadata | Match; absent where absent in source |
| Five required extension versions and schemas | Match; no extension installation/alteration |

Expected representational differences were investigated, not hidden:

- Catalog OIDs differ because objects are newly created. Comparison resolves them
  to qualified object/function/index names; column ordinals are still checked.
- ACL array order differs, but every privilege, grantor and grant option matches.
- Ten function definitions differ in CR/LF presentation. Parsed body/contract and
  settings match: private complete_pos_sale, complete_pos_sale_with_receipt and
  record_trexven_sale; public complete_trexven_onboarding, is_business_member,
  set_trexven_employee_status, update_businesses_updated_at,
  update_trexven_employee, update_updated_at and user_owns_business.
- PostgreSQL minor/platform version differs: recovered production 17.6, staging
  17.11. Managed dependency signatures and extension versions match; this is not
  an application-schema mismatch or proof of checkout runtime compatibility.
- Staging has one bootstrap history entry while source has nine incorporated
  historical entries. This is intentional provenance, not replayed history.

No managed Auth/Storage/Vault table, managed role, extension or publication settings
were recreated/altered. As explicitly present in the reviewed baseline, the two
TREXVEN-owned policies were attached to existing storage.objects and seven new
application tables registered with the existing supabase_realtime publication.
No buckets/objects were created; platform-owned supabase_admin defaults were
verified unchanged rather than modified.

Exact row-count SELECTs confirm all **32 application tables contain zero rows**.
Auth users, Storage buckets and Storage objects remain zero. Permissions is empty;
branch tables do not exist. These observations confirm no seed/import/test data
was introduced, not successful RLS or checkout behavior.

## Staging advisors — recorded, not automatically repaired

Security advisors returned 2 groups / 8 findings: 3 INFO findings for private
tables with RLS and no policies, and 5 WARN findings for authenticated execution
of public SECURITY DEFINER functions. The private ledgers intentionally deny direct
client access; protected RPC behavior still needs security tests. See
[RLS without policies](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)
and [definer execution](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).

Performance advisors returned 5 groups / 172 findings:

| Finding | Count | Level / reference |
| --- | ---: | --- |
| Unindexed foreign keys | 25 | INFO — [guidance](https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys) |
| Auth RLS initplan | 16 | WARN — [guidance](https://supabase.com/docs/guides/database/database-linter?lint=0003_auth_rls_initplan) |
| Unused indexes | 61 | INFO — [guidance](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index) |
| Multiple permissive policies | 61 | WARN — [guidance](https://supabase.com/docs/guides/database/database-linter?lint=0006_multiple_permissive_policies) |
| Duplicate indexes | 9 | WARN — [guidance](https://supabase.com/docs/guides/database/database-linter?lint=0009_duplicate_index) |

Unused-index findings on an empty database are not evidence of dead production
indexes. These and the previously documented price/default/MAINTAIN concerns are
preserved pre-Batch-2 issues, not restore mismatches. No cleanup or privilege change
was made beyond reproducing the approved baseline.

## Optional reference seed — separately reviewed, NOT applied

Seven definitions are copied from repository constants, not production records:

| Permission ID | Repository description |
| --- | --- |
| pos_access | Access Trexven POS |
| complete_sales | Process and complete transactions |
| add_products | Add new products to inventory |
| edit_products | Modify existing product details |
| view_inventory | View stock levels and reports |
| manage_employees | Add, edit, or suspend employees |
| view_camera_events | Access security camera feed and events |

Two proposed private bucket definitions: recordings and event-snapshots. Creating
them is separate from schema parity and is not needed to declare this restore
successful. Permission definitions alone do not grant employee authority;
view_camera_events remains owner-sensitive under Batch 2. Future approval may
separate permission initialization from bucket configuration. The current combined
seed must not be run without approval for both. Permissions/buckets remain empty.

## Evidence and boundary

Under `supabase/tests/baseline/`: `checkpoint_a_staging_catalog.json`,
`checkpoint_a_catalog_comparison.json`, `checkpoint_a_execution_results.json`,
security/performance advisor JSON and `compare_checkpoint_a.py` record results.
The approved SQL/hash and recovered source catalog are retained unchanged.

Checkpoint A establishes schema restore/parity only. SQL authorization suites,
real Auth/REST/RPC, price/branch bypass, checkout/idempotency/concurrency, timezone
and recovery tests remain NOT EXECUTED. Flutter and Edge regression suites were
not rerun in this schema-only checkpoint. Batch 2 is not fully accepted and
production deployment is not authorized.

**Stop here. Checkpoint B requires new user approval specifying reference seed,
three Batch 2 migrations and isolated test scope. No Edge deployment is implied.**
