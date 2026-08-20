from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

from supabase import Client, create_client

from .config import settings

SNAPSHOT_BUCKET = "event-snapshots"


class SupabaseVisionClient:
    """Persistence layer for camera state, detections, zones and events."""

    def __init__(self) -> None:
        self.client: Client = create_client(
            settings.supabase_url,
            settings.supabase_service_role_key,
        )

    def list_active_ai_cameras(self) -> list[dict[str, Any]]:
        result = (
            self.client.table("cameras")
            .select("*")
            .eq("is_active", True)
            .eq("ai_enabled", True)
            .execute()
        )
        return result.data or []

    def get_camera(self, camera_id: str) -> dict[str, Any] | None:
        result = (
            self.client.table("cameras")
            .select("*")
            .eq("id", camera_id)
            .maybe_single()
            .execute()
        )
        return result.data

    def list_zones(self, camera_id: str) -> list[dict[str, Any]]:
        result = (
            self.client.table("camera_zones")
            .select("*")
            .eq("camera_id", camera_id)
            .eq("is_active", True)
            .execute()
        )
        return result.data or []

    def set_camera_status(self, camera_id: str, status: str) -> None:
        self.client.table("cameras").update({
            "status": status,
            "last_seen_at": datetime.now(timezone.utc).isoformat(),
        }).eq("id", camera_id).execute()

    def create_detection(self, camera: dict[str, Any], detection: dict[str, Any]) -> dict[str, Any] | None:
        payload = {
            "business_id": camera["business_id"],
            "camera_id": camera["id"],
            "detection_type": "object",
            "object_type": detection["class_name"],
            "object_label": detection["class_name"],
            "track_id": str(detection["track_id"]) if detection.get("track_id") is not None else None,
            "confidence": detection["confidence"],
            "bounding_box": {
                "x1": detection["bbox"][0],
                "y1": detection["bbox"][1],
                "x2": detection["bbox"][2],
                "y2": detection["bbox"][3],
            },
            "attributes": {
                "class_id": detection["class_id"],
                "center": detection.get("center"),
                "source": "odt-vision",
            },
            "occurred_at": datetime.now(timezone.utc).isoformat(),
        }
        result = self.client.table("camera_detections").insert(payload).execute()
        return result.data[0] if result.data else None

    def upload_event_snapshot(self, camera_id: str, image_bytes: bytes) -> str | None:
        """Upload a JPEG snapshot for a high/critical event and return a signed URL.

        Used so the camera-ai edge function can hand Claude an actual image of
        the moment an event fired, instead of only structured detection JSON.
        Best-effort: returns None on any failure rather than raising, so a
        storage hiccup never blocks event persistence.
        """
        path = f"{camera_id}/{uuid4()}.jpg"
        try:
            self.client.storage.from_(SNAPSHOT_BUCKET).upload(
                path=path,
                file=image_bytes,
                file_options={"content-type": "image/jpeg", "upsert": "true"},
            )
            signed = self.client.storage.from_(SNAPSHOT_BUCKET).create_signed_url(
                path, expires_in=604800
            )
            return signed.get("signedURL") or None
        except Exception:
            return None

    def create_event(self, camera: dict[str, Any], event: dict[str, Any]) -> dict[str, Any] | None:
        now = datetime.now(timezone.utc).isoformat()
        payload = {
            "business_id": camera["business_id"],
            "camera_id": camera["id"],
            "event_type": event["event_type"],
            "description": event["description"],
            "confidence": event.get("confidence"),
            "severity": event.get("severity", "low"),
            "metadata": event.get("metadata", {}),
            "occurred_at": now,
            "detected_at": now,
            "source_provider": "odt-vision",
            "model_name": settings.model_path,
            "raw_payload": event,
            "status": "detected",
            "review_status": "unreviewed",
        }
        result = self.client.table("camera_events").insert(payload).execute()
        return result.data[0] if result.data else None
