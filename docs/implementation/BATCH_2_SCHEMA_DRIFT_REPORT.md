# Batch 2 schema drift report

8 October 2026. Based on approved production metadata and recorded migration SQL,
not production tests or copied records. Baseline has not been restored.

## Migration history comparison

All nine local historical versions/names are present in production; there is no
missing version among these nine. The three Batch 2 versions are absent as expected.
Normalized SQL AST comparison matches seven historical files. Raw hashes differ
with whitespace/comments/statement splitting, so byte inequality alone is not drift.
Detailed counts/hashes are in `supabase/tests/baseline/validation_and_drift.json`.

| Migration | Comparison |
| --- | --- |
| 20260819180000 camera_ai_fixes | Normalized SQL matches recorded history |
| 20260823100000 employee_management | Substantive definition/policy drift |
| 20261002014604 backend_integration_repairs | Normalized SQL matches |
| 20261002015419 backend_rpc_grants_hardening | Qualified versus unqualified outer-column reference |
| 20261002123039 helper_function_anon_execute_hardening | Normalized SQL matches |
| 20261002124738 account_delete_audit_fk_hardening | Normalized SQL matches |
| 20261003224001 testing_readiness_access_controls | Normalized SQL matches |
| 20261004025120 native_camera_rate_isolation | Normalized SQL matches |
| 20261005004045 sale_submission_reliability | Normalized SQL matches |

### Employee migration: recorded SQL is not actual table creation evidence

Recorded 20260823100000 SQL declares first_name/last_name/department, strict
role/code constraints and manager membership-based employee/audit policies.
The local file instead declares name/email, includes provisional employee role,
and owner-based policy names/checks. Actual production employees has name/email,
no first_name/last_name/department, nullable role/code, no role/status CHECK and no
employee-code UNIQUE constraint. It has PK and business/Auth FKs. The manager
policy names from recorded history exist alongside an owners-manage policy.

CREATE TABLE IF NOT EXISTS would not alter a pre-existing table. This evidence
does not prove columns were later dropped; the original state/change chronology
cannot be inferred from it. Preserve actual catalog definitions. Do not replay
either recorded or local CREATE as though it recreates production. Batch 2's
employee-code unique index is a new enforcement step; real duplicate/null/identity
preflight remains a separate deployment requirement, not proved on empty staging.

### Permission-read policy: representational difference

20261002015419 recorded history uses e.id=employee_id, while the local file uses
e.id=employee_permissions.employee_id. The live deparsed policy explicitly resolves
to the outer employee_permissions column. No executed bypass is inferred from the
unqualified spelling. The baseline keeps the live resolved expression.

## Missing original schema

Only seven current tables have CREATE definitions in historical files. These
25 do not: alerts; angel_conversations/messages/insights; business_activity,
business_members, business_settings, businesses; camera_ai_jobs, camera_detections,
camera_event_links, camera_events, camera_health_logs, camera_zones, cameras;
cash_transactions, employee_activity, expenses, financial_transactions; inventory,
inventory_movements, products, recordings, sale_items, sales. All are public tables.
The earliest migration explicitly documents the missing initial schema.

Fourteen live function bodies/contracts match their latest direct repository CREATE
definitions after harmless built-in type/default formatting normalization. Eight
have no direct current CREATE definition: three private sale cores and five public
helpers (camera activity/dashboard, both timestamp triggers and user_owns_business).
The three private cores are derived dynamically from earlier functions by the
readiness/submission migrations; direct AST absence is not a missing migration.
The original public sale bodies needed for that derivation are absent from the
initial history. The recovered catalog captures all 22 current definitions.
No substantive difference was found among the 14 directly comparable contracts;
ALTER/dynamic policy/grant transformations still require restore/catalog parity.

## Security and compatibility concerns for approval

- The pre-Batch-2 source deliberately retains known price/pending/staff-default
  gaps and broad policies. Do not expose staging with real users before the
  coordinated hardening stack is applied and tested.
- Existing anon/authenticated grants include TRUNCATE/REFERENCES/TRIGGER and
  MAINTAIN on many public tables/defaults. Batch 2 revokes the first three but does
  not explicitly revoke MAINTAIN. This is an additional least-privilege review
  item, not a demonstrated REST exploit; no adversarial production test ran.
- Platform-owned supabase_admin defaults already match staging but cannot be
  altered by staging postgres. Preserve/verify managed defaults rather than
  assuming the role. Before deployment, review how future platform-created tables
  receive excessive grants; schema recovery does not fix that issue.
- No production permission records were exported. Seven canonical permission IDs
  needed by grant/revoke tests must come from the reviewed repository reference
  seed. Missing IDs must not be mistaken for a price/RLS failure. Private bucket
  configuration is also a separate repository-derived seed, not copied records.
- Source/staging PostgreSQL minor versions differ (17.6 / 17.11). No custom
  operators or ltree/btree_gist extensions were found; pgcrypto encrypted data was
  not inspected/exported. Runtime compatibility still needs staging rehearsal.
- Legacy product/stock/sale/member/request definitions and RPC signatures are
  retained. No zero-price reclassification, branch mapping or history backfill is
  present. Staging has no historical records: compatibility must use synthetic
  legacy-shaped examples, not claim real production record validation.
- The baseline target setting is a procedural guard, not a trusted identity
  oracle. An independently verified explicit staging project reference is required;
  the existing CLI link points to production and must never execute staging work.

No production SQL writes, function deployment or schema cleanup was performed.
