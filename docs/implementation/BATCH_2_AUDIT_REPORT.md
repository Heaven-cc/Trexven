# Batch 2 audit report

Date: 7 October 2026. Status: read-only audit complete; implementation awaiting approval.

## Scope and evidence

Reviewed both Flutter workspaces, local migrations/tests/function sources, deployed database catalogs and function definitions, table/column grants, RLS, constraints, triggers, deployed employee Edge Functions, migration history and branch availability. Production access was limited to metadata SELECTs and aggregate integrity counts. No production test transactions, schema changes, deployments, settings changes or data writes occurred. These two new audit/plan documents are the only outputs written during this checkpoint.

Target: Heaven-cc's Project, `ufehcfrlygqvminfjumf`, PostgreSQL 17.6. The separate Admin Project is outside scope.

All requested documents were available: both master specifications in Downloads; `FEATURE_GAP_MATRIX.md`, `KPI_COMPONENT_AUDIT.md`, `MIGRATION_AND_ROLLBACK_PLAN.md`, and the Batch 1 report `IMPLEMENTATION_PROGRESS.md` in this directory. No requested document was missing. Document proposals are design references; the user's Batch 2 approval checkpoint controls execution. No applicable AGENTS.md was found in either workspace.

The Owner workspace contains extensive staged and unstaged pre-existing work. POS has no Git repository metadata at its directory. Preserve those changes; do not reset files or commit unrelated work.

## Existing mechanisms to preserve

* `public.user_owns_business` verifies `businesses.owner_id = auth.uid()` rather than trusting a supplied owner ID.
* `private.has_business_permission` already checks actual ownership or active employee plus active membership, and uses relational `employee_permissions`. Strengthen it rather than introducing another permission engine.
* Canonical employee roles are `manager`, `sales_employee`, `inventory_employee`, and legacy/provisional `employee`. Owner authority must continue to derive from business ownership, not a role label.
* Membership IDs and employee IDs are different contracts. `sales.employee_id` and `inventory_movements.employee_id` reference `business_members.id`; branch assignments should reference `employees.id` without changing transaction identities.
* Direct employee and sale writes are already revoked for authenticated clients. Public sale entry points delegate to trusted private transaction functions.
* Checkout checks authenticated membership, supplied membership identity, product business, stock, totals and current prices, and locks products in stable order.
* `private.submit_trexven_sale` uses an advisory lock and `private.sale_requests` keyed by business/user/request. It rejects changed replay payloads and returns the original saved receipt. Existing `complete_pos_sale`, `record_trexven_sale`, and `submit_trexven_sale` signatures must remain compatible.
* Batch 1 guards remain present: employee rejection at Owner account gate, canonical POS role serialization, restricted local manager permissions, inventory price denial and business/context guards. They are useful client safeguards, not server authorization.

## Schema and deployment state

There are 29 public and three private RLS-enabled tables. Relevant existing tables include businesses, business_members, employees, permissions, employee_permissions, products, inventory, inventory_movements, sales, sale_items and audit_logs. RLS is enabled but not forced; trusted definer/service operations therefore require explicit authorization.

Nine remote migration versions match the local migration history: `20260819180000`, `20260823100000`, `20261002014604`, `20261002015419`, `20261002123039`, `20261002124738`, `20261003224001`, `20261004025120`, and `20261005004045`. Matching versions do not by themselves prove matching SQL checksums. Live definitions were inspected separately.

The earliest migration explicitly states that the mature initial schema was never captured in the repository. A fresh database cannot be assumed to reconstruct production from these delta migrations. An isolated, schema-only baseline and drift verification are prerequisites to meaningful migration testing.

Eight Edge Functions are deployed: angel, camera-ingest, camera-worker-ingest, camera-ai, create-employee, manage-employee, employee-login and delete-account. Employee-login has JWT verification disabled for its password-login entry point; it verifies credentials and active employment/membership itself. Unrelated camera-worker authentication must not be rewritten in this batch.

`supabase/config.toml` currently configures Angel/camera functions, not a complete isolated database project or the full deployed function configuration. CLI 2.113.0 works through `supabase.cmd`; the PowerShell wrapper is blocked by execution policy. No execution-policy change was made.

## Findings and mismatches

