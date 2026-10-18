# TREXVEN unified frontend handover

TREXVEN Owner, POS and their shared operational screens now consume one Flutter design package. Both apps retain their separate application structure and supported workflows. The design is compact, primarily borderless and adaptive to brightness, keyboard space and system text scaling.

## Delivered architecture

The canonical package is [trexven_design_system](C:/Users/USER/AndroidStudioProjects/Trexven/packages/trexven_design_system/README.md). Its public library exports named color, typography, spacing and radius tokens; light/dark themes; persistent-label inputs; rich dropdowns; buttons; header actions; cards; dialogs; bottom sheets; loading/empty/error states; and date/form-section components.

Owner, POS and operations import that package directly. Numeric, currency, password and multiline inputs use the same field implementation with their original keyboard, formatter, validator and controller configuration. Search and Angel chat use intentional variants. Native Material components inherit the canonical component themes.

| Consumer | Relative dependency | Presentation coverage |
|---|---|---|
| Owner | packages/trexven_design_system | Auth, setup, dashboard, inventory/catalog, restock, finance, employees, billing, profile/settings, Angel and Intelligence/Vision UI |
| POS | ../Trexven/packages/trexven_design_system | Auth/business selection, dashboard, search/scanner, Quick Add/catalog editor, cart/checkout, sales/receipts, employee/settings UI |
| Shared operations | ../trexven_design_system | Business operations, inventory operations, credit/returns/refunds, cash shifts, employee access/permissions, notifications and payment confirmation |

Release jobs must retain the sibling Owner/POS checkout layout and use matching revisions, as already required by trexven_operations. There are no absolute paths in production package dependencies. Development-machine font paths appear only in screenshot tests and are optional.

## Before replacement: dependency map

- Owner main and screens depended on core/app_theme.dart, its TrexvenColors extension, core/app_sizing.dart and widgets/trexven_widgets.dart. The shared pressable/button/settings widgets were moved into the package before callers were migrated.
- POS main declared its own light/dark ThemeData and screen-local color palettes; individual forms supplied different padding, floating labels, borders and radii.
- Shared operations used native Material inputs and dialogs inherited from whichever app hosted them.
- Controllers, validators, providers, navigation destinations and service interfaces stayed with the apps. Theme tokens and visual components moved into the package. All callers were migrated before obsolete files were removed.

## Form and layout changes

The common defaults are 16dp page padding, 14sp labels, 16sp inputs, 8dp label gaps, 16dp field gaps, 24dp section gaps, 14dp field radii, 16dp card radii and 48dp minimum targets. Normal single-line fields fit 48–56dp. Inputs, error messages, actions and rich product selections may grow.

Owner Login and registration use wrapping secondary actions; reset-password content scrolls with the keyboard. Search fields use minimum height instead of fixed height. Primary actions inherit readable light/dark foreground colors. Painted list-tile containers now provide a Material ancestor so feedback remains visible.

Checkout quantity controls have 48dp targets. Item details, quantity, totals and payment options can wrap. Checkout keeps its footer in ordinary layouts and scrolls the full page when text is enlarged or vertical space is limited. Product names are readable without forcing the controls off-screen.

Owner navigation remains Home / Inventory / Finance / Intelligence / Me. Angel remains in the header beside the notification bell, with a compact icon action on constrained layouts. Manage Subscription remains the single billing destination. POS navigation remains role-aware.

## Requested restock selling price

The original source snapshot had product selection, received quantity, stock preview and update action, but no editable selling-price field. The requested field is now implemented with the same shared field style; no purchase-price field was added.

Restock reuses the existing partial catalog-update API for selling price and the existing idempotent stock-adjustment API. It sends a price update only when the selected price changes. The submitted product, quantity and price are frozen for retries. Price and stock use distinct stable request IDs. A rejected price prevents the stock call; a confirmed price is not submitted again when stock needs retrying. Validation rejects negative/non-finite prices and more than two decimal places. Blank retains the catalog's pending-price behavior.

The existing backend offers separate price and stock operations, so this workflow is not one atomic database transaction. If price succeeds and stock cannot be confirmed, the form explicitly preserves that partial state and offers the original retry. Tests verify this sequence. No schema, RPC signature or service implementation was changed.

## Removed and preserved source

Removed after migration:

- lib/core/app_theme.dart
- lib/core/app_sizing.dart
- lib/widgets/trexven_widgets.dart

The [changed-file manifest](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/design_system/CHANGED_FILES.md) lists the migrated source, shared package, tests, manifests and deletions. The [source audit](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/design_system/source-audit.json) reports no obsolete theme/sizing imports, no raw form controls or app-local theme declarations, and no unlabelled ordinary field calls detected by its structural scan. It compares backend call expressions with the original snapshot, explicitly accounting for the requested restock price call. Fifty-three nonpresentation Dart sources were preserved byte for byte. The audit is a targeted check, not a proof of every runtime behavior.

