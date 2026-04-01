"""
Text-to-Speech Service
=======================
Converts text to speech using gTTS (Google Text-to-Speech).

Install: pip install gtts

Alternative: Use pyttsx3 for offline TTS:
    pip install pyttsx3
    (See commented code below)
"""

from gtts import gTTS
import io
import re
from typing import Optional


class TTSService:
    """
    Text-to-Speech service using gTTS.
    
    Converts text to MP3 audio bytes.
    Supports multiple languages and speeds.
    """
    
    def __init__(self):
        print("✅ TTSService initialized (using gTTS)")
    
    def generate_audio(
        self,
        text: str,
        language: str = "en",
        speed: float = 1.0
    ) -> bytes:
        """
        Convert text to speech and return as bytes.
        
        Args:
            text: Text to convert to speech
            language: Language code (en, fr, es, hi, ta, ml, etc.)
            speed: Not directly supported in gTTS; use slow=True for slow speech
        
        Returns:
            MP3 audio as bytes
        """
        
        # Clean text (remove special characters that cause TTS issues)
        cleaned_text = self._clean_text(text)
        
        if not cleaned_text:
            raise ValueError("No speakable text after cleaning")
        
        # Split long text into chunks (gTTS has a limit)
        chunks = self._split_text(cleaned_text, max_length=500)
        
        # Generate audio for each chunk and combine
        audio_buffer = io.BytesIO()
        
        for chunk in chunks:
            if chunk.strip():
                # slow=True makes speech slower (useful for accessibility)
                tts = gTTS(
                    text=chunk,
                    lang=language,
                    slow=(speed < 0.8)  # Use slow mode if speed is low
                )
                tts.write_to_fp(audio_buffer)
        
        audio_bytes = audio_buffer.getvalue()
        
        if not audio_bytes:
            raise RuntimeError("Failed to generate audio")
        
        return audio_bytes
    
    def _clean_text(self, text: str) -> str:
        """
        Clean text for better TTS output.
        Removes markdown, extra whitespace, special characters.
        """
        # Remove markdown formatting
        text = re.sub(r'\*\*(.+?)\*\*', r'\1', text)  # **bold**
        text = re.sub(r'\*(.+?)\*', r'\1', text)       # *italic*
        text = re.sub(r'`(.+?)`', r'\1', text)          # `code`
        text = re.sub(r'#{1,6}\s', '', text)             # ## headers
        
        # Normalize whitespace
        text = re.sub(r'\s+', ' ', text)
        
        # Remove characters that confuse TTS
        text = re.sub(r'[^\w\s.,!?;:\'"()\-]', ' ', text)
        
        return text.strip()
    
    def _split_text(self, text: str, max_length: int = 500) -> list:
        """
        Split long text into chunks at sentence boundaries.
        gTTS works best with shorter chunks.
        """
        if len(text) <= max_length:
            return [text]
        
        # Split by sentences
        sentences = re.split(r'(?<=[.!?])\s+', text)
        chunks = []
        current_chunk = ""
        
        for sentence in sentences:
            if len(current_chunk) + len(sentence) <= max_length:
                current_chunk += sentence + " "
            else:
                if current_chunk:
                    chunks.append(current_chunk.strip())
                current_chunk = sentence + " "
        
        if current_chunk:
            chunks.append(current_chunk.strip())
        
        return chunks if chunks else [text[:max_length]]


# ============================================================
# ALTERNATIVE: Offline TTS using pyttsx3
# Uncomment and use this class if you don't have internet access
# ============================================================

# import pyttsx3
# import io
# import tempfile
# import os
#
# class TTSServiceOffline:
#     """Offline TTS using pyttsx3 (no internet required)"""
#     
#     def __init__(self):
#         self.engine = pyttsx3.init()
#         # Set properties
#         self.engine.setProperty('rate', 150)    # Speech rate
#         self.engine.setProperty('volume', 1.0)  # Volume (0.0 to 1.0)
#         print("✅ Offline TTSService initialized (using pyttsx3)")
#     
#     def generate_audio(self, text: str, language: str = "en", speed: float = 1.0) -> bytes:
#         # Save to temporary file
#         with tempfile.NamedTemporaryFile(suffix='.mp3', delete=False) as f:
#             temp_path = f.name
#         
#         self.engine.setProperty('rate', int(150 * speed))
#         self.engine.save_to_file(text, temp_path)
#         self.engine.runAndWait()
#         
#         with open(temp_path, 'rb') as f:
#             audio_bytes = f.read()
#         
#         os.unlink(temp_path)
#         return audio_bytes