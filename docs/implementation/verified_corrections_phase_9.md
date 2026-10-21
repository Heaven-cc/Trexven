# Verified corrections — Phase 9: justified duplicate-index cleanup

Status: prepared only in supabase/changes/phase_9_duplicate_index_cleanup.sql; NOT deployed.
No index, query policy, grant, data row, application dependency or frontend was changed.

## Scope and evidence

Read current advisor findings and all 18 index catalog entries for nine reported duplicate pairs. For each pair compare the full pg_index structural record excluding only indexrelid, access method, tablespace, options and partition status. Compare complete CREATE INDEX definitions. All nine pairs match. Candidates are ordinary valid/ready/live non-unique indexes, not primary/exclusion/replica-identity/clustered/partition indexes. All 18 currently have zero constraint references, incoming dependencies and inheritance references.

The proposed removals each have zero scans in the current cumulative statistics. Where the peer has observed use, retain that peer. A zero-scan counter by itself is not the reason for removal: proven duplicate structure and retained equivalent coverage justify it. Keep one of each pair, never remove both.

| Table | Remove duplicate | Retain | Removed scans | Retained scans |
|---|---|---|---:|---:|
| business_members | business_members_business_idx | idx_business_members_business | 0 | 1745 |
| businesses | businesses_owner_id_idx | idx_businesses_owner | 0 | 0 |
| camera_events | idx_camera_events_business | camera_events_business_idx | 0 | 0 |
| camera_events | camera_events_occurred_idx | camera_events_business_time_idx | 0 | 49 |
| cameras | cameras_business_idx | idx_cameras_business | 0 | 3368 |
| inventory_movements | inventory_movements_business_idx | idx_inventory_movements_business | 0 | 42 |
| inventory_movements | inventory_movements_product_idx | idx_inventory_movements_product | 0 | 3 |
| products | products_business_id_idx | idx_products_business | 0 | 468 |
| sales | sales_business_id_idx | idx_sales_business | 0 | 244 |

All 18 currently occupy 16384 bytes each. Removing nine redundant copies would remove 147456 bytes (144 KiB) at the observed size. The practical intent is fewer redundant index maintenance writes as data grows. No benchmark or measured app-latency improvement is claimed; statistics can reset and current storage is small.

## Exact prepared SQL safeguards

- Require a transactional migration batch; local lock timeout 1 second and statement timeout 10 seconds.
- Acquire ACCESS EXCLUSIVE locks on the seven affected parent tables using NOWAIT. If any is busy, abort immediately rather than queueing the lock. Acquired locks are held until transaction completion; successful cleanup briefly blocks other access to those tables. This lock behavior is material and requires production approval.
- Validate all nine pairs before any DROP. Resolve current schema-qualified names; abort if missing, renamed, structurally different, partitioned, invalid or protected.
- Check both complete definitions against the observed baseline, plus equality of pg_index and index relation metadata excluding only the per-copy index OID.
- Recheck constraint, incoming dependency, extension-membership and inheritance protection before dropping a candidate.
- DROP INDEX ... RESTRICT only. No CASCADE, uniqueness change, FK change, raw-table/RPC grant, policy consolidation or data rewrite.
- Retained equivalents provide the same columns/order/predicates/operator classes/collations/include attributes and storage/access method. Neither app references index names through its REST data contracts.
- Keep all historical migrations unchanged. After separate approval, apply once and promote exact source to the actual generated migration version. On lock conflict or baseline drift, inspect current state before retrying; never force through the guard.

## Other findings remain intentionally pending

Current performance advisor groups: 123 missing-FK-index informational findings, 20 RLS initplan warnings, 69 multiple-permissive-policy findings, 34 unused-index informational findings, 1 no-primary-key informational finding and 9 duplicate-index warnings.

This patch targets only the nine proven duplicate pairs. Do not blanket-add 123 indexes, delete indexes merely because their scan count is zero, or merge permissive policies without preserving role/command/OR semantics and all restrictive account/admin/branch boundaries. Additional FK/RLS changes need their own workload/predicate evidence and review. No RLS policy or API behavior change is included here.

References reviewed:
- https://supabase.com/docs/guides/database/database-linter?lint=0009_duplicate_index
- https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys
- https://supabase.com/docs/guides/database/database-linter?lint=0003_auth_rls_initplan
- https://supabase.com/docs/guides/database/database-linter?lint=0006_multiple_permissive_policies
- https://supabase.com/docs/guides/database/query-optimization
- https://www.postgresql.org/docs/current/sql-dropindex.html

Used Supabase Postgres Best Practices (query/index guidance). PostgreSQL documents that a normal DROP INDEX takes ACCESS EXCLUSIVE on its parent, while DROP INDEX CONCURRENTLY cannot run inside a transaction. The prepared migration uses a guarded short transactional operation with NOWAIT; it does not pretend to be concurrent.

## Compatibility / validation / acceptance

Owner and POS keep their current API contracts, valid payloads, business/branch permissions and UI. Phase 8 NULL validation is separately deployed as 20261021020444. No source from either app is modified by Phase 9.

Read-only catalog/statistics review only: no local build, analyzer, test suite, EXPLAIN ANALYZE, load test, fake sales, generated backup or temporary file was run. No table lock or index drop was exercised during preparation. Device acceptance remains pending.

After approval: capture complete pre/post index inventory, verify exactly nine targeted indexes removed and all retained peers unchanged, constraints/RLS/grants/function definitions and financial row counts unchanged, and refresh the advisor. Do not describe unrelated performance/security warnings as fixed. User checks should cover ordinary Owner/POS reads, checkout/recovery, inventory and camera-event navigation without fabricated production transactions.
