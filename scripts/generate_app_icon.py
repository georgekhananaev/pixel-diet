#!/usr/bin/env python3
"""Generate the PixelDiet app icon: a mosaic of pixels that slim down from the top left to the bottom right.

Writes, relative to the repository root (or to --out for previews):
  PixelDiet/AppIcon.icon/                              Icon Composer icon (macOS 26+; Xcode derives
                                                       the macOS 14/15 icon from it)
  PixelDiet/Assets.xcassets/AppIconClean.imageset/icon_clean.png
                                                       full-bleed copy for the window toolbar

Requires Pillow and NumPy (the committed icon was made with Pillow 11.3.0 and NumPy 2.3.1):
  python3 scripts/generate_app_icon.py [--out DIR]
"""

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

SIZE = 1024
BACKGROUND = (12, 16, 40)
GRID = 10  # pixels per row and column (large enough to stay visible at 32 px); the mosaic runs to the icon's edges
PITCH = SIZE / GRID
LARGEST, SMALLEST = 0.90, 0.24  # pixel size as a share of the pitch, top left and bottom right

PALETTE = [(0.00, (255, 60, 95)), (0.18, (255, 95, 75)), (0.36, (255, 150, 60)), (0.50, (255, 205, 60)),
           (0.64, (170, 220, 70)), (0.80, (70, 200, 130)), (1.00, (45, 160, 215))]


def lerp_color(stops, t):
    t = min(max(t, 0.0), 1.0)
    for (t0, c0), (t1, c1) in zip(stops, stops[1:]):
        if t0 <= t <= t1:
            f = (t - t0) / (t1 - t0)
            return tuple(round(a + (b - a) * f) for a, b in zip(c0, c1))
    return stops[-1][1]


def mosaic():
    """The Icon Composer layer: rounded pixels on a transparent canvas, shrinking along the diagonal."""
    image = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    rng = np.random.default_rng(21)
    for row in range(GRID):
        for col in range(GRID):
            t = (row + col) / (2 * (GRID - 1))  # 0 at the top left, 1 at the bottom right
            side = PITCH * (LARGEST - (LARGEST - SMALLEST) * t ** 1.25)
            shade = 1 + rng.uniform(-0.04, 0.04)  # slight variation, like real pixels
            color = tuple(min(255, round(c * shade)) for c in lerp_color(PALETTE, t))
            cx, cy = (col + 0.5) * PITCH, (row + 0.5) * PITCH
            draw.rounded_rectangle([cx - side / 2, cy - side / 2, cx + side / 2, cy + side / 2],
                                   radius=side * 0.24, fill=(*color, 255))
    return image


def flattened(layer, size):
    """Full-bleed rounded icon (background + layer), as used in the toolbar."""
    image = Image.new("RGBA", (SIZE, SIZE), (*BACKGROUND, 255))
    image.alpha_composite(layer)
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, SIZE - 1, SIZE - 1], radius=round(SIZE * 0.2237), fill=255)
    image.putalpha(mask)
    return image.resize((size, size), Image.Resampling.LANCZOS)


def icon_json():
    r, g, b = (c / 255 for c in BACKGROUND)
    return {
        "fill": {"automatic-gradient": f"srgb:{r:.5f},{g:.5f},{b:.5f},1.00000"},
        # Flat pixels: Liquid Glass on every small square reads as beads
        "groups": [{"layers": [{"image-name": "pixels.png", "name": "pixels", "glass": False}]}],
        "supported-platforms": {"squares": ["macOS"]},
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=Path(__file__).resolve().parent.parent,
                        help="root to write into (default: the repository)")
    root = parser.parse_args().out

    layer = mosaic()
    icon_dir = root / "PixelDiet" / "AppIcon.icon"
    (icon_dir / "Assets").mkdir(parents=True, exist_ok=True)
    layer.save(icon_dir / "Assets" / "pixels.png")
    (icon_dir / "icon.json").write_text(json.dumps(icon_json(), indent=2) + "\n")

    clean_dir = root / "PixelDiet" / "Assets.xcassets" / "AppIconClean.imageset"
    clean_dir.mkdir(parents=True, exist_ok=True)
    flattened(layer, 256).save(clean_dir / "icon_clean.png")
    print(f"Wrote {icon_dir} and {clean_dir / 'icon_clean.png'}")


if __name__ == "__main__":
    main()
