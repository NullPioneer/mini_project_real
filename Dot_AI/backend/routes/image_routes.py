"""
Image Processing Routes
========================
Handles Braille image upload and text extraction.

Endpoint: POST /api/process-image
Input:    Multipart image file
Output:   Extracted text from Braille
"""

from fastapi import APIRouter, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
import numpy as np
import cv2
import io
from PIL import Image
from services.braille_service import BrailleProcessor

router = APIRouter()

# Initialize Braille processor (loads CNN model)
braille_processor = BrailleProcessor()


@router.post("/process-image")
async def process_braille_image(file: UploadFile = File(...)):
    """
    Process a Braille image and return extracted text.
    
    Steps:
    1. Validate uploaded file
    2. Preprocess image (grayscale, threshold, denoise)
    3. Segment Braille cells (call segmentation module)
    4. Predict characters using CNN model
    5. Combine into readable text
    """
    
    # --- Validate file type ---
    if not file.content_type.startswith("image/"):
        raise HTTPException(
            status_code=400,
            detail="Invalid file type. Please upload an image (JPG, PNG, etc.)"
        )
    
    try:
        # --- Read uploaded image ---
        image_bytes = await file.read()
        
        if len(image_bytes) == 0:
            raise HTTPException(status_code=400, detail="Empty image file uploaded")
        
        # Convert bytes to numpy array (OpenCV format)
        nparr = np.frombuffer(image_bytes, np.uint8)
        image = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
        
        if image is None:
            raise HTTPException(
                status_code=400,
                detail="Could not read image. Please upload a valid image file."
            )
        
        # --- Process image through Braille pipeline ---
        extracted_text = braille_processor.process(image)
        
        if not extracted_text or extracted_text.strip() == "":
            return JSONResponse(content={
                "success": True,
                "text": "No Braille text could be detected in this image.",
                "confidence": 0.0,
                "character_count": 0
            })
        
        return JSONResponse(content={
            "success": True,
            "text": extracted_text,
            "confidence": 0.95,  # Replace with real confidence from CNN
            "character_count": len(extracted_text)
        })
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Image processing failed: {str(e)}"
        )