<!-- BATCH_2_CLOSURE_STATUS -->
# Batch 2 business-local timezone verification

8 October 2026 — final closure verification. **BATCH 2 — COMPLETE, STAGING VERIFIED.**

Migration `20261008021428_batch_2_business_day_contract.sql` adds authenticated `get_trexven_business_day(uuid)`: trusted membership plus owner/POS permission, validated IANA business timezone, server-local date and UTC half-open day bounds. `private.business_timestamp()` reads server current_timestamp; staff sales-history policy uses the same source. No caller clock override, arbitrary default timezone or historical timestamp rewrite is installed. Owner today statistics now consume this RPC instead of device midnight.

## Actual Auth/HTTP/RPC integration

On the guarded disposable stack only, the test replaced the private trusted clock source temporarily and issued real API requests using the same valid JWT across boundaries. Synthetic branch sales were placed at previous/current/next local-day boundaries. Each frame checked actual staff REST results and the day RPC, not just SQL date arithmetic.

| Controlled frame, America/New_York | Verified behavior |
| --- | --- |
| One minute before local midnight | Prior local date; UTC date differs; prior day's sales only |
| Exactly midnight | New local date/day bound; old rows excluded |
| One minute after midnight | New day's rows only, same authenticated session |
| Spring transition before/after 07:00Z | Local hour skips; UTC day span 23 hours |
| Fall repeated 01:30 at both offsets | Same local date; UTC day span 25 hours |

Seven distinct boundary frames passed; branches followed the business timezone and stale valid sessions did not freeze the prior date. Missing timezone returned explicit day-RPC failure and no staff historical sales; owner's authorized historical access remained available. Forged business rejected. Invalid IANA configuration was denied in staging; restoring synthetic configuration updated RPC behavior without token refresh. No real production timezone was changed and no universal Africa/Lagos assumption was made.

These seven clock frames are part of the native harness's 18 distinct checks (9 cost + 7 clock + forged business + missing zone). [Attempt JSON](evidence/batch_2_closure_native_http.json), [passing retry log](evidence/batch_2_closure_native_http_retry2.log). Initial seven frame failures arose from the harness reading `receipt.sale_id` instead of actual `receipt.id`; correction retained the original failed attempts. Final actual APIs passed all 18 names.

The test clock function was restored to its exact approved server-current_timestamp definition before catalog capture/backup; all 30 semantic groups matched staging. No temporary test clock survives in migrations/staging. Synthetic timestamp manipulation was fixture-only; historical production timestamps and receipts were neither copied nor rewritten.

Legacy businesses with null timezones require owner-approved IANA configuration before staff current-day access and Owner today stats. That explicit production configuration is a rollout prerequisite, not an invented fallback. Owner-wide historical reads remain authorized. Stored timestamps remain timestamptz/UTC instants; local-date calculation changes display/filter interpretation only.
