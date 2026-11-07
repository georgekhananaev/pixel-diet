#!/usr/bin/env python3
"""Build the PixelDiet app icon from its artwork: a 1024 x 1024 SVG or PNG with a transparent background.

Writes, relative to the repository root (or to --out for previews):
  PixelDiet/AppIcon.icon/                              Icon Composer icon: the artwork as a flat layer
                                                       on a navy gradient (macOS 26+; Xcode derives the
                                                       macOS 14/15 icon from it)
  PixelDiet/Assets.xcassets/AppIconClean.imageset/icon_clean.png
                                                       full-bleed copy for the window toolbar

Requires Pillow, and rsvg-convert (brew install librsvg) for SVG artwork:
  python3 scripts/generate_app_icon.py docs/media/logo-agy04-noborder.png [--out DIR]
The current artwork is also kept as PixelDiet/AppIcon.icon/Assets/artwork.png, which works as input too.
"""

import argparse
import io
import json
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image, ImageDraw

SIZE = 1024
# The plate the artwork was drawn on: lighter at the top, darker at the bottom
TOP, BOTTOM = (30, 45, 71), (13, 20, 35)


def srgb(color):
    return "srgb:" + ",".join(f"{c / 255:.5f}" for c in color) + ",1.00000"


def icon_json(layer):
    fill = {
        "linear-gradient": [srgb(TOP), srgb(BOTTOM)],
        "orientation": {"start": {"x": 0.5, "y": 0}, "stop": {"x": 0.5, "y": 1}},
    }
    return {
        # Dark icons keep the plate too; macOS would otherwise replace it with gray
        "fill-specializations": [{"value": fill}, {"appearance": "dark", "value": fill}],
        # The artwork has its own lighting; Liquid Glass on top of it would add a second highlight
        "groups": [{"layers": [{"image-name": layer, "name": "artwork", "glass": False}]}],
        "supported-platforms": {"squares": ["macOS"]},
    }


def raster(artwork, data):
    """The artwork (its path and bytes) as a SIZE x SIZE RGBA image."""
    if artwork.suffix.lower() == ".svg":
        if not shutil.which("rsvg-convert"):
            sys.exit("rsvg-convert not found: brew install librsvg")
        data = subprocess.run(["rsvg-convert", "-w", str(SIZE), "-h", str(SIZE)],
                              input=data, check=True, capture_output=True).stdout
    image = Image.open(io.BytesIO(data))
    if image.size != (SIZE, SIZE) or image.mode != "RGBA":
        sys.exit(f"{artwork}: expected {SIZE} x {SIZE} with transparency, got {image.size[0]} x {image.size[1]} {image.mode}")
    return image


def flattened(artwork, size):
    """Full-bleed rounded icon (gradient + artwork), as used in the toolbar."""
    gradient = Image.linear_gradient("L").resize((SIZE, SIZE))
    image = Image.composite(Image.new("RGBA", (SIZE, SIZE), (*BOTTOM, 255)),
                            Image.new("RGBA", (SIZE, SIZE), (*TOP, 255)), gradient)
    image.alpha_composite(artwork)
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, SIZE - 1, SIZE - 1], radius=round(SIZE * 0.2237), fill=255)
    image.putalpha(mask)
    return image.resize((size, size), Image.Resampling.LANCZOS)


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("artwork", type=Path, help=f"{SIZE} x {SIZE} SVG or PNG with a transparent background")
    parser.add_argument("--out", type=Path, default=Path(__file__).resolve().parent.parent,
                        help="root to write into (default: the repository)")
    args = parser.parse_args()

    data = args.artwork.read_bytes()  # read up front: the artwork may be the layer this run replaces
    image = raster(args.artwork, data)
    layer = "artwork" + args.artwork.suffix.lower()

    icon_dir = args.out / "PixelDiet" / "AppIcon.icon"
    shutil.rmtree(icon_dir / "Assets", ignore_errors=True)  # drop layers of earlier artwork
    (icon_dir / "Assets").mkdir(parents=True)
    (icon_dir / "Assets" / layer).write_bytes(data)
    (icon_dir / "icon.json").write_text(json.dumps(icon_json(layer), indent=2) + "\n")

    clean_dir = args.out / "PixelDiet" / "Assets.xcassets" / "AppIconClean.imageset"
    clean_dir.mkdir(parents=True, exist_ok=True)
    flattened(image, 256).save(clean_dir / "icon_clean.png")
    print(f"Wrote {icon_dir} and {clean_dir / 'icon_clean.png'}")


if __name__ == "__main__":
    main()
