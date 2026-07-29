"""
Ollama Service
===============
Handles communication with Ollama LLM for answering questions
about extracted Braille text.

Setup:
    1. Install Ollama: https://ollama.ai
    2. Pull a model: ollama pull llama3.2
    3. Start Ollama: ollama serve
    4. Ollama runs on http://localhost:11434 by default
"""

import httpx
import json
from typing import List, Optional
import asyncio


class OllamaService:
    """
    Service for interacting with locally-running Ollama LLM.
    
    Supports:
    - Context-based prompting (answers only from Braille text)
    - Conversation history (multi-turn chat)
    - Async requests (non-blocking)
    """
    
    def __init__(
        self,
        base_url: str = "http://127.0.0.1:11434",
        model_name: str = "llama3"  # Upgraded to Llama 3 for much higher reasoning capability
    ):
        self.base_url = base_url
        self.model_name = model_name
        self.timeout = 300.0  # 300 second timeout for LLM responses (model loading can be slow)
        
        print(f"✅ OllamaService initialized (model: {model_name})")
    
    # System prompts are often ignored or hallucinated by TinyLlama.
    # We will pass context directly in the user message instead.
    
    async def generate_answer(
        self,
        question: str,
        context: str,
        history: Optional[List[dict]] = None
    ) -> str:
        """
        Generate an answer to the user's question about the Braille text.
        
        Args:
            question: User's question
            context: Extracted Braille text (used as context)
            history: Previous conversation messages (for multi-turn chat)
        
        Returns:
            LLM-generated answer as string
        """
        
        # Build conversation messages
        messages = [
            {
                "role": "system",
                "content": (
                    "You are a helpful, knowledgeable assistant. The user has provided text that was OCR'd from a Braille document.\n"
                    f"EXTRACTED CONTENT: '{context}'\n\n"
                    "RULES:\n"
                    "1. The primary focus of the conversation is the EXTRACTED CONTENT.\n"
                    "2. You MUST use your general knowledge to explain, summarize, define, or expand upon the concepts or words found in the extracted text when the user asks.\n"
                    "3. If the extracted text contains typos or noise (e.g. random letters like 'U B R A I L L E T X' when it clearly means 'Braille'), intuitively infer the correct meaning and focus on that.\n"
                    "4. Provide clear, conversational, and direct answers without robotic over-explanations of individual characters."
                )
            }
        ]
        
        # Add conversation history (if any)
        if history:
            for msg in history[-10:]:  # Keep last 10 messages for context window
                if msg.get("role") in ["user", "assistant"]:
                    # Scrub out hallucinated tags that might be in history
                    clean_content = msg["content"].replace("User:", "").replace("AI:", "").replace("Assistant:", "").strip()
                    if clean_content:
                        messages.append({
                            "role": msg["role"],
                            "content": clean_content
                        })
        
        messages.append({
            "role": "user",
            "content": question
        })
        
        # Call Ollama API
        try:
            async with httpx.AsyncClient(timeout=self.timeout) as client:
                response = await client.post(
                    f"{self.base_url}/api/chat",
                    json={
                        "model": self.model_name,
                        "messages": messages,
                        "stream": False,  # Get full response at once
                        "options": {
                            "temperature": 0.3,  # Lower = more focused answers
                            "top_p": 0.9,
                            "num_ctx": 4096  # Context window size
                        }
                    }
                )
                
                if response.status_code != 200:
                    raise ConnectionError(
                        f"Ollama API error: {response.status_code} - {response.text}"
                    )
                
                data = response.json()
                answer = data.get("message", {}).get("content", "")
                
                if not answer:
                    return "I could not generate a response. Please try again."
                
                return answer.strip()
                
        except Exception as e:
            raise ConnectionError(
                f"Cannot connect to Ollama. Please ensure Ollama is running: 'ollama serve' \n Details: {str(e)}"
            )
    
    async def list_models(self) -> List[str]:
        """List all available Ollama models."""
        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(f"{self.base_url}/api/tags")
                
                if response.status_code == 200:
                    data = response.json()
                    models = [m["name"] for m in data.get("models", [])]
                    return models
                return []
                
        except Exception:
            return []
    
    async def check_connection(self) -> bool:
        """Check if Ollama is running and accessible."""
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                response = await client.get(f"{self.base_url}/api/tags")
                return response.status_code == 200
        except Exception:
            return False