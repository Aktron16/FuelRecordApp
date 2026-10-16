from PIL import Image
import json
import os

master = Image.open('fuel_records/assets/app_icon_1024.png')

# 1. Android Mipmap icons
android_sizes = {
    'fuel_records/android/app/src/main/res/mipmap-mdpi/ic_launcher.png': (48, 48),
    'fuel_records/android/app/src/main/res/mipmap-hdpi/ic_launcher.png': (72, 72),
    'fuel_records/android/app/src/main/res/mipmap-xhdpi/ic_launcher.png': (96, 96),
    'fuel_records/android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png': (144, 144),
    'fuel_records/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png': (192, 192),
}

for path, size in android_sizes.items():
    os.makedirs(os.path.dirname(path), exist_ok=True)
    resized = master.resize(size, Image.Resampling.LANCZOS)
    resized.save(path)
    print(f'Saved {path} ({size[0]}x{size[1]})')

# 2. iOS AppIcon icons
ios_dir = 'fuel_records/ios/Runner/Assets.xcassets/AppIcon.appiconset'
with open(os.path.join(ios_dir, 'Contents.json'), 'r') as f:
    contents = json.load(f)

for item in contents.get('images', []):
    filename = item['filename']
    size_str = item['size'] # e.g. '20x20' or '83.5x83.5'
    scale_str = item['scale'] # e.g. '1x', '2x', '3x'
    base_w, base_h = [float(x) for x in size_str.split('x')]
    scale = float(scale_str.replace('x', ''))
    target_w = int(round(base_w * scale))
    target_h = int(round(base_h * scale))

    out_path = os.path.join(ios_dir, filename)
    resized = master.resize((target_w, target_h), Image.Resampling.LANCZOS)
    resized.save(out_path)
    print(f'Saved {out_path} ({target_w}x{target_h})')

# 3. Web & Mac Icons if present
web_icon_192 = 'fuel_records/web/icons/Icon-192.png'
web_icon_512 = 'fuel_records/web/icons/Icon-512.png'
if os.path.exists(os.path.dirname(web_icon_192)):
    master.resize((192, 192), Image.Resampling.LANCZOS).save(web_icon_192)
    master.resize((512, 512), Image.Resampling.LANCZOS).save(web_icon_512)
    print('Updated web icons')

print('All platform launcher icons updated successfully!')
