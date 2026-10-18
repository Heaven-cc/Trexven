# Initial duplicate inventory

No source was deleted or consolidated in the access batch. This is a candidate
inventory; similar names alone do not prove behavioral equivalence.

| Candidate paths | Canonical direction | Consumers/tests/risk |
| --- | --- | --- |
| Owner `lib/services/sale_errors.dart`; POS `lib/src/services/sale_errors.dart` | Shared error contract after exact behavior comparison | Both checkout flows; request replay/error regressions; low/medium risk |
| Owner `lib/models/employee.dart`; POS `lib/src/models/employee.dart` | Shared wire role/status contract, retain presentation adapters | Owner staff screens vs POS auth; membership IDs differ; high permission risk |
| Owner product/sale models; POS counterparts | Shared wire/domain contracts when variants arrive | Owner quick sales differ from POS multi-line receipts; high migration risk |
| Owner `stat_card.dart`; dashboard `_miniKPICard`; screen-local summaries | Canonical variant-aware KPI widget | Home/Finance/Employees; density tests; expansion semantics must survive |
| POS scanner/manual search → product detail | Shared product selection entry/checkout workflow | Preserve existing scanner and manual lookup; camera/device tests pending |
| Owner/POS `employee-login/index.ts` | Owner Supabase functions directory as deployment source, documented mirror policy | Shared login endpoint; compare exact files before removing mirror |
| Owner `TrexvenPressable` wrapper plus nested InkWell/button callbacks | Review gesture ownership, not automatic deletion | Existing tap/keyboard semantics; regression tests required |

Do not consolidate Vision with Angel or retail payment recording with SaaS billing.
Do not collapse cash collected and accounts receivable into one amount. Do not
remove historical migrations, models, unused-looking routes or production tables.
