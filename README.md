# TREXVEN (ODT)

AI-powered business management and security platform. A Flutter app + Supabase
backend + a Python computer-vision service that turns IP/RTSP cameras into
structured business intelligence (detections, events, alerts, recordings).

See [`vision/README.md`](vision/README.md) for the AI backend specifically.

## Architecture

```
Flutter app (lib/)  <-->  Supabase (Postgres + Auth + Storage + Edge Functions)  <-->  vision/ (Python, YOLO)
```

- **Flutter app** — inventory, sales, cameras, alerts, "Angel" AI chat.
- **Supabase** — source of truth: `businesses`, `products`, `sales`, `cameras`,
  `camera_zones`, `camera_events`, `camera_detections`, `recordings`, `alerts`.
  Schema lives in [`supabase/migrations/`](supabase/migrations/).
- **Edge functions** (`supabase/functions/`) — `angel` (general business-chat
  assistant, powered by Groq), `camera-ai` (the AI camera intelligence layer —
  powered by **Claude**, see below), `camera-ingest` (lets the app or any
  external system submit a camera event/detection safely).
- **vision/** — a separate Python process that pulls RTSP/IP camera streams,
  runs YOLO detection + ByteTrack tracking, evaluates zones/loitering/crowd
  rules, writes detections/events straight to Postgres with the service-role
  key, and records 5-minute MP4 segments to Supabase Storage.

## One-time setup

### 1. Database schema

Your Supabase project already has a full production schema (businesses,
employees, products, sales, cameras, camera_events, alerts, inventory,
financial_transactions, and more — 26 tables, with RLS and a
`camera_events → alerts` trigger already in place). It predates this repo's
`supabase/migrations/` folder, so `git clone` alone won't reproduce it —
what's tracked here is a **delta migration**
(`20260819180000_camera_ai_fixes.sql`) that fixes the handful of concrete
gaps found while wiring the vision backend and camera-ai to that live schema:
widens `alerts.severity` and its trigger to also treat `'high'` as
alert-worthy (matching the existing `get_camera_activity_summary()` RPC,
which already expected it), creates the `recordings` and `event-snapshots`
storage buckets (didn't exist — every vision-backend upload was failing
silently), and adds `cameras`/`alerts`/`products`/`sales` to the Realtime
publication (only `camera_events`/`camera_detections` were in it, so every
other `.stream()` in the app was silently receiving nothing).

Push it from the repo root:

```bash
npx supabase login                     # opens a browser to authenticate
npx supabase link --project-ref ufehcfrlygqvminfjumf
npx supabase db push                   # applies supabase/migrations/*.sql
```

### 2. Edge function secrets — **this is where the AI keys go**

Two different AI providers, two different jobs:

- **`angel`** (general "ask about my business" chat) calls Groq. Already
  configured in your Supabase project.
- **`camera-ai`** (the camera intelligence layer) calls **Claude** — this is
  what makes the camera "smart": when the vision backend fires a high/critical
  severity event, it snapshots the frame and attaches the URL to the event's
  metadata; `camera-ai` fetches that image and gives it to Claude alongside
  the structured detection data, so the answer is a real read of the scene,
  not just a description of a bounding box. In the app, this shows up as the
  **"Ask AI to explain"** button on high/critical alerts (Intelligence →
  Camera → Alerts). By default it uses `claude-opus-5`; you can point it at a
  cheaper model (this runs automatically per high-severity event, so cost
  scales with your alert volume) by setting `ANTHROPIC_MODEL` — e.g.
  `claude-sonnet-5` or `claude-haiku-4-5`.

Get a Claude API key at **https://console.anthropic.com/settings/keys**, then
set both secrets on your Supabase project (never in a file that gets
committed — Groq's is already set, so only the Anthropic ones are new here):

```bash
npx supabase secrets set ANTHROPIC_API_KEY=sk-ant-your-key-here
npx supabase secrets set ANTHROPIC_MODEL=claude-opus-5   # optional, this is the default
npx supabase functions deploy camera-ai
npx supabase functions deploy angel
npx supabase functions deploy camera-ingest
```

### 3. Vision (AI camera) server

The Flutter app never runs the AI itself — it talks to this separate Python
service, which must run continuously somewhere with network access to your
cameras (your own PC/NUC on the store's LAN, or a cloud VM if your cameras
are reachable from the internet).

```bash
cd vision
cp .env.example .env
# edit .env — fill in SUPABASE_SERVICE_ROLE_KEY (Project Settings > API,
# "service_role" secret — never ship this key inside the mobile app) and
# pick your own VISION_API_KEY (any strong random string).
pip install -r requirements.txt
python -m vision
```

Full details, endpoints and cloud-deployment notes: [`vision/README.md`](vision/README.md).

### 4. Point the Flutter app at your vision server

The app already ships with the Supabase URL/anon key wired up
(`lib/main.dart`) — that part needs no configuration. What you do need to set,
per device, is the vision server address: open the app → **Me tab → Vision
Server Settings**, and enter:

- **Vision Server URL** — `http://<your-PC-LAN-IP>:8000` while testing on the
  same network, or your cloud URL once deployed.
- **Vision API Key** — the same `VISION_API_KEY` you put in `vision/.env`.

## Key placement — summary

| Key | Where it goes | Never put it in |
|---|---|---|
| `ANTHROPIC_API_KEY` (Claude — powers `camera-ai`) | Supabase Edge Function secret (`supabase secrets set`) | The Flutter app, git, `vision/.env` |
| `ANTHROPIC_MODEL` (optional, default `claude-opus-5`) | Supabase Edge Function secret | n/a |
| `GROQ_API_KEY` (powers `angel`, already set) | Supabase Edge Function secret (`supabase secrets set`) | The Flutter app, git, `vision/.env` |
| `SUPABASE_SERVICE_ROLE_KEY` | `vision/.env` only (the Python server's machine) | The Flutter app, git |
| `VISION_API_KEY` (you choose it) | `vision/.env`, and re-entered in the app's Me → Vision Server Settings | git |
| Supabase URL + anon/publishable key | Already in `lib/main.dart` — this one is meant to be public, RLS is what protects your data | n/a |

## Schema you already have but the app doesn't use yet

The live database has real tables the Flutter app never touches:
`employees`, `inventory`, `inventory_movements`, `financial_transactions`,
`cash_transactions`, `expenses`, `sale_items`, `business_activity`,
`angel_conversations`/`angel_messages`/`angel_insights`, `camera_ai_jobs`,
`camera_event_links`, `camera_health_logs`, plus RPCs
`get_camera_dashboard(business_id)` and
`get_camera_activity_summary(business_id, from, to)`. None of this was built
in this pass — it's there for whoever builds the Employees screen, the
proper multi-item POS flow, or richer reporting next; worth reading the
actual column list in Supabase before inventing a competing shape for any of
it, the way this pass almost did.

## What's intentionally not built yet

This system covers the full core loop: add an IP camera → test the RTSP
connection → live AI-annotated feed → detections/events/zones/loitering →
5-minute recordings in Storage → playback → high/critical events auto-become
alerts with a push notification → inventory/sales dashboard → "Angel" chat.

Deliberately **not** attempted here — each is a real, multi-month ML/product
effort in its own right, not a config toggle:

- Employee recognition / re-identification (the `employees` table and
  `camera_detections.employee_id` exist as a schema hook; no recognition
  model is wired up).
- Custom product recognition (YOLO only knows its stock classes, not your
  specific inventory; `products.linked_zone_id` is a hook for later
  shelf-level correlation).
- Theft correlation, cash/money intelligence, camera↔sales correlation —
  `camera_events.metadata` (jsonb) is deliberately open-ended so this logic
  can be added later without another migration.
