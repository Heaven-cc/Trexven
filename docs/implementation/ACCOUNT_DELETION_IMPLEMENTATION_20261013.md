# Security account deletion implementation — 13 October 2026

Implemented the approved account-only deletion in application/backend source. The user explicitly requested implementation without local testing, so no Flutter tests, analysis/build, Edge tests, local Auth invocation, SQL replay or live deletion was run. Only source inspection, source formatting and diff/hash recording were performed.

**Deployed with explicit live approval on 13 October 2026.** Migration `20261013055042_account_deletion_with_history_preservation`, `delete-account` v5 and `account-deletion-recovery` v1 are active in project `ufehcfrlygqvminfjumf`. Read-only metadata and harmless live rejection checks passed. No account deletion was invoked, no local tests ran, and no Flutter build was produced. See [deployment evidence](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/ACCOUNT_DELETION_DEPLOYMENT_20261013.md).

## Implemented behavior

- Security's existing danger card now confirms actual account deletion and invokes the deletion service rather than opening Account Operations. Its remaining password controls/layout are retained.
- The Edge endpoint derives the target from the authenticated bearer token and requires recent password/OAuth/OTP/MFA authentication, explicit `DELETE` confirmation, a UUID request and a 256-bit recovery credential. The client pins the original session token for submission so an account switch cannot retarget that request.
- A server-only durable operation closes account access before calling Auth soft deletion. Auth's non-login UUID tombstone is retained to preserve financial/owner foreign keys. This is irreversible removal of login credentials/identities/sessions, not a cascade deletion of business tables. The previous reviewed-request API remains a separate compatible path.
- Preparation checks all owned businesses, active other users, open/unreconciled cash shifts, pending credit/return/stocktake/handover/inventory/supplier reviews and outstanding credit. Blockers are returned as actionable messages. A user with no owned business is supported by the backend; actual protected operations and ownership transfers are not bypassed. Local interrupted financial intent must be recovered first.
- The migration preserves current authorization helper bodies and adds a closed-account condition. Restrictive RLS supplements existing public/Storage policies. A REST pre-request guard covers definer RPC entry and preserves an existing configured pre-request hook rather than discarding it. Existing non-deleted accounts keep their existing permission bodies; no policy is disabled or broad data grant added.
- Finishing anonymizes account member/employee profile fields and inactivates those memberships, removes the account's private Angel conversations/messages, and retains business, product, sale, payment, expense, credit and audit records. Business assets/Storage objects are retained; no bucket or business is deleted.
- A lost response retains the original request/secret in device secure storage. The recovery Edge route accepts only the credential of an already prepared request, cannot pick another user, and uses a lease to serialize work. It deliberately does not require the Auth session that deletion revokes. Only this new capability-authenticated recovery route uses `verify_jwt=false`; the main deletion route retains `verify_jwt=true` and verifies its bearer token itself.
- The client verifies the matching deletion receipt before clearing the original device session/recovery record. It does not sign out a different current account. Completed server deletion is persisted separately from device cleanup so a restart can finish cleanup without a working deleted-user session.
- AccountGate and the signed-out route expose pending recovery after restart/session removal. Login, Register and Welcome designs were not edited. No raw password, bearer token or recovery secret is written to application logs; the recovery secret is held in secure storage and only its hash is stored server-side.

## Exact application/backend changes

Existing files modified:

- [Security screen](C:/Users/USER/AndroidStudioProjects/Trexven/lib/screens/me/security_screen.dart)
- [AccountGate](C:/Users/USER/AndroidStudioProjects/Trexven/lib/screens/auth/account_gate.dart)
- [Main auth routing](C:/Users/USER/AndroidStudioProjects/Trexven/lib/main.dart)
- [Delete-account Edge endpoint](C:/Users/USER/AndroidStudioProjects/Trexven/supabase/functions/delete-account/index.ts)
- [Function configuration](C:/Users/USER/AndroidStudioProjects/Trexven/supabase/config.toml)

New files:

- [Account deletion service](C:/Users/USER/AndroidStudioProjects/Trexven/lib/services/account_deletion_service.dart)
- [Recovery screen](C:/Users/USER/AndroidStudioProjects/Trexven/lib/screens/auth/account_deletion_recovery_screen.dart)
- [Shared server deletion implementation](C:/Users/USER/AndroidStudioProjects/Trexven/supabase/functions/_shared/account-deletion.ts)
- [Recovery Edge endpoint](C:/Users/USER/AndroidStudioProjects/Trexven/supabase/functions/account-deletion-recovery/index.ts)
- [Applied migration](C:/Users/USER/AndroidStudioProjects/Trexven/supabase/migrations/20261013055042_account_deletion_with_history_preservation.sql)

The CLI originally created migration filename `20261013042954`; after deployment the local file was renamed to the verified remote version `20261013055042` to prevent duplicate application. Its SQL content was unchanged. No new package dependency or replacement transaction/financial ledger was introduced. Documentation and task-only evidence are additional non-application artifacts.

## Delivery limits

- **Status: source implemented and backend deployed; actual account deletion and device behavior unverified.** No successful real account deletion is claimed.
- Production changes consist of the explicitly approved migration and two Edge Function deployments. No Auth deletion call, financial record deletion or data reset occurred.
- Recent reauthentication is required within 15 minutes; stale sessions must sign out/sign back in before confirming deletion. Refreshing a token alone does not satisfy this check.
- The migration depends on the audited Batch 2–9 schema and existing helper signatures. Live checks confirmed the copied permission bodies exactly match their pre-deployment definitions, deletion RPCs are server-only, all 66 new policies are restrictive, and the pre-request hook is configured. Existing financial/workflow histories are intentionally retained. Auth deletion and installed-app compatibility remain unverified.
- Account deletion is not a wipe of the business, financial evidence, business Storage assets or separately paired Vision server data.

Source-only evidence and the pre-change snapshots are in [account_deletion_20261013](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/evidence/account_deletion_20261013). The task-only diff separates these edits from prior dirty-worktree changes. No application file was deleted.

Implementation references: [Supabase server-only deletion API and irreversible soft deletion](https://supabase.com/docs/reference/javascript/auth-admin-deleteuser), [issued-token access after deletion](https://supabase.com/docs/guides/auth/managing-user-data#deleting-users), [Auth's soft deletion/session cleanup implementation](https://github.com/supabase/auth/blob/master/internal/api/admin.go).
