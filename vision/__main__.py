"""Entry point: python -m vision"""
import uvicorn
from .config import settings
from .server import app  # noqa: F401 — registers all routes

if __name__ == "__main__":
    uvicorn.run(
        "vision.server:app",
        host=settings.host,
        port=settings.port,
        reload=False,
        log_level="info",
    )
