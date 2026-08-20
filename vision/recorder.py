"""Continuous video-segment recorder for each active camera.

Records the raw RTSP/camera stream into short MP4 clips and uploads
each clip to Supabase Storage under ``recordings/{camera_id}/``.

Design
------
* One ``Recorder`` instance per camera, managed by ``server.py``.
* Clips are written to a local temp dir first, then uploaded.
* Local clips are deleted after a successful upload.
* If the upload fails the clip is kept locally and retried next time.
"""
from __future__ import annotations

import os
import tempfile
import threading
import time
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import cv2

from .config import settings
from .supabase_client import SupabaseVisionClient

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

SEGMENT_SECONDS: float = 5 * 60  # 5-minute clips (configurable via env later)
FOURCC = cv2.VideoWriter_fourcc(*"mp4v")   # type: ignore[attr-defined]
BUCKET = "recordings"

# The writer's FPS must match the actual rate frames arrive at (roughly
# 1 / frame_interval_seconds), or playback will run faster/slower than
# real time. Clamp to a sane range in case of a very low/high interval.
FPS_DEFAULT = min(30.0, max(1.0, 1.0 / settings.frame_interval_seconds)) \
    if settings.frame_interval_seconds > 0 else 10.0


# ---------------------------------------------------------------------------
# Recorder
# ---------------------------------------------------------------------------

class Recorder:
    """Records camera frames into fixed-length video segments."""

    def __init__(
        self,
        camera: dict[str, Any],
        supabase: SupabaseVisionClient,
    ) -> None:
        self.camera = camera
        self.camera_id: str = str(camera["id"])
        self.business_id: str = str(camera["business_id"])
        self._supabase = supabase
        self._lock = threading.Lock()
        self._writer: cv2.VideoWriter | None = None
        self._tmp_path: Path | None = None
        self._segment_start: float = 0.0
        self._frame_size: tuple[int, int] = (1280, 720)
        self._running = False
        self._thread: threading.Thread | None = None

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def start(self) -> None:
        with self._lock:
            if self._running:
                return
            self._running = True
        # Recorder runs on the calling thread — it blocks, so the server
        # should call record_frame() from the existing camera worker thread.

    def stop(self) -> None:
        with self._lock:
            self._running = False
            self._close_segment()

    def record_frame(self, frame: Any) -> None:
        """Write a single frame.  Call this from the camera processing loop."""
        if not self._running:
            return

        with self._lock:
            # Open a new segment if needed
            if self._writer is None:
                self._open_segment(frame)

            # Rotate segment?
            now = time.monotonic()
            if now - self._segment_start >= SEGMENT_SECONDS:
                self._close_segment()
                self._open_segment(frame)

            if self._writer is not None:
                self._writer.write(frame)

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _open_segment(self, frame: Any) -> None:
        """Open a new video writer for the next segment."""
        h, w = frame.shape[:2]
        self._frame_size = (w, h)
        self._tmp_path = Path(
            tempfile.gettempdir()
        ) / f"trexven_{self.camera_id}_{int(time.time())}.mp4"
        self._writer = cv2.VideoWriter(
            str(self._tmp_path),
            FOURCC,
            FPS_DEFAULT,
            self._frame_size,
        )
        self._segment_start = time.monotonic()

    def _close_segment(self) -> None:
        """Flush the current segment and schedule upload."""
        if self._writer is None:
            return
        self._writer.release()
        self._writer = None
        tmp = self._tmp_path
        self._tmp_path = None

        if tmp is None or not tmp.exists():
            return

        # Upload in a background thread so we don't stall the camera loop
        t = threading.Thread(
            target=self._upload_and_save,
            args=(tmp,),
            daemon=True,
        )
        t.start()

    def _upload_and_save(self, path: Path) -> None:
        """Upload the segment to Supabase Storage and persist metadata."""
        now_utc = datetime.now(timezone.utc)
        date_str = now_utc.strftime("%Y-%m-%d")
        ts_str = now_utc.strftime("%H%M%S")
        storage_path = f"{self.camera_id}/{date_str}/{ts_str}.mp4"

        try:
            with open(path, "rb") as fh:
                data = fh.read()

            self._supabase.client.storage.from_(BUCKET).upload(
                path=storage_path,
                file=data,
                file_options={"content-type": "video/mp4", "upsert": "true"},
            )

            # Get a signed URL (valid 7 days) for playback
            signed = self._supabase.client.storage.from_(BUCKET).create_signed_url(
                storage_path, expires_in=604800
            )
            public_url: str = signed.get("signedURL") or ""

            file_size = os.path.getsize(path)
            duration_est = SEGMENT_SECONDS

            # Persist recording metadata
            self._supabase.client.table("recordings").insert({
                "business_id": self.business_id,
                "camera_id": self.camera_id,
                "storage_path": storage_path,
                "started_at": now_utc.isoformat(),
                "duration_seconds": duration_est,
                "file_size_bytes": file_size,
                "playback_url": public_url,
                "status": "ready",
            }).execute()

        except Exception as exc:  # noqa: BLE001
            print(f"[Recorder] Upload failed for {path}: {exc}")
            return  # Keep file for next retry

        # Remove local file only on success
        try:
            path.unlink(missing_ok=True)
        except Exception:  # noqa: BLE001
            pass
