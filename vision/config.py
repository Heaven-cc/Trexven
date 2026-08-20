from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    supabase_url: str
    supabase_service_role_key: str
    vision_api_key: str = "change-me"
    model_path: str = "yolo11n.pt"
    confidence_threshold: float = 0.50
    event_cooldown_seconds: float = 5.0
    zone_event_cooldown_seconds: float = 8.0
    loitering_seconds: float = 30.0
    crowd_threshold: int = 5
    max_detection_history: int = 120
    frame_interval_seconds: float = 0.10
    reconnect_delay_seconds: float = 3.0
    poll_interval_seconds: float = 2.0
    jpeg_quality: int = 82
    host: str = "127.0.0.1"
    port: int = 8000

    model_config = SettingsConfigDict(env_file=".env", extra="ignore")


settings = Settings()
