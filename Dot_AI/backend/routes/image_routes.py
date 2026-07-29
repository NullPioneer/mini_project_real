"""
Image Processing Routes
========================
Handles Braille image and PDF upload and text extraction.

Endpoint: POST /api/process-image
Input:    Multiple image files or a PDF file
Output:   Extracted text from Braille concatenated from all pages/images
"""

from fastapi import APIRouter, File, UploadFile, HTTPException
from fastapi.responses import JSONResponse
from typing import List
import numpy as np
import cv2
import io
import fitz  # PyMuPDF
from PIL import Image
from services.braille_service import BrailleProcessor

router = APIRouter()

# Initialize Braille processor (loads CNN model)
braille_processor = BrailleProcessor()


@router.post("/process-image")
async def process_braille_images(files: List[UploadFile] = File(...)):
    """
    Process multiple Braille images or a PDF and return extracted text.
    
    Steps:
    1. Validate uploaded files
    2. Convert PDFs to images using PyMuPDF
    3. Pass images to Braille processor pipeline
    4. Combine all extracted text into readable text
    """
    
    if not files:
        raise HTTPException(status_code=400, detail="No files uploaded")
        
    extracted_texts = []
    
    try:
        for file in files:
            file_bytes = await file.read()
            if len(file_bytes) == 0:
                continue
                
            # --- Check if the file is a PDF ---
            if file.content_type == "application/pdf":
                # Convert PDF pages to images
                pdf_document = fitz.open(stream=file_bytes, filetype="pdf")
                for page_num in range(len(pdf_document)):
                    page = pdf_document.load_page(page_num)
                    # Use a relatively high DPI (default is 72) for better OCR accuracy
                    pix = page.get_pixmap(dpi=300)
                    
                    # Convert fitz pixmap to PIL Image
                    img = Image.frombytes("RGB", [pix.width, pix.height], pix.samples)
                    
                    # Convert PIL Image to OpenCV format (BGR)
                    np_img = np.array(img)
                    image = cv2.cvtColor(np_img, cv2.COLOR_RGB2BGR)
                    
                    # Process image through Braille pipeline
                    text = braille_processor.process(image)
                    if text and text.strip():
                        extracted_texts.append(text.strip())
                        
                pdf_document.close()
                
            else:
                try:
                    # Use PIL to safely open all web/mobile image formats
                    pil_img = Image.open(io.BytesIO(file_bytes)).convert("RGBA")
                    image_np = np.array(pil_img)
                    
                    # Convert transparent background to white
                    alpha = image_np[:, :, 3] / 255.0
                    bg = np.ones_like(image_np[:, :, :3], dtype=np.uint8) * 255
                    image_rgb = (image_np[:, :, :3] * alpha[:, :, np.newaxis] + bg * (1 - alpha[:, :, np.newaxis])).astype(np.uint8)
                    
                    # Convert RGB to BGR for OpenCV processing
                    image = cv2.cvtColor(image_rgb, cv2.COLOR_RGB2BGR)
                except Exception as e:
                    print(f"Error loading image with PIL: {e}")
                    raise HTTPException(status_code=400, detail="Invalid image file or format.")
                # Process image through Braille pipeline
                text = braille_processor.process(image)
                if text and text.strip():
                    extracted_texts.append(text.strip())
        
        # --- Combine all text ---
        combined_text = "\n".join(extracted_texts).strip()
        
        if not combined_text:
            return JSONResponse(content={
                "success": True,
                "text": "No Braille text could be detected in these files.",
                "confidence": 0.0,
                "character_count": 0
            })
        
        return JSONResponse(content={
            "success": True,
            "text": combined_text,
            "confidence": 0.95,  # Replace with real confidence from CNN
            "character_count": len(combined_text)
        })
        
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500,
            detail=f"Document processing failed: {str(e)}"
        )