# Batch 3 synthetic disposable verification

These harnesses never accept a hosted target. Run from the Owner repository root.
They require Python 3, Windows PowerShell, WSL Ubuntu, the official verified
Supabase Linux CLI 2.120.0 native experimental stack, and PostgreSQL 17 native
runtime. Runtime binaries/account setup is external to source. Native stack
testing does not replace hosted Edge gateway or Android device acceptance.

1. Copy these six Python files and start_replay4.ps1 into ignored `.batch3-tools`.
2. Copy disposable_config.toml to `.batch3-tools/disposable/supabase/config.toml`.
3. Review the script's absolute checkout path and verified CLI location for your
   workstation. The recorded setup uses SUPABASE_HOME
   `/var/tmp/trexven-batch3-native` and a dedicated postgres process account
   `trexven-b2-pg`, not a hosted connection. Do not change the loopback/identity
   guards or use production credentials. Unset SUPABASE_DB_URL before testing.
4. Start a NEW EMPTY owned `trexven-batch3-replay4` stack with the script. Its private
   start4.log contains synthetic local keys and must stay ignored/private. Never
   publish this log. If that stack already exists, choose a new identity/ports
   and update matching guards deliberately; do not replay onto a used database.
5. Set `$env:BATCH3_REPLAY_RUN='4'`, run reconstruct.py once, then run_tests.py,
   concurrency.py, revocation_race.py and http_verify.py. All psql calls probe
   the local cluster plus native stack state identity and fixed loopback port.
   The local password placeholder `postgres` is synthetic native runtime only.
6. Inspect nonsecret evidence under docs/implementation/evidence. run_tests.py
   adapts only the old fixture's authenticated nonzero-stock insertion and the
   free-product setup to the new stock RPC; old authorization/receipt assertions
   are retained. It seeds seven reviewed permission names only, no storage seed.
   Each SQL suite rolls back. Concurrency/HTTP fixtures persist only locally.
7. Stop exactly this owned stack with `supabase --workdir <disposable workdir>
   stop --stack trexven-batch3-replay4 --output-format json` using the same
   SUPABASE_HOME. Do not use --all, hosted project refs or unsupported --runtime
   on stop. Remove the known private runtime log after preserving nonsecret
   results. Stop preserves synthetic local data; no hosted records are created.

Baseline SHA and the six immutable Batch 2 SHA checks are in reconstruct.py;
the reviewed Batch 3 SHA is recorded in its reconstruction evidence and reports.
The baseline staging-ref guard is substituted only in the executor copy after
local identity validation; the original recovered baseline file is unchanged.
No Supabase-managed platform schema is manually rebuilt and no migration-history
entry is forged. These are ordered SQL replays, not remote migration deploys.
