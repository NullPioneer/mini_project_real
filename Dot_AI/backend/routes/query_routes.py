"""
Query Routes
=============
Handles user questions about extracted Braille text using Ollama LLM.

Endpoint: POST /api/query
Input:    question (str), context (str - extracted Braille text)
Output:   AI-generated answer
"""

from fastapi import APIRouter, HTTPException
from fastapi.responses import JSONResponse
from pydantic import BaseModel
from typing import Optional, List
from services.ollama_service import OllamaService

router = APIRouter()

# Initialize Ollama service
ollama_service = OllamaService()


# --- Request/Response Models ---

class QueryRequest(BaseModel):
    question: str
    context: str
    conversation_history: Optional[List[dict]] = []  # For multi-turn chat

class QueryResponse(BaseModel):
    answer: str
    success: bool
    model_used: str


@router.post("/query")
async def query_braille_text(request: QueryRequest):
    """
    Answer a question about the extracted Braille text.
    
    Uses Ollama LLM with context-based prompting:
    - Only answers based on the extracted text (not general knowledge)
    - Maintains conversation history for follow-up questions
    """
    
    # --- Validate inputs ---
    if not request.question or request.question.strip() == "":
        raise HTTPException(status_code=400, detail="Question cannot be empty")
    
    if not request.context or request.context.strip() == "":
        raise HTTPException(
            status_code=400,
            detail="No Braille text context provided. Please process an image first."
        )
    
    # Limit question length
    if len(request.question) > 1000:
        raise HTTPException(status_code=400, detail="Question too long (max 1000 characters)")
    
    try:
        # --- Generate answer using Ollama ---
        answer = await ollama_service.generate_answer(
            question=request.question.strip(),
            context=request.context.strip(),
            history=request.conversation_history
        )
        
        return JSONResponse(content={
            "success": True,
            "answer": answer,
            "model_used": ollama_service.model_name
        })
        
    except ConnectionError as e:
        raise HTTPException(
            status_code=503,
            detail=f"Ollama service unavailable. Make sure Ollama is running: {str(e)}"
        )
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Query processing failed: {str(e)}"
        )


@router.get("/models")
async def list_available_models():
    """List all Ollama models available on this machine"""
    try:
        models = await ollama_service.list_models()
        return {"models": models}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))