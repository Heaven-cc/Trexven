# Phase 10: auth.uid RLS initplan deployment

Date: 2026-10-21. Status: approved production migration applied and catalog-verified; merge requested by user.

## Problem and proposed behavior

The live performance advisor reports 20 auth_rls_initplan findings. The prepared SQL wraps exactly 25 direct, row-independent `auth.uid()` calls in those 20 policies as `(select auth.uid())`. This allows PostgreSQL to plan the identity lookup as a statement-level initplan. This is a planning optimization, with no intended change in authorization results. No query-plan measurement or speedup is claimed.

Applied source: `supabase/migrations/20261021023640_rls_auth_uid_initplan_optimization.sql`. Production assigned this actual migration version after approval. The prepared file was moved into canonical history without changing its SQL; its PREPARED ONLY comment records its original approval gate.

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

After the user's explicit “Merge and deploy” instruction, the exact prepared SQL was applied once using Supabase apply_migration. Supabase returned success, the migration record was read back and its stored statements matched the approved source exactly. No local clone, build, analyzer, test suite, dependency download, temporary file, backup, synthetic transaction, EXPLAIN workload or app launch was performed. Application runtime acceptance and measured performance remain unverified.

## Deployment checklist used

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

## Observed deployment results

Production migration: `20261021023640_rls_auth_uid_initplan_optimization`. Supabase apply_migration returned `success: true`. All guarded baseline policies and the identity definition matched preparation immediately before application. Current Owner PR head was `b1f3c32f81cf4f27e2e29d9fa31d59446ca6872c`; Owner master and POS main remained at the baseline commits above.

| Read-only comparison | Observed result |
| --- | --- |
| All policies | 298 before and after; exactly the 20 approved targets changed |
| Identity wrappers | Exactly 25 scalar wrappers in target USING/WITH CHECK clauses |
| Target metadata | Roles, commands, permissive/restrictive modes and null expression fields unchanged |
| Target expression structure | Removing only the exact PostgreSQL-deparsed scalar wrapper restores the original expression token sequence; quoted SQL literals/identifiers preserved |
| Non-target policies | All 278 byte-for-byte unchanged in catalog JSON |
| Public/private functions | All 186 definition hashes, ACLs, definer flags and settings unchanged |
| auth.uid | Definition MD5 unchanged |
| Tables | All 83 ownership/grant/RLS records unchanged |
| Indexes | All 207 index definitions and valid/ready states unchanged |
| Constraints | All 401 constraint definitions, validation states and backing-index IDs unchanged |
| Role/database settings | All 11 records unchanged |
| Operational counts | All 20 selected row counts unchanged |
| Migration history | 53 production records; 52 prior filenames plus this actual migration match canonical source names |

Performance advisor after application: auth_rls_initplan is absent (previously 20 findings). Remaining groups: 123 unindexed foreign keys, one missing primary key, 25 unused indexes and 69 multiple-permissive-policy findings. Warning removal is not a measured speedup.

Security advisor findings are identical after excluding only their observation timestamps: 18 RLS-enabled tables without policies, two anon-executable security-definer functions, 87 authenticated-executable security-definer functions and leaked-password protection disabled. These pre-existing findings were not altered or declared resolved.

GitHub exposed zero check runs and zero commit-status contexts for the prepared head; the aggregate status was pending. No CI pass is claimed. Device acceptance remains pending with the user. This phase changed only policy planning expressions and repository migration/report source; no application release or Edge Function deployment occurred.
