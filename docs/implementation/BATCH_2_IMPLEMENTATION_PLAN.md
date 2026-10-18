# Batch 2 implementation plan

Date: 7 October 2026. Status: approved by the user for local development and isolated testing only. See the completion and test reports for actual results and remaining blockers.

## Approval scope

Approve local implementation in both workspaces, additive versioned migration files, isolated SQL/API/Edge tests, and Flutter tests/analysis. No production migration, Edge deployment, data backfill, branch activation, settings change or release is included. Environment provisioning that needs an installation, external credentials or paid staging will require its concrete infrastructure approval if unavailable.

At the original approval checkpoint only this plan and the audit report had been written. Local implementation is now approved; completion/test reports and updated gap/rollback documents record actual results. KPI documents remain unchanged. Changes are scoped for review; Owner's existing staged work and POS's missing Git metadata prevent safely committing the entire workspace. Never commit all existing changes.

## 1. Establish a reproducible isolated baseline

Use a separate unlinked test configuration/project ID, synthetic Auth identities and synthetic business data. Reconstruct a schema-only baseline from audited catalogs/approved schema export, including the pre-migration schema, grants, RLS, functions, triggers and extensions. Verify that replaying existing delta migrations yields the audited definitions; do not mistake a simplified fixture for a production-equivalent schema.

Preferred runtime: local Supabase/PostgreSQL 17 with Docker. Current blocker: Docker/Podman unavailable. Alternative: explicitly isolated staging with no production keys/data. Verify project identity in every test/deployment command and make test runners reject `ufehcfrlygqvminfjumf`. Discover CLI help before generating/running migrations. Do not execute even rollback-only adversarial tests on production.

Files: isolated config and schema/bootstrap fixtures under `supabase/tests/fixtures/`; test runner/environment documentation under `supabase/tests/` and `docs/implementation/`. Do not replace production-linked configuration with test defaults.

## 2. Centralize trusted authorization and close price bypasses

Create a new timestamped migration named `batch_2_authorization_price_enforcement.sql`; retain every historical migration unchanged.

Strengthen existing `private.has_business_permission`, `public.is_business_member`, and `public.user_owns_business` as appropriate. Ownership derives exclusively from businesses.owner_id/auth.uid. Employee authorization requires matching business/user, active employment, active membership and trusted relational grants. Unknown role/permission/identity fails closed. Preserve canonical role values and existing employee/membership IDs.

Manager defaults remain approved sales/inventory/limited staff operations; detailed finance and pricing require explicit owner grants. Vision/Intelligence remains owner-only. Inventory employees cannot gain price authority even through a stale explicit grant. Do not import permission JSON from requests/JWT user metadata. Resolve stored legacy membership JSON versus employee_permissions through a reviewed mapping; do not silently carry conflicting privileges forward.

Add an owner-only permission grant/revoke RPC using existing employee_permissions/permissions, with transactional audit, owner/manager/self escalation protection and immutable identity fields. Tighten update_trexven_employee/set_trexven_employee_status: managers may perform authorized ordinary-staff status/profile operations but never role changes or permission changes. Preserve existing wrappers/signatures and owner-target protection. A manager-created staff account uses the existing provisional `employee` role until its owner assigns role, permissions and branches.

Replace or narrow conflicting policies on the touched tables rather than piling on duplicate permissive policies. Remove unnecessary anon/authenticated TRUNCATE/REFERENCES/TRIGGER grants and unsafe default grants; preserve required SELECT/product DML and approved RPC execution. Keep direct employee, permission, transaction and branch-assignment writes closed. Harden touched definer search paths and explicit actor checks. Review dependencies before revoking helper execution needed by policies.

Protect all present price-bearing fields with a database guard trigger and field allowlist, used by direct INSERT/UPDATE, upsert and bulk paths. Freeze product/business/actor identity changes. Owners and explicitly price-authorized managers may set prices; inventory/sales employees cannot. Guard branch overrides if/when added; this batch will not create unused variant/price-level models.

Proposed pending representation: make selling_price nullable with no arbitrary numeric default; NULL means unpriced. Inventory product creation must omit price and remain inactive/non-sellable. Harden both active flags consistently without renaming/dropping either. Authorized explicitly set zero remains distinguishable from missing price; do not invent a minimum selling price or ban legitimate free products. Existing nonzero prices remain valid; existing zero-price rows require reviewed classification and must not be guessed from quantity or location. Isolated tests must cover omitted price, explicit zero, forbidden values, same-value assignments, mixed bulk statements and alternate RPCs.

Harden all sale cores to reject unpriced/inactive products and unauthorized discounts, while retaining permitted owner/manager behavior, exact financial arithmetic and stock checks. Characterize current behavior first, then consolidate genuinely duplicate private sale logic behind preserved public wrappers.

## 3. Add branch and cross-business integrity structures

Create `batch_2_branch_assignment_foundation.sql` with:

