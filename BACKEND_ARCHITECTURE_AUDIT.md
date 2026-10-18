# Backend and native architecture audit — 4 October 2026

This report covers TREXVEN, the canonical ODT-Vision repository, the retained
TREXVEN/vision implementation, TREXVEN POS and the linked production Supabase
project. Pre-existing uncommitted work was preserved. Git history was not rewritten.
Generated build caches were excluded; ignored source/configuration and installed
Python package text were included in the searches. No camera video or private
business records were inspected for the audit.

## 1–6. Provider audit and removal

Before editing, there were 16 Anthropic/Claude text matches in four project files:

| Original location | What it claimed |
| --- | --- |
| TREXVEN README.md lines 8, 28, 69, 72, 76, 78, 79, 81, 83, 86, 87, 127, 128 | Snapshot-based scene explanations; model names; API-key/model secret setup; key-placement requirements |
| TREXVEN vision/supabase_client.py line 85 | Snapshot upload comment describing a model recipient |
| TREXVEN vision/server.py line 121 | Snapshot evidence comment describing a model recipient |
| TREXVEN TESTING_READINESS.md line 37 | Historical sentence saying the external provider was no longer used |

These were stale documentation/comments. The audit found no active SDK import,
HTTP endpoint, adapter, prompt, fallback, requirement/package dependency, canonical
Vision configuration or provider-specific test. The live `camera-ai` version 5
was already a stored-evidence handler without an external model call. Supabase
function bodies and column defaults contained no vendor matches. Secret-name
inventory contained no vendor key/model secret; secret values were not read.
Installed Python package inventory contained no corresponding SDK.

Removed all 16 project references. Replaced misleading README deployment
instructions with the actual architecture, corrected evidence comments and the
handoff wording. Preserved snapshots and other working camera functionality.
No SDK package or live environment variable needed removal: none existed at
this task's start. Historical setup instructions for vendor API-key/model
variables were removed. No provider was replaced with another external provider.

## 7. Native Intelligence

The existing deterministic evidence/state machine remains the operational
reasoner. It combines supported SKU observations, product context, completed
POS evidence, matching inventory movements, owner-verified employee context,
source history and plausible multi-camera identity evidence. It never writes
inventory itself or labels an unresolved observation as established theft.

Added explicit expected-versus-recorded value reconciliation. Matching product
and quantity with differing value remains `REQUIRES_REVIEW` with both values,
origin of the expectation, correlated POS reference, other evidence and heuristic
confidence preserved. Missing or stale context remains uncertain. Invalid
confidence/quantity/value and corrupted frames are rejected rather than fabricating
model output. Empty frames cannot trigger the detector's sample-image fallback.
Recording failures are isolated from perception and event creation.

## 8. Optional provider architecture

`reasoning_provider.py` defines an advisory Protocol. Default provider is `none`,
external AI is disabled, and no adapter/SDK/provider configuration is installed.
Unsupported requested adapters report their unavailable state and do not replace
native reasoning. A future adapter must run as a separate bounded worker with
approved minimized inputs, timeouts and advisory outputs. That worker is not
implemented now. No model provider credentials are required for Vision/Intelligence.

## 9. Vision to Intelligence

Independent workers ingest latest frames, run provisioned local detection and
tracking, create observations and preserve evidence recordings. A bounded shared
observer performs Re-ID/topology association and feeds durable observations to
native Intelligence. Existing queues, identity recovery, event history, AI Live
selection, owner corrections, alerts and POS/inventory adapter remain intact.
Model-loading failure does not download weights or invent detections; weights
must be provisioned on the host. Unsupported SKU or employee recognition remains
unsupported rather than being presented as working capability.

## 10. Intelligence to Admin

Native decisions commit to the operational SQLite store first. `DataJournal`
builds minimized local candidate snapshots separately. An opt-in `AdminPipeline`
worker sends selected HMAC-pseudonymized records and safe health aggregates to a
separately configured HTTPS gateway using an independent credential. It never
uses the production Supabase key for Admin. Delivery is disabled by default and
also requires per-business analytics approval. The bounded durable outbox retries
with backoff and acknowledges exact payload hashes, including late asset-reference
updates. Collection/storage/network errors do not roll back native decisions.

No Admin credentials were supplied, no Admin Supabase project was connected,
and no receiver was deployed. The ingestion contract is prepared, not a claim
that a separate Admin system exists. Existing production `angel_insights` remains
a compatibility projection for current readers; native operational truth is
not stored by or generated through Angel. Its legacy table name is retained to
avoid duplicating sensitive records or breaking existing readers.

## 11. Training-data structure

Candidates retain schema/event version, event/business/camera references,
timestamps, original prediction, allowlisted detections and track/global IDs,
model versions, initial/current decision, confidence, POS values/reference,
inventory evidence, final outcome, correction, verification, categories,
opaque asset references and provenance. No video/image bytes, signed URLs,
credentials, employee details, names or Re-ID embeddings are exported.

Default training permission is false, eligibility unknown, consent absent and
retention 30 days. Approval requires a recorded consent version and a verified
human terminal correction; POS support alone is insufficient. Eligible candidates
are eligible only for offline review, not automatically inserted into a dataset.
Policy changes invalidate candidates and clear pending exports; shorter retention
also shortens existing candidate expiry. Expired records are inaccessible and
purged locally. Remote retention/deletion and legal rights must be implemented
and checked by the receiver before exports are enabled.

Supported categories include POS support/value contradiction, returned products,
false positives, verified incidents, conflicts and cross-camera identity
corrections. No online training, dataset builder, training job, evaluator,
approval/promoter, historical backfill or remote asset-delivery service was built.

