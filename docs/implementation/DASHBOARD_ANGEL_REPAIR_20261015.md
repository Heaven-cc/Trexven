# Dashboard, finance, alerts and Angel repair

Deployed to `Heaven-cc's Project` (`ufehcfrlygqvminfjumf`) on 15 October 2026, Africa/Lagos.

## Production changes

- Configured the affected Nigerian business with `Africa/Lagos`, conditional on its timezone still being NULL. Other businesses' configured timezones were preserved.
- Migration `20261015001244`, `dashboard_feeds_and_angel_catalog_tasks`, adds a timezone initializer for Nigerian onboarding and an optional `alerts.camera_name` compatibility field for installed clients. No historical sale timestamps or existing product values were rewritten.
- Angel version 13 is ACTIVE with JWT verification enabled. Its three deployed files match the local sources.
- Added owner-confirmed selling-price changes, total-stock changes, and positive/negative stock adjustments. Requests use the caller's JWT and the existing `save_trexven_catalog_product` / `adjust_trexven_catalog_stock` workflows.
- Proposals expire after 10 minutes. Exact product identity is required; duplicate names produce a choice of SKUs/IDs. Confirmation checks the actor, business, conversation, product identity and prior value. A changed product blocks a stale proposal. Retries return the original receipt without repeating the adjustment.
- Completion is reported from a database-verified receipt, with the existing price/stock history plus an Angel audit entry. Models can prepare a proposal but cannot execute a confirmation. Confirm/cancel does not contact Groq.
- The business snapshot collector and Groq destination are identical to deployed version 12. Model history includes only role/content; internal task metadata is excluded.

## Local client changes

- `DatabaseService` now propagates calendar, summary, sales, expense and product failures rather than using a timezone-less fallback or reporting empty/zero figures.
- `AlertService` omits the nonexistent legacy camera-name projection. The backend compatibility field also supports the already installed client.
- No new client build is required for the backend timezone/alerts repairs or Angel's chat confirmation protocol. The improved client failure handling needs an updated app build.

## Verification

- Live reads under the affected owner's authenticated role returned `Africa/Lagos`, a valid financial summary, a valid notification array, and a readable legacy alerts projection. There are currently zero rows in that legacy alerts table for the affected business.
- 48 assertions passed in ephemeral PostgreSQL (PGlite 0.5.10). The synthetic contract fixture executes the exact migration and existing catalog mutation, validation and history function bodies. This covers price, stock set/add/remove, ledger history, retry, expiry, cancellation, stale values, precision, duplicate names, owner/employee/foreign/anonymous denial and private-table access. It does not reproduce the entire managed Supabase stack or test concurrent sessions.
- 24 Angel handler tests passed, plus the existing Angel regression script. They cover trusted caller scope, preparation, explicit confirmation, no-provider confirmation, failures, unsupported tools, and receipt reporting despite failed chat persistence.
- 17 targeted Flutter tests passed across finance repository/calendar/loading and notification/account isolation.
- Deno type checking passed. Dart service analysis found no errors or warnings and seven existing informational style findings. Formatting and scoped `git diff --check` passed.
- Production action storage has RLS enabled; authenticated and anonymous clients have no direct SELECT/INSERT access. Anonymous execution of both task RPCs is revoked. Both RPCs check active business ownership and conversation ownership.
- Supabase advisors flag the intentionally inaccessible private table (RLS without client policies) and the intentionally callable authenticated SECURITY DEFINER RPCs. The RPCs use an empty search path and explicit authorization, and do not grant anonymous execution. Existing unrelated account/auth advisory findings were not altered. References: [private table policies](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy), [authenticated definer functions](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable).

## Usage and remaining validation

Start a new Angel chat and request one change, for example `Change Rice price to 2500`, `Set Rice stock to 20`, `Add 5 Rice to stock`, or `Remove 2 Rice from stock because they were damaged`. Use the exact product name/SKU. Review the displayed before/after values and reply `CONFIRM` or `CANCEL`.

No real stock or price was changed during testing. An authenticated real-device Groq-to-proposal-to-confirmation run and visual device acceptance have not been performed. Camera/Vision connectivity is a separate service and is outside this repair.

To rerun the isolated SQL suite, install its pinned dependency with `npm.cmd install --prefix .tool-cache/angel-tests --save-exact @electric-sql/pglite@0.5.10`, then run `node supabase/tests/angel_catalog_sql_test.cjs`. Handler tests: `node --test supabase/tests/angel_catalog_tasks_test.cjs` and `node supabase/tests/angel_test.cjs`.
