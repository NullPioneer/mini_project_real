import os
import cv2
import numpy as np
import matplotlib.pyplot as plt
from PIL import Image

# Metadata mapping for final figures
braille_map = {
    "⠁": "a", "⠃": "b", "⠉": "c", "⠙": "d", "⠑": "e",
    "⠋": "f", "⠛": "g", "⠓": "h", "⠊": "i", "⠚": "j",
    "⠅": "k", "⠇": "l", "⠍": "m", "⠝": "n", "⠕": "o",
    "⠏": "p", "⠟": "q", "⠗": "r", "⠎": "s", "⠞": "t",
    "⠥": "u", "⠧": "v", "⠺": "w", "⠭": "x", "⠽": "y", "⠵": "z",
    "⠼": "#", "⠠": "CAPS", " ": " "
}

def generate_figures(img_path, output_dir):
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)

    print(f"Loading {img_path}...")
    with Image.open(img_path) as pil_img:
        img_bgr = cv2.cvtColor(np.array(pil_img.convert("RGB")), cv2.COLOR_RGB2BGR)
    
    img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)
    gray = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2GRAY)

    # Figure 3.5: Image Preprocessing (Sharpening)
    kernel_sharpen = np.array([[0, -1, 0], [-1, 5.5, -1], [0, -1, 0]])
    sharpened = cv2.filter2D(gray, -1, kernel_sharpen)
    
    plt.figure(figsize=(15, 2.5))
    plt.subplot(1, 2, 1); plt.title("Original Grayscale"); plt.imshow(gray, cmap='gray'); plt.axis('off')
    plt.subplot(1, 2, 2); plt.title("Figure 3.5: Sharpened Preprocessing"); plt.imshow(sharpened, cmap='gray'); plt.axis('off')
    plt.savefig(os.path.join(output_dir, "fig_3_5_preprocessing.png"), dpi=150)
    plt.close()

    # Figure 3.6: Adaptive Thresholding
    min_dim = min(img_bgr.shape[0], img_bgr.shape[1])
    block_size = max(21, int(min_dim * 0.10))
    if block_size % 2 == 0: block_size += 1
    thresh = cv2.adaptiveThreshold(sharpened, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
                                   cv2.THRESH_BINARY_INV, block_size, 2)
    kernel = np.ones((2,2), np.uint8)
    thresh = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel)
    
    plt.figure(figsize=(15, 2.5))
    plt.title("Figure 3.6: Adaptive Thresholding (Binary Mask)")
    plt.imshow(thresh, cmap='gray'); plt.axis('off')
    plt.savefig(os.path.join(output_dir, "fig_3_6_thresholding.png"), dpi=150)
    plt.close()

    # Figure 3.7: Contour Detection (Raw)
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    img_contours = img_rgb.copy()
    cv2.drawContours(img_contours, contours, -1, (255, 0, 0), 2)
    plt.figure(figsize=(15, 2.5)); plt.title("Figure 3.7: Raw Contour Detection")
    plt.imshow(img_contours); plt.axis('off')
    plt.savefig(os.path.join(output_dir, "fig_3_7_contours_raw.png"), dpi=150)
    plt.close()

    # Figure 3.8: Contour Filtering
    max_dot_area = max(500, (img_bgr.shape[0] * img_bgr.shape[1]) * 0.05)
    filtered_dots = []
    img_filtered = img_rgb.copy()
    for cnt in contours:
        area = cv2.contourArea(cnt)
        if 8 < area < max_dot_area:
            x, y, w, h = cv2.boundingRect(cnt)
            if 0.3 < float(w)/h < 3.0:
                filtered_dots.append(cnt)
                cv2.rectangle(img_filtered, (x, y), (x+w, y+h), (0, 255, 0), 2)
    plt.figure(figsize=(15, 2.5)); plt.title("Figure 3.8: Filtered Braille Dots")
    plt.imshow(img_filtered); plt.axis('off')
    plt.savefig(os.path.join(output_dir, "fig_3_8_contours_filtered.png"), dpi=150)
    plt.close()

    # Figure 3.9: Centroid Extraction
    centroids = []
    img_centroids = img_rgb.copy()
    for cnt in filtered_dots:
        M = cv2.moments(cnt)
        if M['m00'] != 0:
            cx, cy = int(M['m10']/M['m00']), int(M['m01']/M['m00'])
            centroids.append((cx, cy))
            cv2.circle(img_centroids, (cx, cy), 4, (255, 0, 0), -1)
    plt.figure(figsize=(15, 2.5)); plt.title("Figure 3.9: Centroid Extraction")
    plt.imshow(img_centroids); plt.axis('off')
    plt.savefig(os.path.join(output_dir, "fig_3_9_centroids.png"), dpi=150)
    plt.close()

    # Figure 3.10: Deskewing
    pts = np.array(centroids)
    rect = cv2.minAreaRect(pts)
    angle = rect[-1]
    if angle > 45: angle -= 90
    elif angle < -45: angle += 90
    c, s = np.cos(np.radians(angle)), np.sin(np.radians(angle))
    mean_x, mean_y = np.mean(pts[:, 0]), np.mean(pts[:, 1])
    rotated_dots = []
    for (dx, dy) in centroids:
        x_m, y_m = dx - mean_x, dy - mean_y
        rotated_dots.append((x_m * c - y_m * s + mean_x, x_m * s + y_m * c + mean_y))
    plt.figure(figsize=(15, 2.5))
    plt.subplot(1, 2, 1); plt.title("Before Deskewing"); plt.scatter(pts[:,0], pts[:,1], c='red'); plt.gca().invert_yaxis(); plt.axis('equal'); plt.axis('off')
    plt.subplot(1, 2, 2); plt.title("Figure 3.10: After Deskewing"); plt.scatter([d[0] for d in rotated_dots], [d[1] for d in rotated_dots], c='green'); plt.gca().invert_yaxis(); plt.axis('equal'); plt.axis('off')
    plt.savefig(os.path.join(output_dir, "fig_3_10_deskewing.png"), dpi=150)
    plt.close()

    # Figure 3.11: Nearest Neighbor Analysis
    diff = pts[:, None] - pts
    dist = np.sum(diff**2, axis=-1)**0.5
    nn_dist = np.partition(dist, 1, axis=-1)[:, 1]
    median_nn = np.median(nn_dist)
    plt.figure(figsize=(15, 2.5)); plt.title(f"Figure 3.11: NN Analysis (Median Pitch={median_nn:.1f})")
    plt.hist(nn_dist, bins=30, color='skyblue', edgecolor='black')
    plt.axvline(median_nn, color='red', linestyle='dashed', linewidth=2); plt.xlabel("Pixel Distance"); plt.ylabel("Freq")
    plt.savefig(os.path.join(output_dir, "fig_3_11_nn_analysis.png"), dpi=150)
    plt.close()

    # Figure 3.12: Grid Clustering (Y-axis Lines)
    rotated_dots.sort(key=lambda d: d[1])
    plt.figure(figsize=(15, 2.5)); plt.title("Figure 3.12: Grid Clustering")
    colors = ['red', 'blue', 'green', 'orange', 'purple']
    line_y, line_idx = rotated_dots[0][1], 0
    for dot in rotated_dots:
        if abs(dot[1] - line_y) > median_nn * 2:
            line_y, line_idx = dot[1], line_idx + 1
        plt.scatter(dot[0], dot[1], color=colors[line_idx % len(colors)])
    plt.gca().invert_yaxis(); plt.axis('equal'); plt.axis('off')
    plt.savefig(os.path.join(output_dir, "fig_3_12_grid_formation.png"), dpi=150)
    plt.close()

    # Figure 3.12b: Grid Fitting and Segmentation (Colored Grid)
    lines = []; current_line = [rotated_dots[0]]; line_top_y = rotated_dots[0][1]
    for dot in rotated_dots[1:]:
        if (dot[1] - line_top_y) < (median_nn * 3.5): current_line.append(dot)
        else: lines.append(current_line); current_line = [dot]; line_top_y = dot[1]
    lines.append(current_line)

    plt.figure(figsize=(15, 3))
    plt.title("Figure 3.12b: Grid Fitting and Segmentation (Colored Grid Style)")
    plt.scatter([d[0] for d in rotated_dots], [d[1] for d in rotated_dots], c='gray', s=10, alpha=0.5)
    for line in lines:
        line.sort(key=lambda d: d[0])
        pitches = []
        for i in range(len(line)-1):
            d = line[i+1][0] - line[i][0]
            if median_nn * 1.5 < d < median_nn * 3.5: pitches.append(d)
        char_pitch = np.median(pitches) if pitches else median_nn * 2.5
        line_origin_x, mean_y = line[0][0] - (median_nn * 0.3), np.mean([d[1] for d in line])
        num_slots = int((line[-1][0] - line[0][0]) / char_pitch) + 2
        for s in range(num_slots):
            sx = line_origin_x + s * char_pitch
            rect_w, rect_h = median_nn * 1.2, median_nn * 2.5
            plt.gca().add_patch(plt.Rectangle((sx, mean_y-rect_h/2), rect_w, rect_h, fill=False, edgecolor='#00FF00', linewidth=1.5, alpha=0.8))
            plt.plot([sx+rect_w/2, sx+rect_w/2], [mean_y-rect_h/2, mean_y+rect_h/2], color='#FF0000', linewidth=0.8, alpha=0.5)
            plt.plot([sx, sx+rect_w], [mean_y-rect_h/6, mean_y-rect_h/6], color='#0000FF', linewidth=0.8, alpha=0.5)
            plt.plot([sx, sx+rect_w], [mean_y+rect_h/6, mean_y+rect_h/6], color='#0000FF', linewidth=0.8, alpha=0.5)
            plt.text(sx + rect_w/2, mean_y - rect_h/2 - 5, f"C{s}", ha='center', fontsize=8, color='#00CC00', fontweight='bold')
    plt.gca().invert_yaxis(); plt.axis('equal'); plt.axis('off')
    plt.savefig(os.path.join(output_dir, "fig_3_12b_segmentation.png"), dpi=150)
    plt.close()

    # Figure 3.13: 6-bit Bit Indexing
    plt.figure(figsize=(4, 6)); plt.title("Figure 3.13: 6-bit Bit Indexing")
    plt.gca().add_patch(plt.Rectangle((-0.5, -2.5), 2.0, 3.0, fill=False, edgecolor='#00FF00', linewidth=3))
    plt.plot([0.5, 0.5], [-2.5, 0.5], color='#FF0000', linewidth=1.5)
    plt.plot([-0.5, 1.5], [-0.5, -0.5], color='#0000FF', linewidth=1.5); plt.plot([-0.5, 1.5], [-1.5, -1.5], color='#0000FF', linewidth=1.5)
    dot_pos = [(0,0), (0,1), (0,2), (1,0), (1,1), (1,2)]
    for i, (gx, gy) in enumerate(dot_pos):
        plt.scatter(gx, -gy, s=1500, c='white', edgecolors='black', linewidth=2, zorder=3)
        plt.text(gx, -gy, str(i+1), ha='center', va='center', fontsize=20, fontweight='bold', zorder=4)
    plt.xlim(-0.7, 1.7); plt.ylim(-2.7, 0.7); plt.axis('off')
    plt.savefig(os.path.join(output_dir, "fig_3_13_bit_indexing.png"), dpi=150)
    plt.close()

    # Figure 3.14: Unicode Mapping (Specific to braille2.0)
    # ⠃ (b), ⠗ (r), ⠁ (a), ⠊ (i), ⠇ (l), ⠇ (l), ⠑ (e)
    sample_patterns = ['\u2803', '\u2817', '\u2801', '\u280a', '\u2807', '\u2807', '\u2811']
    sample_labels = ['b', 'r', 'a', 'i', 'l', 'l', 'e']
    plt.figure(figsize=(15, 3)); plt.title("Figure 3.14: Unicode Logic")
    for i, (p, label) in enumerate(zip(sample_patterns, sample_labels)):
        bx = i * 2.0
        plt.gca().add_patch(plt.Rectangle((bx-0.6, 0.1), 1.2, 0.8, fill=True, color='#F0FFF0', alpha=0.3))
        plt.gca().add_patch(plt.Rectangle((bx-0.6, 0.1), 1.2, 0.8, fill=False, edgecolor='#00FF00', linewidth=1))
        plt.text(bx, 0.5, f"{p} → {label}", ha='center', fontsize=22, fontweight='bold', color='#333333')
    plt.xlim(-1.0, 13.0); plt.ylim(0, 1); plt.axis('off')
    plt.savefig(os.path.join(output_dir, "fig_3_14_unicode_mapping.png"), dpi=150)
    plt.close()

    # Figure 3.15: Final Output
    plt.figure(figsize=(15, 2)); plt.title("Figure 3.15: Final Output")
    plt.text(0.5, 0.4, "".join(sample_labels), ha='center', va='center', fontsize=60, fontweight='bold', color='#2E7D32',
             bbox=dict(facecolor='#E8F5E9', edgecolor='#2E7D32', boxstyle='round,pad=0.3'))
    plt.axis('off'); plt.savefig(os.path.join(output_dir, "fig_3_15_final_output.png"), dpi=150)
    plt.close()
    print(f"✅ All figures generated in {output_dir}")

if __name__ == "__main__":
    img_path = r'C:/Users/negha/OneDrive/Documents/mini_codes/braille2.0.jpeg'
    output_dir = r'C:/Users/negha/OneDrive/Desktop/mini_project_real/Dot_AI/backend/figures'
    generate_figures(img_path, output_dir)
