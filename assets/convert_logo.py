"""
Convert WOLOW Lite SVG logo to PNG at various sizes for Android and iOS.
Requires: pip install cairosvg
"""
import os
import cairosvg

SVG_PATH = os.path.join(os.path.dirname(__file__), "logo-icon.svg")
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "output", "icons")

# Android adaptive icon sizes (foreground layer)
ANDROID_SIZES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# iOS icon sizes
IOS_SIZES = {
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

# Web icons
WEB_SIZES = {
    "Icon-192.png": 192,
    "Icon-512.png": 512,
    "Icon-maskable-192.png": 192,
    "Icon-maskable-512.png": 512,
    "favicon.png": 32,
}


def convert_svg_to_png(svg_path, output_path, size):
    """Convert SVG to PNG at specified size."""
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    cairosvg.svg2png(
        url=svg_path,
        write_to=output_path,
        output_width=size,
        output_height=size,
    )
    print(f"  Created: {output_path} ({size}x{size})")


def main():
    if not os.path.exists(SVG_PATH):
        print(f"Error: SVG not found at {SVG_PATH}")
        return

    print("Converting WOLOW Lite logo SVG to PNG...\n")

    # Android icons
    print("Android icons:")
    android_dir = os.path.join(OUTPUT_DIR, "android")
    for folder, size in ANDROID_SIZES.items():
        out = os.path.join(android_dir, folder, "ic_launcher.png")
        convert_svg_to_png(SVG_PATH, out, size)

    # iOS icons
    print("\niOS icons:")
    ios_dir = os.path.join(OUTPUT_DIR, "ios")
    for filename, size in IOS_SIZES.items():
        out = os.path.join(ios_dir, filename)
        convert_svg_to_png(SVG_PATH, out, size)

    # Web icons
    print("\nWeb icons:")
    web_dir = os.path.join(OUTPUT_DIR, "web")
    for filename, size in WEB_SIZES.items():
        out = os.path.join(web_dir, filename)
        convert_svg_to_png(SVG_PATH, out, size)

    print(f"\nDone! Icons saved to: {OUTPUT_DIR}")
    print("\nNext steps:")
    print("  1. Android: Copy mipmap-* folders to android/app/src/main/res/")
    print("  2. iOS: Copy Icon-App-*.png files to ios/Runner/Assets.xcassets/AppIcon.appiconset/")
    print("  3. Web: Copy web icons to web/icons/")


if __name__ == "__main__":
    main()
