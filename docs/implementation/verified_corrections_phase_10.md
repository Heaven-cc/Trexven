# Phase 10: auth.uid RLS initplan preparation

Date: 2026-10-21. Status: source prepared; production deployment and merge pending approval.

## Problem and proposed behavior

The live performance advisor reports 20 auth_rls_initplan findings. The prepared SQL wraps exactly 25 direct, row-independent `auth.uid()` calls in those 20 policies as `(select auth.uid())`. This allows PostgreSQL to plan the identity lookup as a statement-level initplan. This is a planning optimization, with no intended change in authorization results. No query-plan measurement or speedup is claimed.

Pending source: `supabase/changes/rls_auth_uid_initplan_optimization.sql`. It is deliberately outside canonical migration history until an approved production application supplies its actual migration version.

## Baselines and scope

- Owner master: `605faf957bd9b1c736d2fe9b9a9bbf245e6f3441`.
- POS main: `e09d559355a81ade80742a9c46f13af7efce2057`.
- Shared production project: `ufehcfrlygqvminfjumf`.
- Read-only catalog: 298 public/private policies; 20 targets on 12 public tables.
- All 65 existing policies on those tables are embedded as exact preconditions, including 45 policies that are not targets. The other 233 policies are outside the affected tables. A successful deployment must leave all 278 non-target policies unchanged.
- All 12 tables have RLS enabled. Their owner, ACL, RLS and forced-RLS states are guarded.
- The live `auth.uid()` definition is STABLE, SQL, invoker, and reads JWT claims from request settings. Its full definition MD5 is `ea3b41bf29e2ad573067939329aa088e`. The migration aborts on definition or stability drift.
- A read-only public/private function-definition scan found no function matching both `set_config` and request JWT/claim setting names. This is a limited catalog check, not proof about external code.

| Table | Policy | Command / mode | Direct calls |
| --- | --- | --- | ---: |
| `businesses` | Owners can view their own business | SELECT / PERMISSIVE | 1 |
| `businesses` | Owners can create their own business | INSERT / PERMISSIVE | 1 |
| `businesses` | Owners can update their own business | UPDATE / PERMISSIVE | 2 |
| `businesses` | Owners can delete their own business | DELETE / PERMISSIVE | 1 |
| `businesses` | business owners can view businesses | SELECT / PERMISSIVE | 1 |
| `businesses` | business owners can insert businesses | INSERT / PERMISSIVE | 1 |
| `businesses` | business owners can update businesses | UPDATE / PERMISSIVE | 2 |
| `recordings` | Business owner can manage recordings | ALL / PERMISSIVE | 1 |
| `employees` | Owners and managers can view business employees | SELECT / PERMISSIVE | 2 |
| `employees` | Owners and managers can insert employees | INSERT / PERMISSIVE | 1 |
| `employees` | Owners and managers can update employees | UPDATE / PERMISSIVE | 1 |
| `audit_logs` | Owners and managers can view audit logs | SELECT / PERMISSIVE | 1 |
| `business_members` | Users can read their own membership status | SELECT / PERMISSIVE | 1 |
| `employee_permissions` | Owners and employees can read assigned permissions | SELECT / PERMISSIVE | 1 |
| `angel_conversations` | Angel author boundary | ALL / RESTRICTIVE | 2 |
| `angel_messages` | Angel message author boundary | ALL / RESTRICTIVE | 2 |
| `credit_approvals` | Credit approval scoped read | SELECT / PERMISSIVE | 1 |
| `sale_returns` | Return scoped read | SELECT / PERMISSIVE | 1 |
| `offline_sale_reconciliations` | Offline reconciliation scoped read | SELECT / PERMISSIVE | 1 |
| `pos_device_activity` | Own or owner device activity | SELECT / PERMISSIVE | 1 |

## Authorization preservation

Only USING/WITH CHECK expressions containing the listed calls are replaced. ALTER POLICY does not specify TO, change names, drop/create policies, change commands, or change permissive/restrictive mode. Null WITH CHECK clauses remain omitted, preserving the existing fallback behavior.

The existing owner-only employee insert/update/delete restrictions, staff and membership read scopes, branch membership restrictions for credit/returns, camera permission boundaries, account-closure boundaries, admin boundaries, subscription restrictions and audit-cost redaction remain unchanged. Legacy policy names mentioning managers and existing PUBLIC role applicability are not broadened or normalized.

