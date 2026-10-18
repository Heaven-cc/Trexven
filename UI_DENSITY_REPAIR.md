# UI sizing changes

The sizing audit was followed by presentation-only changes. Sale handlers, validation, API calls, database operations, navigation destinations, and camera/Angel services retain their existing behavior.

- Shared page/card padding is 16 logical pixels, field padding is 16 horizontal/12 vertical, and primary actions have a 56-pixel minimum height. Buttons wrap and grow with system text size.
- Record Sale uses a 24-pixel title, 30-pixel quantity, 25-pixel total, 56-pixel quantity controls, smaller section gaps, and an intrinsically sized product dropdown. Summary values wrap within the available width. The payment dropdown expands within the form and grows vertically, fixing narrow-screen overflow with enlarged text.
- The dashboard sales card has smaller padding and gaps, with a 30-pixel amount. KPI cards retain a 132-pixel minimum and quick actions a 78-pixel minimum; their text can wrap and the cards grow. Quick-action decorations leave more width for labels. Yesterday's label/value share the available space at large text sizes.
- Add Product/Restock uses the shared spacing, title, input, and button sizes. Mode selectors grow with their labels.
- Inventory, Finance, and Me use smaller page titles/padding. Employee and Profile forms use smaller outer padding and action gaps. The header Angel control has a 48-pixel minimum target and the notification icon is 24 pixels. Bottom navigation sizing is preserved.

## Verification

- Full Flutter suite: **49 tests passed**, including existing sale retry/receipt, duplicate tap, and camera-navigation tests.
- New layout coverage: Record Sale at 320×568, 390×844, 800×1000, and 780×360 with 1×/2× text and light/dark themes; large monetary values, scrolling, submission, and minimum button height. Shared long-label button grows rather than overflowing.
- New dashboard coverage: 320/412-pixel widths at 1×/2× text, minimum card sizes, scrolling, and Cameras callback.
- Android debug APK builds successfully.
- Final APK installed and launched on the connected Samsung SM G991N. Flutter and Supabase initialized, and the Dart VM service connected. Device logs report a secure-storage decryption failure with a fallback to custom ciphers; this launch check does not establish authenticated end-to-end behavior.
- Analysis has no errors; it reports one existing unused-variable warning in Billing and existing informational/deprecation notices. No dependency or unrelated lint changes were made.
- Widget tests use fake sale data and mocked dashboard HTTP responses. They do not create live business records. Physical-device launch is checked separately; exhaustive manual review of all screens remains outside the automated coverage.
