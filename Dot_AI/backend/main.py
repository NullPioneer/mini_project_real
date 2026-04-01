"""
Dot_AI Backend - FastAPI Application
=====================================
Main entry point for the AI-Based Braille Script to Text, Speech,
and Interactive Query System backend.

Run with: uvicorn main:app --host 0.0.0.0 --port 8000 --reload
"""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from routes import image_routes, query_routes, tts_routes
import uvicorn

# Initialize FastAPI app
app = FastAPI(
    title="Dot_AI API",
    description="AI-Based Braille Script to Text, Speech, and Interactive Query System",
    version="1.0.0"
)

# Allow requests from Flutter app (CORS)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, replace with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register route modules
app.include_router(image_routes.router, prefix="/api", tags=["Image Processing"])
app.include_router(query_routes.router, prefix="/api", tags=["Query System"])
app.include_router(tts_routes.router, prefix="/api", tags=["Text-to-Speech"])


@app.get("/")
async def root():
    """Health check endpoint"""
    return {
        "message": "Dot_AI API is running",
        "version": "1.0.0",
        "status": "healthy"
    }


@app.get("/health")
async def health_check():
    """Detailed health check"""
    return {
        "status": "healthy",
        "services": {
            "api": "running",
            "braille_processor": "ready",
            "ollama": "check /api/query",
            "tts": "ready"
        }
    }


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True  # Auto-reload on code changes (dev mode)
    )