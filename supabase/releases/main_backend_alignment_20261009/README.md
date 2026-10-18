# Production package executed

The seven reviewed migrations and four reviewed Edge replacements have been deployed under final explicit authorization to `ufehcfrlygqvminfjumf`. See the [actual execution report](../../../docs/implementation/PRODUCTION_DEPLOYMENT_EXECUTION_REPORT.md). History is 16 and read-only postflight passed. Do not rerun the execution wrapper or pre-deployment-only preflight against the migrated schema; those safeguards deliberately expect the original nine-history baseline. Package verification still checks immutable SQL/Edge source hashes. The manifest now records deployed versions and evidence. Timezone configuration was explicitly excluded; branches remain disabled and applications unpublished.

---

# Main-backend release package — current preparation

Target: `ufehcfrlygqvminfjumf`. No production writes are authorized yet. The authoritative [final compatibility/deployment plan](../../../docs/implementation/FINAL_COMPATIBILITY_AND_COORDINATED_DEPLOYMENT_PLAN.md) specifies actual results, exact seven-file order, secure execution, four reviewed Edge Functions, pending-data retention and separate timezone approval.

Run `python supabase/releases/main_backend_alignment_20261009/verify_package.py` before execution. The manifest freezes all nine history files, seven pending migrations, eight Edge source files and gateway flags. `preflight.sql` is read-only and must pass against main; it is not a migration. The supported TLS/PGPASSFILE production dry-run passed with exactly seven files. The corrected runner uses WSL direct exec, not URL interpolation into a shell. The current runner is dry-run only; no production writer was executed.

A protected C-drive replacement backup is recovered and current, as recorded in evidence; prior D copies failed checksum and are rejected. Recheck freshness after pausing writers immediately before any approved deployment. Both ARM64 debug APKs are prepared and signature-compatible with previous local artifacts, but physical installed-device identity/pending-state verification remains outstanding. Development-only status does not prove that state. Never uninstall or clear data with pending work.

After device verification, obtain separate explicit approval for seven migrations and the four reviewed Edge replacements. The proposed one-business timezone write requires explicit inclusion. Apply no baseline, seeds, roles, history repair, branch activation, customer data import or public application release. Stop and record partial failure; use reviewed forward recovery. See the linked plan for all execution/postflight steps and limitations.
