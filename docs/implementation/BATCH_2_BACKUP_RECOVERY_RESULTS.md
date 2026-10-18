<!-- BATCH_2_CLOSURE_STATUS -->
# Batch 2 backup and restore verification

8 October 2026 — final closure verification. **BATCH 2 — COMPLETE, STAGING VERIFIED.**

Two different recovery paths actually ran in the verified disposable environment. Neither changes production backup settings or proves hosted PITR readiness.

## Operational synthetic-data recovery

Supported PostgreSQL `pg_dump -Fc` created a complete local synthetic database archive. Final `pg_restore --exit-on-error` into the separately created `trexven_b2_restored` database exited 0 with ownership/grants preserved. The first restore using local non-superuser `postgres` failed because it could not SET ROLE supabase_admin; the failed restore log remains. The newly failed disposable restore database was recreated and restored using verified local `supabase_admin`; no hosted credentials were used.

Final restored counts: 10 synthetic Auth users, 4 synthetic businesses, 5 sales, 5 cached receipts, 7 truthful migration-history entries. Auth foreign keys remain compatible; cost-column authenticated SELECT remains false. The original live Flutter request replayed through the actual authenticated SQL RPC on the restored database, returning the same receipt with sale count, receipt count and stock checksum unchanged. API Auth login against the restored database was not tested; its API remained routed to the source database.

Archive SHA-256: `57be43f3977eb6825d18f58b25f6490666f2058e03b02543051db1e1f5362e33`. It contained synthetic Auth/application records, never production records. After restore verification, synthetic identities/rows were removed from source and restore databases and the exact archive was deleted. Do not describe a schema-only file as this operational backup.

Evidence: [backup execution](evidence/batch_2_closure_backup_results.json), [restored counts](evidence/batch_2_closure_restore_identity_final.log), [same-receipt replay](evidence/batch_2_closure_restored_receipt_replay.log), [initial failed restore](evidence/batch_2_closure_pg_restore.log), [final restore](evidence/batch_2_closure_pg_restore_final.log).

## Schema-only recovery

`supabase/tests/baseline/BATCH_2_CLOSURE_RECOVERY_CHECKPOINT.sql` SHA-256 `d5b246667730156bcdc5e903cc555f6b969a85cdfaa38b17c9a145529cefcca0` contains 1,675 statements, zero top-level data INSERTs, zero Auth user INSERTs, zero production references, and retains seven NOT VALID constraints. It does not reconstruct users, stock, receipts or migration history.

A guard-only disposable execution copy restored into `trexven_b2_schemaonly` (empty app/Auth, correct managed defaults) with exit 0. All 30 semantic catalog groups match staging, as do operational restore and both replay databases. [Actual schema restore](evidence/batch_2_closure_schemaonly_restore.log), [screening](evidence/batch_2_closure_recovery_screening.json), [parity](evidence/batch_2_closure_catalog_semantic_parity.json).

The renderer now explicitly renders reviewed non-cost column ACLs. Original pre-Batch-2 regeneration still yields the approved immutable hash; no original snapshot or four applied migration files were rewritten. No managed Auth/Storage/Vault infrastructure was recreated by the application checkpoint.

Intentional transactional migration failure and forward correction left committed synthetic sales/receipts/stock/history unchanged. This is the rehearsed recovery procedure. Production operational backup/PITR retention, restore credentials and restore targets still require separate production-specific review before rollout.

---

## Historical report — superseded by the closure update above

# Batch 2 backup and recovery results

8 October 2026. **BLOCKED: no disposable restore rehearsal executed.** Existing staging was not reset. Production backup settings were not read or changed; staging PITR/backup entitlement was not established.

## Recovery artifacts

A schema-only post-Batch-2 checkpoint is saved at ../../supabase/tests/baseline/BATCH_2_FINAL_RECOVERY_CHECKPOINT.sql.

SHA-256: 020aee18499cc5d392f023ae86d23377aa1a1649684068bf40903c996b5bdb46.

The checkpoint reproduces current application schema, constraints/indexes, function bodies/signatures/ownership/settings, triggers, RLS, policies, ACL/default grants and dependencies. It preserves seven NOT VALID constraints rather than falsely validating historical rows. Local parsing counted 1,610 statements, zero top-level INSERT statements, no Auth-user INSERT or JWT, and no production project reference.

The renderer now permits unvalidated constraints only with an explicit allow_unvalidated argument; its default still regenerates the immutable approved pre-Batch-2 baseline byte-for-byte. The first post-Batch-2 render stopped on its old all-validated assertion; the correction preserves the actual state instead of editing constraints.

Companion artifacts: batch_2_final_recovery_manifest.json (source hashes), batch_2_final_configuration_snapshot.json (11 trusted permission definitions and five actual migration-history names/versions), batch_2_final_start_catalog.json and batch_2_final_end_catalog.json (catalog metadata), batch_2_final_parity.json and batch_2_final_checkpoint_screening.json (checks). Deployment bundle hashes are recorded separately; database schema SQL cannot restore Edge deployments or secrets. Canonical source files and the pinned lockfile must accompany the hash record.

## What this proves

A reviewable schema reconstruction point exists and matches the accepted staged catalog. Test/application data are empty after cleanup. One actual aborted DDL transaction left no probe object. This is a schema recovery artifact, not an exercised full backup, PITR point, restored migration history, restored Auth database or proven recovery time.

The snapshot incorporates all four Batch 2 migrations: do not replay those migrations over it. Restore approved permission configuration separately, and record snapshot provenance truthfully instead of manufacturing migration execution entries.

Its current guard requires the verified staging executor setting and an empty application/Auth schema. It must never be applied over the existing populated staging schema. Before restoring into a separate approved disposable project, review/generate a target-specific guard-only adapter and record its new hash while preserving this archived source.

## Rehearsal and forward recovery

Use the separate empty disposable environment described in BATCH_2_CLEAN_MIGRATION_REPLAY.md. Verify managed infrastructure, restore schema/configuration without production Auth/customer/Storage records, compare catalog/history provenance, deploy the recorded staging function bundles where separately authorized, and run synthetic authorization/checkout tests. Measure restore duration and failure behavior there.

All four migrations contain transaction boundaries. After a failed migration, inspect rollback state and history, then reapply the corrected full failed step or an explicit versioned forward fix. Never use ad hoc patches to conceal failure. Preserve price guards, deny rows, membership IDs, receipts and request ledgers. A previously branch-active database must not be reverted to legacy global stock.

For production, an actual authorized backup covering application data and required Auth state is still essential; this data-free checkpoint cannot recover customer transactions. Review [Supabase backup scope](https://supabase.com/docs/guides/platform/backups), including separately managed resources, before any release proposal.
