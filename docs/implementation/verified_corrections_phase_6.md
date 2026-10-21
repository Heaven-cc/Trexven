# Verified corrections — Phase 6: Owner Intelligence and manual exports

Status: frontend source implemented; not merged/released; user device acceptance pending.
No database migration or Edge deployment is required for these changes.

## Defects and implementation

- IntelligenceTab was a nested Scaffold/AppBar under MainScreen's existing TREXVEN AppBar. It is now a bounded Column with a compact, wrapping labeled toolbar. AI Live, Vision Server, Recordings, Refresh and Add camera / Connect Vision server remain connected to their existing routes. Camera overview, Events, camera cards, live feeds and empty/error/setup states remain. Refresh/Add are disabled while loading, and returning from Add camera checks mounted before reloading.
- The Data & Backup screen displayed Automated Backup Active and guaranteed cloud synchronization without observing a backup service. It now states that automated backup status is unavailable and identifies CSVs as manual extracts that cannot restore every business record.
- The old sales export used a single unpaginated sales read through a legacy single-product model. The new export service reads explicit authorized columns in stable UUID keyset pages of 500. Sales CSVs preserve modern transaction-header values and separate legacy fields rather than synthesizing single-product records. Item-level details, repayments and returns are explicitly excluded.
- Product CSVs retain catalog name/category/price/quantity, labeled catalog stock; no claim that this is an export of branch balances.
- Capture actor and selected business once; verify current identity and selected owner business before each page and before file/share handoff. Every page is explicitly business-filtered and every returned row must match that business. Rejected or incomplete loads never enter the share sheet. Changing account/business during preparation cancels the export.
- Neutralize formula-leading untrusted string cells, including leading whitespace/control characters, while preserving numeric cells as numbers. The CSV library still handles quoting. UTF-8 BOM is added for spreadsheet readers.
- One in-flight export only. Share sheet uses the originating tile's current RenderBox anchor, including iPad positioning after asynchronous loads. Screen disposal aborts handoff. Share result messages distinguish completed/canceled/unconfirmed states and never claim a verified backup or saved recipient copy.
- Files use dedicated trexven_csv_exports/export_* temporary staging directories. Pre-handoff failures delete the newly created staging directory. After handoff, recipient readers may be asynchronous: retain the copy and remove only app-owned directories older than 24 hours on the next export, with OS cache eviction as an additional mechanism. No general temp directory sweep or immediate deletion of a potentially active share occurs. Cleanup is best effort and does not delete recipient copies.

## Exact files

- lib/screens/intelligence/intelligence_tab.dart
- lib/screens/me/data_backup_screen.dart
- lib/services/business_data_export_service.dart
- docs/implementation/verified_corrections_phase_6.md

## Compatibility and evidence

Read MainScreen and its selected-business KeyedSubtree to confirm the nested header and bounded parent body. MainScreen, Appearance, design-system tokens, theme settings and navigation remain unchanged.
Read DatabaseService's owner selection/requireBusinessId and existing paging/projections. The export service reuses owner selection verification without changing the Finance tab's existing methods.
Read live products/sales/sale_items/inventory column metadata; only existing columns are requested. No extra raw-table grant, RPC, server export, storage object, schedule or backup job was created. The service captures one business scope and keeps table RLS authoritative.
Existing dependencies suffice: supabase_flutter, csv 6.x, path_provider and share_plus 10.x. No dependency version or lockfile changed. Reviewed share_plus versioned 10.x documentation for Share.shareXFiles and sharePositionOrigin; no migration to the newer SharePlus API was introduced.
POS source and shared backend behavior are unchanged. Approved POS design/crash corrections and Owner's four-theme appearance are retained.

No local build, analyzer, test suite, generated CSV/temp file, backup, login or fake transaction was executed. Source inspection is not device acceptance. CSV exports are not an atomic database snapshot: concurrent business changes remain possible and are disclosed on screen.

## Manual acceptance (user; not executed)

- Intelligence: one TREXVEN header, usable wrapped toolbar on small screens/large text, all five actions, Events and live feed navigation intact in all four themes.
- Camera loading/error/setup/empty states and return after Add camera do not call setState after disposal.
- Export more than 500/1000 products or sales: stable paging, all accessible records, selected business only.
- Modern multi-item and legacy sales: header totals and legacy fields remain distinct; no fabricated per-product values.
- Formula-like names/categories, leading tab/whitespace, commas, quotes and newlines open as text; genuine negative numbers remain numeric.
- Account/business change, revoked owner access, failed later page and disposal: no partial export handoff.
- Repeated taps: one export. iPad share positioning, rotation, cancellation and unconfirmed share results are usable and truthful.
- Pre-handoff failure deletes its staging directory; a later export removes expired app-owned copies without deleting active or unrelated cache content.
- Backup status does not claim monitoring, automated backups or restore readiness.
