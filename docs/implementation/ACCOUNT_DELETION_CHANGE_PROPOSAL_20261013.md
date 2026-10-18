# Security: actual account deletion — approval boundary

**Later status:** The user approved implementation and instructed that local testing be skipped. The source implementation is documented in [ACCOUNT_DELETION_IMPLEMENTATION_20261013.md](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/ACCOUNT_DELETION_IMPLEMENTATION_20261013.md). This proposal describes the preceding review; no migration or cloud deployment has been performed.

## Confirmed cause

`C:/Users/USER/AndroidStudioProjects/Trexven/lib/screens/me/security_screen.dart` does not invoke deletion. Its `_deleteAccount` method opens the existing Account Operations screen. That screen calls `request_trexven_account_lifecycle`, whose SQL inserts a review request and returns `financial_records_preserved: true`.

`C:/Users/USER/AndroidStudioProjects/Trexven/supabase/functions/delete-account/index.ts` is also explicitly a review-only compatibility endpoint: it returns `deleted_user: false`. Reconnecting that endpoint alone cannot make actual deletion happen.

Existing tests deliberately assert this review-only behavior. This is a contract change, not a failed network connection.

## Concrete proposed scope

Implement deletion of the authenticated person's login/personal account, retaining business, sale, payment, credit, inventory and audit history. Do not cascade-delete a business to make Auth deletion succeed.

1. Add a separate explicit account-deletion action to the existing Edge endpoint, leaving the review-request action compatible for existing callers. Derive the target user from a verified session; never accept an arbitrary user ID. Require recent reauthentication and explicit user confirmation.
2. Check every owned business and account reference, not only the currently selected business. Require unresolved payment intent/ownership handover issues to be resolved before deletion; return actionable errors instead of partly deleting data. A caller without a business must also have a defined supported outcome.
3. Implement a durable deletion state/status record and server-side access cutoff before invoking Auth administration. Existing issued JWTs can remain valid after Auth deletion, so all applicable authorization helpers, direct table/storage policies and sensitive endpoints must deny the deleted account. This requires a reviewed additive migration/security contract; merely signing out the phone is insufficient.
4. Use the server-only Auth deletion API under the approved retention strategy. Supabase supports irreversible soft deletion, which may preserve referenced identity without cascading financial data. Verify its actual anonymization, session and FK behavior in a disposable local Auth stack before choosing it. Do not assume it is interchangeable with hard deletion.
5. Preserve a durable outcome for interruptions between database preparation and Auth deletion. Replays must not delete another account or repeat unrelated cleanup. A failed Auth call must not produce a success toast or clear the user's local recovery intent.
6. Remove only approved personal/profile fields and account-owned non-financial content; preserve financial evidence. Resolve storage ownership deliberately rather than deleting whole buckets. Specify any ownership transfer/archival requirement for a business that still has other active users.
7. Wire Security directly to the confirmed deletion/status action. Keep the existing screen layout; change the confirmation text to describe the actual retained records. Clear local session/cache and navigate to Welcome only after verified completion. Keep unresolved failures recoverable.

## Files expected to change after approval

- `C:/Users/USER/AndroidStudioProjects/Trexven/lib/screens/me/security_screen.dart`: confirmed delete/status wiring and minimal truthful confirmation text.
- A small Owner account-deletion service adapter, if necessary for test injection and durable recovery.
- `C:/Users/USER/AndroidStudioProjects/Trexven/supabase/functions/delete-account/index.ts`: explicit actual-delete action, authentication/reauthentication and durable outcome handling, retaining the existing review action.
- A new reviewed local migration: deletion state, access-cutoff helper and the exact necessary authorization integrations. No existing RLS policy would be disabled or broadly granted.
- Targeted Flutter, Edge and disposable SQL/Auth tests; existing review-only tests remain valid for the compatibility action.

## Required verification

Unauthorized/forged-target denial; cancellation and reauthentication; multiple-business scope; no-business accounts; retained financial history; expired/old JWT denial after closure; storage ownership; concurrent/duplicate requests; Auth failure; lost response; restart recovery; and successful local-session cleanup only after a verified deleted outcome.

## Approval required

The prior task explicitly states: **“Stop and request approval for new migrations, RLS/grant changes, sensitive new backend contracts or any shared-environment deployment.”** This actual-delete behavior is a sensitive new backend contract and requires reviewed database authorization work.

Requested approval is to implement and test this account-only deletion locally, preserving business/financial history. It is not approval to deploy, delete a real account, or change staging/production data. Those operations remain excluded.

No application source or deployed service was changed during this deletion investigation.

Sources: [current Security source](C:/Users/USER/AndroidStudioProjects/Trexven/lib/screens/me/security_screen.dart), [current Edge endpoint](C:/Users/USER/AndroidStudioProjects/Trexven/supabase/functions/delete-account/index.ts), [existing lifecycle SQL](C:/Users/USER/AndroidStudioProjects/Trexven/supabase/migrations/20261009081504_batch_7_enforcement_and_operations.sql), [Supabase user deletion/session limitations](https://supabase.com/docs/guides/auth/managing-user-data#deleting-users), [server Auth deletion API](https://supabase.com/docs/reference/javascript/auth-admin-deleteuser).
