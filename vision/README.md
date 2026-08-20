# ODT Vision Server

The AI-powered camera processing backend for **Trexven / ODT**.

## Quick start (local / development)

```bash
cd vision
cp .env.example .env
# Fill in SUPABASE_SERVICE_ROLE_KEY and VISION_API_KEY in .env

pip install -r requirements.txt

# Run from the repo root:
python -m vision
```

The server starts at `http://0.0.0.0:8000` by default.

> First run downloads the `yolo11n.pt` weights automatically (needs internet
> access once). To pin the model in `vision/config.py`/`.env`, set
> `MODEL_PATH` to an absolute path of your own `.pt` file instead.

## API endpoints

| Method | Path | Description |
|--------|------|-------------|
| GET | `/health` | Server status + active cameras |
| POST | `/start` | Start the vision loop (auto-runs on startup) |
| POST | `/stop` | Stop all camera workers |
| GET | `/frame/{camera_id}` | Latest processed JPEG frame (AI annotated) |
| GET | `/stream/{camera_id}` | MJPEG live stream |
| POST | `/test-connection` | Test an RTSP URL before saving |

All endpoints except `/health` require the `X-Vision-API-Key` header.

## Adding a camera

1. Open the **Trexven** mobile app.
2. Go to **Intelligence** → **Add Camera**.
3. Fill in camera name, RTSP URL, location.
4. Tap **Test Connection** — the app contacts this server.
5. If successful, save. The vision loop picks it up within 2 seconds.

## Cloud deployment

When you get a cloud server (Railway, Render, DigitalOcean, etc.):

1. Set the environment variables from `.env.example` on the server.
2. Run: `uvicorn vision.server:app --host 0.0.0.0 --port 8000`
3. Update the **Vision Server URL** in the Trexven app settings.
4. Done — cameras auto-reconnect.

## Architecture

```
IP Camera (RTSP)
    ↓
CameraManager (OpenCV)
    ↓
Detector (YOLO11 + ByteTrack)
    ↓
EventEngine (cooldown, zones, loitering, crowd)
    ↓
SupabaseVisionClient → camera_detections + camera_events
    ↓
Recorder → Supabase Storage (MP4 segments)
```
