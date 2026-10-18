# TREXVEN / TREXVEN POS form design audit

Date: 10 October 2026

**Result: the two apps do not have a unified form design.** Both use Material 3, blue branding, and some 14-pixel corner radii, but their form tokens, label patterns, dropdown density, focus indicators, and spacing differ. There is also variation between screens within each app.

Scope: current Dart source in both apps, covering themes and all input/dropdown declarations under their screen/features directories. A temporary Flutter widget diagnostic measured representative configurations at 340 logical pixels wide, with 1x and 2x text scaling. It used the current TREXVEN theme and the POS light theme extracted from its source. Screen-specific setup properties were reproduced. This is a source and isolated layout audit, not a physical-device visual review of every screen. Application source was not modified.

## Findings

### 1. Different form themes and no common form tokens — medium

- [TREXVEN theme](C:/Users/USER/AndroidStudioProjects/Trexven/lib/core/app_theme.dart:132): white filled inputs, no enabled/focused outline in the global theme, 14-pixel radius, 14-pixel hint text.
- [TREXVEN sizing](C:/Users/USER/AndroidStudioProjects/Trexven/lib/core/app_sizing.dart:4): 16 horizontal / 12 vertical field padding; 16-pixel field and section gaps; 16-pixel page/card padding.
- [POS theme](C:/Users/USER/AndroidStudioProjects/trexvenpos/lib/main.dart:138): gray filled inputs, visible gray enabled outline, blue focused outline, 16 horizontal / 18 vertical field padding. Label/hint font sizes inherit defaults.
- Brand blue differs: TREXVEN `#2563EB`; POS `#2F66B0`. Backgrounds differ: `#F8FAFC` versus `#F2F2F7`.

Impact: moving between apps changes field size, fill, focus feedback, and typography. POS does not consume TREXVEN's `AppSizing` or `AppTheme`.

### 2. Excessive vertical space in ordinary POS fields and TREXVEN setup dropdowns — medium

Representative measured heights, in Flutter logical pixels, without validation errors:

| Configuration | 1x text | 2x text |
| --- | ---: | ---: |
| TREXVEN theme text input, prefix icon, hint | 48 | 72 |
| TREXVEN theme text input, prefix icon, floating label | 48 | 72 |
| TREXVEN setup text input, prefix icon, 17 vertical padding | 58 | 82 |
| TREXVEN setup dropdown, prefix icon, `isDense: false` | 72 | 72 |
| TREXVEN theme dense dropdown with label | 48 | 72 |
| POS theme text input with label and prefix icon | 60 | 84 |
| POS theme dense dropdown with label | 60 | 84 |

POS's standard representative field is 12 pixels taller than TREXVEN's, matching its additional top/bottom padding. Five such fields add 60 pixels before accounting for gaps.

[Business setup](C:/Users/USER/AndroidStudioProjects/Trexven/lib/screens/setup/business_setup_screen.dart:413) overrides text padding to 17 vertical. Its [dropdown](C:/Users/USER/AndroidStudioProjects/Trexven/lib/screens/setup/business_setup_screen.dart:432) explicitly sets `isDense: false`, creating a 72-pixel representative control despite simple one-line options. [POS Quick Add](C:/Users/USER/AndroidStudioProjects/trexvenpos/lib/src/features/inventory/quick_add_screen.dart:384) duplicates the 18-pixel vertical padding locally, so changing the global theme alone will not standardize it.

These are measured representative configurations, not a guarantee of identical heights for every field. Selected product rows with name, price, and stock legitimately need more height; multiline inputs, errors, and large accessibility text also need room.

### 3. Three different label patterns and inconsistent typography — medium

- [TREXVEN Add Product](C:/Users/USER/AndroidStudioProjects/Trexven/lib/screens/inventory/add_product_screen.dart:614) uses labels above inputs at 15 pixels / weight 600, with 10 pixels between label and input.
- [TREXVEN login](C:/Users/USER/AndroidStudioProjects/Trexven/lib/screens/auth/login_screen.dart:159) and [employee creation](C:/Users/USER/AndroidStudioProjects/Trexven/lib/screens/me/add_employee_screen.dart:211) use hints inside fields. The visual field name disappears once populated.
- [TREXVEN catalog editor](C:/Users/USER/AndroidStudioProjects/Trexven/lib/screens/inventory/catalog_editor_screen.dart:256), [POS login](C:/Users/USER/AndroidStudioProjects/trexvenpos/lib/src/features/auth/login_screen.dart:101), and POS Quick Add use floating `labelText`.
- [Employee role options](C:/Users/USER/AndroidStudioProjects/Trexven/lib/screens/me/add_employee_screen.dart:264) are uppercase at 14 pixels; [product dropdown](C:/Users/USER/AndroidStudioProjects/Trexven/lib/screens/inventory/add_product_screen.dart:815) uses a 15-pixel base style; Add Product text values use 16 pixels / weight 500.

