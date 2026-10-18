<!-- BATCH_2_CLOSURE_STATUS -->
# Batch 2 final security review

8 October 2026 — final closure verification. **BATCH 2 — COMPLETE, STAGING VERIFIED.**

No unresolved critical/high Batch 2 security defect was identified in the tested contracts. This conclusion is bounded by the executed suites; advisor output and untested platform capabilities are not represented as clean or certified.

Authorization derives from auth.uid and trusted membership, not payload role/permission JSON. Owner-only app/backend operations, restricted POS roles, sensitive explicit manager grants, multi-branch assignments, cross-business/forged-branch denial, price protection on direct inserts/updates/upserts and alternative RPCs, revoked stale sessions, concurrent transaction locks and checkout receipt/idempotency were exercised. PG17 MAINTAIN exposure is revoked and RLS recursion recovery remains effective. Missing identity/zone/permission fails closed.

Purchase-cost remains stored with existing constraints/data but is unavailable through active authenticated product grants, product/CSV projections, cost-bearing audit rows and Angel contracts. `view_profit` is explicitly obsolete; no owner/manager shortcut re-enables it. No column/table/customer data was destroyed to remove the feature. Trusted service-role processing remains server-side; Flutter uses public configuration and user authentication only.

The durable intent has no JWT/password, binds immutable actor/business/membership/branch/request and rechecks actor after async results. It stores one native local sale intent; encryption/device-hardening beyond OS application support is deferred to the planned offline engine. Browser submission fails closed. Supabase managed `realtime.apply_rls` was inspected: column privileges filter returned new/old fields; Owner's app subscription performs invalidation and explicit safe fetch. Actual websocket event delivery was not separately instrumented.

## Current staging advisors — remaining findings

| Level / finding | Count | Assessment |
| --- | ---: | --- |
| INFO private RLS enabled without policy | 3 | Private internal tables fail closed; not API-exposed |
| WARN authenticated SECURITY DEFINER executable | 13 | Intended gated RPCs; authorization and search_path reviewed/tested |
| INFO unindexed FK | 34 | Capacity/query-specific review remains |
| WARN auth RLS initplan | 16 | Optimization candidates, no privilege broadening |
| INFO unused index | 39 | No index dropped from short-lived test statistics |
| WARN multiple permissive policies | 61 | Composed policies reviewed; OR-policy risk tested |
| WARN duplicate index | 9 | Compatibility dependencies prevent blind removal |

Counts use each advisor group's `count`, not grouped-array length. [Final raw advisors](evidence/batch_2_closure_advisors.json). Earlier scans included temporary helpers and an Auth-setting warning; no Auth setting was changed. Absence of that warning from the latest scan does not prove leaked-password protection was enabled.

