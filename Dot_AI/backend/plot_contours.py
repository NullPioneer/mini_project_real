import cv2
import numpy as np
import matplotlib.pyplot as plt
import tkinter as tk
from tkinter import filedialog

from PIL import Image

def plot_braille_pipeline(img_path):
    try:
        # Try OpenCV first
        with open(img_path, "rb") as f:
            chunk = f.read()
        chunk_arr = np.frombuffer(chunk, dtype=np.uint8)
        img = cv2.imdecode(chunk_arr, cv2.IMREAD_COLOR)
        
        # Fallback to Pillow if OpenCV fails to decode
        if img is None:
            # print("OpenCV decode failed, trying Pillow fallback...")
            with Image.open(img_path) as pil_img:
                img = cv2.cvtColor(np.array(pil_img.convert("RGB")), cv2.COLOR_RGB2BGR)
    except Exception as e:
        print(f"Error accessing or decoding file {img_path}: {e}")
        return

    if img is None:
        print(f"Failed to decode {img_path}. This file might not be a valid image or is in an unsupported format.")
        return

    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    
    # 0. Blur Recovery
    kernel_sharpen = np.array([[0, -1, 0], [-1, 5.5, -1], [0, -1, 0]])
    gray = cv2.filter2D(gray, -1, kernel_sharpen)
    
    # 1. Scale-invariant Thresholding
    min_dim = min(img.shape[0], img.shape[1])
    block_size = max(21, int(min_dim * 0.10))
    if block_size % 2 == 0: block_size += 1
        
    thresh = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
                                   cv2.THRESH_BINARY_INV, block_size, 2)
    kernel = np.ones((2,2), np.uint8)
    thresh = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel)
    
    # 2. Contours
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    max_dot_area = max(500, (img.shape[0] * img.shape[1]) * 0.05)
    
    # Create an RGB canvas for Matplotlib
    canvas = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
    
    for cnt in contours:
        area = cv2.contourArea(cnt)
        if 8 < area < max_dot_area:
            x, y, w, h = cv2.boundingRect(cnt)
            aspect_ratio = float(w)/h
            if 0.3 < aspect_ratio < 3.0:
                M = cv2.moments(cnt)
                if M['m00'] != 0:
                    cx = int(M['m10']/M['m00'])
                    cy = int(M['m01']/M['m00'])
                    if cx > 2 and cy > 2 and cx < img.shape[1] - 2 and cy < img.shape[0] - 2:
                        cv2.rectangle(canvas, (x, y), (x+w, y+h), (0, 255, 0), 2)
                        cv2.circle(canvas, (cx, cy), 3, (255, 0, 0), -1)

    plt.figure(figsize=(12, 6))
    
    # Only show filename, not full path
    name = img_path.replace('\\', '/').split('/')[-1]
    plt.suptitle(f"Braille Pipeline Visualization: {name}", fontsize=16)
    
    plt.subplot(1, 2, 1)
    plt.title("Adaptive Threshold Mask", fontsize=14)
    plt.imshow(thresh, cmap='gray')
    plt.axis('off')
    
    plt.subplot(1, 2, 2)
    plt.title("Detected Dots (Green Boxes, Red Centers)", fontsize=14)
    plt.imshow(canvas)
    plt.axis('off')
    
    plt.tight_layout()
    plt.show()

def main():
    root = tk.Tk()
    root.withdraw() # Hide the main window
    
    print("Opening file picker...")
    file_paths = filedialog.askopenfilenames(
        title="Select Braille Images to Plot",
        filetypes=[("Image files", "*.jpg;*.jpeg;*.png;*.bmp")]
    )
    
    if not file_paths:
        print("No images selected.")
        return
        
    for path in file_paths:
        print(f"Plotting {path}...")
        plot_braille_pipeline(path)

if __name__ == "__main__":
    main()
