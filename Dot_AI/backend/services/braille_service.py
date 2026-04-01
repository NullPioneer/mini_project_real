"""
Braille Processing Service
===========================
Integrated OpenCV Braille Processing Service.
"""

import numpy as np

# Import our new local braille_ocr pipeline
from braille_ocr.pipeline import process_numpy_image

class BrailleProcessor:
    """
    Main Braille image processing pipeline.
    Uses the integrated rule-based OpenCV mathematical detector.
    """
    
    def __init__(self):
        print("✅ BrailleProcessor initialized with OpenCV OCR Integration")
    
    def process(self, image: np.ndarray) -> str:
        """
        Passes the uploaded image directly to our OpenCV processing pipeline.
        
        Args:
            image: OpenCV BGR image (numpy array)
        Returns:
            Extracted text string
        """
        print("🔄 Starting Braille processing pipeline integration...")
        
        # Directly call our process_numpy_image
        extracted_text = process_numpy_image(image)
        
        print(f"   ✅ Extracted text processing completed: {extracted_text[:30]}...")
        return extracted_text