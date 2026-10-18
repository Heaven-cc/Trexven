# Batch 2 historical production compatibility

8 October 2026. **Read-only metadata and aggregate assessment completed.** Production ufehcfrlygqvminfjumf was never a migration, deployment or adversarial-test target. No identifiable customer rows, Auth identities/passwords/tokens or Storage objects were exported.

Evidence: ../../supabase/tests/baseline/batch_2_final_historical_aggregates.json contains the exact SELECT queries and aggregate results.

| Production aggregate | Result |
| --- | ---: |
| Employees | 1 |
| Canonical role counts | manager: 1 |
| Duplicate employee-code groups / NULL codes | 0 / 0 |
| Duplicate employee identity groups | 0 |
| Employee Auth orphans / missing memberships / role mismatches | 0 / 0 / 0 |
| Products | 2 |
| NULL / zero / negative / nonfinite selling prices | 0 / 1 / 0 / 0 |
| Inactive products | 1 |
| Sales / request ledger rows | 2 / 2 |
| Duplicate request groups / malformed saved receipt identifiers | 0 / 0 |
| Inventory/product, movement/product, sale/member, sale-item business mismatches | All 0 |
| Foreign-key constraints checked for orphan references | 60 |
| Orphan count under each checked FK | All 0 |
| Existing unvalidated constraints | 0 |
| Existing application branch columns | 0 |
| Existing business timezone column | 0 |

No product price or active state was changed. Existing explicit zero and newly omitted NULL are different states; the migration must not turn historic zero into arbitrary prices or pending products.

The absence of original branch references supports the nullable additive transition. Historical sales/stock remain unmapped rather than assigned to a guessed branch. Owner legacy visibility is tested in staging; employee access after real activation requires validated assignments/mapping and unresolved legacy retry review.

The existing production schema has no business timezone column/configuration. Migration 2 adds a nullable timezone without guessing one. Ordinary staff sales-history access fails closed until each business receives an owner-approved IANA timezone; review this as a release dependency before enabling the changed history behavior.

Zero inconsistencies in the current aggregates support unique employee-code and staged composite-FK readiness, but do not prove future writes, every business rule or a full historical transaction replay. Counts describe the point-in-time check only. No production repairs or constraint validation were performed.

Staging uses PostgreSQL 17.11 while production reports 17.6. Review platform-version and extension compatibility before rollout; the [current PostgreSQL minor-release notes](https://supabase.com/changelog/postgres-15-19-17-11-breaking-changes) identify restore-sensitive changes. No platform upgrade or cipher/data probe was performed on production.
