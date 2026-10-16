import os
import math
from PIL import Image, ImageDraw, ImageFilter

W, H = 2048, 2048
img = Image.new('RGBA', (W, H), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

# 1. Vibrant Background Gradient (Luminous royal/electric blue down to rich deep midnight sapphire)
# Brighter and much higher contrast than the old near-black background
for y in range(H):
    t = y / H
    # Top is vibrant electric sapphire blue (24, 76, 175) -> bottom is deep rich navy (11, 23, 56)
    r = int(22 + (12 - 22) * t)
    g = int(68 + (24 - 68) * t)
    b = int(168 + (60 - 168) * t)
    draw.line([(0, y), (W, y)], fill=(r, g, b, 255))

# Radiant ambient lighting glow behind the vehicle and person
glow = Image.new('RGBA', (W, H), (0, 0, 0, 0))
glow_draw = ImageDraw.Draw(glow)
center_x, center_y = int(W * 0.52), int(H * 0.56)
max_rad = int(W * 0.48)
for radius in range(max_rad, 0, -8):
    factor = 1.0 - (radius / max_rad)
    alpha = int(75 * (factor ** 1.4))
    glow_draw.ellipse(
        [center_x - radius, center_y - radius, center_x + radius, center_y + radius],
        fill=(56, 189, 248, alpha)
    )
img = Image.alpha_composite(img, glow)
draw = ImageDraw.Draw(img)

# Ground surface with bright neon cyan pavement accent
ground_y = int(H * 0.81)
# Ground fill: sleek dark graphite floor
draw.rectangle([(0, ground_y), (W, H)], fill=(12, 18, 34, 255))
# Glowing ground horizon line
draw.line([(0, ground_y), (W, ground_y)], fill=(56, 189, 248, 180), width=6)
draw.line([(0, ground_y - 2), (W, ground_y - 2)], fill=(186, 230, 253, 100), width=2)

# --- 2. Gas Pump on Right ---
px1, py1, px2, py2 = int(W * 0.77), int(H * 0.36), int(W * 0.91), ground_y
# Pump main body: Sleek modern dark metallic housing with bright cyan edge
draw.rounded_rectangle([px1, py1, px2, py2], radius=26, fill=(30, 41, 59, 255), outline=(94, 234, 212, 230), width=7)

# Pump canopy top
draw.rounded_rectangle([int(W * 0.75), int(H * 0.32), int(W * 0.93), int(H * 0.365)], radius=14, fill=(15, 23, 42, 255), outline=(56, 189, 248, 255), width=6)
# Canopy indicator light strip
draw.line([(int(W * 0.77), int(H * 0.342)), (int(W * 0.91), int(H * 0.342))], fill=(56, 189, 248, 255), width=6)

# Pump digital display screen - High contrast illuminated cyan
sx1, sy1, sx2, sy2 = int(W * 0.79), int(H * 0.42), int(W * 0.89), int(H * 0.52)
draw.rounded_rectangle([sx1, sy1, sx2, sy2], radius=12, fill=(8, 47, 73, 255), outline=(56, 189, 248, 255), width=5)
# Glowing digits inside screen
draw.rectangle([sx1 + 16, sy1 + 18, sx2 - 16, sy1 + 30], fill=(56, 189, 248, 255))
draw.rectangle([sx1 + 16, sy1 + 42, sx2 - 16, sy1 + 54], fill=(56, 189, 248, 220))

# Fuel nozzle holster
draw.rounded_rectangle([int(W * 0.75), int(H * 0.55), int(W * 0.775), int(H * 0.63)], radius=8, fill=(15, 23, 42, 255), outline=(148, 163, 184, 200), width=3)


# --- 3. Sedan Rear Silhouette (Viewed from behind) ---
tw = int(W * 0.10)
th = int(H * 0.14)
# Left tire
draw.rounded_rectangle([int(W * 0.14), ground_y - th, int(W * 0.14) + tw, ground_y], radius=16, fill=(10, 10, 14, 255), outline=(71, 85, 105, 180), width=4)
# Right tire
draw.rounded_rectangle([int(W * 0.49), ground_y - th, int(W * 0.49) + tw, ground_y], radius=16, fill=(10, 10, 14, 255), outline=(71, 85, 105, 180), width=4)

# Car body silhouette - High contrast crisp metallic charcoal body with vivid highlights
car_points = [
    (int(W * 0.12), ground_y - int(H * 0.05)), # Lower left bumper
    (int(W * 0.11), int(H * 0.65)),             # Left quarter waist
    (int(W * 0.12), int(H * 0.56)),             # Rear left fender
    (int(W * 0.18), int(H * 0.39)),             # Left C-pillar slope up
    (int(W * 0.48), int(H * 0.39)),             # Roof right
    (int(W * 0.57), int(H * 0.56)),             # Right C-pillar slope down
    (int(W * 0.61), int(H * 0.65)),             # Right quarter waist
    (int(W * 0.60), ground_y - int(H * 0.05)), # Lower right bumper
]
# Crisp high-contrast body fill & distinct luminous border
draw.polygon(car_points, fill=(15, 23, 42, 255), outline=(226, 232, 240, 240))
# Inner body contour accent
draw.line([(int(W * 0.18), int(H * 0.395)), (int(W * 0.48), int(H * 0.395))], fill=(255, 255, 255, 255), width=8)

# Rear windshield (Dark glass with brilliant sky reflection)
glass_points = [
    (int(W * 0.20), int(H * 0.415)),
    (int(W * 0.46), int(H * 0.415)),
    (int(W * 0.53), int(H * 0.54)),
    (int(W * 0.16), int(H * 0.54)),
]
draw.polygon(glass_points, fill=(2, 6, 23, 255), outline=(56, 189, 248, 200))
# Crisp bright diagonal glass reflection streak
draw.line([(int(W * 0.23), int(H * 0.435)), (int(W * 0.43), int(H * 0.525))], fill=(255, 255, 255, 140), width=8)

# Trunk lid contour line
draw.line([(int(W * 0.15), int(H * 0.56)), (int(W * 0.58), int(H * 0.56))], fill=(148, 163, 184, 255), width=6)

# Brilliant Neon Taillights (Vivid Red / Bright Carmine with intense presence)
# Left light
draw.rounded_rectangle([int(W * 0.125), int(H * 0.575), int(W * 0.245), int(H * 0.625)], radius=10, fill=(255, 30, 60, 255), outline=(254, 202, 202, 255), width=3)
# Right light
draw.rounded_rectangle([int(W * 0.485), int(H * 0.575), int(W * 0.595), int(H * 0.625)], radius=10, fill=(255, 30, 60, 255), outline=(254, 202, 202, 255), width=3)
# Connecting horizontal LED light bar across the trunk
draw.line([(int(W * 0.245), int(H * 0.60)), (int(W * 0.485), int(H * 0.60))], fill=(255, 50, 80, 255), width=8)
draw.line([(int(W * 0.245), int(H * 0.60)), (int(W * 0.485), int(H * 0.60))], fill=(255, 200, 210, 255), width=3)

# High contrast License Plate
draw.rounded_rectangle([int(W * 0.29), int(H * 0.66), int(W * 0.43), int(H * 0.725)], radius=8, fill=(255, 255, 255, 255), outline=(56, 189, 248, 255), width=4)
# License plate embossed text representation
draw.line([(int(W * 0.32), int(H * 0.692)), (int(W * 0.40), int(H * 0.692))], fill=(15, 23, 42, 255), width=6)

# Dual chrome exhausts
draw.rounded_rectangle([int(W * 0.16), ground_y - 22, int(W * 0.22), ground_y - 6], radius=6, fill=(241, 245, 249, 255), outline=(56, 189, 248, 200), width=3)
draw.rounded_rectangle([int(W * 0.50), ground_y - 22, int(W * 0.56), ground_y - 6], radius=6, fill=(241, 245, 249, 255), outline=(56, 189, 248, 200), width=3)

# Open Fuel Door on Right Rear Quarter Panel
fuel_port_center = (int(W * 0.595), int(H * 0.605))
draw.ellipse([fuel_port_center[0] - 28, fuel_port_center[1] - 28, fuel_port_center[0] + 28, fuel_port_center[1] + 28], fill=(8, 47, 73, 255), outline=(56, 189, 248, 255), width=6)


# --- 4. Silhouette of Person Seen From Behind ---
# Pants / Legs
draw.rounded_rectangle([int(W * 0.635), int(H * 0.67), int(W * 0.685), ground_y], radius=14, fill=(15, 23, 42, 255), outline=(148, 163, 184, 200), width=4)
draw.rounded_rectangle([int(W * 0.705), int(H * 0.67), int(W * 0.755), ground_y], radius=14, fill=(15, 23, 42, 255), outline=(148, 163, 184, 200), width=4)

# Torso / Jacket (Seen from back) - Bright royal electric blue jacket for high contrast
torso = [
    (int(W * 0.625), int(H * 0.515)), # Left shoulder
    (int(W * 0.765), int(H * 0.515)), # Right shoulder
    (int(W * 0.755), int(H * 0.68)),  # Right hip
    (int(W * 0.635), int(H * 0.68)),  # Left hip
]
draw.polygon(torso, fill=(37, 99, 235, 255), outline=(191, 219, 254, 240))
# Center seam / jacket fold highlight
draw.line([(int(W * 0.695), int(H * 0.53)), (int(W * 0.695), int(H * 0.67))], fill=(96, 165, 250, 220), width=5)

# Head / Hair (Back of head silhouette)
head_center = (int(W * 0.695), int(H * 0.455))
draw.ellipse([head_center[0] - 56, head_center[1] - 66, head_center[0] + 56, head_center[1] + 56], fill=(15, 23, 42, 255), outline=(191, 219, 254, 200), width=4)

# Arm extending to car fuel door holding nozzle
draw.line([(int(W * 0.645), int(H * 0.55)), (fuel_port_center[0] + 40, fuel_port_center[1] + 20)], fill=(37, 99, 235, 255), width=34)
draw.line([(int(W * 0.645), int(H * 0.55)), (fuel_port_center[0] + 40, fuel_port_center[1] + 20)], fill=(147, 197, 253, 255), width=8)

# Fuel Nozzle / Handle
nozzle_tip = (fuel_port_center[0] + 4, fuel_port_center[1])
nozzle_handle = (fuel_port_center[0] + 56, fuel_port_center[1] + 30)
draw.line([nozzle_handle, nozzle_tip], fill=(15, 23, 42, 255), width=22)
draw.line([nozzle_handle, nozzle_tip], fill=(248, 250, 252, 255), width=10)

# Fuel Hose curving from pump dispenser down and looping up to nozzle handle
# Bezier-like curve with glowing electric cyan hose
p_start = (int(W * 0.77), int(H * 0.57))
p_ctrl = (int(W * 0.73), int(H * 0.79))
p_end = nozzle_handle
hose_pts = []
for i in range(50):
    t = i / 49.0
    hx = (1 - t)**2 * p_start[0] + 2 * (1 - t) * t * p_ctrl[0] + t**2 * p_end[0]
    hy = (1 - t)**2 * p_start[1] + 2 * (1 - t) * t * p_ctrl[1] + t**2 * p_end[1]
    hose_pts.append((hx, hy))

for i in range(len(hose_pts) - 1):
    draw.line([hose_pts[i], hose_pts[i + 1]], fill=(15, 23, 42, 255), width=20)
    draw.line([hose_pts[i], hose_pts[i + 1]], fill=(56, 189, 248, 255), width=8)

# Downsample to 1024x1024 with antialiasing
out1024 = img.resize((1024, 1024), Image.Resampling.LANCZOS)
os.makedirs('fuel_records/assets', exist_ok=True)
out1024.save('fuel_records/assets/app_icon_1024.png')
print('Generated bright high-contrast app_icon_1024.png successfully!')
