# Account deletion production deployment — 13 October 2026

The user explicitly approved live deployment to TREXVEN Supabase project `ufehcfrlygqvminfjumf`. The migration and both Edge Functions were deployed successfully. No actual account deletion was invoked.

| Component | Live result |
| --- | --- |
| Migration | `20261013055042_account_deletion_with_history_preservation` present in remote migration history |
| Existing `delete-account` | Version 5, ACTIVE, `verify_jwt=true` |
| New `account-deletion-recovery` | Version 1, ACTIVE, custom recovery credential authentication |
| Server deletion RPCs | All four deny execution to anon/authenticated and allow service_role |
| Closed-account policies | 66 restrictive policies on existing public tables and Storage buckets/objects; original policies retained |
| Private operation tables | RLS enabled; client access revoked |
| Existing permission logic | All three copied helper definitions exactly match pre-deployment bodies except the copied function name |
| API pre-request guard | Configured for authenticator in the current database; prior global settings retained |
| Other Edge Functions | Original versions and bundle hashes unchanged |

The existing reviewed account request contract remains available. New functionality handles authenticated account deletion, durable recovery and denial of closed-account access while retaining financial/business history. Backend deployment adds the deletion implementation without invoking it for any account.

Live HTTP checks passed: unauthenticated deletion returned 401; recovery without its credential returned 400 with `Cache-Control: no-store`; recovery OPTIONS returned 200; the anonymous access-check RPC returned 200/true. The operation state table contained zero rows before and after those checks. No local tests, Flutter analysis/build or real deletion were run, as requested. These checks do not prove successful authenticated deletion, business blockers, recovery after lost responses or device cleanup end to end.

The installed application was not rebuilt or distributed. It must use the updated account-deletion service and Security wiring from the earlier source implementation; an older app using the legacy reviewed-request contract continues to create a review request. An app still showing the original request-only interaction remains a frontend integration limitation until an authorized app update is installed.

This deployment step made zero frontend edits or deletions. It renamed only the local backend migration to match the remote version and recorded documentation/evidence. The repository already contains frontend modifications/deletions, so `git diff` is not a clean-tree proof of zero frontend changes across the full conversation. The earlier account-deletion implementation also changed frontend files, as listed in the implementation report. Hash comparison against that source snapshot matches AccountGate, Security, the deletion service and recovery screen; `lib/main.dart` differs because its current source additionally imports/routes through SplashScreen. That drift was left untouched during deployment and prevents claiming all frontend hashes match the prior snapshot.

Evidence: [live checks and source comparison](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/evidence/account_deletion_20261013/deployment/live_checks.json), [live schema](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/evidence/account_deletion_20261013/deployment/live_schema_verification.json), [existing frontend Git diff](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/evidence/account_deletion_20261013/deployment/frontend_git_diff_existing.txt), [deployment manifest](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/evidence/account_deletion_20261013/deployment/deployment_manifest.json).
