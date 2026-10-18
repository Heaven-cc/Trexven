# TREXVEN onboarding rollback and app cleanup

## Onboarding restored

- Restored the original welcome copy and layout, inline business address/phone fields, and Create Business action.
- Restored the completion screen with Go to Dashboard. Removed the progress checklist and first-product detour.
- Removed the added setup-progress widget, redesign-specific tests/report, and inventory empty-state onboarding action.
- Retained submission guards, mounted checks, and existing business-creation RPC behavior.

## App responsiveness changes

- Finance previously created sales/revenue futures inside build, restarting requests on unrelated rebuilds. Futures now remain stable until an explicit refresh or return from Record Sale.
- Replaced Finance's nested shrink-wrapped transaction list with lazy slivers in one scroll view.
- Added pull-to-refresh, a 20-second request timeout, visible failure messages, and retry. Concurrent refresh gestures reuse the active refresh.
- MainScreen now rebuilds for alert polling only when the unread badge count changes. Alert contents and notification handling still update through the alert service.
- Reduced the splash delay from 2.2 seconds to the existing animation's 0.9 seconds.
- Removed an unused Billing build variable and an obsolete inventory test import.

Existing sale reliability, product-selector/freezing repairs, and density improvements were preserved. This change does not modify POS, database schemas, dependencies, or business rules.

## Verification

- Full Flutter test suite: 61 passed, including sale submission/retry guards, inventory/restock selection, loading/error recovery, density, startup, and the new Finance tests.
- Finance tests verify that theme rebuilds do not repeat database requests, explicit refresh does, errors recover through retry, and the final transaction remains reachable by scrolling.
- Flutter analysis: no errors or warnings; 210 informational style/deprecation notices remain.
- Android ARM64 debug APK build: successful (`build/app/outputs/flutter-apk/app-debug.apk`).
- No device frame-timing profile was performed for this cleanup. Reduced requests and widget work are verified; measured on-device frame rate is not claimed.