Official guidance: [SECURITY DEFINER lint](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable), [private RLS lint](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy), [RLS initplan](https://supabase.com/docs/guides/database/database-linter?lint=0003_auth_rls_initplan), [permissive policies](https://supabase.com/docs/guides/database/database-linter?lint=0006_multiple_permissive_policies). No production load-capacity conclusion is derived from synthetic fixtures; the earlier small RLS benchmark is historical, not rerun evidence.

Cleanup retained permission/migration/Edge state and removed synthetic users/data/helpers/credentials. Automatic review rejected a broad disposable cleanup before execution; read-only inventory then exact allowlisted IDs produced an approved scoped cleanup. Production metadata matches its recovered catalog; no production writes/settings/app releases occurred.

---

## Historical report — superseded by the closure update above

# Batch 2 final security review

8 October 2026. Tested authorization protections **pass in staging**; overall security/release acceptance remains **BLOCKED** by missing evidence and a cost-visibility decision. This is not exhaustive proof that no vulnerability exists.

## Verified protections

Trusted authenticated identity, actual business ownership, active membership/employment and relational grants/denials drive authorization. Owner-role strings and client permission JSON do not grant ownership. REST/RPC tests deny cross-business reads/writes, manager escalation, forged identifiers, unauthorized branches and employee price writes through insert/update/upsert/bulk paths. Revocation takes effect without refreshing a JWT; held-row tests verify checkout/price/revocation transaction ordering.

The existing portable fourth migration removes recursive membership RLS by reusing protected can_read_staff through can_read_membership. It revokes PostgreSQL 17 MAINTAIN on current public tables and postgres default table grants. Public CREATE and authenticated products MAINTAIN checks are false. Final schema comparison matches 30/30 groups with no widened grants.

All 29 current SECURITY DEFINER functions are postgres-owned with explicit search_path settings. New Batch 2 definers use an empty path and qualified application objects. Preserved legacy onboarding/camera trigger paths use public with qualified tables; user_owns_business explicitly places pg_temp after public. Client schema CREATE is denied. Private cores/trigger functions are not granted as anonymous REST transaction endpoints. Definer functionality remains authorization-checked; warnings were not hidden by changing to invoker and breaking RLS.

Edge admin operations follow Auth token validation and trusted caller authorization. Creation failure compensation was exercised in the deployed function; denied branch reset leaves the original credential valid. Auth-admin reset cannot be atomically joined to SQL audit/permission transactions: repeated authorization plus audit intent narrows risk but does not certify every concurrent revocation/audit-failure outcome.

## Price visibility: unresolved policy

Write protection is enforced for selling_price and cost_price. Read protection is different: authenticated inventory/product reads currently expose both columns when inventory/POS access allows the row. A real sales-employee GET returned the cost_price field, and catalog privilege inspection confirmed column SELECT.

The master requires separate price visibility, but does not supply an approved cost-price reader mapping. An owner decision was requested: owners plus managers explicitly granted view_finance, or another approved rule. No rule was invented and no column revocation was applied that would silently break existing SELECT-star repositories.

Treat this as an unresolved confidentiality/design requirement and production gate, not as a passed privacy check. Before acceptance, implement the approved contract in grants/RPC/view and both repository projections, then test direct REST, explicit column selection and alternative paths. Potential impact is sensitive cost disclosure to otherwise authorized product readers; severity depends on the approved access policy.

## Advisor disposition

| Current finding | Count / level | Disposition |
| --- | --- | --- |
| Private RLS with no policies | 3 INFO | Intentional direct-client denial on internal request/rate ledgers |
| Authenticated public definer endpoints | 12 WARN | Intentional authorization/atomicity boundaries; reviewed, tested allow/deny paths, keep visible |
| Unindexed FKs | 34 INFO | Potential parent-maintenance/read workload cost; includes new composite references; no unproved extra indexes |
| Auth RLS initplan | 16 WARN | Legacy per-row evaluation cost; production-scale evidence needed |
| Unused indexes | 40 INFO | Usage counter changes with synthetic activity; not evidence for dropping indexes |
| Multiple permissive policies | 61 WARN | Preserved baseline OR policies constrained by grants/restrictive boundaries; no observed scope bypass |
| Duplicate index groups | 9 WARN | Preserved baseline redundancy; dependencies/workload must be proven before removal |

A rollback-only 1,000-product insertion produced 1,003 visible rows under real authenticated-role RLS. EXPLAIN ANALYZE used products_business_id_idx: planning 0.123 ms, execution 328.585 ms, 10,546 shared-hit blocks. Repeated helper evaluation is measurable; one warm synthetic run is not a production SLO, load test or basis for arbitrary RLS consolidation. All inserted benchmark rows rolled back. Live checkout race tests passed but no production-size throughput claim is made.

Full advisor findings, query/plan and privilege evidence are in batch_2_final_operational_evidence.json. No new indexes or policies were dropped to silence warnings; platform-managed default grants were not modified.

References: [definer endpoint review](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable), [FK indexes](https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys), [RLS initplan](https://supabase.com/docs/guides/database/database-linter?lint=0003_auth_rls_initplan), [permissive policies](https://supabase.com/docs/guides/database/database-linter?lint=0006_multiple_permissive_policies), [duplicate indexes](https://supabase.com/docs/guides/database/database-linter?lint=0009_duplicate_index).

## Remaining boundaries

No service-role credential was exposed to clients. Deployed verify_jwt=false handlers explicitly authenticate users; separately review gateway verification for user-token-only functions before production. Actual provider response, login rate-limit/SMTP delivery, device restart, clock-controlled DST integration and full backup/replay remain unverified. No claim of complete critical/high-severity clearance is made while required cost-policy and lifecycle evidence are unresolved.
