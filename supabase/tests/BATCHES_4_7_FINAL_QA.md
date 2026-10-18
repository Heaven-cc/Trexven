# Deferred Batch 4–7 QA

These new suites have **not been executed**. Do not interpret syntax parsing or
earlier Batch 4 results as a pass for the current source. No production or
production-derived customer records are test inputs.

Recover the local WSL/PostgreSQL runtime and adequate C: scratch space first.
Reconstruct a fresh synthetic loopback schema from the reviewed application-only
baseline, approved original reference permissions, and deployed Batch 2/3
foundation. Replay the 14 new migrations in filename order, including the final
Batch 4 recovery migration **after** Batch 7. Do not use the old Batch 4 function
refresh script: it omits newer dependencies and is not a full migration replay.

The explicit `run_batches_4_7_deferred.py --execute-final-qa` runner requires
`BATCH3_REPLAY_RUN=6`; `native_sql.py` independently verifies the owned synthetic
loopback stack, excludes a remote database URL and uses the existing local test
connection. Every suite has a fresh synthetic fixture and rolls back. No Storage
bucket or customer data seed is applied by this runner.

Run the six SQL suites, `billing_provider_test.ts`, Owner and POS suites, Flutter
analysis and compatible Android update/restart tests in the final QA phase.
Report commands, counts, exit codes and informational/deprecation findings.
Add concurrent-session coverage for revocation, count versus checkout, drawer
close versus late synchronization, and webhook/payment identity conflicts.
Test JWT gateway behavior for the revised `camera-ai` and `delete-account`
functions, including missing/invalid tokens and employee lifecycle denial.

Device gate: an update with the same application ID/signing identity must retain
the version-1 pending journal, encrypted queue and secure-storage keys. An
uninstall/reinstall can delete them; it is not safe while unresolved money or
queued sales remain. A corrupt/lost key must fail closed, never silently clear
the encrypted file. Existing APKs do not contain these new changes.

Billing commercial values in the SQL suite are synthetic transaction-local test
settings only. No real provider, webhook or charging is enabled. Backup metadata
does not prove that an operational backup can be restored.
