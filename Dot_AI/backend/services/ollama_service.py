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
        base_url: str = "http://localhost:11434",
        model_name: str = "tinyllama"  # Utilizing extremely small model (640MB)
    ):
        self.base_url = base_url
        self.model_name = model_name
        self.timeout = 60.0  # 60 second timeout for LLM responses
        
        print(f"✅ OllamaService initialized (model: {model_name})")
    
    def _build_system_prompt(self, context: str) -> str:
        """
        Build a context-aware system prompt.
        
        This ensures the LLM ONLY answers based on the extracted Braille text,
        not from its general training knowledge.
        """
        return f"""You are Dot_AI, an intelligent Braille reading assistant.

Your ONLY job is to answer questions based on the following Braille text that was extracted from an image:

--- EXTRACTED BRAILLE TEXT START ---
{context}
--- EXTRACTED BRAILLE TEXT END ---

STRICT RULES:
1. ONLY answer questions based on the text above.
2. If the question cannot be answered from the text, say: "I cannot find that information in the Braille text."
3. Be clear, concise, and helpful.
4. If asked to summarize, provide a brief summary of the extracted text.
5. Do NOT use information from outside the provided text.
6. Respond in a friendly, accessible tone suitable for visually impaired users.
"""
    
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
        messages = []
        
        # Add system prompt with Braille context
        messages.append({
            "role": "system",
            "content": self._build_system_prompt(context)
        })
        
        # Add conversation history (if any)
        if history:
            for msg in history[-10:]:  # Keep last 10 messages for context window
                if msg.get("role") in ["user", "assistant"]:
                    messages.append({
                        "role": msg["role"],
                        "content": msg["content"]
                    })
        
        # Add current question
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
                
        except httpx.ConnectError:
            raise ConnectionError(
                "Cannot connect to Ollama. "
                "Please ensure Ollama is running: 'ollama serve'"
            )
        except httpx.TimeoutException:
            raise TimeoutError(
                "Ollama took too long to respond. "
                "Try a smaller model or check your hardware."
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