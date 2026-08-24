"""
Generate WOLOW Lite app icons into the IconKitchen/ output folder.

Produces the exact structure IconKitchen (icon.kitchen) would generate:
  android/play_store_512.png
  android/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher{,_background,_foreground,_monochrome}.png
  android/res/mipmap-anydpi-v26/ic_launcher.xml          (adaptive-icon definition)
  ios/AppIcon-*.png                                       (AppIcon set + Contents.json)
  web/apple-touch-icon.png, favicon.ico, icon-192{, -maskable}.png, icon-512{, -maskable}.png

Uses the same logo rendering as generate_logo.py so the icons match what is
already deployed on Android/iOS. Requires Pillow.
"""
import math
import os
import sys

from PIL import Image, ImageDraw

sys.path.insert(0, os.path.dirname(__file__))
from generate_logo import create_logo, BG_DARK, BG_BLACK, BLUE, SEPARATOR

# IconKitchen output root
OUTPUT_DIR = os.path.normpath(
    os.path.join(os.path.dirname(__file__), "..", "IconKitchen")
)

# Android mipmap densities -> pixel size
ANDROID_DENSITIES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# iOS AppIcon filenames (from IconKitchen ios/Contents.json) -> pixel size
IOS_ICONS = {
    "AppIcon@2x.png": 120,
    "AppIcon@3x.png": 180,
    "AppIcon~ipad.png": 76,
    "AppIcon@2x~ipad.png": 152,
    "AppIcon-83.5@2x~ipad.png": 167,
    "AppIcon-40@2x.png": 80,
    "AppIcon-40@3x.png": 120,
    "AppIcon-40~ipad.png": 40,
    "AppIcon-40@2x~ipad.png": 80,
    "AppIcon-20@2x.png": 40,
    "AppIcon-20@3x.png": 60,
    "AppIcon-20~ipad.png": 20,
    "AppIcon-20@2x~ipad.png": 40,
    "AppIcon-29.png": 29,
    "AppIcon-29@2x.png": 58,
    "AppIcon-29@3x.png": 87,
    "AppIcon-29~ipad.png": 29,
    "AppIcon-29@2x~ipad.png": 58,
    "AppIcon-60@2x~car.png": 120,
    "AppIcon-60@3x~car.png": 180,
    "AppIcon~ios-marketing.png": 1024,
}