| Finding | Evidence and implication | Priority |
| --- | --- | --- |
| Inventory staff can write selling prices | Product INSERT/UPDATE policies check add_products/edit_products, not price authority; no price guard trigger exists. Direct writes/upserts can bypass Flutter. | Critical |
| Pending products can reach checkout | selling_price is NOT NULL DEFAULT 0; active/is_active default true. POS QuickAdd deliberately sets both false, but sale cores do not enforce pending/active state. Raw inserts can bypass this. | Critical |
| Manager defaults exceed approved scope | Central helper grants view_finance and view_camera_events by default. Master specifies owner-only Vision and explicit grants for detailed finance/pricing. Explicit overrides also lack the inventory-role price prohibition. | High |
| Staff administration uses divergent authority | update_trexven_employee checks manager membership directly and permits changing ordinary staff between operational roles. create-employee accepts operational role choices for nonowners. manage-employee does not consistently check active employment or the centralized grant. Managers must not assign roles/permissions. | High |
| Membership activity differs from employment activity | is_business_member checks active membership without employee status; several policies/service paths use that weaker predicate. Suspended/revoked staff may retain access on those paths. | High |
| Excessive table privileges | anon/authenticated have TRUNCATE/REFERENCES/TRIGGER grants on audited tables, including products; authenticated product TRUNCATE was verified effective. Ordinary REST has no truncate route, so this is an excessive grant finding, not a demonstrated Flutter truncate exploit. | High |
| Inventory writes are broader than inventory reads | inventory has member-wide write policies while its restrictive read policy requires view_inventory. Stock adjustment authority needs explicit enforcement. | High |
| No branch foundation | No branches, employee-branch assignments or branch foreign keys exist. inventory.location and products.location are text, not trustworthy branch identity. | High |
| Cross-business relationships need stronger integrity | Separate business/product foreign keys do not prove that the referenced product belongs to the same business. Composite constraints are needed where appropriate; preserve historical sale-item snapshots and nullable product references. | High |
| Sales history is too broad | Sales SELECT is business-wide pos_access. POS getRecentSales filters a supplied membership ID and limits 20; it does not implement all authorized branch sales for the business-local day. Business timezone is not configured in the audited schema. | High |
| Multiple-business client assumption | Schema permits multiple businesses per owner; Owner lookup uses maybeSingle. Onboarding updates the first owned business, so it must not be reused to create another business. | Medium |
| Duplicate stock sources | Checkout updates products.quantity. inventory is a separate stock-shaped table; no production inventory rows currently exist. A second independently mutable stock source would produce conflicting balances. | High |
| Duplicate sale cores | private.complete_pos_sale and private.complete_pos_sale_with_receipt repeat transaction logic. Consolidate behind the existing wrappers only after characterization tests. | Medium |
| Employee-login copies diverge | Owner and POS copies differ in Auth email resolution, permission/default response and diagnostic errors. Blind copying/deletion could change login contracts. | Medium |
| Sensitive writes/audit span services | Staff Auth creation/reset and database updates are separate service-role operations. Compensation and authorization rechecks exist only partially; audit failure handling needs explicit tests. | Medium |

Price surfaces present are products.selling_price and products.cost_price. No variant price, wholesale/VIP/retail price-level columns or branch overrides were found; those structures must not be invented as existing functionality. Review cost-price visibility/update authority alongside sensitive field allowlists. Both active and is_active, and both reorder_level and low_stock_threshold, coexist; avoid unrelated destructive cleanup.

Actual owner checks and current employee/sale DML revocations already block several escalation paths. Broad employee INSERT/UPDATE RLS policies are dormant under current client grants; do not report them as an executed direct-write exploit. employee_permissions/business_members have read policies but no supported client permission-grant write path; add an owner-only trusted grant/revoke contract, not permissive table writes.

SECURITY DEFINER functions include mixed search_path choices. Harden touched functions with qualified identifiers and a fixed safe search_path; review authenticated/private execute grants and default privileges. Service-role operations must verify the real caller independently because RLS does not constrain service-role access. No service-role credential was identified in the inspected Flutter code; no secret values are included here.

PostgreSQL distinguishes table privileges from RLS: TRUNCATE/REFERENCES bypass row policies; permissive policies combine with OR and restrictive policies with AND. Missing explicit WITH CHECK alone is not proof of an update hole because USING can supply its default. See [PostgreSQL 17 row security](https://www.postgresql.org/docs/17/ddl-rowsecurity.html).

## Legacy data and compatibility

Read-only aggregate checks found one business, two products, zero inventory rows, two sales, one zero-price product and one inactive product. No noncanonical employee roles, duplicate employee identities or missing membership links were found in the checked aggregates. These checks do not prove every historical relationship is valid. No row-level customer/staff/financial contents were copied.

Do not infer that the zero-price product is pending or that any historical record belongs to a newly named branch. Require reviewed classification of existing zero-price products and explicit stock allocation before branch activation. Preserve historical branch-unknown records as NULL/legacy and keep them accessible to authorized owners. New branch-aware transactions must use verified assignments and branch stock; NULL must never bypass an activated business's branch enforcement.

No durable offline outbox was found in inspected POS checkout code. Preserve current request/receipt formats and any existing caller formats; do not claim offline reconciliation has already been implemented. Branch changes must never retag queued requests or an unfinished cart.

## Validation limits

Existing SQL tests cover sale replay/atomicity and several permission cases, but do not cover the complete Batch 2 adversarial matrix. They were inspected, not run against production.

Supabase local status returned exit 1: Docker and Podman are not available. No remote development branches exist. No local/staging authorization test environment was verified. Installing infrastructure or creating staging is outside this read-only checkpoint.

No Flutter tests or analysis were rerun for this audit. Batch 1's recorded results are Owner 61 passed, POS 20 passed; Owner analysis 210 findings and POS 10 informational findings, with nonzero analysis exits. Those are prior results, not Batch 2 execution or clean-analysis claims.

Audit complete does not mean production security is complete. The accompanying plan is the approval boundary for local implementation and isolated validation; production deployment remains separately prohibited.

## Post-approval local-source addendum

During implementation local Angel Edge source also allowed employee context and
had its own permission defaults. Actual ownership and selected-business checks
now protect that local boundary, with updated mock tests. This does not establish
identical deployed behavior: live Angel source was not reconciled in this batch.
Include it in deployment review. Original checkpoint results above are historical;
new local results and blocked database acceptance are in the completion/test
reports. No production writes, deployments or branch activation followed the audit.
