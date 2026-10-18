# TREXVEN design system

Canonical Flutter visual foundation for TREXVEN Owner, POS and shared operational screens. Both apps import `package:trexven_design_system/trexven_design_system.dart` directly. Obsolete Owner theme, sizing and widget implementations have been removed.

## Development and release layout

Keep the existing sibling checkout arrangement:

```text
workspace/
  Trexven/
    packages/
      trexven_design_system/
      trexven_operations/
  trexvenpos/
```

Owner consumes `packages/trexven_design_system`; POS consumes `../Trexven/packages/trexven_design_system`; operations consumes `../trexven_design_system`. These are relative dependencies. CI and release jobs must check out the matching Owner revision alongside POS, as already required by the operations package. Build either app normally with `flutter pub get`, `flutter analyze` and `flutter build`. There are no Windows absolute paths in production dependency declarations and no copied theme source in POS. The package is private (`publish_to: none`).

## Foundations

| Token | Default |
|---|---|
| Brand seed | `#2563EB` |
| Light canvas / input and card fill | `#F5F7FC` / white |
| Overview hero | `#111B35` with white text |
| Page horizontal padding | 16dp |
| Label | 14sp, weight 600 |
| Input | 16sp |
| Label gap / field gap / section gap | 8 / 16 / 24dp |
| Input padding | 16dp horizontal, 12dp vertical |
| Field / card / dialog radius | 14 / 16 / 20dp |
| Minimum field, button and icon-button target | 48dp |

`TrexvenTheme.lightTheme` and `darkTheme` own typography, adaptive semantic colors, input states, button states, cards, navigation, tabs, dialogs, date pickers, bottom sheets, menus and feedback. Dark mode uses a lighter blue foreground/fill with a dark `onPrimary` color for readability. Normal single-line fields are 48–56dp; labels, errors, multiline content and large text may grow. Do not impose a maximum height or reduce the system text scaler.

## Components

- `TrexvenTextField` and `TrexvenTextFormField`: persistent label, controller/focus support, keyboard/action configuration, numeric/currency formatters, password visibility, multiline content and original validators.
- `TrexvenFieldVariant.search` and `.chat`: intentional placeholder variants without ordinary field labels.
- `TrexvenDropdown<T>`: persistent label, selected value, validation, expanded menu and adaptive theme. Set `rich: true` for product selectors with multiple lines.
- `TrexvenInputDecoration`: semantic content only. Visual padding, borders, radii, typography and states come from the theme.
- `TrexvenHeroMetric`, `TrexvenMetricCard` and `TrexvenProductRow`: one dark overview metric, compact supporting cards and product/transaction rows that stack at narrow widths or large text sizes.
- `TrexvenFieldLabel`, `TrexvenFormSection`, `TrexvenDateField`, `TrexvenButton`, `TrexvenHeaderAction`, `TrexvenCard`, `TrexvenTapCard`, `TrexvenDialog`, `TrexvenBottomSheet`, `TrexvenLoading`, `TrexvenEmptyState`, `TrexvenErrorState`.

Native Material buttons, dialogs, navigation bars and list tiles also inherit this same theme. Their existing callbacks, form state and routes remain in the apps. Screen composition can differ between Owner and POS. Camera/scanner framing and overlays retain their visual purpose.

## Form example

```dart
TrexvenTextFormField(
  label: 'Selling price',
  controller: priceController,
  keyboardType: const TextInputType.numberWithOptions(decimal: true),
  validator: validatePrice,
);
```

Fields include their 16dp trailing gap by default. Use `gap: 0` only when a parent explicitly owns the spacing, and `showLabel: false` only beside an external `TrexvenFieldLabel` or an intentional search/chat variant.

## Verification

Owner and POS tests exercise shared geometry, validation, keyboard insets, dropdown selection, retained form values and real priority screens at 320/340/390dp, text scales 1/1.3/2 and both brightness modes. Checkout tests also verify accessible quantity targets and cart state. See Owner `docs/implementation/TREXVEN_DESIGN_SYSTEM_HANDOVER.md` for full results, source audit, screenshots and limitations.

The subsequent PDF visual redesign is documented in Owner `docs/implementation/visual_redesign/HANDOVER.md`. The Owner main-screen source and navigation-bar theme remain unchanged in that redesign.
