import os
import cv2
import numpy as np

# =========================
# CONFIG
# =========================

braille_map = {
    "⠁": "a", "⠃": "b", "⠉": "c", "⠙": "d", "⠑": "e",
    "⠋": "f", "⠛": "g", "⠓": "h", "⠊": "i", "⠚": "j",
    "⠅": "k", "⠇": "l", "⠍": "m", "⠝": "n", "⠕": "o",
    "⠏": "p", "⠟": "q", "⠗": "r", "⠎": "s", "⠞": "t",
    "⠥": "u", "⠧": "v", "⠺": "w", "⠭": "x", "⠽": "y", "⠵": "z",
    "⠀": " ",
    "⠂": ",", "⠲": ".", "⠖": "!", "⠦": "?", "⠤": "-", "⠄": "'", "⠶": "\"", "⠜": "\"",
    "⠼": "#" 
}

def translate_braille(text):
    result = ""
    is_number = False
    
    num_map = {
        "⠁": "1", "⠃": "2", "⠉": "3", "⠙": "4", "⠑": "5", 
        "⠋": "6", "⠛": "7", "⠓": "8", "⠊": "9", "⠚": "0"
    }

    for c in text:
        if c == "⠼":
            is_number = True
            continue
        elif c == "⠀" or c == " ":
            is_number = False
            result += " "
            continue
            
        if is_number and c in num_map:
            result += num_map[c]
        else:
            is_number = False
            result += braille_map.get(c, "")
            
    return result

# =========================
# VISION ALGORITHM
# =========================

def process_numpy_image(img: np.ndarray) -> str:
    """
    Main entry point for Dot_AI backend braille service.
    Takes directly a valid numpy BGR image array.
    """
    if img is None:
        print("❌ Invalid image provided.")
        return ""
        
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    
    # 0. Blurry Image Recovery (Sharpening Convolution filter)
    kernel_sharpen = np.array([[0, -1, 0],
                               [-1, 5.5, -1],
                               [0, -1, 0]])
    gray = cv2.filter2D(gray, -1, kernel_sharpen)
    
    # 1. Full Page Adaptive Thresholding
    thresh = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
                                   cv2.THRESH_BINARY_INV, 21, 2)
                                   
    kernel = np.ones((2,2), np.uint8)
    thresh = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, kernel)
    
    # 2. Extract All Dots directly from the raw piece of paper
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    dots = []
    
    for cnt in contours:
        area = cv2.contourArea(cnt)
        if 8 < area < 500:  
            M = cv2.moments(cnt)
            if M['m00'] != 0:
                cx = int(M['m10']/M['m00'])
                cy = int(M['m01']/M['m00'])
                if cx > 2 and cy > 2 and cx < img.shape[1] - 2 and cy < img.shape[0] - 2:
                    dots.append((cx, cy))
                
    if not dots:
        print("❌ No dots found.")
        return ""
        
    # 2.5 Mathemtical Deskewing (Tilt Correction)
    if len(dots) > 10:
        pts = np.array(dots)
        rect = cv2.minAreaRect(pts)
        angle = rect[-1]
        
        if angle > 45:
            angle = angle - 90
        elif angle < -45:
            angle = 90 + angle
            
        c, s = np.cos(np.radians(angle)), np.sin(np.radians(angle))
        mean_x, mean_y = np.mean(pts[:, 0]), np.mean(pts[:, 1])
        
        rotated_dots = []
        for (x, y) in dots:
            x_m, y_m = x - mean_x, y - mean_y
            new_x = x_m * c - y_m * s + mean_x
            new_y = x_m * s + y_m * c + mean_y
            rotated_dots.append((new_x, new_y))
        dots = rotated_dots
        
    if len(dots) < 2:
        return ""
        
    # Scale Invariance Core Function
    pts = np.array(dots)
    diff = pts[:, None] - pts
    dist = np.sum(diff**2, axis=-1)**0.5
    nn_dist = np.partition(dist, 1, axis=-1)[:, 1]
    median_nn = np.median(nn_dist)
    if median_nn < 5:
        median_nn = 14 # Safety Fallback
        
    # 3. Cluster Dots into Lines (Y-Axis)
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
        
    braille_output = []
    
    # 4. Cluster Dots into distinct 3x2 Cells (X-Axis) based on median_nn constraints
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
        
        # --- NEW 1D GRID ALGORITHM ---
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
            
            if slot_idx < 0:
                slot_idx = 0
                
            if slot_idx not in slots:
                slots[slot_idx] = []
            slots[slot_idx].append(dot)
            
        if not slots:
            braille_output.append(" ")
            continue
            
        max_slot = max(slots.keys())
        
        # 5. Extract 6-Bit Pattern per Slot
        for curr_slot in range(max_slot + 1):
            if curr_slot not in slots:
                braille_output.append("⠀")
                continue
                
            cell_dots = slots[curr_slot]
            pattern = [0]*6
            
            slot_origin_x = line_origin + (curr_slot * CHAR_PITCH)
            x_mid = slot_origin_x + (median_nn * 0.5)
            
            for (cx, cy) in cell_dots:
                col = 0 if cx <= x_mid else 1
                if cy < y_top_thresh:     row = 0
                elif cy < y_mid_thresh:   row = 1
                else:                     row = 2
                    
                if row == 0 and col == 0:   pattern[0] = 1
                elif row == 1 and col == 0: pattern[1] = 1
                elif row == 2 and col == 0: pattern[2] = 1
                elif row == 0 and col == 1: pattern[3] = 1
                elif row == 1 and col == 1: pattern[4] = 1
                elif row == 2 and col == 1: pattern[5] = 1
                
            value = sum([bit << k for k, bit in enumerate(pattern)])
            braille_output.append(chr(0x2800 + value))
            
        braille_output.append(" ") 
        
    braille_text = "".join(braille_output).replace("  ", " ").strip()
    
    # Translate natively to English
    if not braille_text:
        return ""
        
    english_text = translate_braille(braille_text)
    return english_text
