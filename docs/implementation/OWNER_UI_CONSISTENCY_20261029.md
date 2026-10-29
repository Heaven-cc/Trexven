# TREXVEN Owner UI consistency corrections — 29 October 2026

Base: master at e8363528372ed34310b1bb0214e706fcef6dbd45.

## Scope

Correct the recording's Finance overflow and layout movement, mismatched initial loading states, startup transitions, notification status/content/density, money formatting, product-name space allocation, and Vision setup flow. Preserve employee screen naming (item 8), notification page titles (item 9), and branding (item 14). TREXVEN POS is not modified. The approved Billing glass background is preserved.

## Implementation

- Financial summary renders the same hero, breakdown, and metric-card structure while loading. Values are masked until the report completes. Insights no longer starts above missing cards.
- The line-chart loading state has natural height and no 160-pixel constraint. It follows the line-chart structure instead of rendering bars inside a card inside another card.
- Initial data screens use purpose-specific skeletons. The authenticated launch resolves through a noninteractive Home shell instead of another Flutter splash and a blank loading page; authorization still completes before business screens are constructed.
- Billing loads independent reads concurrently with a timeout, an existing retry state, and the existing disabled checkout state. It does not activate subscriptions or change prices.
- Notification icons reflect current read state. Opening a notification acknowledges it, timestamps are visible, and rows show employee/actor/change context. Failed acknowledgements remain visible and retryable. Account changes still hide original-account content.
- Production notification RPC enriches only already-authorized Owner staff events. It preserves notification keys, routes, page bounds, and per-user acknowledgements. Only a whitelist of audit metadata is returned. POS feed contents are unchanged.
- Home, Inventory, Finance, transaction previews and Billing use business currency formatting without conversion. Finance now carries the verified business currency with its report.
- Product rows allow two lines for names and give names more width; Inventory pagination and fixed actions remain.
- Cloud Vision setup removes device-side LAN/server-secret entry and duplicate setup actions. The release can configure VISION_CLOUD_URL, requiring public HTTPS, with business-scoped JWT requests. Existing device LAN preferences do not become the cloud endpoint.

## Backend verification

Production project: ufehcfrlygqvminfjumf. Migration: 20261029153746_owner_notification_context.sql.

- Authorized feed check returned 8 existing staff events with context; timestamps and personal read fields were preserved; employee routes were preserved.
- An unauthenticated Owner-feed request was rejected.
- Country Billing catalog returned Nigeria and six plan/cycle options; checkout_available remains false.
- Security advisor categories and counts were unchanged after the migration.

## Validation and remaining dependency

All 35 targeted regressions passed in GitHub Actions, including summary-position stability, chart skeleton overflow at large text sizes, reporting failures, currency handling, account isolation, notification acknowledgements, and cloud setup. Static analysis reports no errors (existing lint warnings remain). Android validation uses Java 17; Kotlin is updated to 2.2.20 to satisfy the current Flutter SDK while retaining AGP 8.11.1 and Gradle 8.14. Kotlin compatibility: https://kotlinlang.org/docs/gradle-configure-project.html. The Android debug build is being rechecked after this compatibility correction.

Dart formatter parsed changed sources and git diff --check passed. Targeted layout, notification, account-isolation, reporting, inventory and Vision checks plus an Android debug build are configured in the Owner UI consistency workflow. Record the workflow result before treating this as a verified release.

Local Flutter setup was blocked by automatic approval review when its environment detector attempted a cloud metadata request. Supabase CLI telemetry was also blocked; the migration was applied and verified through the connected Supabase API instead.

Cloud Vision has no deployed endpoint configured in the inspected backend. This change provides the cloud-only app flow and an honest unavailable state; it does not provision a server, invent an endpoint, or claim cameras are live. A deployed authenticated Vision service and its HTTPS URL remain necessary.
