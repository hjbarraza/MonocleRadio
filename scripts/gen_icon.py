#!/usr/bin/env python3
"""Generate Monocle Radio icons from the source SVG.
Produces the macOS .icns app icon and template PNGs for the menu bar.

Requires rsvg-convert (brew install librsvg) and iconutil (Xcode CLT)."""

import os
import shutil
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "assets", "monocle-logo.svg")
OUT_DIR = os.path.join(ROOT, "build", "icon")
RESOURCES_DIR = os.path.join(ROOT, "MonocleRadio", "Resources")


def render_svg(svg: str, px: int, out_path: str) -> None:
    """Render an SVG string to a square PNG at the given pixel size."""
    subprocess.run(
        ["rsvg-convert", "-w", str(px), "-h", str(px), "-o", out_path],
        input=svg.encode("utf-8"),
        check=True,
    )


def template_variant(svg: str) -> str:
    """Strip the black background and recolor the mark black on transparent,
    so macOS can treat it as a template image (auto-inverts in dark menu bars)."""
    out = svg.replace('<rect width="512" height="512" fill="#000"/>', "")
    return out.replace('fill="#fff"', 'fill="#000"')


def main() -> None:
    if not os.path.exists(SRC):
        sys.exit(f"Source SVG not found at {SRC}")

    os.makedirs(OUT_DIR, exist_ok=True)
    os.makedirs(RESOURCES_DIR, exist_ok=True)

    with open(SRC, "r", encoding="utf-8") as f:
        svg_full = f.read()
    svg_template = template_variant(svg_full)

    # App icon: render full SVG at every size macOS expects, then pack into .icns.
    iconset = os.path.join(OUT_DIR, "AppIcon.iconset")
    os.makedirs(iconset, exist_ok=True)
    sizes = [(16, 1), (16, 2), (32, 1), (32, 2),
             (128, 1), (128, 2), (256, 1), (256, 2),
             (512, 1), (512, 2)]
    for size, scale in sizes:
        px = size * scale
        suffix = f"_{size}x{size}" + ("@2x" if scale == 2 else "")
        out = os.path.join(iconset, f"icon{suffix}.png")
        render_svg(svg_full, px, out)
        print(f"✓ icon{suffix}.png ({px}x{px})")

    icns = os.path.join(OUT_DIR, "AppIcon.icns")
    subprocess.run(["iconutil", "-c", "icns", iconset, "-o", icns], check=True)
    print(f"✓ {icns}")

    # Menu bar: 1x/2x/3x PNGs. SwiftUI's Image(nsImage:) doesn't reliably preserve
    # PDF vector data through the MenuBarExtra pipeline, so we bundle the rasters
    # macOS would pick from an asset catalog and assemble them into a multi-rep
    # NSImage in Swift. Base 18pt × scale.
    for scale in (1, 2, 3):
        px = 18 * scale
        name = f"MenuBarIcon{'' if scale == 1 else f'@{scale}x'}.png"
        out = os.path.join(OUT_DIR, name)
        render_svg(svg_template, px, out)
        shutil.copy(out, os.path.join(RESOURCES_DIR, name))
        print(f"✓ {name} ({px}x{px})")


if __name__ == "__main__":
    main()
