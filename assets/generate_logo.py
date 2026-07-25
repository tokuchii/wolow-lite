"""
Generate WOLOW Lite app icons using Pillow.
Creates icons for Android, iOS, and Web.
"""
import os
import math
from PIL import Image, ImageDraw, ImageFont

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "output", "icons")

# Colors
BG_DARK = (28, 28, 30)       # #1C1C1E
BG_BLACK = (0, 0, 0)         # #000000
BLUE = (10, 132, 255)        # #0A84FF
BLUE_DARK = (0, 112, 224)    # #0070E0
LABEL = (229, 229, 229)      # #E5E5E5
SEPARATOR = (56, 56, 58)     # #38383A


def create_logo(size, include_text=False):
    """Create a WOLOW logo at the specified size."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    cx, cy = size // 2, size // 2
    r = size // 2 - 2

    # Background circle with gradient effect
    for i in range(r, 0, -1):
        ratio = i / r
        cr = int(BG_BLACK[0] * (1 - ratio) + BG_DARK[0] * ratio)
        cg = int(BG_BLACK[1] * (1 - ratio) + BG_DARK[1] * ratio)
        cb = int(BG_BLACK[2] * (1 - ratio) + BG_DARK[2] * ratio)
        draw.ellipse(
            [cx - i, cy - i, cx + i, cy + i],
            fill=(cr, cg, cb, 255),
        )

    # Outer ring
    ring_r = int(r * 0.94)
    draw.ellipse(
        [cx - ring_r, cy - ring_r, cx + ring_r, cy + ring_r],
        outline=SEPARATOR + (255,),
        width=max(1, size // 512),
    )

    # Power button
    power_r = int(r * 0.36)  # radius of the power circle
    power_cy = cy - int(r * 0.06)  # slightly above center
    line_top = power_cy - int(r * 0.38)
    line_bottom = power_cy - int(r * 0.08)
    stroke = max(2, size // 40)

    # Power circle arc (from 220 to 320 degrees, i.e., bottom gap)
    bbox = [cx - power_r, power_cy - power_r, cx + power_r, power_cy + power_r]
    draw.arc(bbox, start=220, end=320, fill=BLUE + (255,), width=stroke)

    # Power line
    draw.line(
        [(cx, line_top), (cx, line_bottom)],
        fill=BLUE + (255,),
        width=stroke,
    )

    # Signal waves
    wave_cy = cy + int(r * 0.32)
    wave_base_r = int(r * 0.22)
    wave_spacing = int(r * 0.16)
    wave_width = max(2, int(size // 50))

    for side in [-1, 1]:  # left and right
        for i, opacity in enumerate([0.7, 0.45, 0.2]):
            wr = wave_base_r + i * wave_spacing

            # Calculate arc endpoints
            if side == -1:
                sa = math.radians(210 + i * 10)
                ea = math.radians(250 - i * 10)
            else:
                sa = math.radians(310 + i * 10)
                ea = math.radians(350 - i * 10)

            x1 = cx + side * int(wr * 0.3) + int(wr * math.cos(sa))
            y1 = wave_cy + int(wr * math.sin(sa))
            x2 = cx + side * int(wr * 0.3) + int(wr * math.cos(ea))
            y2 = wave_cy + int(wr * math.sin(ea))

            color = (
                int(BLUE[0] * opacity),
                int(BLUE[1] * opacity),
                int(BLUE[2] * opacity),
                255,
            )

            # Draw curved wave
            points = []
            steps = 20
            if side == -1:
                start_a, end_a = math.radians(200), math.radians(250)
            else:
                start_a, end_a = math.radians(290), math.radians(340)

            for s in range(steps + 1):
                t = s / steps
                angle = start_a + t * (end_a - start_a)
                px = cx + int(wr * math.cos(angle))
                py = wave_cy + int(wr * 0.6 * math.sin(angle))
                points.append((px, py))

            if len(points) >= 2:
                draw.line(points, fill=color, width=wave_width, joint="curve")

    return img


def save_icon(img, path):
    """Save icon to path, creating directories as needed."""
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, "PNG")
    print(f"  {path} ({img.size[0]}x{img.size[1]})")


def main():
    print("Generating WOLOW Lite icons...\n")

    # Generate base high-res logo
    base = create_logo(1024)

    # Android mipmap icons
    print("Android icons:")
    android_sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, sz in android_sizes.items():
        icon = base.resize((sz, sz), Image.LANCZOS)
        save_icon(icon, os.path.join(OUTPUT_DIR, "android", folder, "ic_launcher.png"))

    # iOS icons
    print("\niOS icons:")
    ios_sizes = {
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    for name, sz in ios_sizes.items():
        icon = base.resize((sz, sz), Image.LANCZOS)
        save_icon(icon, os.path.join(OUTPUT_DIR, "ios", name))

    # Web icons
    print("\nWeb icons:")
    web_sizes = {
        "Icon-192.png": 192,
        "Icon-512.png": 512,
        "Icon-maskable-192.png": 192,
        "Icon-maskable-512.png": 512,
        "favicon.png": 32,
    }
    for name, sz in web_sizes.items():
        icon = base.resize((sz, sz), Image.LANCZOS)
        save_icon(icon, os.path.join(OUTPUT_DIR, "web", name))

    # Also save the full-res logo for reference
    save_icon(base, os.path.join(OUTPUT_DIR, "logo-1024.png"))

    print(f"\nDone! All icons saved to: {OUTPUT_DIR}")
    print("\nTo apply the icons:")
    print("  Android: Copy mipmap-* folders to android/app/src/main/res/")
    print("  iOS: Copy Icon-App-*.png to ios/Runner/Assets.xcassets/AppIcon.appiconset/")
    print("  Web: Copy web icons to web/icons/")


if __name__ == "__main__":
    main()
