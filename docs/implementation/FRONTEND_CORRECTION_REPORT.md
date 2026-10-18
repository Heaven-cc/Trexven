# TREXVEN frontend correction report — 10 October 2026

Status: frontend corrections implemented and verified locally. Personal-device visual and workflow acceptance remains pending. This report does not certify completion of the entire Master Implementation Specification.

## Scope and inspection evidence

Read the frontend execution directive, both master specification files, the supplied Dashboard screenshot `1000210561.jpg`, the existing application navigation and repositories. The Billing and My Profile reference screenshots were requested but have not been supplied in this working context. They were not treated as inspected.

The source inventory covers 142 Dart files, including 57 Owner/shared screen files and 13 POS screen files. All were read by the inventory pass; manual investigation concentrated on navigation, Dashboard/product grants, Profile, Billing, Angel, shared financial/inventory/access forms and POS product/checkout flows. Per-screen source findings and route references are recorded in [frontend_screen_audit.json](evidence/frontend_screen_audit.json). Source inspection is distinguished from executed widget tests and physical-device interaction. The initial inventory snapshot was captured after the first small priority corrections; it is not a pristine repository snapshot. Earlier staged/unstaged work was preserved.

## Implemented corrections

### Dashboard

Read-only production catalog inspection on `ufehcfrlygqvminfjumf` confirmed that authenticated users lack table-wide product SELECT, while individual columns are readable except `cost_price`. The detailed dashboard used SELECT *, causing the screenshot's 42501 error. It now reuses the existing business-scoped, explicitly allowed catalog projection, including its legacy-column compatibility fallback. No broad grants, RLS bypass or service credential was introduced. [Read-only grant evidence](evidence/frontend_dashboard_grants.json).

Product and detailed dashboard sales reads now use ordered pages so totals do not stop at the default PostgREST row cap. A failed page rejects the load instead of showing partial totals. Tests exercise 1,001 products and 501 sales, the forbidden-column scenario, and business filters on every request. Low-stock counts include empty active, priced products and exclude inactive/unpriced products. Existing zero-priced products remain valid and unchanged. Unqueried pending/failed transaction counters were removed from the expanded view. Currency uses the selected business; the misleading LIVE badge became TODAY. Failure UI uses readable messages, preserving actual failure state.

Sales Today, Transactions, Stock Value, Low Stock, Products, quick actions, insights, owned-business selection, Angel, notifications and the established five bottom destinations remain connected. Existing device-local dashboard day boundaries were preserved; business-timezone/day-boundary behavior is a separate compatibility limitation and is not certified for owners travelling across timezones. Existing financial business-day RPC paths were preserved.

### Compact borderless presentation

Ordinary Owner cards and normal input states use surface contrast and rounded corners. Focus/error/selection indicators and existing live-feed overlays retain their meaningful states. Shared actions use a minimum 48px target and grow with text. KPI padding/type, app-bar titles and Angel access were reduced. No hard fixed height was added to multi-line content.

Profile now has a 44px avatar, compact heading, a validated full-name field, real read-only account email, a guarded Save Changes action, scrolling/keyboard handling and clear actual save feedback. It retains the existing metadata update path and removes its duplicate Billing entry.

### Canonical subscription destination

`Me -> Manage Subscription -> Billing & Plans` is the sole BillingScreen navigation entry. Manage Subscription displays the actual configured START/CORE/PRO plan beside the tile; unenrolled owners see No active subscription. The one Billing implementation reads the existing plan catalog, entitlement RPC and billing history. Compact plan cards show human-readable features and current-plan state. Nullable commercial values remain nullable; no price or quota was invented. Upgrades are disabled with Plan upgrades are not available yet. Existing cancellation requests retain their review/journal contract and do not falsely report cancellation complete. Enrollment/non-enrollment widget tests verify the actual screen's HTTP contract and prohibit charging requests.

### Angel

