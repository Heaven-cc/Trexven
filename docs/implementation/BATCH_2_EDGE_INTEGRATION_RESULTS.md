<!-- BATCH_2_CLOSURE_STATUS -->
# Batch 2 final Edge verification

8 October 2026 — final closure verification. **BATCH 2 — COMPLETE, STAGING VERIFIED.**

Staging `qysspzlfiysekvxnlzsh` retains four ACTIVE version-2 functions: employee-login, create-employee, manage-employee and Angel. No production function deployment occurred. Supabase JS is pinned to 2.117.2 with Deno lockfile; POS login-permission mirror is synchronized.

| Executed check | Final result |
| --- | --- |
| Real deployed main harness | 32/32; exit 0 |
| Boundary harness | 10 distinct checks latest passing; exit 0 |
| Deno frozen checks | Four entrypoints; exit 0 each |
| Deno shared runtime helpers | 9 passed; exit 0 |
| Combined Node wrappers | 12 TAP passed; exit 0 |

The boundary harness has four additional Edge checks and six REST checks; do not call all ten Edge-only tests. Five first-run boundary assertions failed because main fixture JWTs had expired. Reauthentication verified `/auth/v1/user` before retry; final ten passed. The attempt JSON preserves 20 attempts, 15 pass/5 fail. The earlier mirror-helper failure is preserved in initial Deno logs; corrected mirror and added cost assertions yield 9 final passes.

Coverage includes canonical role login, authorization derived from trusted membership, owner-only creation, manager sensitive-action restrictions, unauthorized branch reset denial, immutable password after denial, real six-digit numeric password reset/login/restore, persistence failure compensation, blocked employees, forged businesses and Angel authorization ordering. No provider credentials were configured: authorized Angel returns the expected unavailable-provider response; unauthorized callers are rejected first. AI generation itself remains deferred/unverified.

`verify_jwt:false` is intentional and retained: presession employee login and each authenticated handler implement their own appropriate session validation; it is not blanket authorization. Service-role administration stays server-side. Employee login serialization suppresses obsolete `view_profit`, preserving explicit `view_finance`; Angel product retrieval excludes purchase cost.

Evidence: [32 main checks](evidence/batch_2_closure_staging_edge.json), [boundary attempts](evidence/batch_2_closure_staging_boundary.json), [Deno runtime](evidence/batch_2_closure_deno_helpers_final.log), [Node runtime](evidence/batch_2_closure_node_tests_final.log). Commands are `deno check --frozen` on the four entrypoints, `deno test --frozen --allow-read` on shared tests, and `node --experimental-strip-types --test` on helper/employee/camera suites. Internal creation/reset scenario counts are not extra TAP tests. Test-only failure/hold helpers were removed after integration checks.

---

## Historical report — superseded by the closure update above

# Batch 2 deployed Edge integration results

8 October 2026. Staging-only integration **passed within the tested scope**. Production functions were not changed. All four required functions are ACTIVE, version 1, in qysspzlfiysekvxnlzsh. Deployment responses and bundle hashes are preserved in ../../supabase/tests/baseline/batch_2_final_operational_evidence.json.

## Implementation

Supabase JS imports are pinned to 2.117.2 in employee-login, create-employee, manage-employee and Angel; the shared Deno lockfile is included in deployment bundles. The POS employee-login mirror matches the canonical Owner source byte-for-byte. Local Deno 2.9.6 / TypeScript 6.0.3 was installed inside the ignored workspace tool directory.

Angel previously checked missing provider configuration before checking authorization. It now rejects employee/forged-business requests first and returns 503 with the authorized selected business for an owner when the provider is absent. No prompt, conversation or provider call is written in that case. Regression mocks and live requests verify this change.

No provider key, custom test secret, production key or paid provider was configured. Supabase-managed server environment variables supply privileged server clients; those keys were not retrieved or exposed to Flutter. Public staging API configuration and generated synthetic credentials were kept in ignored files and removed after testing.

## Authentication

Employee-login accepts pre-session Employee ID/password requests, verifies credentials through Auth and checks active employment/membership. Other functions explicitly validate bearer tokens with Auth getUser and derive authority through trusted caller-scoped database RPCs or ownership checks before using their server admin client. Client role, permission and business claims do not grant authority.

The deployed functions currently use verify_jwt=false with these explicit authentication checks. This is a deliberate application-authentication configuration, not a claim that the platform gateway verifies JWTs. Anonymous privileged operations were denied in live tests. Current [Supabase guidance](https://supabase.com/docs/guides/functions/auth-headers) recommends keeping gateway verification enabled for user-token-only functions; review/test that additional defense before production rather than assuming it is required for pre-session login.

## Executed tests

| Check | Result | Execution status |
| --- | --- | --- |
| Deno check of all four entrypoints and imported helpers | All type checks passed | Exit 0; batch_2_final_deno_check.log |
| Deno test --allow-read supabase/tests/batch_2_edge_helpers_test.mts | 8 passed, 0 failed | Exit 0; batch_2_final_deno_runtime_tests.log |
| Node helper + employee + Angel mocks | 11 TAP tests passed; creation/reset scripts contain 9/6 internal scenarios | Exit 0 |
| node supabase/tests/batch_2_final_edge.cjs | 32/32 named live checks passed | Exit 0; batch_2_final_edge_results.json |
| Boundary harness deployed Edge checks | Four additional named checks passed | Exit 0 on final run; batch_2_final_boundary_results.json |

Live coverage includes manager/sales/inventory login and canonical roles; forged context ignored; wrong/missing credentials and suspended employees denied; owner ordinary staff creation; restricted manager provisional creation; owner/manager promotion forbidden; anonymous, employee and other-owner denials; owner and authorized manager resets; old password rejection; manager self reset denial; cross-business/branch denial; and Angel owner context/employee rejection.

A temporary synthetic insert-failure trigger forced finalization to fail after Auth creation. The function compensated by deleting the uncommitted Auth identity. Aggregate evidence showed exactly seven expected users, five employees and seven memberships, with zero unlinked Auth users and zero failed-name employees. The trigger/function and all synthetic rows were removed.

A six-digit numeric credential was reset and successfully used for Employee ID login, then replaced with the original random synthetic password. This verifies compatibility of numeric credentials through the password pathway; no separate PIN hashing/reset service or PIN-strength/rate-limit stress test is claimed.

## Limits and recovery

Actual external Angel AI responses, SMTP delivery, operational rate-limit/load behavior and the narrow Auth-admin reset/revocation race are not fully certified. Password reset crosses SQL and Auth services: a pre-call audit intent and post-call completion record support reconciliation, but there is no distributed transaction. A completion-audit failure must be reconciled by an operator, not blindly retried as if no reset occurred.

An initial 2.117.3 dependency attempt was blocked by Deno's dependency-age safeguard. It was replaced with the older pinned 2.117.2, without bypassing the safeguard. Runtime mocks print Node's experimental type-stripping notice; Deno tests and cloud HTTP calls supply separate real runtime evidence.
