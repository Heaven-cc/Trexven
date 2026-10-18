# Batch 2 closure verification harnesses

These are the nonsecret harnesses actually used for final closure on 8 October 2026. They are executable provenance, not an instruction to deploy or reset a hosted project. Never point them at production or existing staging. Fixture credentials/status and the operational dump were removed after testing.

## Verified environment

- Windows PowerShell plus WSL Ubuntu, official Supabase CLI 2.120.0 Linux amd64 release, checksum checked against its official release checksum file.
- Native experimental stack runtime; PostgreSQL 17.11.0.004-r1 and the platform-managed Auth/Storage/Realtime schemas.
- Dedicated non-login WSL process account `trexven-b2-pg`. `SUPABASE_NATIVE_POSTGRES_USER=trexven-b2-pg`.
- `SUPABASE_HOME=/tmp/trexven-batch2-closure-native`; isolated unlinked workdir `.batch2-tools/disposable`, generated `supabase/config.toml` with `[experimental] stack = true`.
- Owned stack `trexven-batch2-closure`; executed identity `2d308235459edaa3b9677651ce39251abedc7cff860fea7ab71021e94e88063e`. API 127.0.0.1:54321, database 127.0.0.1:54322. No production credentials.

Supported native runtime documentation: [Supabase CLI local development](https://supabase.com/docs/guides/local-development/cli/getting-started). Use the exact release's `start --help`, `status --help` and `stop --help`; stack flags differ from older Docker-only releases.

## Reproduction prerequisites

Reprovision a **new owned free disposable stack**; the recorded stack is stopped. Inspect available port/disk space first. From the isolated workdir start with `start --stack trexven-batch2-closure --runtime native --exclude functions,studio,mail,analytics,pooler --eager`. Capture `status` JSON privately into `.batch2-tools/native_status_windows.json`; do not print tokens/passwords. The status structure contains `runtime`, `identity` and `env`. Verify the actual native identity, loopback DB/API endpoints and empty application/Auth/history state before any write. Do not link this workdir to either hosted project.

Copy the reviewed scripts from this directory into ignored `.batch2-tools` before execution from the Owner repository root; paths intentionally retain the actual executed layout. A fresh stack has a new ID: review/update only disposable executor identity checks in the copied harness, never the immutable baseline or applied migration files. `native_sql.py` permits only loopback port 54322, database names `postgres`, `trexven_b2_replay2`, `trexven_b2_restored`, `trexven_b2_schemaonly`, and local users postgres/supabase_admin. Match the native PostgreSQL tool path to the verified version. These guards do not replace proof that a database is newly owned and disposable.

## Actual sequence

1. `python .batch2-tools/adapt_baseline.py`: verify immutable pre-Batch-2 SHA and create executor copy with the verified disposable identity guard. Do not set the staging project reference on a local database.
2. `python .batch2-tools/native_sql.py .batch2-tools/disposable_baseline.sql`: restore only application schema into managed-platform-compatible empty target.
3. `python .batch2-tools/replay_migrations.py`: transactional application of all six source migrations with truthful history; the snapshot history row is not a claim of nine individual historical executions. The first run applied the day migration separately with its dedicated execution/history log; the second ran the entire ordered six-file harness.
4. `python .batch2-tools/run_disposable_suites.py`: extract only the reviewed base permissions INSERT from the optional seed; no Storage seed. Render/execute six rollback-only suites. Run the four older suites with `run_older_suites.py`.
5. `node .batch2-tools/native_http.cjs`: actual synthetic Auth/API/RPC cost and controlled-clock checks. This creates ignored fixture credentials and synthetic users; never use production tokens. It temporarily replaces the **local-only** clock function, then restores the exact approved server clock before parity/backup. `retry` uses the original local fixture; refresh test sessions locally when necessary. The test script's JSON includes every attempt, not just passing names.
6. Run POS `flutter test --dart-define=LIVE_RESTART_PHASE=before test/pending_sale_live_restart_test.dart`, then `after` in a separate process. The fixture requires exactly `http://127.0.0.1:54321`. The normal suite intentionally skips this explicit live test. Use `PENDING_RESTART_PHASE=before/after` for generic disk persistence tests.
7. `python .batch2-tools/atomic_recovery.py`: guarded local intentional failure/transaction rollback and corrected additive probe. Expected psql error is retained; committed row checksums must match afterward.
8. `python .batch2-tools/backup_native.py`: actual local custom-format dump and restore into a newly owned disposable restore database, local supabase_admin required for ownership. The script recreates only the named disposable restore database: inventory/approve ownership before invoking it. `verify_restored_receipt.py` replays the original saved request through authenticated RPC on the restored database.
9. `second_replay.py`: independently prepare a new database using managed-platform template, remove only its synthetic app/Auth/history content, restore fresh managed defaults, run baseline then all six source migrations. It must never target existing staging. Compare actual preflight and preserve every execution log.
10. `render_closure_checkpoint.py` creates the reviewed final schema-only checkpoint from catalog metadata; `restore_schemaonly.py` restores it into a new empty managed-compatible disposable database. This path imports no Auth/application records and does not invent migration history.
11. Capture read-only catalogs using `closure_catalog_queries.json`; `compare_native_semantic.py` resolves database-local relation OIDs and applies reviewed AST normalization from `compare_checkpoint_a.py`. Preserve raw and normalized comparisons, owners/grants/column order/settings/constraint validation.
12. Inventory exact synthetic business/user/child IDs, perform allowlisted cleanup, verify zero fixture rows/Auth sessions/helpers, remove fixture credentials/dump, and `stop --stack-id <verified-owned-id>`. Never use `stop --all` or a hosted reset. The actual final scoped cleanup and stop results are in the reports.

Full command results, failures and limits are in [clean replay](../../../docs/implementation/BATCH_2_CLEAN_MIGRATION_REPLAY.md), [backup recovery](../../../docs/implementation/BATCH_2_BACKUP_RECOVERY_RESULTS.md), [timezone results](../../../docs/implementation/BATCH_2_TIMEZONE_TEST_RESULTS.md) and [restart results](../../../docs/implementation/BATCH_2_OFFLINE_RESTART_TEST_RESULTS.md). No paid resources or production deployment are authorized by this README.
