import threading
import time
from typing import Any

import cv2

from .config import settings


class CameraManager:
    """Resilient OpenCV camera/RTSP source with automatic reconnects."""

    def __init__(self, source: str | int) -> None:
        self.source = self._normalize_source(source)
        self.capture: cv2.VideoCapture | None = None
        self.lock = threading.Lock()
        self.last_error: str | None = None
        self.last_frame_at: float | None = None

    @staticmethod
    def _normalize_source(source: str | int) -> str | int:
        if isinstance(source, int):
            return source
        value = str(source).strip()
        return int(value) if value.isdigit() else value

    def open(self) -> None:
        with self.lock:
            if self.capture is not None and self.capture.isOpened():
                return
            self.capture = cv2.VideoCapture(self.source)
            self.capture.set(cv2.CAP_PROP_BUFFERSIZE, 1)
            if not self.capture.isOpened():
                self.capture.release()
                self.capture = None
                self.last_error = f"Could not open camera source: {self.source}"
                raise RuntimeError(self.last_error)
            self.last_error = None

    def read(self) -> Any:
        with self.lock:
            if self.capture is None or not self.capture.isOpened():
                self.open()
            ok, frame = self.capture.read()
            if ok:
                self.last_frame_at = time.monotonic()
                self.last_error = None
                return frame

            self.last_error = "Could not read a frame from the camera"
            self._release_locked()
            raise RuntimeError(self.last_error)

    def reconnect(self) -> None:
        self.close()
        time.sleep(settings.reconnect_delay_seconds)
        self.open()

    def _release_locked(self) -> None:
        if self.capture is not None:
            self.capture.release()
            self.capture = None

    def close(self) -> None:
        with self.lock:
            self._release_locked()
