# Historical blocked deployment report — superseded

The camera guard conflict was explicitly authorized and the deployment completed
successfully. Current result: **16/16 migrations applied; delete-account v4;
camera-ai v7 preserved; camera guard dormant; original production data preserved.**
See [the authorized deployment completion report](FINAL_BACKEND_AUTHORIZED_DEPLOYMENT_REPORT.md)
and its execution evidence. The prior blocked report below is retained for history.

Directive: `cbb55dc2-3391-4456-9fd2-1cdb47fbacb6/Pasted text.txt`.
Target verified: **ufehcfrlygqvminfjumf**, Heaven-cc's Project, ACTIVE_HEALTHY.
Staging verified separately: **qysspzlfiysekvxnlzsh**, Trexven-Staging.

## Executed safeguards

- Frozen `final_coordinated_20261009` manifest SHA-256 verified:
  `9d7ed348a6b31a02200e9fe3ff6e93a11dcb14125d7c2b6fb6f22de31f8ea328`.
  Package verifier exit 0; deployed predecessor files, all sixteen candidate
  hashes and generated chronological history guards match. No frozen file edited.
- Secure linked production connection verified with intended `PGPASSFILE`,
  USER-only protected ACL and TLS `verify-full`. Password contents not inspected
  or printed. Project identity and exactly sixteen existing history versions match.
- Read-only schema comparison found zero drift groups. The protected operational
  archive's encrypted/decrypted checksums and prior successful isolated restore
  evidence remain valid. At **2026-10-09 21:14:52 UTC**, all 84 table fingerprints
  remain unchanged from the backup. No refresh was necessary.
- Execution resources are available for backend SQL: approximately 1.3 GB free
  on C and the existing local PostgreSQL client. Android scratch/build/device
  checks are excluded by this directive and are not deployment blockers here.
- Read all pending migration contents relevant to destructive/Vision changes.
  No baseline restore, production reset or historical transaction rewrite was
  attempted. Read/unread deletion in the notification function is confined to
  the authenticated user's acknowledgement; it is not a migration-time customer
  data deletion.

## Unavoidable conflict in the frozen candidate

Migration 12,
`20261009082051_batch_7_verified_provider_and_entitlement_controls.sql`, lines
51–62, creates `private.guard_subscription_camera()`, revokes its client execution,
and installs `batch_7_camera_entitlements` BEFORE INSERT OR UPDATE on existing
`public.cameras`. It changes the camera database authorization path even though
subscriptions remain unenforced by default and no camera rows are rewritten.
That directly conflicts with the directive's restriction against Vision migrations
and changes to existing Vision configuration. It is not required merely to preserve
the currently deployed camera function.

The same migration contains non-Vision provider/count/offline authorization
corrections. Removing only its camera statements changes the frozen hash and
applied contents; skipping the migration invalidates every subsequent exact
history guard. No statement was omitted, dependency silently skipped, or history
forged. The subscription catalog also contains dormant Vision feature metadata;
the final notification RPC includes read-only Owner Vision alert routing. These
references must be classified explicitly in any Vision-free successor scope.

The validated coordinated backend cannot safely be replaced with an untested
prefix: Batch 6's cash function alias correction is in Batch 8 migration 15,
behind migration 12. Stopping the prefix before that correction would leave the
known intermediate cash implementation exposed. Earlier additions have therefore
been held rather than deployed as a partially corrected operational backend.

## Actual deployment results

| Component | Result |
| --- | --- |
| Sixteen new database migrations | **0 applied**. Original production history remains sixteen. Migration 12 conflicts with the Vision restriction; the coordinated dependency chain is held. |
| Reviewed delete-account replacement | **Not deployed**. Production lacks required `request_trexven_account_lifecycle(uuid,uuid,text,text)` RPC; replacing the Edge alone would leave its reviewed request path unavailable. |
| camera-ai | Explicitly excluded as instructed; existing **v7**, JWT enabled, bundle hash unchanged. |
| Other Edges | No deployment. Camera ingest/worker, Angel, employee-login/create/manage and existing delete-account metadata unchanged. |
| ODT Vision server/pipelines/streams | Not accessed, configured, deployed or changed. |
| Production data/settings | No writes. Backup comparison shows existing records unchanged; no inventory balance/sale/receipt/account modification, provider enabling, charging or branch activation. |
| Flutter/Android | No build, device requirement, publication or additional full test suite. |

The legacy production deletion endpoint remains its prior v3 implementation;
it must not be represented as replaced or made non-destructive by this attempt.
No live endpoint was invoked to test deletion or create business transactions.

## Smallest resolution

The pending scope question concerns the explicit Vision restriction, not routine
deployment permission. Either authorize a separately frozen/tested Vision-free
successor that preserves the original candidate and migration order, or explicitly
permit the dormant camera subscription database guard while keeping camera-ai
and all Vision processing/services unchanged. Do not reinterpret the general
sixteen-migration approval as permission to override the specific Vision exclusion.

After the chosen resolution, repeat the required identity/history/backup freshness
checks and execute only the eligible, verified package. No blind partial retry or
backup restore over current production is warranted.

Evidence: [read-only preflight](evidence/final_backend_directive_preflight.json)
and [Edge preservation](evidence/final_backend_directive_edge_preservation.json).
Final status: **BLOCKED by the frozen candidate's Vision scope conflict**, not
Android readiness or credential availability.
