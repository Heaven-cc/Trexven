# TREXVEN

TREXVEN combines the Flutter business app, transactional POS/inventory backend,
local camera perception and native contextual Intelligence.

## Current architecture

- Flutter and Supabase definitions: this repository.
- POS terminal: `C:\Users\USER\AndroidStudioProjects\trexvenpos`.
- Canonical Vision/Intelligence server: `C:\Users\USER\ODT-Vision`.
- This repository's `vision/` directory is an older implementation retained for
  compatibility/reference. Launch the canonical server for current testing.

Vision ingests camera frames, runs provisioned local detector/tracker/Re-ID
models, creates observations and captures evidence. Native Intelligence combines
observations with available POS, inventory and business context. Missing or
conflicting evidence stays uncertain. Neither requires an external LLM API.
The deployed `camera-ai` function explains stored evidence without an external
model. Future optional reasoning adapters must remain advisory and isolated.

Angel is a separate user-facing assistant with its own Groq API configuration.
Its provider is not used by Vision or native Intelligence. Its configuration and
business data permissions are separate from this architecture.

## Testing and configuration

Read [TESTING_READINESS.md](TESTING_READINESS.md) for installable debug APKs,
server startup, pairing, acceptance scenarios, backups and known limitations.
Read the canonical server's `ARCHITECTURE.md` for versioned observations,
reconciliation, data policies and optional Admin delivery.

Flutter supports `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` Dart defines.
Backend service keys belong on the server only. Production business data remains
in the operational store; Admin receives only selected, pseudonymized records
through a separately configured, asynchronous ingestion gateway.

| Configuration | Placement |
| --- | --- |
| Supabase URL / publishable key | Flutter client; authorization is enforced by RLS |
| Production Supabase service-role key | Vision host / backend only |
| Vision pairing key | Vision host and approved app pairing settings |
| Angel Groq key/model | Angel Edge Function secrets only |
| Admin gateway credentials | Vision host only; disabled by default |

Commercial launch work and Google signup are deferred. Customer video is not
training data by default. No automatic retraining or model promotion is built.
