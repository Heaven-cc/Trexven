# Backend-only audit and tested repairs

13 October 2026. **This records the initial backend validation audit. Production
and cloud staging were read-only.** The expanded frontend-to-backend audit is in
[the current report](FRONTEND_BACKEND_INTEGRATION_AUDIT_20261013.md), including
frontend blockers, additional Angel repairs, Flutter tests and concurrent source
changes. Its instruction prohibits deployments; no deployment approval is pending.

## Existing connections and reused features

Read-only inspection covered Owner and POS sales/payment calls, bulk inventory
counts/imports, credit approval/repayment, Angel conversations, notification
retrieval/read acknowledgements, and the permission boundaries they use.
All **54 literal RPC names** found in the current clients exist in production and
have authenticated execution grants. This is endpoint coverage, not proof of
every screen's runtime behavior. Named parameter inspection confirmed the main
sale, repayment, stock count and notification calls use the existing contracts.

Reused the existing confirmed-payment transaction core, Owner sale adapter,
credit ledger, catalog import/stock-count persistence, operation receipts and
idempotency, role-scoped notifications, low-stock alerts, and persisted Angel
conversation/history. No duplicate backend service or new frontend was created.
No absent connection requiring a new service was found in these audited flows.

## Repairs prepared

The [forward migration](../../supabase/migrations/20261013005127_backend_null_input_validation.sql)
changes six validation clauses across **five existing RPCs**:

| Existing backend operation | Defect reproduced before repair | Repaired behavior |
| --- | --- | --- |
| `count_trexven_stock` | SQL NULL counts acknowledged as a successful empty operation | Require a JSON array; preserve the bulk count response and retry receipt |
| `complete_trexven_transaction` | An approved credit transaction could accept SQL NULL payment lines | Require a JSON array; an explicit empty array remains available for approved unpaid credit |
| `repay_trexven_credit` | NULL method reduced debt and wrote a repayment without a payment method | Require cash, bank transfer or card |
| `request_trexven_return` | NULL items created an empty return request | Require a nonempty JSON item array |
| `inspect_trexven_return` | NULL conditions or a missing per-item condition marked a return inspected | Require the inspection array and an explicit permitted condition for each item |

The migration modifies only these clauses in the existing definitions. It drops
no object, changes no grant/RLS policy, and rewrites no historical row. An exact
clause occurrence check fails the whole transaction if the reviewed source has
drifted. Signatures, default arguments, result types, owners, security settings,
and grants were verified unchanged in the isolated database.

Angel now returns **400** for malformed JSON, NULL, arrays and scalar bodies,
using the existing `{success:false,error:...}` response shape. These requests
cannot create conversations/messages or call the AI provider. The existing Auth
and rate-limit checks remain in place. The prior local Angel source matched
deployed version 12 after newline normalization. Review the exact task-only
[Angel patch](evidence/backend_only_20261013/angel-validation.patch); the full Git
diff also includes substantial pre-existing changes from before this task.

Refund approval already rejects missing methods through its collection boundary.
Its implementation was retained after the reproduction disproved the proposed
additional repair. No refund-method production defect is claimed.

## Current verification

- **49/49 local replay/check steps passed**, including a fresh schema-only
  baseline, 23 existing migration sources, and the new validation migration.
- All **six validation gaps** reproduced before repair and failed closed after
  repair. Both reproduction and regression transactions rolled back.
- Valid bulk count persists both product/version/quantity-string lines once;
  retry returns the same receipt; a stale line rolls back the entire batch.
- A deliberately mismatched third migration clause failed; the earlier two
  replacements rolled back. A subsequent source comparison proved no partial
  persistence. Exactly five RPC bodies changed in the successful migration;
  function metadata/grants/security stayed unchanged.
- **13 existing database suites passed**: authorization, branch isolation,
  checkout compatibility, price security, catalog/inventory, financial
  operations, offline cash, recovery boundaries, inventory operations, shared
  drawers, subscriptions, Owner/session integration, notifications. The suites
  contain 136 explicit `assert_true` calls plus denial/error assertions.
- **38 Node test cases passed**, including the expanded Angel tests covering six
  malformed bodies. Auth/database/provider calls in these handler tests are
  mocked; this does not prove a successful live Groq conversation.
- Empty synthetic fixtures were verified after tests; the newly created local
  database was removed successfully. Cloud staging and production received no
  migration, deployment, test fixture, provider call, or data write.

[Passing database evidence](evidence/backend_only_20261013/attempt_4/database_results.json)
and [audit summary](evidence/backend_only_20261013/audit_summary.json) record the
scope. Earlier attempts remain in `attempt_1` through `attempt_3`: the initial
refund expectation was wrong, the initial bulk fixture violated the existing
single-active-session rule, and the first deliberately drifted clause still
contained its old substring. Only test expectations/setup changed to correct
those attempts; production was not used to work around test failures.

## Production and outstanding verification

Live read-only inspection found 32 existing migration-history entries, no new
validation migration, and zero public tables without RLS. Aggregate checks found
zero repayment entries without methods, zero inspected/approved returns missing
conditions, and zero returns without items. These checks do not certify every
historical financial record.

Existing security advisors remain: nine INFO findings for private RLS tables
without client policies, 67 WARN findings for authenticated callable
security-definer functions, and one WARN for disabled leaked-password protection.
No platform setting or permission was changed. Relevant references:
[privileged RPC advisor](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable)
and [password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection).

No frontend limitation preventing these backend repairs was found. Actual
device scanning, screen interactions, real payment verification, valid-user
production checkout and a successful live Groq response were not exercised.
No Flutter build/test command or frontend formatting operation was run here.

## Frontend protection proof

**ZERO frontend source files were modified or deleted by this task.** SHA-256
comparison found **164 Owner + 91 POS protected source/assets/configuration
files unchanged**, with no additions or deletions. The protected Owner Git status
comparison also has zero changes from the entry baseline. POS has no usable Git
repository, so its evidence uses hashes rather than inventing a Git diff.

[Source integrity proof](evidence/backend_only_20261013/frontend_source_integrity.json)
and the saved before manifests cover both apps. The broader raw comparison also
recorded changes to ignored Gradle cache/lock files and generated
`android/local.properties` during the session. Dart/Java processes were active;
this task's commands did not write those Android paths. Those generated-file
changes were retained and were not reversed. Pre-existing frontend Git edits
and deletions also remain untouched.

## Earlier deployment proposal (superseded)

The earlier proposal consisted of the five-RPC forward migration and
the Angel validation patch. Production remained unchanged. Approval was requested
because the user's rule said **"Request approval before any potentially
destructive or incompatible database change."** The repair preserves valid
frontend contracts but rejects NULL inputs that the backend previously accepted,
which may affect other callers. No destructive migration was proposed. The later
request explicitly prohibits deployments; this earlier proposal is not active.
