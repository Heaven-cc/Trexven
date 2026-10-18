# Product selector and loading repair

## Causes verified before fixing

The original Restock implementation failed regression tests in two ways: its two-line selected product overflowed the default dense dropdown height, and refreshed Product objects invalidated the selected dropdown value. Product equality was object identity, while every stream emission constructs new objects. The initial-loading state test also failed because loading and errors were treated as an empty product list.

Add/Restock recreated the Supabase product stream in build. Selecting a product, typing a quantity, or other parent rebuilds therefore restarted business lookup and the product subscription. Inventory search had the same stream lifetime problem. These are distinct from visual spacing issues.

The global ErrorWidget handler inserted a full Scaffold inside whatever widget failed, including an unbounded scrolling form. Its replacement is now a bounded inline fallback with a working restart action through the app navigator key.

## Changes

- Add/Restock retains its product stream and uses stable product IDs as dropdown values. Fresh rows update the preview; deleted/unavailable products clear the selection and disable submission.
- The dropdown uses intrinsic height for its two-line contents. Loading, error, empty inventory, and retry are explicit. New Product remains usable while Restock data is unavailable.
- Initial product loads time out after 20 seconds and offer retry. Quiet realtime streams remain valid after their initial data. The same initial-load protection covers Inventory and Record Sale.
- Inventory search reuses its stream. Failures have a working retry action.
- Personnel retains one shared employee stream for statistics and the list, handles errors and retry, checks mounted after business lookup, and disables adding employees until a business exists. Initial business/data loads are bounded.
- Stock submission guards repeated taps, restores controls after failures, and captures the submitted product/quantity so concurrent stream changes cannot invalidate the success handler.
- Existing Supabase scoping, queries, database schema, sale recording rules, stock-update semantics, and navigation destinations are preserved.

## Verification

**59 Flutter tests passed.** New tests cover selection through fresh rows, one stream across typing/rebuilds, refreshed stock in the update request, menu opening/outside dismissal, no leftover dropdown barrier, loading/error/retry/empty/deleted-product states, stalled initial loads, rejected stock writes and repeated taps, Inventory search/retry, Personnel errors and disposal during lookup, and the inline error fallback inside an unbounded form. Existing sale retry/receipt, duplicate-sale tap, camera and responsive-layout tests pass.

Analysis reports no errors; the existing unused Billing variable warning remains, along with informational/deprecation notices. Changed files pass git diff --check.

The Android ARM64 debug APK builds successfully at build/app/outputs/flutter-apk/app-debug.apk. The initial multi-architecture build and one test compilation failed because the disk was full. Only regenerable project debug/test artifacts and temporary compiler directories created by this run were removed before verification was rerun.

Physical-device inspection during the audit was interrupted by concurrent phone use. The original complete phone freeze was not captured, and no matching Android ANR was found in retained logs. The dropdown assertion/overflow were reproduced in automated widget tests; popup dismissal and continued interaction are verified after the fix. No live product or sale records were changed during verification.
