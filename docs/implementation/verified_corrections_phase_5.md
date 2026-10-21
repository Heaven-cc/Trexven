# Verified corrections — Phase 5: country billing preparation

Status: database foundation deployed under explicit approval as 20261021012021_country_billing_foundation; Edge Functions NOT deployed.
Checkout, provider registration, payment verification and automatic activation remain disabled.
This phase is not runtime-complete and does not authorize a subscription charge.

## Defects and corrections

- The global subscription_plans row cannot represent independent monthly/yearly prices by country. Added an owner-scoped catalog and a separate (plan, country, cycle) configuration table with no seeded prices. Nigeria/NG/NGN, Ghana/GH/GHS, Togo/TG/XOF and Ivory Coast/CI/XOF remain separate keys.
- New country-session requests authorize the current owner through user_owns_business, whose current production definition also checks closed-account and administrative business restrictions. They validate against the business's stored country, lock the configured price and active plan, and preserve operation_replay/operation_save identity and payload checks.
- Store the amount, currency, country and monthly/yearly cycle in the billing session. The service-only exact-decimal snapshot RPC returns the amount as text. Existing sessions keep both new fields null.
- Activation preparation changes only the interval source: use the paid session's cycle, falling back to the existing global plan cycle for historical sessions. The approved live function's exact definition hash and service-only ACL are guarded before replacement. No invocation or subscription activation occurs in the migration.
- Owner Billing reads the new owner-scoped catalog. Only a missing-function PGRST202 permits a feature/history fallback; old global prices are hidden in that fallback. Authorization and network errors are not treated as configuration success.
- All three cards now offer monthly/yearly selection within the existing design. No invented introductory offer or renewal authorization appears. Checkout remains disabled and cancellation review/history/recovery links remain intact.
- Terms and Privacy open their existing screens using Navigator; no new dependency.
- Prepared Paystack adapter obtains authoritative snapshots server-side, uses exact integer arithmetic and a deterministic session reference, validates checkout host, checks HMAC SHA-512 over raw webhook bytes, independently verifies the transaction server-side and compares reference, metadata, amount, currency and test domain. Pending/abandoned/reversed payments never become verified.
- Prepared checkout handler validates a real caller with getUser, requires business ownership, rejects client price/email/target overrides, and calls the owner session RPC. It attaches the deterministic reference through the existing service-only enabled-provider gate BEFORE contacting Paystack. A timeout keeps the original request/reference; no replacement reference is manufactured.
- Prepared webhook delegates to the existing idempotent service-only billing event recorder. It deliberately does not call entitlement activation. Raw body size and provider fetch time are bounded. No credentials, tokens or payment bodies are logged.
- Release guard is a source constant false; adapter rejects live keys; global enabledBillingProviders remains empty. No prices, secrets or provider registration were written.

## Exact files

- lib/screens/me/billing_screen.dart
- lib/models/subscription_plan.dart
- supabase/migrations/20261021012021_country_billing_foundation.sql
- supabase/functions/_shared/paystack-provider.ts
- supabase/functions/_shared/paystack-server.ts
- supabase/functions/prepare-billing-checkout/index.ts
- supabase/functions/verify-paystack-billing/index.ts
- docs/implementation/verified_corrections_phase_5.md

## Compatibility and production evidence

Read current production billing table/column metadata and live request, attachment, activation and operation replay/save definitions and ACLs. Billing sessions have RLS enabled; authenticated has SELECT only, while service_role holds writes. Existing owner billing SELECT and account/admin policies are unchanged.

Production read-only baseline on 2026-10-21:
- Three global plans have null price, currency and interval.
- Provider configuration is empty.
- Billing sessions, payments and subscriptions each have zero rows.
- New country price table and exact-decimal snapshot function do not exist.
- Activation definition MD5: 8c8419cb8986887e151d1e257da64120.
- Activation ACL: postgres and service_role only.

