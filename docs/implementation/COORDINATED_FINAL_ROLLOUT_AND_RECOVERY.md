# Coordinated final rollout and recovery

**Preparation only. Production execution is not authorized.** Main target is
`ufehcfrlygqvminfjumf`; staging is `qysspzlfiysekvxnlzsh`. Never restore the
pre-Batch-2 baseline or staging database over production.

The [manifest](../../supabase/releases/final_coordinated_20261009/manifest.json)
defines sixteen pending migrations in exact chronological order, two reviewed
Edges with JWT verification enabled, frozen Owner/POS/shared source and evidence.
`manifest.sha256` identifies this source candidate. Android artifact fields are
currently null; this is not a complete installable release.

## Before approval

1. Obtain adequate safe C scratch space (at least 8 GB requested). Build both
   Android candidates from the frozen sources and resolved dependencies. Use
   established package IDs/signing identities. Determine installed version codes
   on the actual devices before choosing an increment; do not infer them from
   `pubspec.yaml` or old APKs. Do not publish.
2. Verify startup/auth, business selection, navigation, scanner, online checkout,
   offline cash, pending recovery and an in-place update retaining secure keys
   and queues. Never uninstall or clear data to make this test pass. Resolve or
   retain each original pending operation before changing its actor/context.
3. Add exact new APK hashes/package/signer/version evidence; freeze a new complete
   manifest. Re-run `python supabase/releases/final_coordinated_20261009/verify_package.py`.
   Any changed source/migration invalidates its corresponding test evidence.
4. Recheck main identity, expected sixteen history entries, catalog and protected
   backup freshness using read-only access. The reviewed credential source is
   `%APPDATA%\TREXVEN\secrets\pgpass.conf`; use PostgreSQL `PGPASSFILE`, official
   CA and `sslmode=verify-full`. Never pass a password in command text/logs.
5. If production rows/schema changed, refresh the protected archive and repeat
   isolated recovery. Freeze the new recovery evidence. Present one approval
   request identifying the exact final manifest SHA and outstanding accepted risks.

## After explicit approval of that exact candidate

1. Repeat package/identity/history/backup checks immediately before writing.
   Stop on unexpected drift, history, archive integrity or target mismatch.
2. Use a controlled maintenance window and retain device journals and queues.
   Do not rely on unverified old test-app compatibility; arrange compatible
   in-place updates with their owners. No branch/provider activation is included.
3. Execute only the manifest's `guarded_execution` SQL files, in listed order,
   via the fixed main-project PostgreSQL connection. Each file keeps the reviewed
   migration and its history insertion in one transaction, takes the release
   advisory lock and checks the exact preceding history before DDL. Require
   `psql -X -w -v ON_ERROR_STOP=1`; never continue after failure. These generated
   guards and chronological execution were replayed in isolation. Do not also
   execute their canonical counterparts or use an indiscriminate database push.
4. Verify all thirty-two history versions, expected catalog/functions/grants/RLS,
   valid indexes and compatibility signatures. Compare existing rows to the
   preflight snapshot using protected fingerprints rather than logging records.
   Distinguish explicitly approved reference additions/new nullable fields from
   any unexpected existing-field changes. No historical sale/receipt rewrite is
   included. Halt the rollout on unexplained differences.
5. Deploy only `camera-ai` and `delete-account` from the frozen package with
   `verify_jwt = true`. The supported CLI command shape, reviewed using help, is
   `supabase functions deploy camera-ai delete-account --project-ref ufehcfrlygqvminfjumf --use-api`
   from the frozen candidate directory. Never omit function names, disable JWT,
   prune unrelated functions, or deploy unreviewed Admin/ingest/provider code.
6. Retrieve deployed source/metadata and confirm both intended hashes and JWT
   settings. Verify safe read-only production contracts. No adversarial tests,
   synthetic financial records or real charging against production.
7. Perform the previously verified compatible test-app in-place updates and
   inspect retained pending operations before allowing new payments. App
   installation is distinct from publication; neither app is publicly released.

## Recovery boundaries

An individual failed migration rolls back its own schema changes and history
entry. Earlier committed migrations remain applied: record the exact stopped
version, pause affected new workflows, keep all ledgers/receipts/journals and
prepare a reviewed forward correction. Do not drop populated tables, restore
permissive RLS, replay completed receipts, clear queues or reverse genuine money
movements as a generic rollback. Keep billing providers and branch flags disabled.

The non-destructive deletion Edge must not be reverted to the legacy destructive
endpoint as a recovery shortcut. Notifications may be disabled by hiding their
entry points/revoking reviewed RPC execution while retaining acknowledgements.
The new Owner numeric RPC and integer wrapper must remain compatible with
retained operation payloads; do not rename arguments during recovery.

The protected archive is outside both repositories, encrypted with Windows DPAPI
CurrentUser and USER-only ACL. Recovery requires the original Windows profile
and DPAPI keys. Decrypt only in memory, verify plaintext/encrypted hashes, list
the PostgreSQL archive and restore into an owned API-unexposed isolated database
using Supabase-compatible platform prerequisites/roles. The successful rehearsal
matched schema and all 84 table fingerprints and removed its recovery database.
Production restore is a separately approved operation requiring reconciliation
of transactions occurring after the snapshot. This database archive does not
back up Edge secrets, platform settings or an independent offsite recovery copy.
At the verified snapshot Storage objects and Vault secrets were empty; recheck
those dependencies if that changes.
