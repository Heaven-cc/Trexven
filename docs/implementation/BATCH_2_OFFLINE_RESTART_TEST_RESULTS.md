<!-- BATCH_2_CLOSURE_STATUS -->
# Batch 2 persisted submission/restart verification

8 October 2026 — final closure verification. **BATCH 2 — COMPLETE, STAGING VERIFIED.**

The earlier negative characterization correctly found memory-only cart/request recovery. A minimum native single-intent journal now closes the interrupted online submission gap; the complete encrypted offline cash-sale queue remains deferred.

`FilePendingSaleStore` writes/flushed-renames a versioned JSON file under application support before any RPC dispatch. It persists original user, business, membership, optional branch, request key, payment and line-item payload; no session token/password is stored. Corrupt final files fail closed. A retained intent cannot be reassigned by actor/business/branch/cart edits. Startup recovery requires the original authenticated actor and fresh branch authorization, then retries the saved request.

New definite rejection can release an unsent/uncommitted intent. Unknown network outcomes remain durable; stale permission denial after uncertainty does not erase it. Checkout and recovery recheck actor binding after asynchronous RPC completion and receipt display. The added actor-switch widget regression proves another employee cannot display/acknowledge the original receipt and the cart/intent remain intact.

## Actual boundaries executed

| Command / boundary | Result |
| --- | --- |
| `flutter test --no-pub --dart-define=PENDING_RESTART_PHASE=before test/pending_sale_test.dart --reporter expanded` | 2 passed; exit 0 |
| Same command with `after` in a new process | 2 passed; exit 0; PID differs |
| `flutter test --dart-define=LIVE_RESTART_PHASE=before test/pending_sale_live_restart_test.dart --reporter expanded` | 1 passed; exit 0 |
| Same live command with `after` in a new process | 1 passed; exit 0; PID differs |
| Final full POS suite | 37 passed, 1 explicit-live test skipped; exit 0 |

The live phases use only fixture API `http://127.0.0.1:54321`: before persists the intent, commits the actual Supabase sale RPC, saves receipt/stock evidence and simulates loss of the committed response. The next process restores original actor/business/branch/membership/request, dispatches once, gets the original receipt, observes exactly one sale and one stock deduction, then acknowledges. Staging SQL/HTTP separately verify revoked authority, branch switching, cashier membership IDs and duplicate request protection.

Evidence: [disk before](evidence/pos_batch_2_closure_restart_before_final_retry.log), [disk after](evidence/pos_batch_2_closure_restart_after_final_retry.log), [live before](evidence/pos_batch_2_closure_live_restart_before_final.log), [live after](evidence/pos_batch_2_closure_live_restart_after_final.log), [full suite](evidence/pos_batch_2_closure_pos_tests_final.log).

Failed attempts remain: fakeAsync widget filesystem hang (replaced with memory store in widgets; actual file IO tested outside fakeAsync), initial numeric stock cast failure (corrected num conversion), wrong Owner-cwd restart invocation, and disk-full compiler failure. After removing only duplicate Batch 2 archives, sequential before/after phases passed. The stuck failed run was interrupted; it is not counted as passing.

Scope: actual host-process restart with native file persistence, not an Android device relaunch/instrumentation run. Browser durable storage is unsupported and fails closed; installed POS is required for this minimum feature. No offline queue, multi-intent queue, cash-outbox migration or encryption engine is claimed. Existing legacy request/receipt/offline payload identifiers remain unchanged.

---

## Historical report — superseded by the closure update above

# Batch 2 offline and restart compatibility

8 October 2026. **Existing live-process retry verified; durable restart recovery not implemented/accepted.** No Android device or emulator was connected (adb devices returned an empty list). No device-level result is claimed.

## Executed boundaries

| Scenario | Evidence | Outcome |
| --- | --- | --- |
| Unknown checkout response while process survives | Existing checkout_flow_test widget; complete POS suite | Retains cart/request key, prevents duplicate taps, exact retry recovers saved receipt |
| Same request submitted concurrently/reconnected HTTP retry | Live REST/RPC and SQL | Same receipt, one stock deduction |
| Branch selection with unfinished cart | BranchContext unit tests | Switching/clearing rejected; no branch guessed |
| Revoked permission or branch assignment with stale JWT | Live RPC/REST | New submission rejected; revoked branch stock hidden |
| Price changes during queued-looking stale request | Live held-row test | Checkout waits and rejects committed stale price atomically |
| Owner legacy receipt recovery | Live REST | Stable existing receipt remains accessible without retagging |
| Separate Flutter VM restart | New offline_restart_characterization_test, before/after processes | Demonstrates loss of cart, request key and selected branch |

Executed in POS:
~~~text
flutter test test/offline_restart_characterization_test.dart --dart-define=RESTART_PHASE=before --reporter expanded
flutter test test/offline_restart_characterization_test.dart --dart-define=RESTART_PHASE=after --reporter expanded
~~~
Both commands exited 0 with one test passing. They deliberately assert the observed absence of persistence; they are **negative characterization**, not successful durable-sale recovery. The evidence file is written only by the test and is never read by the application. Before/after process IDs differ; the second process creates an empty cart, a new UUID and a NULL branch.

Logs: batch_2_final_restart_before.log and batch_2_final_restart_after.log. The characterization also runs in the complete POS suite (34 tests). It uses synthetic models and makes no backend connection.

## Existing implementation and gaps

CartNotifier holds cart and checkoutRequestId in memory. BranchContext is re-created with authentication/business context and starts unselected. No encrypted durable outbox or pending-sale journal was found in this flow. Cart state is independent of AuthState: logout does not itself clear/persist/reconcile an unfinished cart. The checkout route blocks leaving an uncertain sale while it remains mounted; account changes, process death and recovery outside that route are not a fully verified workflow.

Server request keys remain scoped to the original authenticated actor/business; a different employee must not adopt a pending receipt or recreate a genuine sale under another identity. Local current-business guards and branch-cart guards are tested, but logout/login persistence and original-actor recovery need durable lifecycle tests.

The master explicitly assigns the full encrypted offline cash queue, 24-hour authorization, pending-sync receipts and reconciliation to Phase 3. No offline engine or arbitrary queue format was invented in Batch 2. Restart durability remains a known missing existing capability, not a regression silently declared fixed.

Acceptance still needs an actual supported device or equivalent persistent application harness, durable request/branch/actor recovery where implemented, interrupted receipt retrieval, logout/login with pending sales and reconnect/revocation cases. Any later-phase deferral must be explicitly accepted as non-blocking before final Batch 2 acceptance; no such acceptance is assumed here.
