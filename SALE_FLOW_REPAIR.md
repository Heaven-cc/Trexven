# Sale flow repair — 5 October 2026

## Causes

Record Sale created a new async product stream inside every build. Selection and quantity updates therefore restarted the subscription/business lookup. Fresh stream rows were new Product objects, while the dropdown identified its selection by object identity. Its dense field also could not fit the two-line selected product content. The screen now caches its stream, resolves current selection by product ID, and reserves sufficient field/menu height.

POS sent display labels (`Cash`, `POS Terminal`, `Transfer`) to a function/database constraint accepting `cash`, `card`, `bank_transfer`. Every offered payment option failed that validation. A generic error hid the reason. Exact SQL decimal totals could also reject binary floating-point artifacts; client totals now follow the database's two-decimal money precision.

The initial UI failures were different. Both flows shared a missing capability: the backend had no request identity, so a successful commit followed by a lost response could be submitted again. POS discarded its generated request UUID and the original function returned no receipt.

## Final flow

1. Record Sale uses the account's business; POS uses the signed-in employee's business-membership ID. Client validation rejects invalid quantities/prices and empty carts.
2. Both send `submit_trexven_sale` with a UUID request key, business, employee (null for quick sales), total, canonical payment method, and items.
3. The public function is an invoker wrapper. Its private transaction checks authentication, active business access, and sale permission before reading retry data. An advisory transaction lock serializes matching requests. The private ledger has RLS enabled and no client table privileges.
4. Existing validated transaction bodies continue enforcing current product prices, available stock, session/employee matching, discounts, and exact item totals. Sales, sale_items, products.quantity, payment method, receipt number, and the retry result commit together. A failure rolls all of them back.
5. Matching retries return the saved receipt snapshot. Reusing a key with changed details is rejected. UI guards prevent repeated taps; uncertain outcomes retain the original request and disable editing/leaving until an identical retry resolves it. POS clears the cart only after confirmation and displays persisted receipt items, payment, total, and sale ID. Record Sale displays the persisted receipt reference.

The schema records payments through sales.payment_method and the completed sale total; there is no separate payments table or payment-gateway charging flow. Stock in both existing apps comes from products.quantity; the separate inventory table is not their checkout stock source. No parallel stock or payment writes were added.

## Deployment and verification

Applied `20261005004045_sale_submission_reliability` to the shared Supabase project. Legacy RPC signatures remain compatible. The migration was first tested inside a rolled-back transaction, then its regression test was repeated against the deployed functions.

- Trexven: **36 tests passed** with `flutter test --no-pub`.
- POS: **10 tests passed** with `flutter test --no-pub`.
- Widget tests cover product selection, fresh stream rows, quantity controls, repeated taps, actionable errors, uncertain-response retry identity, stock updates arriving before retry, cart clearing, and receipt display.
- HTTP tests cover request structure, all three payment labels, canonical values, receipt parsing, and unchanged retry requests.
- Live database regression tests cover quick/POS sale creation, saved items/receipts, cash/card/transfer recording, stock changes, discount/repeated lines, identical retries, changed-payload rejection, and atomic rollback for invalid totals, oversells, stale prices, wrong employees, and foreign accounts.
- Existing backend transaction tests also passed, covering legacy sales, tenant isolation, onboarding, and suspension/reactivation.
- Changed code compiles in tests; targeted static analysis reports no errors/warnings. Trexven retains existing informational style/deprecation notices.

Database fixtures were rolled back; verification left no test sales or stock changes. Security advisors add only the intentional [RLS-without-policy information](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy) for the private deny-by-default retry ledger. Existing public-definer/password-protection advisories are unrelated to this repair.

Verification used widget tests, mocked HTTP transport, and live authenticated-role database transactions. A physical-device session spanning live UI/auth/HTTP was not run, and updated APKs were not installed. Fresh offline dependency resolution is blocked by the existing video_player 2.14.0 constraint/cache; checks used the existing package configuration. Existing installations require rebuilding with these client changes. Retry identity is retained for the active form/cart, not persisted across application termination.