Read current Owner BillingScreen, SubscriptionPlan, business onboarding country values, legal screens, provider foundation, entitlement helper and pubspec. POS has no matching billing/subscription/entitlement source paths. Existing checkout/sale, entitlement read, cancellation/history and POS permissions contracts are unchanged. No Owner operations package or POS source changed in this phase. No shared Flutter package was copied between apps.

## Provider facts and commercial blockers

Official documentation checked on 2026-10-21:
- https://paystack.com/docs/api/
- https://paystack.com/docs/api/transaction/
- https://paystack.com/docs/payments/webhooks/
- https://paystack.com/docs/payments/verify-payments/

Paystack specifies x100 for NGN/GHS and ALSO for XOF, despite XOF not allowing fractional base amounts. Its availability table lists Nigeria/NGN, Ghana/GHS and Côte d'Ivoire/XOF. Togo eligibility is not established by those docs. Togo pricing remains independently supported in the catalog, while this prepared Paystack adapter rejects TG.

Still required before any live checkout:
- Approved exact monthly/yearly prices for each plan/country and explicit publication.
- Verified merchant eligibility, market/account configuration and appropriate credentials supplied through secure deployment configuration.
- Approval and deployment of each prepared Edge Function (checkout verify_jwt=true; signed webhook verify_jwt=false).
- Separately approved removal of the disabled release guard, live-mode implementation/review, and provider registration.
- Durable frontend checkout journal, uncertain initialization/verification recovery and guarded URL launch before enabling the button.
- Separately approved entitlement activation and reconciliation. No callback/client success response may activate subscriptions.
- User acceptance on devices; no application build/analyzer/test suite or fake payment/authentication was run.

## Approved database production checkpoint

Deployed ONLY the exact approved country billing foundation SQL. It creates an empty server-managed pricing table, adds nullable session snapshot fields, creates the owner catalog/session and service snapshot RPCs, and changes activation's interval source with its previous fallback retained. It inserts no commercial values, enables no provider, activates no subscription, and deploys no Edge Function.

The exact approved SQL was applied once and promoted to its actual migration version. No earlier foundation SQL was replayed.

## Manual acceptance (user; not executed)

- Missing catalog backend: features, cancellation and billing history still load; pricing/checkout truthful.
- Each recognized business country uses its own country key; TG and CI never share a price row merely because both use XOF. Unknown country shows unavailable.
- All plans show monthly/yearly options; missing prices never become zero or free.
- Terms and Privacy open and return normally in all four existing themes.
- Later approved provider exercise: wrong owner/country, changed request payload, amount/currency/metadata mismatch, bad raw signature, pending/reversed status and wrong test/live domain must fail.
- Later approved recovery exercise: retain the original session/reference after uncertainty; duplicate events produce one recorded payment/invoice; no automatic subscription activation.

## Deployment evidence — 2026-10-21

Migration 20261021012021_country_billing_foundation succeeded. Before/after source/catalog comparison found 12 existing public API definitions and ACLs unchanged. Activation exactly matches the approved session-cycle change, with the same postgres/service_role-only ACL. Billing session table ACL and policies, all global plan records and empty provider configuration are unchanged.

All 15 checked row counts stayed unchanged: sales 4, sale_items 4, sale_payments 3, private.sale_requests 4, private.catalog_requests 7, inventory 0, inventory_movements 5, expenses 0, sale_returns 0, credit_entries 1, billing_sessions 0, billing_payments 0, billing_invoices 0, business_subscriptions 0, subscription_events 0.

New country pricing table has RLS enabled, zero rows and no anonymous/authenticated table access. Both new session snapshot columns are nullable without defaults. New catalog and request functions allow authenticated owners, deny anonymous execution and use an empty search_path. The exact-decimal snapshot is service-only; the private country normalizer is postgres-only and not SECURITY DEFINER. Catalog retains checkout_available=false. No runtime financial/authentication operation was exercised. Edge deployment, live release, pricing, credentials and device acceptance remain pending as described above.
