# POS Expenses deployment — 19 October 2026

Production project: `ufehcfrlygqvminfjumf`
Applied migration: `20261019205934_pos_expenses_backend`
Deployment tool returned `success: true`.

## Inspected sources

- Owner master: `5215fd7e0d015da5d29cc1ce0ec4b733d92d352c`
- POS main: `8a4c92141bada52f759e1423a8dbecb2e0152e37`
- All 116 Owner and 74 POS Dart files under lib/ and packages/ were read remotely, together with root/package manifests and lockfiles.
- No missing relative import/export/part targets. No imported package names absent from lockfiles.
- Both apps have repository-local operations/design packages. Their path dependencies do not point into the other repository.
- Both lockfiles resolve supabase_flutter 2.17.2, supabase 2.16.1 and postgrest 2.9.1.
- All 34 Owner and 27 POS distinct statically named direct/wrapped RPC names exist in production. This checks existence, not all argument shapes, dynamic routes, response semantics, native dependencies or runtime behavior.
- Owner expense history and FinanceReport use DatabaseService.getExpenses with the unchanged projection id/category/description/amount/payment_method/created_at.
- No expense writes were found in either app. POS Save/history are deliberately unavailable.
- Live finance, branch, closed-account and admin expense policies are RESTRICTIVE. The handoff's claim that these boundaries were permissive was stale.

## Deployed change

- Nullable branch_id, shift_id, request_id, business_date and business_timezone; foreign keys, request uniqueness and history/shift indexes.
- Cross-business member/branch/shift guard trigger.
- New record_expenses and view_pos_expenses permissions. No employee permission rows were automatically granted. Owners can explicitly grant them through the existing set_trexven_employee_permission RPC.
- record_pos_expense validates authenticated active membership, POS access, expense authority, branch assignment and money/category/description.
- Server sets cash payment method, timestamp, local business date and timezone snapshot. No client expense date or employee identity parameter exists.
- A null shift is explicitly supported, even when registers exist. No automatic drawer selection.
- A selected shift requires cash_shifts permission and the existing locked open-shift/register-assignment/joined-member validation.
- One negative cash_events cash_out entry accompanies a selected drawer expense. No cash_transactions write or second expense deduction.
- Expense, optional cash event, audit and durable request receipt commit atomically. Existing actor/business/payload-bound advisory-lock replay runs before current shift validation, so a successful retry can replay after shift closure.
- get_pos_expenses returns branch-scoped own records by default. Explicit branch history additionally requires view_pos_expenses and manager/owner authorization. Page limit 1–100, default 50; paired timestamp/UUID keyset cursor.
- Raw expense reads are owner-only. Anonymous table access and authenticated direct writes are revoked. Existing restrictive lifecycle/admin/finance policies remain.
- SECURITY DEFINER endpoints use an empty search_path and deny anonymous execution.

## Read-only deployment evidence

- Migration history contains exact version/name above.
- Both installed function bodies and cross-business guard were retrieved after deployment.
- Both RPCs: SECURITY DEFINER true, empty search_path, anon EXECUTE false, authenticated EXECUTE true.
- Effective anon SELECT/INSERT false; authenticated INSERT/UPDATE/DELETE false. Authenticated table grant is SELECT only, subject to RLS.
- New columns, foreign keys, uniqueness/history indexes, guard trigger and owner read policies are present.
- Expenses count before/after: 0 / 0. No expense or financial transaction was created for verification.
- No existing application records were rewritten by this migration.

Security advisor: 76 → 78 authenticated SECURITY DEFINER notices, corresponding to the two intentionally authenticated RPCs. Anonymous SECURITY DEFINER notices remain 2, unchanged; no new expense endpoint is anonymously executable. Seventeen private RLS/no-policy informational notices and the disabled leaked-password-protection warning pre-existed and remain outside this change.
Advisor explanations: [authenticated RPC notice](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable), [anonymous RPC notice](https://supabase.com/docs/guides/database/database-linter?lint=0028_anon_security_definer_function_executable), [private RLS notice](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy), [password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

## Client contract for later integration

record_pos_expense:
- Required: p_business_id UUID, p_request_id UUID, p_amount numeric, p_category text.
- Optional: p_description text (up to 2000 characters), p_branch_id UUID, p_shift_id UUID.
- Categories exactly match the approved POS form: Shop supplies; Food & refreshments; Transport; Utilities; Other expense.
- Persist original request/payload through transport failures; retry the same key and payload. Never generate another key merely because a response times out.
- Response is the saved expense row, including server date/timezone and request/branch/shift IDs.

get_pos_expenses:
- p_business_id required; p_branch_id required when branches enabled, null when disabled.
- p_limit default 50, capped at 100.
- p_before_created_at and p_before_id must be supplied together from next_cursor.
- p_branch_history defaults false (own entries). True requires explicitly authorized manager/owner.
- Returns items, scope and next_cursor; null cursor ends pagination. A full last page can yield one final empty request.

## Limits and remaining work

No local clone, build, test run, dependency installation, backup or temporary source file was created. These are source/catalog checks, not authenticated transaction tests or device/runtime verification. Race/replay and Owner query behavior were reviewed structurally; no production business transaction was fabricated.

Neither app's Flutter files nor the POS repository were modified. Unpushed local crash fixes were not available and were not overwritten.

POS Expenses is NOT end-to-end functional yet: Save/history integration and owner permission-grant UI discovery remain pending. After local fixes are pushed, wire the approved existing form to these contracts, use durable journal recovery, display the server business day, and preserve the existing design. Do not wire raw table queries in POS or default to an arbitrary drawer.

Source changes are in the backend PR; production deployment has already occurred under existing authorization.
