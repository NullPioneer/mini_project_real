import sys
import os
import cv2
import numpy as np
from services.braille_service import BrailleProcessor

def test_integration():
    print("Testing Backend Integration...")
    
    # 1. Initialize Processor
    processor = BrailleProcessor()
    
    # 2. Create a dummy test image
    dummy_image = np.full((300, 300, 3), 255, dtype=np.uint8)
    
    # 3. Process it directly via the integrated path
    try:
        result = processor.process(dummy_image)
        print("Success! The pipeline processed the numpy array without saving to disk.")
        print(f"Result length: {len(result)}")
        print(f"Result text: '{result}'")
    except Exception as e:
        print(f"Integration failed: {e}")

if __name__ == "__main__":
    test_integration()
