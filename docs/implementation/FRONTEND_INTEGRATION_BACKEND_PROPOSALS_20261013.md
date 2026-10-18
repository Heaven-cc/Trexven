# Backend proposals requiring separate approval

These are proposals only. This integration task did not add migrations, alter grants/RLS, deploy functions, or write shared application data. Existing locally prepared backend repairs remain local.

## Historical profit

The Owner now displays profit as unavailable. Neither current product cost nor zero is a valid substitute for missing historical costs.

Extend the existing atomic transaction implementation to record immutable cost-at-sale evidence on its existing sale items or a narrowly scoped associated record. Choose and document the costing policy first: weighted average, FIFO, or another supported inventory valuation policy. Record the policy/version, effective unit cost, source and currency/precision together with the original quantity. Capture this inside the same transaction as stock deduction. Client-supplied cost must never determine the snapshot.

Returns must reference the original sale item and reverse the attributable recorded cost under a documented treatment for damaged stock, restocking and partial returns. Supplier returns and adjustments require their own existing movement semantics; they must not silently rewrite a sale snapshot. Distinguish gross margin from profit after authorized expenses and other adjustments.

Expose an authorized server aggregate for the requested business/branch and UTC interval. Return sales, refunds, recognized cost, expenses, known/unknown coverage and the applicable definition. Preserve current restricted product-cost grants; the Owner screen must not gain general cost-column access. Explicitly represent historical unknown values and incomplete periods. Do not backfill old sales from today's costs. Any historical recovery must have auditable contemporaneous evidence and separate approval.

Approval needed: costing and return policy, additive storage/index design, aggregate signature, permitted roles and compatible migration. Required tests: atomic failure, idempotent checkout, fractional rounding, partial returns, cross-business/branch denial, unknown historical costs and DST interval boundaries.

## Safe expense posting

Authorized expense reads now use the existing `expenses` table, with business-scoped explicit fields and complete interval pagination. An arbitrary direct insert does not establish an operation receipt, idempotency or reliable cash/ledger posting. The existing backend offers no dedicated expense-posting RPC identified by the audit. Expense entry remains unavailable.

Propose one additive authorized RPC around the existing expense persistence and operation registry. Accept business, permitted branch, stable request ID, amount, category, description, payment method and an explicitly defined posting date/time. Require exact request-payload identity on replay; reject changed payloads under the same key. Derive actor and permissions from authenticated server context. Apply existing cash register/shift restrictions when money leaves a drawer and integrate the existing financial audit/ledger workflow in one database transaction. Do not create another expense table or ledger. Return the existing recovery receipt shape with the expense identifier.

Define whether a posting can be backdated, who can do it, and whether `created_at` remains an audit timestamp while a separate effective timestamp controls reporting. Define permitted categories, positive monetary precision, source evidence, currency and reversal permissions. Reversals should be append-only/auditable, not deletion of posted financial history. If interval totals move server-side, add an authorized aggregate or compatible summary field rather than a second reporting service.

Approval needed: RPC signature and posting/reversal rules, minimal compatible storage changes if needed, and grants using existing authorization helpers. Required tests: duplicate/changed payload, lost-response recovery, cash-shift enforcement, branch/role denial, atomic ledger failure, backdating and reversal reporting.

## Duplicate-safe Angel message recovery

The existing Angel request has no per-message request ID. Creating an explicit client UUID conversation prevents accidental reuse of the latest conversation, but does not make sends idempotent. The client now makes one send attempt and offers history refresh after an uncertain result. It never uses message text to deduplicate or silently retries the provider request.

Propose an optional additive `request_id` for sends, scoped to authenticated user, business and authorized conversation. Persist the exact immutable payload identity, conversation, status, user-message identity and stored final response. Enforce uniqueness on the full scope and reject a different payload under the same request ID. Repeated completed requests return the stored response without another user message or provider call. Preserve current response fields and support older clients without falsely claiming they are idempotent.

Use an atomic admission/lease to prevent concurrent provider calls. Persist message and operation transitions transactionally. A provider timeout after dispatch is an unknown outcome: an expired lease alone must not trigger automatic duplicate billing or another send. Unless the provider supports a verified idempotency/lookup contract, return an explicit unresolved state requiring review. Supply an authorized status/history lookup so clients can recover without invoking the provider. Keep conversation ownership checks and message RLS intact; never key solely on message text or accept user/role claims from the client.

Approval needed: additive request/status persistence, indexes and backward compatible Edge/status contract. Required tests: concurrent duplicate admission, payload conflict, account/business/conversation denial, response replay, crash before dispatch, crash after provider dispatch and partial message persistence. Live Groq behavior remains unverified in this task.

## Other boundaries

- **Remember me:** Login currently toggles only local widget state. Supabase initialization uses one application-wide persisted session store, and AccountGate reacts to that session. A distinct temporary versus remembered session policy requires deliberate changes to auth initialization/storage, restart behavior and Google/email callback restoration. No raw passwords should be stored. The approved authentication files were preserved; no new Remember me policy was implemented.
- **Branches:** The current Owner routes supply no authoritative selected branch. Checkout preserves `p_branch_id: null` and existing server restrictions. Branch-enabled businesses must retain their backend enforcement; supporting branch selection/context or changing the operational notification branch contract is a separate approved extension. No branch security exception was added.
- **Live checks:** Staging/production deployment, real camera devices, live payments/settlement and Groq calls require separate authorized verification. Manual terminal/transfer evidence records user confirmation, not verified external settlement.

No proposal is an authorization to execute it.
