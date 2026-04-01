# =============================================================
#  Routes Package __init__.py
#  Exposes all route modules for easy importing in main.py
# =============================================================

from .image_routes import router as image_router
from .query_routes import router as query_router
from .tts_routes import router as tts_router

__all__ = ["image_router", "query_router", "tts_router"]