Pinned maintained `flutter_markdown_plus` 1.0.12; only the Markdown renderer and its Markdown dependency were added. Assistant text uses a selectable MarkdownBody with paragraphs, emphasis, headings, lists/checklists, inline/fenced code, blockquotes, links and tables. Code/tables scroll horizontally in narrow bubbles. Responses can be copied completely. Safe link handling permits HTTP/HTTPS URLs with a host and rejects active/local schemes and credential-bearing URLs. AI-supplied image URLs are not automatically fetched. Input/suggestions/send controls retain loading guards, visible feedback and bottom safe area. Stored history, API payloads, conversation identifiers and returned response content are preserved. Connectivity/service failures remain distinct from rendering and are not fabricated as answers.

Renderer documentation: https://pub.dev/packages/flutter_markdown_plus and https://pub.dev/documentation/flutter_markdown_plus/latest/.

### Other Owner/shared screens and POS

CustomerPresentation centralizes human role/feature/status labels, money/date formatting and safe error messages. Identified raw SQL/Auth/exception dumps, developer-facing backend readiness messages and unformatted reconciliation maps were corrected. Local import/payment validation stays actionable. CSV/Excel import accepts readable headings while preserving legacy headings, leading-zero barcodes, decimal-unit rules and canonical request fields; review is guarded against repeated requests. Blank update prices are correctly described as preserved, rather than pending.

Shared stocktake, return, finance, cash drawer, employee permission and account/recovery presentation uses readable states. Payment-method dropdowns serialize the existing cash/bank_transfer/card values. Actual confirmations and retained financial requests are preserved; no false success is shown on failure. Events, Alerts and Recordings remain separate. Only existing Vision display labels/errors were refined; no processing/control infrastructure was activated.

POS price-load failures now retry on the selected product rather than requiring navigation back. Tests reproduced small-screen/enlarged-text overflow; search/empty/error content now scrolls and price cards wrap. Product selection -> failed price load -> retry -> add to cart -> return to the same search list is tested at 320px and 1.0/1.6 text scales. Product identity, stock and request/cart behavior are preserved. Checkout/recovery errors are readable and do not expose database internals.

## Executed verification

| Check | Result | Exit |
| --- | --- | --- |
| Complete Owner Flutter suite | 99 passed, 0 failed, 0 skipped | 0 |
| Complete POS Flutter suite | 78 passed, 0 failed, 1 skipped | 0 |
| Owner Flutter analysis | 260 informational findings; 0 warnings, 0 errors | 1 |
| POS Flutter analysis | 69 informational findings; 0 warnings, 0 errors | 1 |
| Formatting check | 70 modified Dart files; 0 changes remaining | 0 |
| Canonical Billing navigation search | One construction in Me; one implementation | 0 |
| Raw exception interpolation scan | No identified visible $e/$error/$ex/$failure interpolation in the 70 screen files | 0 |
| Frozen candidate integrity | All 280 packaged file hashes and original manifest hash match | 0 |
| Current backend source comparison | 19 frozen migration/Edge source hashes match | 0 |

The skipped POS restart integration test requires an explicit disposable live fixture and LIVE_RESTART_PHASE. It was not executed in this frontend task and is not claimed passed. Persisted-journal and offline queue unit/regression coverage ran in the full suites. No physical-device, Google sign-in, provider payment, production RPC write, install/update or real-camera acceptance test was performed.

Analysis is not clean: the informational style/deprecation findings above remain. Initial checks exposed duplicate Theme arguments and analysis of archived POS copies under Owner, plus regression/test-fixture and narrow-screen failures. The duplicate arguments and actual layout defects were corrected, the immutable release archive was excluded from active-app analysis, and the final suites/checks were rerun. The former 56px layout assertion and uppercase status expectation were updated to the approved compact target and readable status. Older failed logs remain as development evidence, not final success evidence.

Final logs: [Owner tests](evidence/frontend_owner_tests.log), [POS tests](evidence/frontend_pos_tests.log), [Owner analysis](evidence/frontend_owner_analysis.log), [POS analysis](evidence/frontend_pos_analysis.log), [format check](evidence/frontend_format_check.log), [machine-readable results](evidence/frontend_verification_results.json).

