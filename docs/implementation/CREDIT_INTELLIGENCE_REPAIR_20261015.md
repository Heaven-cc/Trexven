# Credit/Returns and first-use Intelligence repair

## Credit and Returns

Live logs showed `column credit_accounts.id does not exist`. The shared operations client sorted every table by `id`; credit accounts are keyed by `sale_id`. The combined Financial Operations screen waits for all its tables, so this failed request blocked Returns as well.

- The shared Owner/POS operations client now orders credit accounts by `sale_id`.
- Production migration `20261015004140`, `credit_account_legacy_read_compatibility`, supplies a generated, read-only `id = sale_id` alias for installed clients. The canonical primary key, foreign keys, RLS policies, balances, repayment and refund workflows are preserved.
- The original installed-client query was verified under the affected owner's authenticated database role: one credit account is readable, and the alias equals its sale ID. Returns currently has zero records for this business.
- An isolated PostgreSQL test verifies balances remain unchanged, the primary key remains `sale_id`, old ordering works, cross-business RLS remains enforced, the alias cannot be overwritten, and new accounts generate the correct alias.

## Intelligence

The owner confirmed no cameras have been added. Supabase also contains zero cloud camera registrations for the affected business. The previous tab unconditionally contacted the default/saved Vision server before reaching its empty state.

- Before requesting cameras, the tab initializes saved pairing and checks whether an API key is configured.
- Unconfigured installations show `Set up Intelligence` and a `Connect Vision server` action without making a camera request or displaying zero camera totals as a verified server snapshot.
- A configured server returning an empty camera list shows `No cameras yet` with the existing add-camera flow.
- Configured-server failures still show an error and retry; they are not converted into empty camera lists.
- Returning from Vision Server settings refreshes the tab, and the setup action opens settings without an automatic connection attempt with missing credentials.
- The standalone Vision server was not started, and no camera was added or enabled.

## Verification and delivery

28 targeted Flutter tests passed across new initial-setup/pagination tests and existing Intelligence, shared Vision and Vision service suites. Targeted Dart analysis had zero errors/warnings and four existing informational style findings. Formatting passed.

Credit/Returns compatibility is deployed and supports the existing app. The Intelligence change and canonical credit pagination fix are included in the successfully built debug test APK at `build/app/outputs/flutter-apk/app-debug.apk`. Install the updated Owner app to receive the frontend changes. No physical-device installation, visual acceptance, or camera feed validation is claimed.

APK SHA-256: `86E6D905C971164B4871B2347465B27CB4CBBDA3585FED7E1C0E0F6F1BF4C1DF`. Size: 232777949 bytes. `flutter build apk --debug --no-pub` completed successfully. The existing Kotlin version produced a future-support warning; Android build configuration was not changed for this repair.
