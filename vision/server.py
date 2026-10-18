import threading
import time
from typing import Any

import cv2
from fastapi import FastAPI, Header, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel

from .camera_manager import CameraManager
from .config import settings
from .detector import Detector
from .event_engine import EventEngine
from .recorder import Recorder
from .supabase_client import SupabaseVisionClient

app = FastAPI(title="ODT Vision Server", version="2.1.0")

detector = Detector()
supabase = SupabaseVisionClient()
running = False
worker_thread: threading.Thread | None = None
frames: dict[str, Any] = {}
workers: dict[str, CameraManager] = {}
recorders: dict[str, Recorder] = {}
worker_threads: dict[str, threading.Thread] = {}


# ---------------------------------------------------------------------------
# Auth helper
# ---------------------------------------------------------------------------

def authorize(api_key: str | None) -> None:
    if settings.vision_api_key and api_key != settings.vision_api_key:
        raise HTTPException(status_code=401, detail="Invalid vision API key")


# ---------------------------------------------------------------------------
# Camera source resolution
# ---------------------------------------------------------------------------

def source_for(camera: dict[str, Any]) -> str | int | None:
    settings_data = camera.get("settings") or {}
    source = settings_data.get("source") or camera.get("stream_url") or camera.get("device_id")
    if source is None:
        return None
    value = str(source).strip()
    return int(value) if value.isdigit() else value


# ---------------------------------------------------------------------------
# Per-camera processing loop
# ---------------------------------------------------------------------------

def process_camera(camera: dict[str, Any]) -> None:
    camera_id = str(camera["id"])
    source = source_for(camera)
    if source is None:
        supabase.set_camera_status(camera_id, "error")
        return

    manager = CameraManager(source)
    workers[camera_id] = manager

    recorder = Recorder(camera, supabase)
    recorders[camera_id] = recorder
    recorder.start()

    events = EventEngine(
        cooldown_seconds=settings.event_cooldown_seconds,
        zone_cooldown_seconds=settings.zone_event_cooldown_seconds,
        loitering_seconds=settings.loitering_seconds,
        crowd_threshold=settings.crowd_threshold,
    )

    try:
        manager.open()
        supabase.set_camera_status(camera_id, "online")
        zones = supabase.list_zones(camera_id)
        last_zone_refresh = time.monotonic()
        last_detection_persist = 0.0

        while running:
            try:
                frame = manager.read()
            except Exception:
                supabase.set_camera_status(camera_id, "error")
                try:
                    manager.reconnect()
                    supabase.set_camera_status(camera_id, "online")
                    continue
                except Exception:
                    time.sleep(settings.reconnect_delay_seconds)
                    continue

            # Record raw frame (before AI overlay)
            recorder.record_frame(frame.copy())

            now = time.monotonic()
            if now - last_zone_refresh >= max(5.0, settings.poll_interval_seconds):
                try:
                    zones = supabase.list_zones(camera_id)
                except Exception:
                    pass
                last_zone_refresh = now

            result = detector.track(frame)[0]
            detections = detector.detections(result)
            frames[camera_id] = result.plot()

            if settings.frame_interval_seconds <= 0 or now - last_detection_persist >= settings.frame_interval_seconds:
                for detection in detections:
                    try:
                        supabase.create_detection(camera, detection)
                    except Exception:
                        pass
                last_detection_persist = now

            for event in events.events_from_detections(detections, zones):
                # High/critical events get a snapshot attached so the camera-ai
                # reviewers can inspect an actual image, not just
                # detection JSON. Best-effort — a snapshot failure must never
                # block the event itself from being recorded.
                if event.get("severity") in ("high", "critical"):
                    ok, encoded = cv2.imencode(
                        ".jpg",
                        frames[camera_id],
                        [int(cv2.IMWRITE_JPEG_QUALITY), settings.jpeg_quality],
                    )
                    if ok:
                        snapshot_url = supabase.upload_event_snapshot(camera_id, encoded.tobytes())
                        if snapshot_url:
                            event.setdefault("metadata", {})["snapshot_url"] = snapshot_url
                try:
                    supabase.create_event(camera, event)
                except Exception:
                    pass

            time.sleep(max(0.0, settings.frame_interval_seconds))

    except Exception:
        try:
            supabase.set_camera_status(camera_id, "error")
        except Exception:
            pass
    finally:
        recorder.stop()
        manager.close()
        workers.pop(camera_id, None)
        recorders.pop(camera_id, None)
        worker_threads.pop(camera_id, None)
        if running:
            try:
                supabase.set_camera_status(camera_id, "offline")
            except Exception:
                pass


# ---------------------------------------------------------------------------
# Vision manager loop (polls Supabase for active cameras)
# ---------------------------------------------------------------------------

