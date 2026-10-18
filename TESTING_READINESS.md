# TREXVEN testing handoff — 4 October 2026

Scope: core Intelligence, shared Vision, backend wiring, Angel and infrastructure
needed for controlled testing. Commercial plans, billing, entitlements, release
updates and Google sign-in remain deferred.

## Canonical components

| Component | Working directory |
| --- | --- |
| TREXVEN Flutter application and Supabase definitions | `C:\Users\USER\AndroidStudioProjects\Trexven` |
| TREXVEN POS application | `C:\Users\USER\AndroidStudioProjects\trexvenpos` |
| Canonical Vision + Intelligence server | `C:\Users\USER\ODT-Vision` |

The `Trexven/vision` directory is an older implementation. Do not launch it for
this build. Run the server from `ODT-Vision` instead.

## Backend and integration changes

- Shared Vision already provides camera handoff, scoped app APIs, automatic AI
  Live selection, latest-frame capture, evidence recording, shared event history,
  POS/inventory reconciliation and owner corrections.
- Recent anonymous identities now recover from a local SQLite checkpoint after
  restart. Re-ID still requires plausible configured topology, sufficient image
  quality and an unambiguous appearance match. Cache TTL remains 300 seconds by
  default. Persistent event history does not imply indefinite identity matching.
- Employee access is enforced by role defaults and explicit permissions. Inactive
  employees are denied; camera control remains owner-only. Direct sales writes
  are revoked; validated, atomic sale RPCs manage stock and transactions.
- POS uses the real membership ID, `created_at`, `sku`, product active flags and
  `selling_price`. Unsupported separate pricing tables are no longer queried.
- Angel loads saved history, uses server-side conversation history, checks every
  persistence write, restricts context by permissions and uses exact sales
  aggregates for today/30 days. Other detailed context remains bounded samples.
  Groq is configured; the architecture audit observed deployed Angel version 10
  and left its source/provider unchanged.
- `camera-ai` now explains stored Intelligence evidence inside TREXVEN. This
  testing build does not send camera data or snapshots to an external model.
- Separate distributed request limiters cap Angel and camera explanations at
  20 per authenticated user per minute each.
- Vision has a separate bounded per-user request limiter: 10 connection probes
  and 2,400 app data/frame requests per minute. Probes require the owner.
- Notifications respect independent category toggles. Unsupported digest choices
  and the unconnected Angel microphone control are removed.
- Unmatched product observations can prepare a suggested sale for human review.
  Saving still requires explicit confirmation and the normal transactional sale
  path. Intelligence never decrements stock on its own.

Migration: `supabase/migrations/20261003224001_testing_readiness_access_controls.sql`.
The linked Supabase project remains `ufehcfrlygqvminfjumf`; these changes are
applied to that existing project. Do not use real customer data for destructive
acceptance scenarios such as deleting an account.

## Verification and installable builds

- TREXVEN Flutter regression suite: 34 tests passed.
- POS regression suite: 3 tests passed, covering signed-out UI, real backend row
  shapes, membership IDs and inactive-account handling.
- Canonical Vision regression suite after the architecture audit: 173 tests
  passed, including both physical-camera tests. One upstream test-client
  deprecation warning remains.
- Supabase transaction and readiness access suites passed in rolled-back
  transactions. These cover business isolation, sale/stock atomicity, overselling,
  permission boundaries, suspension, conversation privacy and request limits.
- Angel mocked-provider checks passed for grounded aggregates, restricted context,
  authentication, rate limits, persistence failures and conversation ownership.
  A real Groq request was not exercised by the architecture audit.
- A live Vision backup was created and verified after the backup process exited.
  Backup recovery, identity recovery and API rate-limit checks passed.

TREXVEN debug APK:
`C:\Users\USER\AndroidStudioProjects\Trexven\build\app\outputs\flutter-apk\app-debug.apk`.
POS debug APK:
`C:\Users\USER\AndroidStudioProjects\trexvenpos\build\app\outputs\flutter-apk\app-debug.apk`.
These are debug builds for controlled testing, not signed release packages.

## Start a controlled device-testing session

1. Run the canonical server in a terminal:

   ```powershell
   cd C:\Users\USER\ODT-Vision
   .\.venv\Scripts\python.exe -m uvicorn vision.server:app --host 0.0.0.0 --port 8000
   ```

2. Use the same trusted LAN for phone, Vision host and cameras. Pair the signed-in
   owner's business through TREXVEN → Me → Vision Server Settings. Use the host's
   LAN address and the existing Vision pairing key; keep the service-role key on
   the Vision machine only.
3. Register cameras, verify the live frame, and configure zones/topology through
   the owner-authorized Intelligence configuration API. See
   `C:\Users\USER\ODT-Vision\vision\SHARED_INTELLIGENCE.md` for request examples.
4. Use a dedicated test business with seeded products, employees and sales.
   Connect POS to the same business. Confirm role changes and suspension before
   exercising employee flows.
5. Run the acceptance scenarios after configuration: A → B → C handoff; delayed
   POS sale; ambiguous removal; returned product; employee handling; conflicting
   evidence; offline/reconnect; recordings/playback; event vs notification inbox;
   Angel persistence and grounded answers; role isolation; account deletion.

## Backup, recovery and rollback

The canonical server has verified `scripts/backup_vision.py` commands:

```powershell
.\.venv\Scripts\python.exe scripts/backup_vision.py backup
.\.venv\Scripts\python.exe scripts/backup_vision.py verify --folder <backup-folder>
.\.venv\Scripts\python.exe scripts/backup_vision.py restore --folder <backup-folder> --destination <new-data-directory>
```

Backups contain the consistent database and finalized evidence clips, with
SHA-256 checksums. Recovery refuses an existing destination and rewrites clip
paths for the recovered directory. Stop Vision before switching `DATABASE_PATH`
to a restored store. Protect backups as private business data and credentials.

For app rollback, retain the previous APK and reinstall that version. For Vision,
retain the previous source/dependency lock and database backup; stop workers
before switching versions. For Edge Functions, redeploy a reviewed prior source
version. Database rollback should be a reviewed forward migration; do not reset
the existing Supabase database. The private sale RPCs must remain in place while
clients lack direct sales-write privileges.

## Limits of this handoff

Core Intelligence V1 accepts known SKU observations from authenticated reports
or structured integrations. Stock YOLO classes do not establish SKU removal or
identify real employees. Evidence scores are heuristics, not probabilities.

Physical camera accuracy, store lighting, sustained load, network loss, paid
provider responses and full device journeys require the testing stage. Existing
automated checks are implementation verification, not launch certification.
Notifications currently require the app's active connection; terminated-app
push delivery is still unfinished. Public hosting/TLS, centralized crash
monitoring, production backup scheduling and recovery drills, capacity sizing,
and a launch deployment target remain infrastructure work before production.
The architecture audit prepared optional Admin delivery but did not configure an
Admin connection or build a dataset/training system. See the canonical server's
`vision/ARCHITECTURE.md`. This handoff does not claim launch infrastructure is finished.
