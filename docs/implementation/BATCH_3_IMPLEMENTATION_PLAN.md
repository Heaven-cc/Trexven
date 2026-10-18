# Batch 3 implementation plan — 9 October 2026

Batch 3 local development is authorized now. Its intended shared main backend is `ufehcfrlygqvminfjumf`. Supabase staging `qysspzlfiysekvxnlzsh` remains the Batch 2 verification/recovery reference and is not the Batch 3 default backend. Production writes and deployment remain unapproved.

The master implementation and UI/UX specifications remain authoritative. Existing sellable product IDs, membership IDs, receipt IDs, checkout RPC arguments, request keys and durable submission formats are retained. Products become variants by adding an optional parent group and string attributes; existing products are not rebuilt.

Implemented review units:

1. Additive migration `20261009003200_batch_3_catalog_inventory_foundation.sql`: groups, composite business scope, uniqueness of nonempty trimmed manufacturer barcode/SKU, trusted catalog permissions, explicit stock RPC and movement history, idempotency, pending unpriced products, threshold latches and price history. SHA-256 `1045d82c16082f519af78e379a54b53fe9f4955da39d9455bfb123a423424823`.
2. Owner `Product`, `DatabaseService`, catalog editor/import screens, inventory navigation and restock delta adapter. Search/category/archive controls and CSV/XLSX reviewed creation/update; no generated barcodes or purchase costs. Native file picker dependencies are pinned in pubspec/lock.
3. POS product repository/models, quick-add actual database identity, duplicate barcode handling, authorized catalog editor and decimal unit quantity/cart/receipt support. Price fields require owner or manager with the existing explicit `override_price` grant. Stock requires `adjust_stock`.
4. Isolated SQL, real Auth/REST, concurrency, permission-race and Flutter tests, followed by analysis and updated release evidence.

Stock is changed atomically by signed deltas with reasons and request UUIDs. Countable/unknown legacy units stay whole; approved measured units are kg, g, litre, ml, metre and cm with at most three decimals. PostgreSQL uses NUMERIC; POS line totals use integer fixed-scale arithmetic. Existing zero prices remain valid; null prices remain pending/non-sellable. Prices allow at most two decimals. No historical price/quantity backfill occurs.

Bulk import/update is owner-only until a separately approved bulk permission exists. Updates require explicit reviewed target selection and preserve omitted price/attributes; initial quantity cannot reset existing stock. Threshold changes reuse existing explicit sensitive-manager permission rather than inventing a new entitlement.

The new global catalog mutation paths fail closed when branches are activated. Real branch activation, historical inventory mapping, branch price overrides and branch stock workflows require their own approved mapping/workflow implementation. OCR review integration/provider operation and camera/native file-picker instrumentation remain pending. No UI/KPI redesign, packs conversion, purchase costs or unrelated master batch is included.

Validation uses a separately owned disposable native Supabase reconstructed from the recovered schema-only baseline plus the six unchanged Batch 2 migrations and this migration. Hosted production/staging receive no tests, synthetic users, migrations or function deployments in this work.
