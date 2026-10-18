# Current backup custody ? replacement verified on C

A later integrity check rejected the original D-drive encrypted backup (checksum mismatch), and 39 copied source files also failed comparison. The drive-D copies must not be used for deployment or recovery. No diagnosis of the physical drive or repair/format operation was attempted. Original repository source and production were not modified by this storage failure.

A replacement production dump was created read-only at 2026-10-09T05:51:52.975947+00:00 and fully restored into a fresh, unexposed local database. All 79 table fingerprints and all 30 application schema groups match; pg_dump and pg_restore returned 0. The clone database and its owned runtime files were removed. Encryption/decryption and the replacement encrypted-file checksum passed.

Retained encrypted archive: `C:\Users\USER\AppData\Roaming\TREXVEN\backups\ufehcfrlygqvminfjumf\20261009-5f220e743115415bb00699c4b30dcfd8\production.dump.dpapi`.

Plain archive SHA-256: `e73eda6ee33bc49392944b42e6f6cf7cfe6abab33fe6c58450387ed093a6d748`. Encrypted archive SHA-256: `d780083e12483367a5628a7b813984e9c36f330b9a0e52afcce40b6ba93086d0`. This copy requires the original Windows profile/DPAPI keys; Storage object bytes and independent offsite recovery remain outside its scope. The current sanitized [evidence](evidence/production_operational_backup.json) supersedes the earlier custody details below.

---

# Current status ? verified on retry

The protected passfile now authenticates. A full operational database backup and two isolated restores succeeded; all 79 table fingerprints and 30 application schema groups match. The encrypted backup remains outside the repositories. No production changes occurred. See [current recovery report](PRODUCTION_OPERATIONAL_BACKUP_RECOVERY_REPORT.md) and [sanitized evidence](evidence/production_operational_backup.json).

The attempts below are historical and superseded.

---

# Production backup/recovery prerequisite — 9 October 2026

## Current intended-passfile attempt

The user supplied `%APPDATA%\TREXVEN\secrets\pgpass.conf` as the intended credential source. It resolved to `C:\Users\USER\AppData\Roaming\TREXVEN\secrets\pgpass.conf`, exists, is owned by the Windows user, has inheritance disabled and grants FullControl only to that user. Its contents were not displayed or parsed for credential extraction. PostgreSQL used PGPASSFILE; the Linux client required an opaque temporary copy with directory mode 0700/file mode 0600. Copies were removed after both attempts; verified temporary directory count is zero. The original file was not modified.

The first verify-full attempt stopped because the operating-system CA list did not contain Supabase's root. The official public CA was obtained from the exact certificate URL in [Supabase's dashboard source](https://github.com/supabase/supabase/blob/master/apps/studio/hooks/custom-content/custom-content.json), `https://supabase-downloads.s3-ap-southeast-1.amazonaws.com/prod/ssl/prod-ca-2021.crt`. Certificate file SHA-256 is `700723581420dd1ac98fd7e9ac529f0ef210eadcaf87fc868a3ad7d114c2f3b7`. The client retained PGSSLMODE=verify-full and explicitly used that root certificate; no production SSL setting was changed.

The second attempt reached PostgreSQL authentication and was rejected. Exit code 2; sanitized category **database authentication rejected**. Raw connection errors were withheld. No production SQL was executed through this connection, no password was printed, and no customer/Auth data was exported.

The management connector independently reconfirmed Heaven-cc's Project and passed the read-only production preflight again. Alignment package hashes and linked identity also passed again. These do not substitute for a successful dump connection or a recoverable backup.

**Current blocker:** update the same protected passfile with the current PostgreSQL database credential matching `aws-1-eu-west-3.pooler.supabase.com:5432`, database `postgres`, user `postgres.ufehcfrlygqvminfjumf`, then confirm it is ready. Do not send the file contents, substitute an account password/API key, reset production or guess alternate credentials. A correction/confirmation was requested before another attempt.

**Backup prerequisite remains unsatisfied.** No operational archive was created, integrity-checked or restored in this attempt. The protected operational backup and isolated recovery check must execute after authentication succeeds; earlier synthetic recovery results are not claimed as this production backup's verification. Installed-client compatibility, authenticated Edge gateway acceptance and explicit seven-migration/Edge deployment approval remain pending. No migrations, Edge deployments, branch activation or app publishing occurred.

Evidence: [sanitized passfile connection result](evidence/production_backup_pgpass_connection.json). The older process-variable/transcript status below is historical and is superseded by this intended-passfile result.

---

## Earlier attempt — historical

Status: **BLOCKED — no production operational backup created or verified.** Production remains unchanged. No migration approval is requested while this safeguard remains unsatisfied.

Executed successfully in this request:

- Linked reference is `ufehcfrlygqvminfjumf`.
- Connector identity is Heaven-cc's Project, ACTIVE_HEALTHY, eu-west-3, PostgreSQL 17.6.1.155.
- The alignment package verifier passed: exact migration set, source SHA-256 and linked reference.
- The reviewed read-only production preflight passed: six catalog fingerprints, nine original history versions and manufacturer barcode/SKU preconditions.
- Supported provider backup listing returned zero backups, PITR false, WAL-G true and empty physical-backup metadata.
- PowerShell and its Python child independently found SUPABASE_DB_PASSWORD unset. Windows Process, User and Machine scopes were all unset. No password value was printed.

The user subsequently supplied a credential in the conversation. It was not copied into source or echoed. Automatic approval review rejected an attempt to retrieve it from the local current-conversation transcript as credential probing from an unintended source. That method was not retried or bypassed. No password-authenticated PostgreSQL connection, production dump, decrypt/restore operation or new recovery validation ran.

Smallest remaining access action: provide an intended protected credential source. Either make the existing SUPABASE_DB_PASSWORD available to the actual tool process (a separate terminal variable is not inherited by this already-running process), or provide only the path to an account-restricted PostgreSQL passfile/service configuration. Never send its contents in chat.

Verified session-pooler fields for a passfile are:

`aws-1-eu-west-3.pooler.supabase.com:5432:postgres:postgres.ufehcfrlygqvminfjumf:<existing password>`

The linked file contains the correct project-specific username and session port. Future verification must require production TLS and a read-only transaction; no local-test sslmode=disable may be reused for production. Passwords must stay out of command arguments, logs, source and evidence. Temporary private passfiles must be removed after use.

Once an approved source is accessible, the authorized next actions are read-only connection verification, protected operational pg_dump outside the repositories, archive/checksum verification and isolated non-adversarial recovery acceptance. Customer/Auth records must stay protected and must not be exposed in tool output or repurposed as adversarial fixtures. A schema-only file or management API access is not an operational recovery point. Existing synthetic restore tests establish earlier procedure evidence only; they do not verify a new production backup. Storage object bytes and external provider secrets require separate recovery coverage and cannot be assumed to be in a database dump.

Other deployment safeguards remain: installed/distributed Owner/POS compatibility or an approved coordinated replacement; valid-session acceptance for the reviewed Edge replacements with authenticated gateways retained true where applicable; separately reviewed Nigeria timezone mapping if included; and explicit approval of the seven migrations and Edge deployment. No applications are published, branches activated, stock redistributed or production settings changed.
