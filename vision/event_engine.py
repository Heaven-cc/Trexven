import math
import time
from collections import defaultdict
from typing import Any


class EventEngine:
    """Converts raw detections into useful, rate-limited business events."""

    def __init__(
        self,
        cooldown_seconds: float = 5.0,
        zone_cooldown_seconds: float = 8.0,
        loitering_seconds: float = 30.0,
        crowd_threshold: int = 5,
    ) -> None:
        self.cooldown_seconds = cooldown_seconds
        self.zone_cooldown_seconds = zone_cooldown_seconds
        self.loitering_seconds = loitering_seconds
        self.crowd_threshold = crowd_threshold
        self.last_event: dict[tuple[str, str | None], float] = defaultdict(float)
        self.first_seen: dict[tuple[str, str], float] = {}
        self.last_centers: dict[tuple[str, str], tuple[float, float]] = {}

    def should_emit(self, event_type: str, track_id: int | None, cooldown: float | None = None) -> bool:
        key = (event_type, str(track_id) if track_id is not None else None)
        now = time.monotonic()
        limit = self.cooldown_seconds if cooldown is None else cooldown
        if now - self.last_event[key] < limit:
            return False
        self.last_event[key] = now
        return True

    @staticmethod
    def _inside_zone(center: list[float] | tuple[float, float], polygon: list[Any]) -> bool:
        if len(polygon) < 3:
            return False
        x, y = center
        inside = False
        j = len(polygon) - 1
        for i in range(len(polygon)):
            xi, yi = float(polygon[i][0]), float(polygon[i][1])
            xj, yj = float(polygon[j][0]), float(polygon[j][1])
            intersects = ((yi > y) != (yj > y)) and (
                x < (xj - xi) * (y - yi) / ((yj - yi) or 1e-9) + xi
            )
            if intersects:
                inside = not inside
            j = i
        return inside

    def _base_event(self, event_type: str, description: str, detection: dict[str, Any], severity: str = "info", **metadata: Any) -> dict[str, Any]:
        merged = {
            "class_id": detection["class_id"],
            "class_name": detection["class_name"],
            "track_id": detection.get("track_id"),
            "bbox": detection["bbox"],
            "source": "odt-vision",
        }
        merged.update(metadata)
        return {
            "event_type": event_type,
            "description": description,
            "severity": severity,
            "confidence": detection.get("confidence"),
            "metadata": merged,
        }

    def events_from_detections(
        self,
        detections: list[dict[str, Any]],
        zones: list[dict[str, Any]] | None = None,
    ) -> list[dict[str, Any]]:
        events: list[dict[str, Any]] = []
        now = time.monotonic()
        zones = zones or []
        active_tracks: set[str] = set()

        for detection in detections:
            track = detection.get("track_id")
            track_key = str(track) if track is not None else f"bbox:{detection['bbox']}"
            class_name = str(detection["class_name"])
            state_key = (class_name, track_key)
            active_tracks.add(f"{class_name}:{track_key}")

            self.first_seen.setdefault(state_key, now)
            center = detection.get("center")
            if center:
                self.last_centers[state_key] = (float(center[0]), float(center[1]))

            # General detection: useful for people, vehicles, bags, etc.
            event_type = f"{class_name}_detected"
            if self.should_emit(event_type, track):
                severity = "low"
                if class_name.lower() in {"knife", "gun", "fire", "smoke"}:
                    severity = "critical"
                elif class_name.lower() in {"backpack", "suitcase"}:
                    severity = "medium"
                events.append(self._base_event(
                    event_type,
                    f"{class_name} detected by the camera",
                    detection,
                    severity,
                ))

            # Person loitering: persistent track with minimal movement.
            if class_name.lower() == "person" and now - self.first_seen[state_key] >= self.loitering_seconds:
                if self.should_emit("person_loitering", track, self.zone_cooldown_seconds):
                    events.append(self._base_event(
                        "person_loitering",
                        "A person has remained in the area for an extended period",
                        detection,
                        "high",
                        duration_seconds=round(now - self.first_seen[state_key], 1),
                    ))

            # Configured business zones.
            if center:
                for zone in zones:
                    polygon = zone.get("polygon") or []
                    if not self._inside_zone(center, polygon):
                        continue
                    zone_name = zone.get("name") or "configured zone"
                    zone_type = str(zone.get("zone_type") or "monitored")
                    zone_event = f"zone_{zone_type}_entered"
                    if self.should_emit(zone_event, track, self.zone_cooldown_seconds):
                        # Matches the real camera_zones.zone_type check constraint:
                        # general, entrance, exit, cash_register, sales_floor,
                        # stock_room, restricted, shelf, loading_area, parking, other.
                        severity = "high" if zone_type in {
                            "restricted", "cash_register", "stock_room", "loading_area", "exit",
                        } else "low"
                        events.append(self._base_event(
                            zone_event,
                            f"{class_name} entered {zone_name}",
                            detection,
                            severity,
                            zone_id=zone.get("id"),
                            zone_name=zone_name,
                            zone_type=zone_type,
                        ))

        # Crowd detection is camera-level rather than object-level.
        people = [d for d in detections if str(d.get("class_name", "")).lower() == "person"]
        if len(people) >= self.crowd_threshold and self.should_emit("crowd_detected", None):
            events.append({
                "event_type": "crowd_detected",
                "description": f"Unusually high number of people detected ({len(people)})",
                "severity": "medium",
                "confidence": max((float(p.get("confidence", 0)) for p in people), default=0.0),
                "metadata": {
                    "people_count": len(people),
                    "threshold": self.crowd_threshold,
                    "track_ids": [p.get("track_id") for p in people],
                    "source": "odt-vision",
                },
            })

        # Remove state for tracks that disappeared for a while. This allows a
        # returning person to generate a fresh loitering cycle.
        stale = [key for key in self.first_seen if f"{key[0]}:{key[1]}" not in active_tracks]
        for key in stale:
            self.first_seen.pop(key, None)
            self.last_centers.pop(key, None)

        return events
