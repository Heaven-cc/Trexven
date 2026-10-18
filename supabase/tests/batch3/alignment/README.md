# Exact main-schema and CLI history alignment replay

Run from the Owner root using the prerequisites in ../README.md. Copy these
helpers to ignored .batch3-tools, and the parent run_tests.py/concurrency.py there.
Copy the parent disposable_config.toml to the documented disposable config path.
Start a NEW EMPTY owned trexven-batch3-replay6 native stack with start_replay6.ps1.
Private start6.log contains only local synthetic keys and must remain ignored.
Set BATCH3_REPLAY_RUN=6. Run cli_alignment_replay.py, then run_tests.py,
concurrency.py, alignment_http.py and alignment_revocation.py.

The CLI helper requires a pristine application schema, restores the schema-only
baseline, copies only nine verified production migration version/name metadata
entries and pushes seven pending files using a hardcoded synthetic loopback URL.
It requires actual supported supabase.cmd, then verifies a second empty dry-run
and all 16 local history entries. --resume-prepared is only for a failed dry-run
on this same prepared local copy with exactly the original nine entries intact;
it refuses a copy where any new migration already committed.

sslmode=disable is ONLY for the native loopback test proxy. Never use that setting
against production. The executor also rejects SUPABASE_DB_URL and checks the native
state name, loopback port and cluster identity before SQL. It cannot be pointed
at a hosted DB. No customer records, Auth rows, passwords or subscription data
are imported. New test users use example.invalid addresses and synthetic passwords.

Stop exactly replay6 through the supported named-stack stop command and remove
only its known private startup log after preserving nonsecret evidence. Starting
a previously used stack does not make it pristine: choose new guards/ports/name
deliberately instead of resetting a shared or production database.
