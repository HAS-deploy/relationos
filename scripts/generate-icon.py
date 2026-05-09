#!/usr/bin/env python3
"""
Generate the production RelationOS app icon as a 1024x1024 RGB PNG (no
alpha — App Store rejects RGBA submissions for the marketing icon).

Design (locked, no text per Apple policy):
    - Background: deep teal (#0F8B6E) flat fill.
    - Glyph: two interlocking circles ("Venn") in white, slightly off-center,
      with the overlap region rendered in a darker teal so the intersection
      reads as a third shape — a visual stand-in for "private network".
    - Soft rounded corner mask is left to iOS's icon clipping; we render a
      square. Apple applies the rounded-corner shape automatically.

Run from the repo root:
    python3 scripts/generate-icon.py

Writes:
    RelationOS/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png
"""

from __future__ import annotations
import os
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "RelationOS" / "Resources" / "Assets.xcassets" / "AppIcon.appiconset" / "AppIcon-1024.png"

SIZE = 1024
BG       = (15, 139, 110)       # deep teal #0F8B6E
WHITE    = (255, 255, 255)
INTERSECT = (8, 89, 71)         # darker teal for the overlap region

# Two circles overlapping at the center. Radii sized so the intersection
# (lens shape) is visually significant but not overwhelming.
RADIUS = 280
OFFSET = 175  # half the horizontal distance between the two circle centers
CY = SIZE // 2
CX_LEFT = SIZE // 2 - OFFSET
CX_RIGHT = SIZE // 2 + OFFSET


def render() -> Image.Image:
    # Base canvas in solid RGB (no alpha for the App Store icon).
    img = Image.new("RGB", (SIZE, SIZE), BG)

    # Pass 1: render each circle to an alpha mask, paste white where masks
    # are set. We supersample 2x to get clean edges then downsample.
    SS = 2
    big = Image.new("RGB", (SIZE * SS, SIZE * SS), BG)
    draw = ImageDraw.Draw(big)

    def circle(cx, cy, r, fill):
        draw.ellipse(
            [(cx - r) * SS, (cy - r) * SS, (cx + r) * SS, (cy + r) * SS],
            fill=fill,
        )

    # Two white circles, then darker-teal lens for the intersection.
    circle(CX_LEFT, CY, RADIUS, WHITE)
    circle(CX_RIGHT, CY, RADIUS, WHITE)

    # Compute intersection by rendering an ellipse mask and copying onto
    # the supersampled canvas. The intersection of two equal circles is the
    # set of pixels inside BOTH — easier to draw as: render circle A as
    # mask, render circle B as mask, AND them, fill on the canvas with the
    # darker-teal color.
    mask_a = Image.new("L", (SIZE * SS, SIZE * SS), 0)
    mask_b = Image.new("L", (SIZE * SS, SIZE * SS), 0)
    da = ImageDraw.Draw(mask_a)
    db = ImageDraw.Draw(mask_b)
    da.ellipse(
        [(CX_LEFT - RADIUS) * SS, (CY - RADIUS) * SS,
         (CX_LEFT + RADIUS) * SS, (CY + RADIUS) * SS],
        fill=255,
    )
    db.ellipse(
        [(CX_RIGHT - RADIUS) * SS, (CY - RADIUS) * SS,
         (CX_RIGHT + RADIUS) * SS, (CY + RADIUS) * SS],
        fill=255,
    )
    intersection = Image.new("L", (SIZE * SS, SIZE * SS), 0)
    intersection.paste(
        Image.eval(mask_a, lambda v: 255 if v == 255 else 0),
        (0, 0),
        mask=mask_b,
    )

    overlay = Image.new("RGB", (SIZE * SS, SIZE * SS), INTERSECT)
    big.paste(overlay, (0, 0), mask=intersection)

    # Downsample for clean antialiasing.
    img = big.resize((SIZE, SIZE), Image.LANCZOS)
    return img


def main() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img = render()
    # Save without alpha. PIL writes RGB PNG by default for an RGB image.
    img.save(OUT, format="PNG", optimize=True)
    print(f"wrote {OUT} ({OUT.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
