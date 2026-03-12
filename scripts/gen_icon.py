#!/usr/bin/env python3
"""Generate Monocle Radio icons from official Monocle M monogram.
Creates macOS .icns app icon and menu bar template icons."""

from PIL import Image
import subprocess
import os

SRC = os.path.join(os.path.dirname(__file__), "..", "build", "icon", "source.png")
OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "build", "icon")
RESOURCES_DIR = os.path.join(os.path.dirname(__file__), "..", "MonocleRadio", "Resources")
os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(RESOURCES_DIR, exist_ok=True)


def make_menubar_icon(src_img, size):
    """Create a template icon for the menu bar (black on transparent).
    macOS template images: black pixels become white in dark mode automatically."""
    img = src_img.resize((size, size), Image.LANCZOS)
    # Convert to RGBA, make white pixels transparent, keep black
    pixels = img.load()
    for y in range(size):
        for x in range(size):
            r, g, b, a = pixels[x, y]
            # Brightness threshold — dark pixels become black, light become transparent
            brightness = (r + g + b) / 3
            if brightness > 128:
                pixels[x, y] = (0, 0, 0, 0)       # transparent
            else:
                pixels[x, y] = (0, 0, 0, a)        # black, keep alpha
    return img


def create_iconset(src_img):
    """Generate .iconset folder with all required sizes, then convert to .icns."""
    iconset_dir = os.path.join(OUT_DIR, "AppIcon.iconset")
    os.makedirs(iconset_dir, exist_ok=True)

    # Required sizes for macOS .icns
    sizes = [
        (16, 1), (16, 2),
        (32, 1), (32, 2),
        (128, 1), (128, 2),
        (256, 1), (256, 2),
        (512, 1), (512, 2),
    ]

    total = len(sizes) + 2  # +2 for menubar icons
    for i, (size, scale) in enumerate(sizes):
        px = size * scale
        img = src_img.resize((px, px), Image.LANCZOS)
        suffix = f"_{size}x{size}" + ("@2x" if scale == 2 else "")
        path = os.path.join(iconset_dir, f"icon{suffix}.png")
        img.save(path)
        pct = int((i + 1) / total * 100)
        bar = "█" * (pct // 2) + "░" * (50 - pct // 2)
        print(f"[{bar}] {pct}% icon{suffix}.png ({px}x{px})")

    # Convert to .icns
    icns_path = os.path.join(OUT_DIR, "AppIcon.icns")
    subprocess.run(
        ["iconutil", "-c", "icns", iconset_dir, "-o", icns_path],
        check=True
    )
    print(f"\n✓ {icns_path}")

    # Menu bar template icons (18pt @ 1x and 2x)
    for scale in [1, 2]:
        px = 18 * scale
        img = make_menubar_icon(src_img, px)
        name = f"MenuBarIcon{'@2x' if scale == 2 else ''}.png"
        # Save to build dir
        path = os.path.join(OUT_DIR, name)
        img.save(path)
        # Also copy to Resources for SPM bundling
        res_path = os.path.join(RESOURCES_DIR, name)
        img.save(res_path)
        print(f"✓ {name} ({px}x{px})")


if __name__ == "__main__":
    if not os.path.exists(SRC):
        print(f"Source image not found at {SRC}")
        print("Download it first: curl -o build/icon/source.png <url>")
        exit(1)

    src = Image.open(SRC).convert("RGBA")
    create_iconset(src)
    print("\nDone! Icons generated and copied to MonocleRadio/Resources/")
