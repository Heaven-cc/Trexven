# Batch 3 test results — 9 October 2026

Final source was tested locally. Production/staging were not migration or test targets. Both applications still point to the main intended backend; new RPCs are not deployed there.

| Check | Actual result | Exit |
|---|---|---|
| Owner full Flutter suite | 75 passed, 0 skipped | 0 |
| POS full Flutter suite | 45 passed, 1 explicitly skipped live-backend test | 0 |
| Owner analysis | 208 informational, 0 warnings, 0 errors | 1 |
| POS analysis | 4 informational, 0 warnings, 0 errors | 1 |
| Local Auth/REST | 27 passed checks, actual synthetic Auth sessions | 0 |
| Deno Edge helper tests | 9 passed, 0 failed | 0 |
| Concurrent stock | 12 distinct changes plus six same-key retries; 13 movements, final 113 | 0 |
| Revocation race | Revoker waited for active authorization; next request denied, final 101 | 0 |
| Final clean schema replay | Baseline + six immutable Batch 2 files + final Batch 3 file, each exit 0 | 0 |
| Packaged Python harness | py_compile executed successfully | 0 |

SQL suites on final fourth disposable (actual SELECT assertion invocations, helper definitions excluded):

| Suite | Assertions | Exit |
|---|---|---|
| batch_3_catalog_inventory_tests | 42 | 0 |
| batch_2_authorization_tests | 21 | 0 |
| batch_2_branch_isolation_tests | 17 | 0 |
| batch_2_price_security_tests | 14 | 0 |
| batch_2_checkout_compatibility_tests | 11 | 0 |

Total 105 executed assertions. Four earlier Batch 2 regression bodies retained their authorization/receipt assertions; only fixture nonzero stock insertion and zero-price setup were adapted to the required reasoned catalog stock/import RPC. This is not a claim that unmodified old direct-stock fixtures pass against Batch 3. Each suite rolls back. Only seven reviewed permission definitions were seeded; no optional Storage bucket seed was applied.

The final migration SHA-256 is `1045d82c16082f519af78e379a54b53fe9f4955da39d9455bfb123a423424823`. Baseline SHA `5eb2ee5437911b21eab424a05abf21eb7cc7945bc805e5a41d58459e21b3e21e`; all six Batch 2 hashes are unchanged. Four independent disposable stacks were used during iterations; the final full migration was reconstructed cleanly on the fourth. Earlier replay/function refresh logs are retained and are not substituted for this final complete replay. Ordered SQL execution did not forge Supabase migration-history entries.

Coverage: inventory/manager price restrictions including revoked grants; direct quantity bypass; manufacturer barcode/SKU duplicate rejection; variant identity; bulk creation, atomic rollback, explicit updates, omitted-price preservation and replay; pending/archived unsellability and valid zero-price checkout; fractional receipts and stock; zero-inclusive alert dedup/recovery; future price audit; history-protected unit changes; forged businesses, missing identity, real REST RLS reads and current-session revocation. Original Batch 2 branch/isolation/checkout regression suites pass. Branch activation/new branch stock workflows are not claimed.

Investigated failures/recovery:

- Initial native runtime extraction under /tmp failed; a separate owned persistent runtime was used. No hosted changes.
- Fixture reference permissions were initially absent and old authenticated nonzero quantity inserts conflicted with the new stock guard. The harness now seeds only reviewed permissions and adapts synthetic setup through the RPC, without weakening guards.
- An initial assertion used the wrong receipt field; corrected to the existing `id` contract. Concurrent quantity formatting `113` vs `113.000` was corrected to numeric comparison and rerun.
- Initial HTTP-mock responses omitted their request reference; tests were fixed and rerun. A native HTTP harness expected 200 for a successful void RPC; corrected to allow 204, then all 27 checks passed. No backend workaround.
- Final Flutter attempt hit drive C disk-full (errno 112), then damaged compiler cache caused closed-connection/invalid-kernel errors. Those runs were interrupted, not counted as passes. Generated test caches were preserved on a dedicated drive D task directory, task-owned leftover compilers stopped, generated caches cleared and final full suites rerun successfully. Existing APKs/user data were untouched.
- Added missing-brace informational findings were fixed only in touched catalog files, followed by final full tests/analysis. The remaining 208 Owner/4 POS informational findings are reported, not a clean analysis claim.

Evidence: [final summary](evidence/batch_3_final_verification.json), [SQL](evidence/batch_3_sql_results.json), [HTTP](evidence/batch_3_http_results.json), [reconstruction](evidence/batch_3_replay4_reconstruction.json), [concurrency](evidence/batch_3_concurrency_results.json), [revocation](evidence/batch_3_revocation_race.json), and full per-app test/analysis logs in evidence. Reproducible guarded harnesses are in supabase/tests/batch3.

Not executed: production migrations/deployments/writes; real production operational backup/recovery (secure connection missing); true-gateway valid-session smoke on replacement Edge bundles; Android native file chooser/scanner instrumentation; APK installed/distributed compatibility; OCR provider integration. No tests are claimed for these. All four owned native stacks were stopped through supported named-stack commands, preserving local synthetic data only. Private local runtime logs/keys are not release evidence.

Main-backend alignment update: see [MAIN_BACKEND_ALIGNMENT_REPORT.md](MAIN_BACKEND_ALIGNMENT_REPORT.md) and the guarded release package in supabase/releases/main_backend_alignment_20261009. Fresh live metadata matches all six baseline sections; the supported CLI applied exactly seven pending files to a new disposable with nine original history metadata entries, recorded history 16 and returned an empty second dry-run. Post-push 105 SQL assertions and 27 local HTTP checks passed. No production history repair, baseline restore or additional Flutter fix is required. Production backup, client/Edge acceptance and explicit approval gates remain pending.
