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
        log_path = r"c:\Users\negha\OneDrive\Desktop\braille_log.txt"
        with open(log_path, "a") as f:
            f.write(f"Incoming image shape: {image.shape}\n")
            
        print("🔄 Starting Braille processing pipeline integration...")
        import cv2
        
        # Performance protection
        max_dim = 1800
        height, width = image.shape[:2]
        if max(height, width) > max_dim:
            scale = max_dim / max(height, width)
            image = cv2.resize(image, (int(width * scale), int(height * scale)), interpolation=cv2.INTER_AREA)
            
        extracted_text = process_numpy_image(image)
        
        with open(log_path, "a") as f:
            f.write(f"Processed image shape: {image.shape}, extracted_text length: {len(extracted_text)}\n")
            
        print(f"   ✅ Extracted text processing completed: {extracted_text[:30]}...")
        return extracted_text