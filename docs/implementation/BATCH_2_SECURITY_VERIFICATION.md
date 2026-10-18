# Batch 2 security verification

<!-- BATCH_2_FINAL_STATUS -->

8 October 2026 final completion phase: **BLOCKED**, staging-only. This section supersedes the historical checkpoint statements below. Production remains read-only and no release is authorized.

Four required Edge Functions are deployed and integration-tested. Current results: 73 SQL checks plus four older suites; 36 main REST/RPC, 32 main Edge and 10 boundary named checks have final passing outcomes. Owner 64/POS 34 Flutter tests pass. Analysis: zero errors/warnings, Owner 209/POS 4 infos, exit 1 each. All 30 staging catalog groups match after cleanup; only 11 permission definitions and five migration-history entries remain alongside the four deployments.

Fresh replay and actual restore remain blocked by the missing approved disposable environment. Cost-price visibility needs an owner-approved reader contract. Device/persistent pending-sale recovery and controlled-clock midnight/DST HTTP lifecycle remain unverified; no later-phase offline engine or UI redesign was started. See [final completion report](BATCH_2_FINAL_COMPLETION_REPORT.md) and [acceptance matrix](BATCH_2_FINAL_ACCEPTANCE_MATRIX.md).


## Historical checkpoint record — superseded by final status above

# Batch 2 security verification

8 October 2026. **PASSED WITH DOCUMENTED LIMITATIONS in dedicated staging.**
Real SQL/RLS and authenticated HTTP coverage is recorded in
BATCH_2_DATABASE_TEST_RESULTS.md. Production remains unchanged; no production
credentials/records were used. Standard staging Auth issued synthetic JWTs; no
service-role key entered Flutter, the HTTP harness or committed artifacts.

Verified: trusted active employment/membership, owner business isolation, employee
owner-only administrative rejection, owner-only grant/role changes, manager
escalation denial, direct and bulk price protection, pending products, explicit
manager pricing/revocation, assigned/inactive branches, forged business/branch
identifiers, legacy checkout/member IDs, exact receipts/request-key retries and
atomic failed checkout. Revocation is evaluated from current database rows despite
stale JWTs. Held-row concurrency verifies authorization/price transaction ordering.
Existing explicit authorized zero and omitted NULL price are distinguished.

The first real SQL test found recursive employee/membership RLS. A versioned
forward migration introduces private.can_read_membership, reusing can_read_staff,
and moves the membership lookup inside trusted definer execution rather than
joining the RLS-protected employee table in a policy expression. No duplicate
permission contract or relaxed policy was introduced. MAINTAIN table/default
grants were also revoked. Anonymous execute and private transaction cores remain
closed in tests; restrictive policies and table mutation revocations protect
against legacy permissive policies.

## Final advisors compared with Checkpoint A

| Finding | Checkpoint A | Final B | Interpretation |
| --- | ---: | ---: | --- |
| RLS enabled, no policy | 3 INFO | 3 INFO | Private request/rate ledgers intentionally deny direct clients |
| Authenticated public SECURITY DEFINER execution | 5 WARN | 12 WARN | Intentional privileged, authorization-checked RPCs; review remains necessary |
| Unindexed foreign keys | 25 INFO | 34 INFO | New composite/branch references increase index review needs |
| Auth RLS initplan | 16 WARN | 16 WARN | Preserved legacy policy performance work |
| Unused indexes | 61 INFO | 41 INFO | Test activity changes usage counters; not evidence for deleting indexes |
| Multiple permissive policies | 61 WARN | 61 WARN | Preserved baseline policies; effective grants/restrictive boundaries tested |
| Duplicate indexes | 9 WARN | 9 WARN | Preserved redundant indexes; no automatic removal |

Final advisors have 15 security and 161 performance findings, with full per-object
details in checkpoint_b_security_advisors.json and checkpoint_b_performance_advisors.json.
No advisor was silenced by removing a policy/index without dependency review.

The 12 public definer endpoints are assert_trexven_staff_access,
complete_trexven_onboarding, create_trexven_branch, finalize_trexven_employee,
is_business_member, set_trexven_branch_assignment, set_trexven_branch_status,
set_trexven_employee_permission, set_trexven_employee_status,
submit_trexven_branch_sale, update_trexven_employee and user_owns_business.
They require privileged lookup or atomic mutation; their bodies check caller
identity/ownership or trusted membership, and grants exclude anonymous access.
Tested allow/deny paths do not establish exhaustive proof of every input or future
change. Keep these warnings visible; do not switch to invoker mechanically and
break RLS lookups.

Nine additional FK findings concern request branch, compatibility branch,
assignment employee/branch composite keys, inventory/movement product and branch,
and sales branch. Some access indexes lead with business_id rather than the FK's
declared column order. Evaluate query plans and parent-delete/maintenance workloads
before proposing extra indexes; current synthetic correctness does not establish
production performance. Nine duplicate groups remain on business_members,
businesses, camera_events (two groups), cameras, inventory_movements (two groups),
products and sales. Existing permissive policies remain for compatibility but
sensitive writes are revoked and restrictive scope policies apply; do not assume
role names alone authorize changes.

Advisor remediation:
- [Private RLS without policies](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy)
- [Definer execution review](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable)
- [Foreign-key indexes](https://supabase.com/docs/guides/database/database-linter?lint=0001_unindexed_foreign_keys)
- [RLS initplans](https://supabase.com/docs/guides/database/database-linter?lint=0003_auth_rls_initplan)
- [Unused indexes](https://supabase.com/docs/guides/database/database-linter?lint=0005_unused_index)
- [Permissive policies](https://supabase.com/docs/guides/database/database-linter?lint=0006_multiple_permissive_policies)
- [Duplicate indexes](https://supabase.com/docs/guides/database/database-linter?lint=0009_duplicate_index)

Platform-managed supabase_admin defaults were not changed. Review their effect
on future platform-created application objects separately; current object grants
and exposed application tables were tested, not every possible future object.

Limits: live employee-code login/creation/reset Edge flows were not deployed or
tested; Deno is unavailable. Auth fixture creation bypasses email delivery, so it
does not certify sign-up/SMTP behavior. Current-day boundary and DST arithmetic
tests do not freeze Auth/HTTP time at historical transitions. Production-sized
load, client device offline restart, real historical FK/data mapping and backup
recovery remain unverified. Test helpers/accounts/records were removed after
global signout; final staging contains only schema and 11 permission definitions.
