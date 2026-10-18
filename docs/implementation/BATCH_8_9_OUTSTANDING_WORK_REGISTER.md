# Batch 8/9 outstanding work register — 9 October 2026

This supersedes the earlier source-only Batch 4–7 handover. It does not change
the deployed Batch 2/3 package or authorize production execution.

| Requirement | Current evidence and disposition |
| --- | --- |
| Server identity and access | Trusted POS context RPC, canonical membership IDs, owner verification, revocation and forged-ID tests implemented and passed in isolation/staging. Production still has its deployed Batch 2/3 foundation. |
| Owner and POS business selection | Select existing authorized businesses; owner ownership is rechecked; pending operations/cart prevent unsafe switching. Multi-context and forged-context tests pass. Actual device switching remains unverified. Branches remain inactive. |
| Confirmed payments and recovery | Shared payment confirmation, fractional Owner quantities, retained original payment/request on retry, receipts and encrypted journals integrated. SQL, Flutter and two-process actual-RPC recovery checks passed. |
| Finance and inventory | Credit approval/limits, repayments, inspected refunds, delta stocktake, conditions and movement ledgers implemented. Rollback SQL suites passed. Concurrent checkout passed. No purchase-cost functionality reintroduced. |
| Shared drawers | Multiple employees in one open drawer, assignments, cash totals, closure/review and late synchronization implemented. Isolated drawer/offline suites passed. |
| Employee permissions/settings | Existing Owner creation/editing retained; shared permission review uses actual database definitions and owner-only grant RPC. POS own profile/password/appearance and device recovery notifications implemented. Relevant Flutter tests passed; live password/device checks remain pending. |
| In-app notifications | Reuses alerts/reviews/audits with personal read/unread acknowledgements. Server role/permission/entitlement filtering, Owner-only Vision, deep links, missing/NULL authorization and revocation tested. Cached/in-flight results disappear on account change. Push intentionally unconfigured. |
| UI integration | Owner compact KPI variants, hero preservation, responsive confirmation, subscription display; POS role-scoped four-tab navigation and settings. Widget tests cover narrow screens/text scaling. Android screenshot/performance review remains blocked by device access. |
| Account lifecycle | Non-destructive reviewed request UI/RPC/Edge implemented; genuine hosted JWT tests retain Auth/business records. Production's legacy endpoint remains unchanged pending coordinated deployment. Automatic suspension, lawful purge and renewal-stop automation are not enabled or verified; review requests are not a completed deletion workflow. |
| Backup/recovery | Protected DPAPI archive restored in an API-unexposed isolated database; 84 table fingerprints and schema match. Fresh read-only check still matches. A verified operational backup is available; automated/offsite backup service is not established by this check. |
| Billing | START/CORE/PRO foundation, expiry/grace, trusted verification interface and deduplication tested. Actual provider, commercial values and live collection remain unconfigured; no charging or silent subscription enrollment. |
| External integrations | Existing Google OAuth, Vision/Intelligence and Angel contracts and graceful failure states retained. Actual OAuth redirect, camera server, AI provider and live-device operation are not certified by mocks or SQL tests. Missing usable external services/settings remain separate dependencies. |
| Android candidate/update | Old debug APK metadata inspected; current-source APKs not built. ADB reports zero devices. Never uninstall/clear an installation with pending transactions. Need safe C scratch space and a connected test device. |
| Production | Sixteen new migrations and two Edges prepared and tested outside production. No new production writes. Fresh preflight and explicit approval of the completed frozen candidate remain required. |

Executed tests are listed in the [final report](TREXVEN_FINAL_IMPLEMENTATION_AND_RELEASE_READINESS_REPORT.md).
The remaining external gates prevent claiming complete production release readiness.
