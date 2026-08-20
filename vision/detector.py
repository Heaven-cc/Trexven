from typing import Any

from ultralytics import YOLO

from .config import settings


class Detector:
    """YOLO detector with persistent multi-object tracking."""

    def __init__(self) -> None:
        self.model = YOLO(settings.model_path)

    def track(self, frame: Any) -> Any:
        return self.model.track(
            frame,
            persist=True,
            verbose=False,
            conf=settings.confidence_threshold,
            tracker="bytetrack.yaml",
        )

    @staticmethod
    def detections(result: Any) -> list[dict[str, Any]]:
        output: list[dict[str, Any]] = []
        boxes = result.boxes
        if boxes is None:
            return output

        names = result.names
        for i in range(len(boxes)):
            xyxy = boxes.xyxy[i].tolist()
            confidence = float(boxes.conf[i].item())
            class_id = int(boxes.cls[i].item())
            track_id = None
            if boxes.id is not None:
                track_id = int(boxes.id[i].item())

            x1, y1, x2, y2 = xyxy
            output.append({
                "class_id": class_id,
                "class_name": names[class_id],
                "confidence": confidence,
                "track_id": track_id,
                "bbox": xyxy,
                "center": [(x1 + x2) / 2.0, (y1 + y2) / 2.0],
                "width": max(0.0, x2 - x1),
                "height": max(0.0, y2 - y1),
            })
        return output