def vision_loop() -> None:
    global running
    while running:
        try:
            cameras = supabase.list_active_ai_cameras()
        except Exception:
            time.sleep(settings.poll_interval_seconds)
            continue

        configured = {str(camera["id"]) for camera in cameras}

        for camera in cameras:
            camera_id = str(camera["id"])
            thread = worker_threads.get(camera_id)
            if thread is None or not thread.is_alive():
                thread = threading.Thread(target=process_camera, args=(camera,), daemon=True)
                worker_threads[camera_id] = thread
                thread.start()

        for camera_id in list(workers):
            if camera_id not in configured:
                workers[camera_id].close()

        time.sleep(settings.poll_interval_seconds)


def start_worker() -> None:
    global running, worker_thread
    if running:
        return
    running = True
    worker_thread = threading.Thread(target=vision_loop, daemon=True)
    worker_thread.start()


def stop_worker() -> None:
    global running
    running = False
    for manager in list(workers.values()):
        manager.close()
    for rec in list(recorders.values()):
        rec.stop()


# ---------------------------------------------------------------------------
# MJPEG frame generator
# ---------------------------------------------------------------------------

def _mjpeg_generator(camera_id: str):
    """Yield MJPEG boundary frames indefinitely."""
    boundary = b"--frame\r\nContent-Type: image/jpeg\r\n\r\n"
    while True:
        image = frames.get(camera_id)
        if image is None:
            time.sleep(0.1)
            continue
        ok, encoded = cv2.imencode(
            ".jpg",
            image,
            [int(cv2.IMWRITE_JPEG_QUALITY), settings.jpeg_quality],
        )
        if ok:
            yield boundary + encoded.tobytes() + b"\r\n"
        time.sleep(settings.frame_interval_seconds or 0.1)


# ---------------------------------------------------------------------------
# REST endpoints
# ---------------------------------------------------------------------------

@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "status": "ok",
        "running": running,
        "active_cameras": len(workers),
        "camera_ids": list(workers.keys()),
        "model": settings.model_path,
        "confidence_threshold": settings.confidence_threshold,
    }


@app.post("/start")
def start(x_vision_api_key: str | None = Header(default=None)) -> dict[str, Any]:
    authorize(x_vision_api_key)
    start_worker()
    return {"status": "started"}


@app.post("/stop")
def stop(x_vision_api_key: str | None = Header(default=None)) -> dict[str, Any]:
    authorize(x_vision_api_key)
    stop_worker()
    return {"status": "stopping"}


@app.get("/frame/{camera_id}")
def frame(camera_id: str, x_vision_api_key: str | None = Header(default=None)) -> StreamingResponse:
    authorize(x_vision_api_key)
    image = frames.get(camera_id)
    if image is None:
        raise HTTPException(status_code=404, detail="No processed frame available")

    ok, encoded = cv2.imencode(
        ".jpg",
        image,
        [int(cv2.IMWRITE_JPEG_QUALITY), settings.jpeg_quality],
    )
    if not ok:
        raise HTTPException(status_code=500, detail="Could not encode frame")

    return StreamingResponse(iter([encoded.tobytes()]), media_type="image/jpeg")


@app.get("/stream/{camera_id}")
def stream(
    camera_id: str,
    x_vision_api_key: str | None = Header(default=None),
) -> StreamingResponse:
    """MJPEG live stream endpoint. Suitable for <img> tags and Flutter Image.network."""
    authorize(x_vision_api_key)
    if camera_id not in workers and frames.get(camera_id) is None:
        raise HTTPException(status_code=404, detail="Camera not active")
    return StreamingResponse(
        _mjpeg_generator(camera_id),
        media_type="multipart/x-mixed-replace; boundary=frame",
    )


class ConnectionTestRequest(BaseModel):
    stream_url: str
    timeout_seconds: float = 8.0


@app.post("/test-connection")
def test_connection(
    body: ConnectionTestRequest,
    x_vision_api_key: str | None = Header(default=None),
) -> dict[str, Any]:
    """Attempt to open an RTSP/IP camera URL and read one frame.

    Returns {"success": true, "message": "..."} or {"success": false, "message": "..."}.
    """
    authorize(x_vision_api_key)

    url = body.stream_url.strip()
    if not url:
        return {"success": False, "message": "No stream URL provided"}

    cap: cv2.VideoCapture | None = None
    try:
        cap = cv2.VideoCapture(url)
        cap.set(cv2.CAP_PROP_BUFFERSIZE, 1)

        deadline = time.monotonic() + body.timeout_seconds
        while time.monotonic() < deadline:
            ok, _frame = cap.read()
            if ok:
                return {
                    "success": True,
                    "message": "Connection successful",
                    "width": int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)),
                    "height": int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT)),
                    "fps": cap.get(cv2.CAP_PROP_FPS),
                }
            time.sleep(0.3)

        return {"success": False, "message": "Could not read a frame within timeout"}

    except Exception as exc:
        return {"success": False, "message": str(exc)}
    finally:
        if cap is not None:
            cap.release()


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

@app.on_event("startup")
def startup() -> None:
    start_worker()


@app.on_event("shutdown")
def shutdown() -> None:
    stop_worker()