## 12. Version tracking

New Vision events and local detections carry detector and Re-ID artifact SHA-256,
tracker configuration/runtime version and `trexven-native-rules-v1.1`. Source
versions are allowlisted for export. Existing records without provenance remain
unknown. Owner-reported observations are explicitly labelled as non-model reports.
The additional local detection column is an additive SQLite migration.

## 13. Angel found and preserved

Local source and live Angel version 10 use the Groq OpenAI-compatible HTTP endpoint
with default model `openai/gpt-oss-120b`, optionally overridden by `GROQ_MODEL`.
`GROQ_API_KEY` remains configured. No Angel source, provider, secret, conversation
logic or deployment was changed. No real provider request was issued during this
audit. Camera explanations now have a separate limiter so they cannot throttle
Angel. Shared evidence projections do not call the assistant API.

## 14–15. Tests and deployed changes

- Added 20 Python architecture test cases: no keys/provider-none, unavailable
  future adapter, offline operation, POS value uncertainty, candidate generation,
  consent/verification/revocation/expiry, owner/scoping boundaries, identity
  correction candidates, model fingerprints, raw detection versions, corrupt
  frames, missing model, Admin failure/retry/no-network behavior, optional storage
  failure, recording failure isolation, late asset references and safe health.
- Corrected the existing physical-camera test's assertion race: a live frame is
  published before event persistence and its completed-frame counter. The test
  waits for that counter within the original bounded deadline.
- Complete canonical Vision suite: **173 passed**, including both physical-camera
  lifecycle tests; one upstream Starlette test-client deprecation warning.
  The initial full run was 171 passed/1 failed on the assertion race; it was fixed
  and the complete suite rerun successfully.
- Complete TREXVEN Flutter suite: **34 passed**.
- Complete POS Flutter suite: **3 passed**.
- Existing Angel mocked backend regression: **passed** without changing Angel.
- New camera backend mock check: **passed** for native explanations, no external
  fetch, user-scoped reads, missing evidence, authentication and the independent
  limiter.
- Existing Supabase transaction and access-control SQL suites: **passed** in
  rolled-back transactions, leaving no synthetic business/account records.
- New camera limiter SQL suite: **passed**, including separate Angel budget,
  service-only execution, 20-request cap and missing-user denial.
- `camera-ai` deployed successfully as **version 6**, JWT verification enabled,
  no external provider call, independent request budget.
- Migration `20261004025120_native_camera_rate_isolation.sql` applied to the
  linked production project. Angel deployment remained version 10.

## 16–17. Remaining matches, dependencies and issues

No active project-source/configuration/package vendor match remains outside this
intentional audit report. This report retains the audit terms to explain removal.
The installed environment has 13 lexical matches, all non-runtime-provider
metadata, contributor text or author names; these were left intact to preserve
package provenance and functionality:

| Relative path under ODT-Vision/.venv/Lib/site-packages | Matching lines | Reason retained |
| --- | --- | --- |
| anyio-4.14.2.dist-info/scm_file_list.json | 8 | Upstream contributor-instruction filename |
| yarl-1.24.5.dist-info/METADATA | 751, 752, 754, 794, 796, 797, 799, 801 | Upstream changelog about contributor instructions |
| PIL/SunImagePlugin.py | 11 | Historical author name, Jean-Claude Rimbault |
| python_dotenv-1.2.2.dist-info/METADATA | 279 | Contributor surname Bonnefoy-Claudet, substring false positive |
| networkx/algorithms/centrality/eigenvector.py | 150, 325 | Mathematical reference to Claude Berge |

This audit report itself has four intentional matching lines: 12, 172, 173 and
174. Together with the 13 installed-package matches above, these are every
remaining text match found in the audited source/configuration/package scope.

Git history and binary/generated caches are not rewritten. No active external
LLM dependency exists in Vision/Intelligence. Angel's independent Groq endpoint
remains the only discovered active external model provider in this scope.
Production Supabase sync is optional network integration, not an AI dependency.
The existing installed HTTP client is now explicitly pinned as `httpx==0.28.1`
because business context and optional Admin delivery import it directly. No new
package was installed.

Supabase security advisors retain five existing authenticated SECURITY DEFINER
warnings for guarded onboarding/membership/employee/ownership functions and a
leaked-password-protection warning. Private limiter tables intentionally have
RLS with no client policy/direct grants (deny-all), which creates informational
advisor notices. No new public authenticated privileged function was exposed.
Remediation references:
[function-execution guidance](https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable),
[password protection](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection),
[private RLS notice](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy).

The repositories contained substantial pre-existing changes. Whole-repository
whitespace checks reported pre-existing Flutter whitespace; unrelated screens
were not reformatted. These are not test failures. Store accuracy, long-duration
load and real Admin delivery are not certified by these unit/integration checks.
The retained legacy direct-cloud Vision implementation is not the canonical
local-first target. Future operation should use ODT-Vision.

## 18. Next steps

Use `ODT-Vision/vision/ARCHITECTURE.md` to review policy and gateway requirements.
Implement the separate Admin receiver's authentication, idempotency, consent
revocation/deletion and retention before configuring exports. Then verify its
outage behavior against the real environment using a dedicated test business.
Review approved asset delivery and dataset provenance before building datasets;
keep training/evaluation/model promotion offline and controlled. Provision
approved local model files and validate supported SKU observations, camera
handoffs, value discrepancies and owner corrections in the actual store. Review
the existing Supabase advisor warnings and deployment/rollback controls before
launch. No additional model provider is needed to test the native system.
