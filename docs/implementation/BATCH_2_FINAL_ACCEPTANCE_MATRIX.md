<!-- BATCH_2_CLOSURE_STATUS -->
# Batch 2 final acceptance matrix

8 October 2026 — final closure verification. **BATCH 2 — COMPLETE, STAGING VERIFIED.**

| Required acceptance | Status | Evidence |
| --- | --- | --- |
| Purchase-cost excluded, historical data retained | Implemented/tested | 11 new SQL assertions, REST denials, model/Edge tests |
| Selling-price/zero/null and checkout preservation | Implemented/tested | 14 price + 11 checkout assertions; Owner null roundtrip |
| Real persisted process restart | Implemented/tested | Native file before/after, actual RPC receipt/stock once |
| Midnight/UTC difference/DST/stale JWT | Implemented/tested | Seven real API clock frames; 23/25h boundaries |
| Fresh migration replay repeated | Implemented/tested | Two clean baseline + six-migration executions |
| Backup/restore | Implemented/tested | Operational pg_dump/restore plus schema-only actual restore |
| Owner/role/manager/branch/business isolation | Implemented/tested | 84 SQL assertions, 78 latest-passing hosted HTTP checks |
| Required Edge integration | Implemented/tested | 32 main + four boundary Edge checks |
| Critical/high Batch 2 security defect | None identified in exercised scope | Final security review; advisors disclosed |
| Owner/POS regression | Passed | Owner 66; POS 37 plus one default skip |
| Analyzer | Findings disclosed | Owner 209/POS 4 infos, exit 1; no errors/warnings |
| Cleanup/production unchanged | Verified | Zero fixture/Auth rows; permissions/history/Edge retained; six metadata sections unchanged |

## Explicit scope classifications

- **Implemented and tested:** current release cost exclusion, server authorization/pricing/branches, legacy checkout, one native durable interrupted submission, server day RPC, fresh replay/recovery, staging Edge and synthetic cleanup.
- **Implemented but not separately instrumented:** native storage's Android/iOS/device integration and actual Realtime websocket delivery. Host file/process persistence and managed Realtime privilege code were verified; no device/websocket test is claimed.
- **Proposed, not implemented:** coordinated production rollout/timezone configuration and historical branch mapping. Requires separate production approval and deployment-specific review.
- **Blocked:** no remaining required Batch 2 staging acceptance blocker. Earlier native environment, clock and persistence blockers are superseded by this evidence.
- **Requires production deployment:** six migrations, updated Edge/Owner/POS contracts, approved timezone configuration. Nothing deployed to production.
- **Deferred:** purchase-cost UI/profit feature, encrypted offline cash engine, browser durable journal, actual branch activation/consolidated reporting, AI provider operation, later UI/KPI work. No new entitlement/branch limit/price was invented.

Evidence index: [completion](BATCH_2_FINAL_COMPLETION_REPORT.md), [database](BATCH_2_DATABASE_TEST_RESULTS.md), [Edge](BATCH_2_EDGE_INTEGRATION_RESULTS.md), [restart](BATCH_2_OFFLINE_RESTART_TEST_RESULTS.md), [timezone](BATCH_2_TIMEZONE_TEST_RESULTS.md), [replay](BATCH_2_CLEAN_MIGRATION_REPLAY.md), [recovery](BATCH_2_BACKUP_RECOVERY_RESULTS.md), [security](BATCH_2_FINAL_SECURITY_REVIEW.md).

---

## Historical report — superseded by the closure update above

# Batch 2 final acceptance matrix

8 October 2026. Final acceptance: **BLOCKED**. This matrix supersedes earlier checkpoint status statements; it does not invalidate their historical evidence. Verified environment: staging qysspzlfiysekvxnlzsh, PostgreSQL 17.11.0.003. Production ufehcfrlygqvminfjumf remained read-only.

All requested planning documents were found, including the Batch 1 report IMPLEMENTATION_PROGRESS.md and both master specifications in Downloads. Master functional requirements govern scope; proposed UI measurements are not approval to redesign. No applicable AGENTS.md was found. Both workspaces contain earlier work; it was preserved.