Both Angel author policies remain RESTRICTIVE. Their related-record checks and owner checks are unchanged. Row-dependent helpers such as branch, business permission, membership and ownership predicates are not wrapped or rewritten.

Two policies already using scalar auth.uid subqueries are excluded: `Assignment authorized read` on employee_branch_assignments and `Own current business notification acknowledgements` on trexven_notification_reads.

## Owner/POS compatibility review

Reviewed selected current callers before preparing the shared backend change:

- Owner `lib/services/database_service.dart`: businesses remain filtered by current owner and selected business; membership lookup remains current-user scoped; credit approval lookup remains business/id scoped.
- Owner `lib/core/user_provider.dart`: current Supabase identity remains the source of user state.
- Owner `lib/services/recording_service.dart`: business/status filters, storage URL lookup and business-scoped delete remain unchanged.
- Both independent copies of `packages/trexven_operations/lib/src/financial_operations_screen.dart`: existing business, branch and actor filters on returns, approvals and offline reconciliation remain compatible.
- POS `lib/src/features/auth/permission_service.dart`: explicit grants, owner-only full access and offline restrictions remain unchanged.

This is source/catalog compatibility evidence, not device acceptance or an exhaustive re-audit. No frontend, dependency, RPC, column, table grant, storage, Auth configuration, Edge Function, billing or UI source is modified. The POS redesign and crash fixes remain on the unchanged POS main commit above.

## Transaction and operational risk

Execute only as one transactional Supabase migration batch after concrete approval. The SQL requests NOWAIT ACCESS EXCLUSIVE locks on the 12 tables before examining all guarded definitions; it fails immediately if a required lock is unavailable. Successful acquisition briefly blocks competing table work until transaction completion. A 1-second lock timeout and 10-second statement timeout bound the attempted batch; failure must roll back all policy changes.

All scope and identity-definition guards run before any ALTER. A mismatch requires new review; do not bypass guards, retry in a loop, consolidate policies, or extend this migration. No production data writes, fake identities, role probes, backup dumps or migration-history repairs are included.

## Evidence completed

Read-only catalog/advisor inspection and selected source inspection completed. The prepared target list matches the baseline catalog exactly: 20 policies, 25 calls and 12 tables. In-memory source comparison confirms each proposed expression reverses exactly to its original by removing the added scalar wrapper, and preserves null expression fields.

The prepared SQL has not been executed or parsed by PostgreSQL. No local clone, build, analyzer, test suite, dependency download, temporary file, backup, synthetic transaction, EXPLAIN workload or app launch was performed. No deployment or runtime success is claimed.

## Required checks after an approved application

1. Capture fresh read-only catalog, function, grant/RLS, index/constraint and operational row-count baselines immediately before application; recheck both repository heads.
2. Apply the exact reviewed SQL once using a named migration. Abort and report any guard, lock or execution failure.
3. Verify the new migration record, exactly 20 intended policy changes and 25 scalar wrappers; compare policy roles, modes, commands and all unaffected expression structure. Account for PostgreSQL deparser whitespace/aliases without discarding meaningful SQL tokens.
4. Verify all 278 non-target policies, function definitions, table ownership/grants/RLS, indexes/constraints and relevant operational row counts against the preflight baseline.
5. Rerun read-only performance/security advisors. Report actual remaining counts; disappearance of these warnings is not a measured performance claim.
6. Save the exact applied source under its actual canonical migration version and update this report/PR with observed deployment results. Do not invent a version or mark prepared SQL applied early.
7. User device acceptance remains pending: session restoration, business selection, staff/permissions, financial history and recording access under their real accounts. Do not create accounts or probe identities for this check.

If correction is needed after commit, re-read current policy definitions and prepare a separately reviewed forward migration using the original expressions embedded in this source. Preserve all roles/modes and unrelated policy changes; do not blindly restore the whole catalog.

## Remaining work

Advisor baseline also reports 123 unindexed foreign keys, 69 multiple-permissive-policy findings, 25 unused indexes and one table without a primary key. These require separate analysis; none is addressed or declared safe to change here. Live billing activation and device acceptance remain subject to their prior prerequisites.

## Primary references

- https://supabase.com/docs/guides/database/postgres/row-level-security
- https://supabase.com/docs/guides/troubleshooting/rls-performance-and-best-practices-Z5Jjwv
- https://www.postgresql.org/docs/current/sql-alterpolicy.html

Supabase recommends scalar wrapping only when the function result is independent of row data. PostgreSQL documents that omitted ALTER POLICY clauses remain unchanged.