def draw_content(size: int, color=BLUE, opacities=(0.7, 0.45, 0.2)) -> Image.Image:
    """Draw only the WOLOW logo content (power symbol + signal waves) on a
    transparent background. This is used for the Android adaptive-icon
    foreground and monochrome layers."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx, cy = size // 2, size // 2
    r = size // 2 - 2

    # Power symbol (circle arc with bottom gap + vertical line)
    power_r = int(r * 0.36)
    power_cy = cy - int(r * 0.06)
    line_top = power_cy - int(r * 0.38)
    line_bottom = power_cy - int(r * 0.08)
    stroke = max(2, size // 40)

    bbox = [cx - power_r, power_cy - power_r, cx + power_r, power_cy + power_r]
    draw.arc(bbox, start=220, end=320, fill=color + (255,), width=stroke)
    draw.line(
        [(cx, line_top), (cx, line_bottom)],
        fill=color + (255,),
        width=stroke,
    )

    # Signal waves (left + right, fading opacity)
    wave_cy = cy + int(r * 0.32)
    wave_base_r = int(r * 0.22)
    wave_spacing = int(r * 0.16)
    wave_width = max(2, int(size // 50))

    for side in [-1, 1]:
        for i, opacity in enumerate(opacities):
            wr = wave_base_r + i * wave_spacing
            if side == -1:
                start_a, end_a = math.radians(200), math.radians(250)
            else:
                start_a, end_a = math.radians(290), math.radians(340)

            points = []
            steps = 20
            for s in range(steps + 1):
                t = s / steps
                angle = start_a + t * (end_a - start_a)
                px = cx + int(wr * math.cos(angle))
                py = wave_cy + int(wr * 0.6 * math.sin(angle))
                points.append((px, py))

            fill = (
                int(color[0] * opacity),
                int(color[1] * opacity),
                int(color[2] * opacity),
                255,
            )
            if len(points) >= 2:
                draw.line(points, fill=fill, width=wave_width, joint="curve")

    return img


def create_foreground(size: int, scale: float = 0.85) -> Image.Image:
    """Adaptive-icon foreground: logo content scaled into the safe zone
    (central ~61% of the adaptive canvas) on a transparent background."""
    base = draw_content(size)
    target = int(size * scale)
    scaled = base.resize((target, target), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(scaled, ((size - target) // 2, (size - target) // 2), scaled)
    return canvas


def create_monochrome(size: int, scale: float = 0.85) -> Image.Image:
    """Adaptive-icon monochrome layer: white logo content in the safe zone."""
    base = draw_content(size, color=(255, 255, 255), opacities=(1.0, 0.6, 0.3))
    target = int(size * scale)
    scaled = base.resize((target, target), Image.LANCZOS)
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    canvas.paste(scaled, ((size - target) // 2, (size - target) // 2), scaled)
    return canvas


def create_background(size: int) -> Image.Image:
    """Adaptive-icon background: solid dark color matching the logo."""
    return Image.new("RGBA", (size, size), BG_DARK + (255,))


def create_maskable(size: int, scale: float = 0.8) -> Image.Image:
    """Web maskable icon: solid dark background + full logo scaled to the
    maskable safe zone (central 80%)."""
    canvas = Image.new("RGBA", (size, size), BG_DARK + (255,))
    logo = create_logo(size)
    target = int(size * scale)
    scaled = logo.resize((target, target), Image.LANCZOS)
    canvas.paste(scaled, ((size - target) // 2, (size - target) // 2), scaled)
    return canvas


def save(img, path):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, "PNG")
    print(f"  {os.path.relpath(path, OUTPUT_DIR)} ({img.size[0]}x{img.size[1]})")


def main():
    print("Generating WOLOW Lite icons into IconKitchen/\n")

    # ---- Android ---------------------------------------------------------
    print("Android:")
    base_512 = create_logo(512)
    save(base_512, os.path.join(OUTPUT_DIR, "android", "play_store_512.png"))

    for folder, sz in ANDROID_DENSITIES.items():
        res_dir = os.path.join(OUTPUT_DIR, "android", "res", folder)
        save(create_logo(sz), os.path.join(res_dir, "ic_launcher.png"))
        save(create_background(sz), os.path.join(res_dir, "ic_launcher_background.png"))
        save(create_foreground(sz), os.path.join(res_dir, "ic_launcher_foreground.png"))
        save(create_monochrome(sz), os.path.join(res_dir, "ic_launcher_monochrome.png"))

    # ---- iOS -------------------------------------------------------------
    print("\niOS:")
    base_1024 = create_logo(1024)
    ios_dir = os.path.join(OUTPUT_DIR, "ios")
    for name, sz in IOS_ICONS.items():
        icon = base_1024.resize((sz, sz), Image.LANCZOS)
        save(icon, os.path.join(ios_dir, name))

    # ---- Web -------------------------------------------------------------
    print("\nWeb:")
    web_dir = os.path.join(OUTPUT_DIR, "web")
    save(base_512, os.path.join(web_dir, "icon-512.png"))
    save(base_512.resize((192, 192), Image.LANCZOS), os.path.join(web_dir, "icon-192.png"))
    save(create_maskable(512), os.path.join(web_dir, "icon-512-maskable.png"))
    save(create_maskable(192), os.path.join(web_dir, "icon-192-maskable.png"))
    save(base_512.resize((180, 180), Image.LANCZOS), os.path.join(web_dir, "apple-touch-icon.png"))

    # favicon.ico (multi-size)
    ico_path = os.path.join(web_dir, "favicon.ico")
    ico_img = create_logo(48)
    ico_img.save(ico_path, sizes=[(16, 16), (32, 32), (48, 48)])
    print(f"  web/favicon.ico (16/32/48)")

    print(f"\nDone! All icons written to: {OUTPUT_DIR}")
    print("Note: android/res/mipmap-anydpi-v26/ic_launcher.xml and ios/Contents.json already exist.")


if __name__ == "__main__":
    main()
