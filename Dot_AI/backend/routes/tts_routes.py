"""
Text-to-Speech Routes
======================
Converts text to audio and returns the audio file.

Endpoint: POST /api/tts
Input:    text (str)
Output:   audio/mpeg file
"""

from fastapi import APIRouter, HTTPException
from fastapi.responses import StreamingResponse, JSONResponse
from pydantic import BaseModel
from typing import Optional
from services.tts_service import TTSService
import io

router = APIRouter()

# Initialize TTS service
tts_service = TTSService()


class TTSRequest(BaseModel):
    text: str
    language: Optional[str] = "en"  # Language code (en, fr, es, etc.)
    speed: Optional[float] = 1.0    # Speech speed multiplier


@router.post("/tts")
async def text_to_speech(request: TTSRequest):
    """
    Convert text to speech and return audio file.
    
    Returns: MP3 audio stream
    """
    
    # --- Validate input ---
    if not request.text or request.text.strip() == "":
        raise HTTPException(status_code=400, detail="Text cannot be empty")
    
    if len(request.text) > 5000:
        raise HTTPException(
            status_code=400,
            detail="Text too long for TTS (max 5000 characters). Split into smaller chunks."
        )
    
    try:
        # --- Generate audio ---
        audio_bytes = tts_service.generate_audio(
            text=request.text.strip(),
            language=request.language,
            speed=request.speed
        )
        
        # Return audio as streaming response
        return StreamingResponse(
            io.BytesIO(audio_bytes),
            media_type="audio/mpeg",
            headers={
                "Content-Disposition": "attachment; filename=response.mp3",
                "Content-Length": str(len(audio_bytes))
            }
        )
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Text-to-speech conversion failed: {str(e)}"
        )


@router.post("/tts/base64")
async def text_to_speech_base64(request: TTSRequest):
    """
    Convert text to speech and return as base64 string.
    Useful for Flutter integration.
    """
    import base64
    
    if not request.text or request.text.strip() == "":
        raise HTTPException(status_code=400, detail="Text cannot be empty")
    
    try:
        audio_bytes = tts_service.generate_audio(
            text=request.text.strip(),
            language=request.language,
            speed=request.speed
        )
        
        audio_base64 = base64.b64encode(audio_bytes).decode('utf-8')
        
        return JSONResponse(content={
            "success": True,
            "audio_base64": audio_base64,
            "format": "mp3",
            "size_bytes": len(audio_bytes)
        })
        
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Text-to-speech conversion failed: {str(e)}"
        )