Impact: labels move, disappear, or change weight/size depending on the form. There is no shared label component spanning both apps.

### 4. Missing and uneven field gaps — medium

[POS product editor](C:/Users/USER/AndroidStudioProjects/trexvenpos/lib/src/features/inventory/catalog_edit_screen.dart:292) places seven generated text fields directly in a ListView, followed immediately by Unit and Variant group dropdowns. There is no explicit inter-field padding for these children. Attribute and price fields repeat this pattern. Oversized fields coexist with cramped boundaries.

[TREXVEN editor text fields](C:/Users/USER/AndroidStudioProjects/Trexven/lib/screens/inventory/catalog_editor_screen.dart:254) receive 12 pixels of bottom padding, but [Unit](C:/Users/USER/AndroidStudioProjects/Trexven/lib/screens/inventory/catalog_editor_screen.dart:335), Variant group, and generated attribute fields do not consistently receive that wrapper. Thus the rhythm varies depending on the preceding control.

Outer spacing is also inconsistent: Edit Employee and Reset Password use 24-pixel page padding, Add Camera uses 20 horizontal, while the shared TREXVEN token is 16. [POS login](C:/Users/USER/AndroidStudioProjects/trexvenpos/lib/src/features/auth/login_screen.dart:55) uses a 24-pixel card inset. Wider login layouts can be intentional, but these values currently have no shared named policy.

### 5. Field shape and focus behavior vary within TREXVEN — medium

[Add Product inputs](C:/Users/USER/AndroidStudioProjects/Trexven/lib/screens/inventory/add_product_screen.dart:684) use 17-pixel corners and a 1.4-pixel focused outline. Setup uses 14-pixel corners and a 1.5-pixel focused outline. Global-theme-only fields retain a borderless focused state. [Add Camera](C:/Users/USER/AndroidStudioProjects/Trexven/lib/screens/intelligence/add_camera_screen.dart:326) adds 16-pixel vertical padding.

Impact: fields on different screens have visibly different silhouettes, density, and focus feedback, even before comparing POS.

### 6. POS dark mode lacks the light theme's form styling — medium

[POS dark theme](C:/Users/USER/AndroidStudioProjects/trexvenpos/lib/main.dart:58) declares only Material 3 and a dark color scheme; it does not carry over the custom input decoration theme. Global-theme-only fields therefore fall back to different form defaults. Quick Add and Product Search additionally hardcode light backgrounds/text colors. TREXVEN has corresponding custom light/dark input themes.

### 7. Fixed-height POS search field needs accessibility review — low

[Product Search](C:/Users/USER/AndroidStudioProjects/trexvenpos/lib/src/features/inventory/product_search_screen.dart:97) fixes its input container at 48 pixels, with 16-pixel text and 13-pixel vertical content padding. This constrains growth at larger system font sizes. This audit identifies the constraint; clipping on a physical device has not been established. The search field should grow when its text requires more room.

## Suggested unified specification

This is a proposed local design decision based on the existing apps, not an implemented change.

- One shared form theme/token source consumed by both apps, including light/dark variants and focused/error/disabled states.
- One persistent label pattern for ordinary data-entry forms: label above field, 14 pixels / weight 600, 8-pixel label-to-field gap. Keep search/chat fields as intentional variants.
- Text values at 16 pixels; common 14-pixel radius; consistent fill and visible focus outline.
- Default padding of 16 horizontal / 12 vertical; ordinary single-line controls around 48–56 pixels at normal text size. Use minimum sizes, allowing growth for larger fonts and errors.
- Dense one-line dropdowns aligned with adjacent text fields. Explicit richer product-selector variant for name/price/stock rows.
- 16-pixel page/card padding and inter-field gaps; 24-pixel section gaps. Use named exceptions for wider layouts.
- Wrap all catalog-editor fields and dropdowns with the same spacing component.

Suggested repair order: shared tokens and form components; POS catalog gaps; POS Quick Add/global density; TREXVEN setup dropdowns; migrate remaining labels/overrides; verify light/dark, long values, narrow screens, errors, and large text.

## Verification

The isolated Flutter diagnostic passed for seven representative form configurations at both text scales (14 measurements). It did not contact the backend. The temporary diagnostic was removed after measurement. No full regression suite, APK build, or device walkthrough was performed for this audit. The app UI was left unchanged.