* `branches`: id, business_id, name, active state and audit timestamps, with unique identity/business pair.
* `employee_branch_assignments`: business_id, employees.id, branch_id, active state, unique assignment and composite business foreign keys. Only owner-authorized assignment mutations; neither employees nor managers may self-assign.
* A single reusable branch authorization helper composed with the centralized permission contract. Owner access still requires owning the branch's business. Employee access requires active branch and active assignment; supplying a UUID is never authority.
* Nullable branch_id columns on future branch-scoped sales/inventory/movements and private request metadata, with composite business/branch integrity. Preserve sale_item relationships, historical NULL product references and membership actor foreign keys.
* Appropriate business/product composite constraints and indexes on scoped records. Check existing data before validation; use staged NOT VALID constraints where needed. Keep existing financial snapshots and identifiers intact.
* Explicit business-local IANA timezone configuration for daily sales scope. Do not infer timezone from workstation or country. Missing/invalid configuration fails closed for employee day-history access with a clear setup error; owners retain authorized history access.

Reuse existing inventory as the eventual branch stock store instead of creating a competing ledger. Add a branch/product uniqueness constraint for branch-populated rows while keeping legacy rows compatible. Restrict stock operations through trusted transactional entry points and immutable movement records; do not allow direct edits to bypass adjustment authority. Business-wide products remain catalog records and default prices, not a source of another branch's stock balance.

Products need not be duplicated by branch. Shared catalog visibility is distinct from branch inventory/sales authority. Cross-branch visibility does not confer write/sale rights; no unrestricted cross-branch reporting is added by default.

## 4. Secure checkout transition and legacy activation

Create `batch_2_branch_checkout_compatibility.sql`. Preserve old public RPC argument lists and return types, request keys, receipt IDs, membership IDs and saved receipts. Add a distinct branch-aware submission entry point (rather than ambiguous PostgREST overloads) and reuse the same request ledger/transaction core.

Two explicitly controlled modes:

1. Legacy business: existing stock/sale behavior remains under strengthened business permissions and price guards. New historical branch fields remain NULL. NULL is an identified compatibility state, not a fabricated branch.
2. Branch-enabled business: all new stock/sales resolve an active authorized branch and use branch inventory atomically. Branchless older calls may resolve only an owner-approved compatibility branch when the actor's authorized context is unambiguous. Otherwise fail with an upgrade/context error; never silently pick an arbitrary assigned branch or fall back to business-wide stock.

Never activate a business merely because branches were created. An owner-reviewed allocation must reconcile branch stock totals to current products.quantity under transaction locks, record the mapping and prevent simultaneous legacy/branch stock mutations. Do not distribute current stock automatically and do not reassign historical transactions. Rehearse one explicit default branch as the safe single-branch transition, but leave production activation/backfill for a separate approval.

Branch-aware requests validate branch/business/product/assignment server-side. Keep request uniqueness business/user/request so switching branch cannot create a second sale with the same key. Store/check resolved branch metadata for new requests without rewriting old saved payloads or receipts. Old replay remains exact; branch mismatch rejects, and revocation is checked before replay. Preserve caller-visible receipt contracts while adding optional branch information only for new records.

Use stable product/stock locks and a consistent authorization-revocation lock order. Test last-stock races, concurrent retries and branch activation races. Define revocation ordering explicitly: transactions already serialized before revocation may complete; operations serialized afterward must fail. Do not claim an in-flight transaction can be undone by revocation.

## 5. Edge and minimal Flutter integration

Owner function files: `supabase/functions/create-employee/index.ts`, `manage-employee/index.ts`, `employee-login/index.ts`. Replace divergent manager membership/JSON checks with the central trusted actor contract; verify active identity, scope and owner-only role/permission assignment before service-role actions. Recheck authorization close to Auth-admin operations and handle compensation/audit failures. Service credentials remain server-only.

Characterize the POS `supabase/functions/employee-login/index.ts` response/email behavior before convergence. Use one documented canonical source with a tested compatibility mirror or adapter; retain existing clients' login/session/employee/membership fields. Do not delete the divergent copy or unrelated functions on appearance alone. Add Deno/Edge authorization tests for these administrative paths, using mocks only where Auth-admin service behavior requires it and identifying integration coverage separately.

Owner candidate files: `lib/services/database_service.dart`, `lib/core/user_provider.dart`, `lib/models/business.dart`, `lib/screens/auth/account_gate.dart`, and employee management call sites where trusted APIs replace writes. Replace maybeSingle ownership lookup with explicit verified business selection; do not change onboarding's existing update contract. Additional-business creation, if exposed in this batch, must use a separate owner-only contract rather than onboarding. Owner-only administrative/finance/Vision endpoints enforce true ownership server-side; a client app-name flag is not authorization because both apps share a public Supabase backend.

POS candidate files: `lib/src/features/auth/auth_provider.dart`, `permission_service.dart`, `lib/src/models/employee.dart`, product/sale models, `features/inventory/product_repository.dart`, `features/pos/sales_repository.dart`, checkout/cart/context call sites. Add explicit per-device authorized branch context and safe branch switching, preserve pending products and optional legacy JSON fields, and use branch-aware requests only in activated context. Sales history becomes all authorized branch sales today rather than arbitrary employee history. UI checks mirror the backend but do not replace it.