No backend schema, RLS, Edge Function, auth contract, financial calculation, ODT Vision processing or production data was edited by this task. The workspace already contained unrelated changes; the manifest uses the task-start snapshot rather than attributing all Git changes to this task.

## Visual evidence

These are actual Flutter widget renders at 390dp width in both themes. Original source was rendered in isolated temporary baseline checkouts, which have been removed. Arial and MaterialIcons are loaded as screenshot fixtures to replace Flutter test block glyphs; before and after use the same fixture. These are widget screenshots, not device captures or pixel-perfect font approval.

| Screen | Before light | After light | Before dark | After dark |
|---|---|---|---|---|
| Owner Login | [PNG](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/design_system/before/owner-login-light.png) | [PNG](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/design_system/after/owner-login-light.png) | [PNG](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/design_system/before/owner-login-dark.png) | [PNG](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/design_system/after/owner-login-dark.png) |
| Business Setup | [PNG](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/design_system/before/owner-setup-light.png) | [PNG](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/design_system/after/owner-setup-light.png) | [PNG](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/design_system/before/owner-setup-dark.png) | [PNG](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/design_system/after/owner-setup-dark.png) |
| Add Camera | [PNG](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/design_system/before/owner-camera-light.png) | [PNG](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/design_system/after/owner-camera-light.png) | [PNG](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/design_system/before/owner-camera-dark.png) | [PNG](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/design_system/after/owner-camera-dark.png) |
| POS Login | [PNG](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/design_system/before/pos-login-light.png) | [PNG](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/design_system/after/pos-login-light.png) | [PNG](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/design_system/before/pos-login-dark.png) | [PNG](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/design_system/after/pos-login-dark.png) |

## Verification

Final runs passed on 2026-10-10. Formatting was applied to migrated UI, shared components and adapted tests.

| Check | Final result | Evidence |
|---|---|---|
| Formatting verification | 90 migrated/package source files checked; 0 changes required | [Log](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/design_system/format-check.txt) |
| Owner full test suite | 163 passed | [Log](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/design_system/owner-tests-final.txt) |
| POS full test suite | 116 passed, 1 skipped | [Log](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/design_system/pos-tests-final.txt) |
| Owner analyzer, including shared packages | 0 errors, 0 warnings; 117 informational lints | [Log](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/design_system/owner-analyze-final.txt) |
| POS analyzer | 0 errors, 0 warnings; 65 informational lints | [Log](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/design_system/pos-analyze-final.txt) |
| Actual screenshot capture tests | Owner 6 passed; POS 2 passed | [Owner log](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/design_system/owner-capture.txt), [POS log](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/design_system/pos-capture.txt) |
| Source audit | Passed; no obsolete references, raw form controls, unlabelled ordinary fields or unexpected scanned backend-call changes | [JSON](C:/Users/USER/AndroidStudioProjects/Trexven/docs/implementation/design_system/source-audit.json) |

Both app runs used `flutter test --no-pub --reporter expanded` and `flutter analyze --no-pub --no-fatal-infos`. On this Windows host the Flutter tools snapshot was invoked with the bundled Dart SDK to avoid the launcher issue. The informational lints remain, primarily existing flow-control/style and deprecated framework API notices; the analyzer is not represented as completely lint-free. POS's skipped test requires an explicitly disposable live fixture, which was not supplied or mutated.

Shared-package dependencies resolved with offline pub get in both apps. No package/library upgrade was needed. Form-validation tests also assert that rendered validation messages have no line cap, so error text grows instead of being truncated at large text scales.

Layout matrices exercise 320/340/390dp, scales 1/1.3/2, both themes and keyboard insets. They cover shared fields, dropdown selection, retained values, validation, Owner Login/registration/setup/camera/new product/restock, POS Login/Quick Add and populated Checkout. Existing suites additionally exercise navigation, sales, receipt recovery, employee permissions, billing, stock/inventory operations, finance, notifications and durable offline state with synthetic services.

## Remaining limits

- No physical device, emulator, APK/release build or live backend mutation was performed. Native keyboard/autofill, camera/scanner video and platform-specific rendering need device QA.
- Screenshot coverage is representative. Every migrated screen was checked structurally and analyzed, but every live-data, dialog and deeply nested workflow was not visually captured at every scale.
- Camera/scanner guides, media overlays, brand artwork, pill/status badges and data-visualization composition intentionally retain specialized visuals using shared tokens where applicable.
- Existing duplicate Google sign-in controls and the existing Google setup behavior on Owner auth screens were preserved; changing that workflow was outside the styling task.
- Analyzer informational lints and the deliberately skipped disposable-live-fixture test are reported with the final verification results rather than hidden.

Supabase integration review used the [Supabase skill](C:/Users/USER/.codex/plugins/cache/openai-curated-remote/supabase/1.0.0/skills/supabase/SKILL.md), the local existing catalog function, and [official Dart RPC documentation](https://supabase.com/docs/reference/dart/rpc). The markdown changelog fetch was unsupported by the web reader; no new Supabase API or library version was introduced.