## Visual evidence and remaining acceptance

[Profile](evidence/frontend_previews/profile.png), [plan component](evidence/frontend_previews/billing_plan.png) and [Angel Markdown](evidence/frontend_previews/angel_markdown.png) were rendered from actual widgets at 390×844 with synthetic display fixtures and inspected. The plan image is a component preview, not a fully authenticated device Billing screenshot. Test captures use a controlled Arial substitution for test text families and Flutter Material icons; typography on an Android device must still be compared with actual Roboto rendering. No customer records were used in these images.

Personal-device checks remain for all listed routes: authenticated Dashboard retry/refresh and business selection, daylight/dark themes, system font sizes and keyboard/insets, actual subscription retrieval, Profile save, Angel history/connectivity/Markdown/link opening, camera/event/alert/recording navigation and playback, employee/inventory forms, sales/receipt confirmations, and offline recovery across app updates. Billing/Profile reference screenshots remain unavailable. Do not treat these source/widget results as full device visual sign-off or complete master-plan acceptance.

There is no backend authorization blocker for the specific product-column failure and no production correction is proposed by this frontend pass. No production schema, migrations, Edge Functions, ODT Vision services/models/pipelines, charging configuration or branch activation was changed. No APK/AAB was built, no app was published or installed, and no Google sign-in functionality was added. Existing subscription charging/providers/branch workflows remain as previously configured. Flutter application source changes now differ intentionally from the old frozen backend candidate; that candidate was not edited or regenerated.

## Every screen file inspected

The inventory below is source-level inspection. Runtime coverage is limited to the executed tests described above; physical-device verification is pending for every screen.

