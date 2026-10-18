# Current backup custody ? replacement verified on C

A later integrity check rejected the original D-drive encrypted backup (checksum mismatch), and 39 copied source files also failed comparison. The drive-D copies must not be used for deployment or recovery. No diagnosis of the physical drive or repair/format operation was attempted. Original repository source and production were not modified by this storage failure.

A replacement production dump was created read-only at 2026-10-09T05:51:52.975947+00:00 and fully restored into a fresh, unexposed local database. All 79 table fingerprints and all 30 application schema groups match; pg_dump and pg_restore returned 0. The clone database and its owned runtime files were removed. Encryption/decryption and the replacement encrypted-file checksum passed.

Retained encrypted archive: `C:\Users\USER\AppData\Roaming\TREXVEN\backups\ufehcfrlygqvminfjumf\20261009-5f220e743115415bb00699c4b30dcfd8\production.dump.dpapi`.

Plain archive SHA-256: `e73eda6ee33bc49392944b42e6f6cf7cfe6abab33fe6c58450387ed093a6d748`. Encrypted archive SHA-256: `d780083e12483367a5628a7b813984e9c36f330b9a0e52afcce40b6ba93086d0`. This copy requires the original Windows profile/DPAPI keys; Storage object bytes and independent offsite recovery remain outside its scope. The current sanitized [evidence](evidence/production_operational_backup.json) supersedes the earlier custody details below.

---

# Production operational backup and recovery ? 9 October 2026

Status: **VERIFIED for local database recovery. No production deployment performed.**

Production identity is `ufehcfrlygqvminfjumf`, Heaven-cc's Project, eu-west-3, PostgreSQL 17.6.1.155. The linked reference, immutable alignment package and reviewed read-only production preflight passed. Nine historical migrations remain unchanged. PGPASSFILE authenticated successfully using the intended account-restricted Windows file, without displaying or extracting its contents. The client used `sslmode=verify-full` and the official Supabase CA. `pg_stat_ssl` reported false for the pooler's separate database connection; that is recorded separately from verified client-to-pooler TLS. No server TLS settings were changed.

## Executed results

| Check | Actual result |
|---|---|
| Passfile ACL | Current Windows user only; inheritance disabled |
| Protected backup directory | Current Windows user only; inheritance disabled |
| Package verification / production preflight | Passed / passed |
| pg_dump custom-format export | Exit 0; 615,549 bytes |
| pg_restore archive listing | Exit 0 |
| Full isolated restores | Two fresh local databases; both exit 0 |
| Snapshot data comparison | 79 of 79 table counts and whole-row hash fingerprints match |
| Application catalog comparison | 30 of 30 semantic groups match |
| DPAPI encryption/decryption | Successful; recovered SHA-256 matches original |
| Cleanup | Both restore databases dropped; dedicated local stack stopped and removed; plaintext dump and temporary passfiles removed |
| Production migrations / Edge deployments / settings writes | Zero |

Plain archive SHA-256: `cedf30404bbb9cbfcf943cbb4e2e758d8a04160def6a7184c8127bffa6283d4a`.
Encrypted archive SHA-256: `4f9901ea3b889400d5f1ebee612e522c42a712ddea6ebc0e282cc469c45bdc67`.

Retained archive: `D:\TREXVEN_Protected_Backups\ufehcfrlygqvminfjumf\20261009-ad81dc16bcb24eee9213bde3e316f536\production.dump.dpapi`.

Private manifests, snapshot fingerprints and diagnostics stay in that protected directory. Repository evidence contains no customer rows or credentials. No real-user login, checkout, migration, permission mutation or adversarial test was run on the restored customer data. The restore database was separate from the local runtime's default database and was never exposed through its Auth/REST services.

## Recovery procedure and scope

1. Use the original Windows account/profile and its DPAPI keys. Decrypt `production.dump.dpapi` with Windows `ProtectedData.Unprotect(..., CurrentUser)` into a new ACL-protected temporary file. Verify the original SHA-256 above before proceeding. The decrypt/hash check was actually executed twice. DPAPI encryption does not provide independent offsite or different-machine recovery; losing the profile/keys may make this copy unrecoverable.
2. Provision a fresh compatible Supabase PostgreSQL 17 environment with the standard managed roles and required extension binaries. The executed runtime used PostgreSQL `17.11.0.004-r1`; the source was 17.6. Create a fresh database from template0, owned by postgres. Verify local loopback, exact stack identity and unused database name first. Never point this drill at either hosted project.
3. Run PostgreSQL 17 `pg_restore --exit-on-error` into that fresh database as its local Supabase administrator, preserving object owners and ACLs. Do not use `--clean`, reset an existing database, or enable Auth/API workers against restored users. The two actual restores returned exit 0 without omitted archive objects or manual schema fixes.
4. Compare restored data to the retained snapshot fingerprints with timezone UTC. The source dump and fingerprints used the same exported repeatable-read, read-only snapshot. Compare the application catalog using qualified object identities rather than database-specific OIDs. Then remove only the dedicated restored database and runtime. A real incident restore requires separate authorization, target validation and a reviewed reconciliation of transactions occurring after the backup.

The catalog check covers 32 application tables, 319 columns, 115 constraints, 96 indexes, 22 functions, 108 policies, 8 triggers, 7 Realtime table registrations, grants, dependencies and related metadata. The initial constraint comparison flagged eight Auth foreign keys solely because the referenced index OID changed from 16504 to 21287. Definitions, referenced Auth table, validation and external dependencies matched. Raw comparison evidence is retained privately; normalization was corrected without altering any database.

The first dump attempt could not open the unmounted drive-D WSL path and produced zero archive bytes. The successful attempt streamed binary output directly into the protected Windows file handle. Authentication initially succeeded but a local verifier incorrectly asserted TLS on the pooler backend; this assertion was corrected to distinguish the client TLS check. Neither failure changed production.

This is a single-database logical backup, including application/Auth/Storage metadata and migration history. It does not archive Storage object bytes, Edge source/configuration, global role passwords, provider infrastructure or external encryption keys. Standard roles/extensions were supplied by the compatible local runtime. Vault data portability and Storage object recovery are not asserted. Provider backup listing previously showed zero available backups and PITR disabled; neither setting was changed.

## Remaining deployment gates

- Confirm actually installed/distributed Owner and POS builds, or approve a coordinated compatible replacement. Declared/local APK version 1.0.0+1 does not establish what users run.
- Complete valid-session acceptance of reviewed Edge replacements with authenticated gateway verification retained. No Edge function was deployed in this request.
- Approve the exact seven-migration rollout and any Edge deployment separately, including the coordinated client rollout and proposed business timezone configuration. Branch workflows remain dormant.
- Immediately before an approved rollout, repeat identity, package/hash, catalog/history and compatibility preflight and take a fresh protected backup if production has changed. This verified snapshot is not a rollback substitute for later transactions.

The database-backup prerequisite is now satisfied for the documented local recovery scope. It does not mean production integration or independent disaster recovery has been completed. Application source did not change, so Flutter suites were not rerun for this operational task.
