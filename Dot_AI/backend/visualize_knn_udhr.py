import os
import cv2
import numpy as np
import matplotlib.pyplot as plt
from PIL import Image

def generate_knn_visualization(img_path, output_path, k=6):
    print(f"Loading {img_path}...")
    # 0. Load Image (Handling potential GIFs/JPEGs)
    with Image.open(img_path) as pil_img:
        img_bgr = cv2.cvtColor(np.array(pil_img.convert("RGB")), cv2.COLOR_RGB2BGR)
    
    img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)

    # 1. Preprocessing & Thresholding (Standard Pipeline Logic)
    kernel_sharpen = np.array([[0, -1, 0], [-1, 5.5, -1], [0, -1, 0]])
    sharpened = cv2.filter2D(gray, -1, kernel_sharpen)
    
    min_dim = min(img_bgr.shape[0], img_bgr.shape[1])
    block_size = max(21, int(min_dim * 0.10))
    if block_size % 2 == 0: block_size += 1
    
    thresh = cv2.adaptiveThreshold(sharpened, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
                                   cv2.THRESH_BINARY_INV, block_size, 2)
    kernel = np.ones((2,2), np.uint8)
    thresh = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel)

    # 2. Extract Dots & Centroids
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    max_dot_area = max(500, (img_bgr.shape[0] * img_bgr.shape[1]) * 0.05)
    
    centroids = []
    for cnt in contours:
        area = cv2.contourArea(cnt)
        if 8 < area < max_dot_area:
            x, y, w, h = cv2.boundingRect(cnt)
            if 0.3 < float(w)/h < 3.0:
                M = cv2.moments(cnt)
                if M['m00'] != 0:
                    cx, cy = int(M['m10']/M['m00']), int(M['m01']/M['m00'])
                    centroids.append((cx, cy))
    
    pts = np.array(centroids)
    num_pts = len(pts)
    print(f"✅ Found {num_pts} dots.")

    # 3. K-Nearest Neighbor Analysis
    # Matrix of distances between all points
    diff = pts[:, None, :] - pts[None, :, :]
    dist_matrix = np.sqrt(np.sum(diff**2, axis=-1))

    # For each point, find the indices of the K+1 nearest points (K plus itself)
    # k+1 because the nearest neighbor to a point is always itself (dist=0)
    k_neighbors = np.argsort(dist_matrix, axis=1)[:, :k+1]

    # Calculate median NN (the key scale metric)
    nn_dist = np.partition(dist_matrix, 1, axis=1)[:, 1]
    median_nn = np.median(nn_dist)
    print(f"📏 Computed median_nn = {median_nn:.2f}")

    # 4. Plot Visualization
    plt.figure(figsize=(15, 10))
    plt.imshow(img_rgb, alpha=0.6) # Main image background (faded)
    
    # Plot connections
    print(f"Drawing {k} nearest neighbors for each dot...")
    for i in range(num_pts):
        for j in range(1, k+1): # skip index 0 (itself)
            neighbor_idx = k_neighbors[i, j]
            p1 = pts[i]
            p2 = pts[neighbor_idx]
            
            # Only draw lines the are within 4*median_nn distance 
            # to avoid long messy connections across lines
            if dist_matrix[i, neighbor_idx] < 4 * median_nn:
                plt.plot([p1[0], p2[0]], [p1[1], p2[1]], color='cyan', linewidth=0.8, alpha=0.5)

    # Plot points
    plt.scatter(pts[:, 0], pts[:, 1], c='red', s=10, label='Dot Centroids')
    
    plt.title(f"Figure 3.11: K-Nearest Neighbor Analysis (UDHR Sample)\nK={k}, Median Pitch={median_nn:.2f}px", fontsize=16)
    plt.axis('off')
    plt.tight_layout()
    
    plt.savefig(output_path, dpi=200)
    plt.close()
    print(f"✅ Visualization saved to {output_path}")

if __name__ == "__main__":
    udhr_path = r'C:/Users/negha/OneDrive/Documents/mini_codes/udhr_braille.jpeg'
    output_png = r'C:/Users/negha/OneDrive/Desktop/mini_project_real/Dot_AI/backend/figures/fig_3_11_knn_udhr.png'
    os.makedirs(os.path.dirname(output_png), exist_ok=True)
    generate_knn_visualization(udhr_path, output_png, k=6)