| App | Screen source | Source correction status |
| --- | --- | --- |
| owner | [lib/screens/auth/forgot_password_screen.dart](../../lib/screens/auth/forgot_password_screen.dart) | Inspected; existing flow preserved; device check pending |
| owner | [lib/screens/auth/login_screen.dart](../../lib/screens/auth/login_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/auth/register_screen.dart](../../lib/screens/auth/register_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/auth/reset_password_screen.dart](../../lib/screens/auth/reset_password_screen.dart) | Inspected; existing flow preserved; device check pending |
| owner | [lib/screens/dashboard/angel_screen.dart](../../lib/screens/dashboard/angel_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/dashboard/dashboard_screen.dart](../../lib/screens/dashboard/dashboard_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/finance/finance_tab.dart](../../lib/screens/finance/finance_tab.dart) | Inspected; existing flow preserved; device check pending |
| owner | [lib/screens/finance/operational_finance_screen.dart](../../lib/screens/finance/operational_finance_screen.dart) | Inspected; existing flow preserved; device check pending |
| owner | [lib/screens/finance/record_sale_screen.dart](../../lib/screens/finance/record_sale_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/intelligence/add_camera_screen.dart](../../lib/screens/intelligence/add_camera_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/intelligence/alerts_screen.dart](../../lib/screens/intelligence/alerts_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/intelligence/camera_alert_screen.dart](../../lib/screens/intelligence/camera_alert_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/intelligence/camera_detail_screen.dart](../../lib/screens/intelligence/camera_detail_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/intelligence/camera_event_screen.dart](../../lib/screens/intelligence/camera_event_screen.dart) | Inspected; existing flow preserved; device check pending |
| owner | [lib/screens/intelligence/camera_intelligence_screen.dart](../../lib/screens/intelligence/camera_intelligence_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/intelligence/camera_screen.dart](../../lib/screens/intelligence/camera_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/intelligence/event_detail_screen.dart](../../lib/screens/intelligence/event_detail_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/intelligence/events_screen.dart](../../lib/screens/intelligence/events_screen.dart) | Inspected; existing flow preserved; device check pending |
| owner | [lib/screens/intelligence/intelligence_tab.dart](../../lib/screens/intelligence/intelligence_tab.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/intelligence/live_feed_screen.dart](../../lib/screens/intelligence/live_feed_screen.dart) | Inspected; existing flow preserved; device check pending |
| owner | [lib/screens/intelligence/recording_playback_screen.dart](../../lib/screens/intelligence/recording_playback_screen.dart) | Inspected; existing flow preserved; device check pending |
| owner | [lib/screens/intelligence/recordings_screen.dart](../../lib/screens/intelligence/recordings_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/intelligence/vision_server_screen.dart](../../lib/screens/intelligence/vision_server_screen.dart) | Inspected; existing flow preserved; device check pending |
| owner | [lib/screens/inventory/add_product_screen.dart](../../lib/screens/inventory/add_product_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/inventory/catalog_editor_screen.dart](../../lib/screens/inventory/catalog_editor_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/inventory/catalog_import_screen.dart](../../lib/screens/inventory/catalog_import_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/inventory/inventory_tab.dart](../../lib/screens/inventory/inventory_tab.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/main_screen.dart](../../lib/screens/main_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/me/about_screen.dart](../../lib/screens/me/about_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/me/add_employee_screen.dart](../../lib/screens/me/add_employee_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/me/appearance_screen.dart](../../lib/screens/me/appearance_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/me/billing_screen.dart](../../lib/screens/me/billing_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/me/business_profile_screen.dart](../../lib/screens/me/business_profile_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/me/data_backup_screen.dart](../../lib/screens/me/data_backup_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/me/edit_employee_screen.dart](../../lib/screens/me/edit_employee_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/me/employee_confirmation_screen.dart](../../lib/screens/me/employee_confirmation_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/me/employee_details_screen.dart](../../lib/screens/me/employee_details_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/me/employment_screen.dart](../../lib/screens/me/employment_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/me/help_support_screen.dart](../../lib/screens/me/help_support_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/me/me_tab.dart](../../lib/screens/me/me_tab.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/me/notifications_settings_screen.dart](../../lib/screens/me/notifications_settings_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/me/permissions_screen.dart](../../lib/screens/me/permissions_screen.dart) | Inspected; existing flow preserved; device check pending |
| owner | [lib/screens/me/privacy_policy_screen.dart](../../lib/screens/me/privacy_policy_screen.dart) | Inspected; existing flow preserved; device check pending |
| owner | [lib/screens/me/profile_screen.dart](../../lib/screens/me/profile_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/me/security_screen.dart](../../lib/screens/me/security_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/me/terms_of_service_screen.dart](../../lib/screens/me/terms_of_service_screen.dart) | Inspected; existing flow preserved; device check pending |
| owner | [lib/screens/setup/business_setup_screen.dart](../../lib/screens/setup/business_setup_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/setup/setup_complete_screen.dart](../../lib/screens/setup/setup_complete_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [lib/screens/splash_screen.dart](../../lib/screens/splash_screen.dart) | Inspected; existing flow preserved; device check pending |
| owner | [lib/screens/welcome_screen.dart](../../lib/screens/welcome_screen.dart) | Inspected; existing flow preserved; device check pending |
| owner | [packages/trexven_operations/lib/src/account_operations_screen.dart](../../packages/trexven_operations/lib/src/account_operations_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [packages/trexven_operations/lib/src/cash_shift_screen.dart](../../packages/trexven_operations/lib/src/cash_shift_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [packages/trexven_operations/lib/src/employee_access_screen.dart](../../packages/trexven_operations/lib/src/employee_access_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [packages/trexven_operations/lib/src/financial_operations_screen.dart](../../packages/trexven_operations/lib/src/financial_operations_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [packages/trexven_operations/lib/src/inventory_operations_screen.dart](../../packages/trexven_operations/lib/src/inventory_operations_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [packages/trexven_operations/lib/src/notification_center_screen.dart](../../packages/trexven_operations/lib/src/notification_center_screen.dart) | Presentation/data-access correction applied; device check pending |
| owner | [packages/trexven_operations/lib/src/operational_permissions_screen.dart](../../packages/trexven_operations/lib/src/operational_permissions_screen.dart) | Presentation/data-access correction applied; device check pending |
| pos | [lib/src/features/auth/business_selection_screen.dart](../../../trexvenpos/lib/src/features/auth/business_selection_screen.dart) | Inspected; existing flow preserved; device check pending |
| pos | [lib/src/features/auth/login_screen.dart](../../../trexvenpos/lib/src/features/auth/login_screen.dart) | Inspected; existing flow preserved; device check pending |
| pos | [lib/src/features/inventory/catalog_edit_screen.dart](../../../trexvenpos/lib/src/features/inventory/catalog_edit_screen.dart) | Presentation/data-access correction applied; device check pending |
| pos | [lib/src/features/inventory/product_detail_screen.dart](../../../trexvenpos/lib/src/features/inventory/product_detail_screen.dart) | Presentation/data-access correction applied; device check pending |
| pos | [lib/src/features/inventory/product_search_screen.dart](../../../trexvenpos/lib/src/features/inventory/product_search_screen.dart) | Presentation/data-access correction applied; device check pending |
| pos | [lib/src/features/inventory/quick_add_screen.dart](../../../trexvenpos/lib/src/features/inventory/quick_add_screen.dart) | Inspected; existing flow preserved; device check pending |
| pos | [lib/src/features/inventory/scanner_screen.dart](../../../trexvenpos/lib/src/features/inventory/scanner_screen.dart) | Inspected; existing flow preserved; device check pending |
| pos | [lib/src/features/pos/checkout_screen.dart](../../../trexvenpos/lib/src/features/pos/checkout_screen.dart) | Presentation/data-access correction applied; device check pending |
| pos | [lib/src/features/pos/dashboard_screen.dart](../../../trexvenpos/lib/src/features/pos/dashboard_screen.dart) | Presentation/data-access correction applied; device check pending |
| pos | [lib/src/features/pos/employee_settings_screen.dart](../../../trexvenpos/lib/src/features/pos/employee_settings_screen.dart) | Inspected; existing flow preserved; device check pending |
| pos | [lib/src/features/pos/offline_cash_screen.dart](../../../trexvenpos/lib/src/features/pos/offline_cash_screen.dart) | Presentation/data-access correction applied; device check pending |
| pos | [lib/src/features/pos/operations_screen.dart](../../../trexvenpos/lib/src/features/pos/operations_screen.dart) | Inspected; existing flow preserved; device check pending |
| pos | [lib/src/features/pos/recent_sales_screen.dart](../../../trexvenpos/lib/src/features/pos/recent_sales_screen.dart) | Inspected; existing flow preserved; device check pending |

## Files modified in this frontend pass

The list identifies this task's Dart edits, including formatting on touched files, plus dependency/analyzer configuration. Earlier unrelated dirty files were not reset or represented as new frontend changes. Hashes are recorded in [frontend_modified_files.json](evidence/frontend_modified_files.json).

- owner: [lib/core/app_sizing.dart](../../lib/core/app_sizing.dart)
- owner: [lib/core/app_theme.dart](../../lib/core/app_theme.dart)
- owner: [lib/models/subscription_plan.dart](../../lib/models/subscription_plan.dart)
- owner: [lib/screens/auth/login_screen.dart](../../lib/screens/auth/login_screen.dart)
- owner: [lib/screens/auth/register_screen.dart](../../lib/screens/auth/register_screen.dart)
- owner: [lib/screens/dashboard/angel_screen.dart](../../lib/screens/dashboard/angel_screen.dart)
- owner: [lib/screens/dashboard/dashboard_screen.dart](../../lib/screens/dashboard/dashboard_screen.dart)
- owner: [lib/screens/finance/record_sale_screen.dart](../../lib/screens/finance/record_sale_screen.dart)
- owner: [lib/screens/intelligence/add_camera_screen.dart](../../lib/screens/intelligence/add_camera_screen.dart)
- owner: [lib/screens/intelligence/alerts_screen.dart](../../lib/screens/intelligence/alerts_screen.dart)
- owner: [lib/screens/intelligence/camera_alert_screen.dart](../../lib/screens/intelligence/camera_alert_screen.dart)
- owner: [lib/screens/intelligence/camera_detail_screen.dart](../../lib/screens/intelligence/camera_detail_screen.dart)
- owner: [lib/screens/intelligence/camera_intelligence_screen.dart](../../lib/screens/intelligence/camera_intelligence_screen.dart)
- owner: [lib/screens/intelligence/camera_screen.dart](../../lib/screens/intelligence/camera_screen.dart)
- owner: [lib/screens/intelligence/event_detail_screen.dart](../../lib/screens/intelligence/event_detail_screen.dart)
- owner: [lib/screens/intelligence/intelligence_tab.dart](../../lib/screens/intelligence/intelligence_tab.dart)
- owner: [lib/screens/intelligence/recordings_screen.dart](../../lib/screens/intelligence/recordings_screen.dart)
- owner: [lib/screens/inventory/add_product_screen.dart](../../lib/screens/inventory/add_product_screen.dart)
- owner: [lib/screens/inventory/catalog_editor_screen.dart](../../lib/screens/inventory/catalog_editor_screen.dart)
- owner: [lib/screens/inventory/catalog_import_screen.dart](../../lib/screens/inventory/catalog_import_screen.dart)
- owner: [lib/screens/inventory/inventory_tab.dart](../../lib/screens/inventory/inventory_tab.dart)
- owner: [lib/screens/main_screen.dart](../../lib/screens/main_screen.dart)
- owner: [lib/screens/me/about_screen.dart](../../lib/screens/me/about_screen.dart)
- owner: [lib/screens/me/add_employee_screen.dart](../../lib/screens/me/add_employee_screen.dart)
- owner: [lib/screens/me/appearance_screen.dart](../../lib/screens/me/appearance_screen.dart)
- owner: [lib/screens/me/billing_screen.dart](../../lib/screens/me/billing_screen.dart)
- owner: [lib/screens/me/business_profile_screen.dart](../../lib/screens/me/business_profile_screen.dart)
- owner: [lib/screens/me/data_backup_screen.dart](../../lib/screens/me/data_backup_screen.dart)
- owner: [lib/screens/me/edit_employee_screen.dart](../../lib/screens/me/edit_employee_screen.dart)
- owner: [lib/screens/me/employee_confirmation_screen.dart](../../lib/screens/me/employee_confirmation_screen.dart)
- owner: [lib/screens/me/employee_details_screen.dart](../../lib/screens/me/employee_details_screen.dart)
- owner: [lib/screens/me/employment_screen.dart](../../lib/screens/me/employment_screen.dart)
- owner: [lib/screens/me/help_support_screen.dart](../../lib/screens/me/help_support_screen.dart)
- owner: [lib/screens/me/me_tab.dart](../../lib/screens/me/me_tab.dart)
- owner: [lib/screens/me/notifications_settings_screen.dart](../../lib/screens/me/notifications_settings_screen.dart)
- owner: [lib/screens/me/profile_screen.dart](../../lib/screens/me/profile_screen.dart)
- owner: [lib/screens/me/security_screen.dart](../../lib/screens/me/security_screen.dart)
- owner: [lib/screens/setup/business_setup_screen.dart](../../lib/screens/setup/business_setup_screen.dart)
- owner: [lib/screens/setup/setup_complete_screen.dart](../../lib/screens/setup/setup_complete_screen.dart)
- owner: [lib/services/catalog_import.dart](../../lib/services/catalog_import.dart)
- owner: [lib/services/database_service.dart](../../lib/services/database_service.dart)
- owner: [lib/services/sale_errors.dart](../../lib/services/sale_errors.dart)
- owner: [lib/widgets/angel_markdown.dart](../../lib/widgets/angel_markdown.dart)
- owner: [lib/widgets/stat_card.dart](../../lib/widgets/stat_card.dart)
- owner: [lib/widgets/trexven_widgets.dart](../../lib/widgets/trexven_widgets.dart)
- owner: [packages/trexven_operations/lib/src/account_operations_screen.dart](../../packages/trexven_operations/lib/src/account_operations_screen.dart)
- owner: [packages/trexven_operations/lib/src/cash_shift_screen.dart](../../packages/trexven_operations/lib/src/cash_shift_screen.dart)
- owner: [packages/trexven_operations/lib/src/customer_presentation.dart](../../packages/trexven_operations/lib/src/customer_presentation.dart)
- owner: [packages/trexven_operations/lib/src/employee_access_screen.dart](../../packages/trexven_operations/lib/src/employee_access_screen.dart)
- owner: [packages/trexven_operations/lib/src/financial_operations_screen.dart](../../packages/trexven_operations/lib/src/financial_operations_screen.dart)
- owner: [packages/trexven_operations/lib/src/inventory_operations_screen.dart](../../packages/trexven_operations/lib/src/inventory_operations_screen.dart)
- owner: [packages/trexven_operations/lib/src/notification_center_screen.dart](../../packages/trexven_operations/lib/src/notification_center_screen.dart)
- owner: [packages/trexven_operations/lib/src/operational_permissions_screen.dart](../../packages/trexven_operations/lib/src/operational_permissions_screen.dart)
- owner: [packages/trexven_operations/lib/src/payment_confirmation_dialog.dart](../../packages/trexven_operations/lib/src/payment_confirmation_dialog.dart)
- owner: [packages/trexven_operations/lib/trexven_operations.dart](../../packages/trexven_operations/lib/trexven_operations.dart)
- owner: [test/billing_frontend_test.dart](../../test/billing_frontend_test.dart)
- owner: [test/catalog_import_test.dart](../../test/catalog_import_test.dart)
- owner: [test/catalog_repository_test.dart](../../test/catalog_repository_test.dart)
- owner: [test/frontend_refinement_test.dart](../../test/frontend_refinement_test.dart)
- owner: [test/shared_vision_experience_test.dart](../../test/shared_vision_experience_test.dart)
- owner: [test/ui_density_test.dart](../../test/ui_density_test.dart)
- pos: [lib/src/features/inventory/catalog_edit_screen.dart](../../../trexvenpos/lib/src/features/inventory/catalog_edit_screen.dart)
- pos: [lib/src/features/inventory/product_detail_screen.dart](../../../trexvenpos/lib/src/features/inventory/product_detail_screen.dart)
- pos: [lib/src/features/inventory/product_search_screen.dart](../../../trexvenpos/lib/src/features/inventory/product_search_screen.dart)
- pos: [lib/src/features/pos/checkout_screen.dart](../../../trexvenpos/lib/src/features/pos/checkout_screen.dart)
- pos: [lib/src/features/pos/dashboard_screen.dart](../../../trexvenpos/lib/src/features/pos/dashboard_screen.dart)
- pos: [lib/src/features/pos/offline_cash_screen.dart](../../../trexvenpos/lib/src/features/pos/offline_cash_screen.dart)
- pos: [lib/src/features/pos/pending_sale_provider.dart](../../../trexvenpos/lib/src/features/pos/pending_sale_provider.dart)
- pos: [lib/src/services/sale_errors.dart](../../../trexvenpos/lib/src/services/sale_errors.dart)
- pos: [test/frontend_product_navigation_test.dart](../../../trexvenpos/test/frontend_product_navigation_test.dart)
- Owner dependency/configuration: [pubspec.yaml](../../pubspec.yaml), [pubspec.lock](../../pubspec.lock), [analysis_options.yaml](../../analysis_options.yaml).
- Local frontend tooling/logs under `.batch3-tools`; this report and its evidence files under `docs/implementation`.