| Requirement | Classification | Evidence or outstanding prerequisite |
| --- | --- | --- |
| Owner accesses own business | Implemented and verified | SQL authorization suite and real Auth/REST |
| Owner cannot access another business | Implemented and verified | SQL, REST and deployed Edge denial |
| Employee excluded from Owner App | Implemented and verified | Owner gate regressions, trusted owner queries, SQL/HTTP owner-only endpoint denial |
| Trusted active employment and membership | Implemented and verified | Server helpers, disabled login, stale-token permission revocation |
| Manager cannot self-grant or alter owner permissions | Implemented and verified | SQL/HTTP escalation denial; permission mutations owner-only |
| Manager cannot create/promote owner or manager | Implemented and verified | SQL role mutation and deployed creation tests |
| Manager ordinary staff administration | Implemented and verified | Deployed provisional creation, status changes and password reset |
| Sensitive manager pricing requires explicit grant | Implemented and verified | Price PATCH denied by default, grant succeeds, revocation takes effect |
| Sales employee cannot edit prices | Implemented and verified | SQL and real REST |
| Inventory insert/update/upsert/bulk/cost-price write restrictions | Implemented and verified | SQL and real REST, atomic bulk rejection |
| Unpriced products pending and non-sellable | Implemented and verified | NULL price/inactive insert, checkout denied |
| Existing explicit zero prices preserved | Implemented and verified | SQL contract and production aggregate; no price rewrite |
| Price/cost read visibility independently governed | Missing within Batch 2; decision required | Existing inventory read permits cost_price SELECT. Approved role/permission mapping is unspecified; no invented mask policy |
| Business/branch isolation and forged IDs | Implemented and verified | SQL, REST, deployed management across unauthorized branch denied |
| Multiple authorized branch assignments | Implemented and verified | SQL and REST assignment visibility/revocation |
| Explicit POS branch selection and unfinished-cart guard | Implemented and verified | POS branch tests; no automatic selection |
| Branch identifiers on stock, movements and sales | Implemented and verified | Additive nullable fields/composite FKs; branch checkout test |
| Legacy NULL branch records accessible to owner | Implemented and verified | SQL and REST receipt visibility |
| Real branch activation/history allocation | Intentionally deferred | No real business activated; separate inventory mapping/stock workflow approval needed |
| Existing checkout and membership contracts | Implemented and verified | Legacy complete_pos_sale, public request ledger and repository tests |
| Atomic checkout, stock races and request replay | Implemented and verified | SQL and live concurrent last-stock/duplicate request/price/revocation tests |
| Receipt interruption recovery while process survives | Implemented and verified | Widget ambiguous retry plus real server receipt replay |
| Durable request/cart/branch restoration after process death | Missing existing capability; intentionally deferred to master Phase 3 | Separate Flutter processes prove current cart/key/branch reset; this is negative characterization, not acceptance |
| Pending-sale logout/login and device offline reconciliation | Implemented but unverified as an end-to-end device workflow | No connected Android device, durable queue absent; server actor/branch isolation tested |
| Business-local current day, missing/invalid timezone | Implemented and verified | SQL plus live REST boundaries and unchanged-token configuration changes |
| Historical receipt access | Implemented and verified within tested scope | Owner HTTP reads historical records; staff current-day policy and branch receipt replay restrictions retained |
| DST conversion and 23/25-hour days | Implemented and verified at SQL level | Temporal suite; no frozen-clock HTTP/Auth transition proof |
| Clock-controlled midnight/DST HTTP lifecycle | Implemented but unverified | Controlled clock/test environment still needed |
| Four migration source hashes/order/portable correction | Implemented and verified statically | Original hashes unchanged; fourth file contains no project-specific data/configuration |
| Fresh baseline plus four migrations replay | Implemented but unverified | No approved disposable project or local PostgreSQL/container runtime available |
| Recoverable schema checkpoint and atomic failure rollback | Implemented and verified within limited scope | Screened schema-only checkpoint; deliberately aborted DDL transaction leaves no probe table |
| Restore/forward-recovery rehearsal in disposable environment | Implemented but unverified | Restore not executed; checkpoint is not a tested backup |
| Historical production compatibility assessment | Implemented and verified for aggregates/metadata | 60 FK orphan checks all zero; employee/price/receipt counts documented |
| Required staging Edge deployment and integration | Implemented and verified | Four ACTIVE functions, Deno type checks, real HTTP roles/compensation |
| Angel provider response | Implemented but unverified | Owner authorization precedes missing-provider 503; no provider secret or paid call enabled |
| Shared permission/helper deduplication | Implemented and verified | Existing helpers reused; POS login mirror matches canonical source |
| RLS recursion and MAINTAIN restriction | Implemented and verified | Existing versioned correction, SQL/HTTP tests, final grants/catalog |
| Advisor review and synthetic query benchmark | Implemented and verified within limited workload | 1,003 visible product rows, 328.585 ms; not production-scale acceptance |
| Regression/analysis | Implemented and verified | Owner 64/POS 34 tests; 209/4 infos, zero errors/warnings, analyzer exit 1 |
| Cleanup and production boundary | Implemented and verified | Zero Auth/session/business/transaction/test-helper/bucket rows; 11 permissions, five history rows, four deployed functions retained |
| Variants, branch price overrides, inventory lifecycle, full offline engine, billing, KPI redesign | Intentionally deferred | Later master phases; not introduced in Batch 2 |

No blanket statement that every security requirement is complete is made. Cost-price confidentiality needs an explicit approved rule; fresh replay and restore are essential acceptance blockers. Remaining offline/clock limitations also require evidence or explicit acceptance as non-blocking, not an assumption.

See BATCH_2_FINAL_COMPLETION_REPORT.md for exact results, changes and release gates.
