import cv2
import numpy as np
import os
import shutil

# Load the file we just processed
img_path = "debug_input.png"
if not os.path.exists(img_path):
    print("No debug input found")
    exit(1)

# We want a color copy to draw bounding boxes and characters and dots on
img = cv2.imread(img_path)
draw_img = img.copy()

# Import the exact logic
from braille_ocr.pipeline import *

# Preprocess
gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
min_dim = min(img.shape[0], img.shape[1])
block_size = max(21, (min_dim // 150) * 2 + 1)
thresh = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
                               cv2.THRESH_BINARY_INV, block_size, 2)
contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
dots = []
max_dot_area = max(500, (img.shape[0] * img.shape[1]) * 0.05)

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
                    dots.append((cx, cy))
                    # Draw actual detected dots as RED
                    cv2.circle(draw_img, (cx,cy), 3, (0,0,255), -1)

if not dots:
    print("no dots")
    exit(0)

# Nearest Neighbor
import math
nn_dist = []
for d1 in dots:
    dists = []
    for d2 in dots:
        if d1 != d2:
            d = math.hypot(d1[0]-d2[0], d1[1]-d2[1])
            dists.append(d)
    if dists:
        nn_dist.append(min(dists))

median_nn = np.median(nn_dist) if nn_dist else 14
if median_nn < 5: median_nn = 14

dots.sort(key=lambda d: d[1])
lines = []
current_line = [dots[0]]
line_top_y = dots[0][1]

for dot in dots[1:]:
    if (dot[1] - line_top_y) < (median_nn * 3.5):
        current_line.append(dot)
    else:
        lines.append(current_line)
        current_line = [dot]
        line_top_y = dot[1]
if current_line:
    lines.append(current_line)

for line_idx, line_dots in enumerate(lines):
    line_dots.sort(key=lambda d: d[0])
    y_coords = sorted([d[1] for d in line_dots])
    
    row_clusters = []
    current_cluster = [y_coords[0]]
    for y in y_coords[1:]:
        if y - np.mean(current_cluster) < median_nn * 0.5:
            current_cluster.append(y)
        else:
            row_clusters.append(current_cluster)
            current_cluster = [y]
    row_clusters.append(current_cluster)
    
    valid_y_clusters = [np.mean(c) for c in row_clusters if len(c) >= 3]
    if valid_y_clusters:
        row0_y = valid_y_clusters[0]
        if len(valid_y_clusters) > 1:
            Y_PITCH = np.median(np.diff(valid_y_clusters))
            if not (median_nn * 0.5 < Y_PITCH < median_nn * 2.0):
                Y_PITCH = median_nn
        else:
            Y_PITCH = median_nn
    else:
        row0_y = np.mean(row_clusters[0])
        Y_PITCH = median_nn
        
    y_top_thresh = row0_y + (Y_PITCH * 0.5)
    y_mid_thresh = row0_y + (Y_PITCH * 1.5)
    
    cells = []
    current_cell = [line_dots[0]]
    for dot in line_dots[1:]:
        dx = dot[0] - current_cell[-1][0]
        if dx < median_nn * 1.3:
            current_cell.append(dot)
        else:
            cells.append(current_cell)
            current_cell = [dot]
    cells.append(current_cell)
    
    pitches = []
    for i in range(len(cells) - 1):
        dist = cells[i+1][0][0] - cells[i][0][0]
        if median_nn * 2.0 < dist < median_nn * 3.5:
            pitches.append(dist)
            
    if pitches:
        CHAR_PITCH = np.median(pitches)
    else:
        CHAR_PITCH = median_nn * 2.5
    
    base_ref = cells[0][0][0]
    offsets = []
    for c in cells:
        dist = c[0][0] - base_ref
        k = np.round(dist / CHAR_PITCH)
        offsets.append(c[0][0] - k * CHAR_PITCH)
        
    line_origin = np.median(offsets)
    slots = {}
    
    for dot in line_dots:
        dx = dot[0] - line_origin
        slot_idx = int(np.floor((dx + median_nn * 0.5) / CHAR_PITCH))
        if slot_idx < 0: slot_idx = 0
        if slot_idx not in slots: slots[slot_idx] = []
        slots[slot_idx].append(dot)
        
    if not slots: continue
    max_slot = max(slots.keys())

    font = cv2.FONT_HERSHEY_SIMPLEX
    font_scale = max(0.4, min(1.0, CHAR_PITCH / 30))
    thickness = max(1, int(CHAR_PITCH / 20))
    
    for curr_slot in range(max_slot + 1):
        slot_origin_x = line_origin + (curr_slot * CHAR_PITCH)
        x_start = int(slot_origin_x - median_nn * 0.5)
        x_end = int(slot_origin_x + median_nn * 1.5)
        y_start = int(row0_y - median_nn)
        y_end = int(row0_y + Y_PITCH * 2.5)

        if curr_slot not in slots:
            continue
            
        # Draw bounding box for cell
        cv2.rectangle(draw_img, (x_start, y_start), (x_end, y_end), (255, 0, 0), 2)
        
        cell_dots = slots[curr_slot]
        pattern = [0]*6
        x_mid = slot_origin_x + (median_nn * 0.5)
        
        for (cx, cy) in cell_dots:
            col = 0 if cx <= x_mid else 1
            if cy < y_top_thresh: row = 0
            elif cy < y_mid_thresh: row = 1
            else: row = 2
            
            if row == 0 and col == 0: pattern[0] = 1
            elif row == 1 and col == 0: pattern[1] = 1
            elif row == 2 and col == 0: pattern[2] = 1
            elif row == 0 and col == 1: pattern[3] = 1
            elif row == 1 and col == 1: pattern[4] = 1
            elif row == 2 and col == 1: pattern[5] = 1

        val = sum([b << k for k, b in enumerate(pattern)])
        bc = chr(0x2800 + val)
        eng = translate_braille(bc)
        if not eng: eng = "?"
        if bc == "⠠": eng = "CAP"
        if bc == "⠼": eng = "NUM"
        if eng == " ": eng = "_"
        
        # Draw character above bounding box
        cv2.putText(draw_img, eng, (x_start, y_start - 5), font, font_scale, (0, 128, 0), thickness, cv2.LINE_AA)

output_path = r"c:\Users\negha\.gemini\antigravity\brain\f07a7d4f-f2c2-459d-b3ec-151f4c089a07\artifacts\segmentation_out.png"
# Ensure artifact dir exists
os.makedirs(os.path.dirname(output_path), exist_ok=True)
cv2.imwrite(output_path, draw_img)
print("Saved segmentation output to artifacts.")
