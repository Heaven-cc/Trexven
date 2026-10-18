# Batch 2 closure review map

8 October 2026. Production unchanged; review local code, staging execution evidence and final reports before any release.

| Change | Files |
| --- | --- |
| Retain historical cost, remove active access | `supabase/migrations/20261008020234_batch_2_purchase_cost_contract.sql`; `supabase/tests/batch_2_cost_contract_tests.sql` |
| Trusted business day and timezone boundaries | `supabase/migrations/20261008021428_batch_2_business_day_contract.sql`; Owner `lib/services/database_service.dart` |
| Explicit non-cost product contract; null price retained | Owner `lib/models/product.dart`, `lib/services/database_service.dart`, `lib/screens/me/data_backup_screen.dart`, `test/product_contract_test.dart`; POS `lib/src/features/inventory/product_repository.dart` |
| Remove obsolete profit grant and Angel cost projection | Owner/POS `supabase/functions/_shared/login-permissions.ts`; Owner `supabase/functions/angel/index.ts`; POS permission service and employee model; shared helper tests |
| One native pending intent before dispatch | POS `lib/src/services/pending_sale.dart`, `pending_sale_file.dart`, `pending_sale_unsupported.dart`; pinned direct path_provider dependency |
| Startup recovery and actor-safe receipt acknowledgement | POS `lib/src/features/pos/pending_sale_provider.dart`, `checkout_screen.dart`, `lib/main.dart` |
| Actual persistence/process/API regressions | POS `test/pending_sale_test.dart`, `pending_sale_live_restart_test.dart`, `checkout_flow_test.dart`, permission tests |
| Recovery renderer with explicit column ACLs | `supabase/tests/baseline/build_baseline.py`; immutable original baseline preserved; new `BATCH_2_CLOSURE_RECOVERY_CHECKPOINT.sql` |
| Reproducible isolated execution | `supabase/tests/closure/README.md` and nonsecret guarded harnesses; actual catalogs in `supabase/tests/baseline/BATCH_2_CLOSURE_*_CATALOG.json` |
| Live staging regression adaptations | `supabase/tests/checkpoint_b_rest.cjs`, `batch_2_final_edge.cjs`, `batch_2_final_boundaries.cjs`, shared Deno/Node tests |
| Closure documentation | Twelve required reports, historical report entry-point updates, `evidence/batch_2_closure_*` and `evidence/pos_batch_2_closure_*` |

Four original applied migrations and the approved pre-Batch-2 baseline have unchanged SHA-256. Existing unrelated Owner work and the master UI/KPI architecture were preserved. POS has no Git repository in this workspace, so its test logs are copied into the Owner evidence directory. No mixed-work commit, production deployment or app release was performed.