Context switching warns/clears unfinished carts; existing requests retain original IDs/business/branch and cannot be retagged. No new offline queue format or offline subsystem is introduced without a separate compatible design. Screens, KPI sizing, typography, navigation bars and animations remain unchanged except minimal business/branch/context and authorization controls.

## 6. Required tests and execution evidence

New SQL suites: `supabase/tests/batch_2_authorization_tests.sql`, `batch_2_price_security_tests.sql`, `batch_2_branch_isolation_tests.sql`, `batch_2_checkout_compatibility_tests.sql`; extend existing sale/readiness tests without weakening assertions. Run as authenticated/anon roles with genuine synthetic JWT identities, not only superuser assertions. Also exercise actual isolated REST/RPC behavior for upserts, bulk updates, column writes and effective EXECUTE privileges.

Acceptance matrix:

| # | Required assertion |
| --- | --- |
| 1 | Owner accesses own business |
| 2 | Owner cannot access another owner's business |
| 3 | Employee fails verified Owner context and owner-only operations |
| 4 | Manager cannot grant or escalate own permissions |
| 5 | Manager cannot promote anyone to owner or assign operational roles |
| 6 | Sales employee cannot change prices |
| 7 | Inventory employee cannot insert/update prices |
| 8 | Upsert, bulk and alternate RPC price bypasses fail atomically |
| 9 | Manager price edit succeeds only with explicit owner grant |
| 10 | Unauthorized/inactive branch access fails |
| 11 | Multi-assigned employee accesses exactly active assignments |
| 12 | Forged business/actor identifiers fail |
| 13 | Forged branch/business combination fails |
| 14 | Valid legacy checkout signatures continue working in legacy mode |
| 15 | Membership IDs, saved receipt and idempotency behavior remain exact |
| 16 | Legacy/unmapped data remains accessible to authorized owners/users under compatibility rules |
| 17 | NULL/unpriced/inactive products cannot sell |
| 18 | Missing/invalid auth, permission and RPC execution fail closed |
| 19 | Cross-business reads, writes and linked references fail |
| 20 | Revoked permissions/assignments and suspended employment take effect server-side |

Additional cases: sensitive manager defaults denied, owner-only Vision, business-local midnight/DST boundaries, invalid timezone, exact authorized zero price, price change during sale, stock race, concurrent duplicate key, cross-branch key reuse, stale context, replay after revocation, forbidden identity/permission JSON changes, activation reconciliation and recovery. Verify both rejected requests and unchanged balances/audit/request state.

Flutter: extend Owner `test/backend_service_test.dart`; POS permission/access/checkout/sale-submission suites and branch-context tests. Run full `flutter test --no-pub --reporter expanded` in each workspace after implementation. Run `flutter analyze --no-pub` separately; record exact exit codes and errors/warnings/informational counts, including existing findings. Fix relevant regressions without unrelated style cleanup. Existing counts are baselines, not promised future results.

## 7. Rollback, reports and approval boundaries

Authorization/price migration: restore compatible APIs if necessary while retaining the safer grants/price denial; never roll back by reopening the known security gap. Nullable price recovery cannot restore NOT NULL/default-zero safely once unpriced rows exist: forward-recover using pending-aware code and reviewed pricing, never invent prices.

Branch schema migration: before any branch data exists, remove only demonstrably unused new objects if necessary in isolation. Once assignments/stock/sales exist, retain schema/data and forward-fix. Disabling new client flows must not reopen branchless global stock writes for an already activated business.

Checkout migration: preserve wrappers and existing receipt ledger. Quiesce branch writes for reconciliation/recovery; do not merge branch stock into products.quantity blindly or delete branch financial records. Restore service/code definitions from recorded versions only after contract tests; never rewrite historical requests to make retries pass.

After implementation, update `FEATURE_GAP_MATRIX.md` and `MIGRATION_AND_ROLLBACK_PLAN.md`. Produce `BATCH_2_TEST_RESULTS.md` with commands, runtime/project, counts, exits and unexecuted checks; produce `BATCH_2_COMPLETION_REPORT.md` separating implemented-and-tested, implemented-not-tested, proposed, blocked, requires-production-deployment and deferred. Preserve `KPI_COMPONENT_AUDIT.md` for later UI work.

Production requires a separate review of schema drift, sanitized baseline fidelity, backups/restore rehearsal, migration checksums, employee grant mapping, zero-price classification, timezone configuration, branch/stock allocation and compatible client release order. None is authorized by approving this local Batch 2 plan.

Deferred: variants/price levels/optional branch overrides, complete inventory lifecycles/transfers, durable offline reconciliation, consolidated reporting UI, financial workflows, subscriptions/limits and all visual redesign. Their future backend price/branch contracts must reuse this foundation.
