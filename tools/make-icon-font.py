#!/usr/bin/env python3
"""Trace an image into a one-glyph icon font for use in a terminal.

The glyph is every pixel that is opaque and not near-white, so white or
transparent areas become the background and any cut-outs. Fonts hold one
color: the terminal (or a herdr color rule) tints the glyph.

    pip install fonttools numpy pillow potracer
    python tools/make-icon-font.py icon.png MyIcon.ttf --family "My Icon" --codepoint F9001
"""
import argparse

import numpy as np
import potrace
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.cu2quPen import Cu2QuPen
from fontTools.pens.ttGlyphPen import TTGlyphPen
from PIL import Image, ImageDraw, ImageFont

UPM = 1000
ADVANCE = 600   # one terminal cell
SIZE = 640      # glyph box, slightly wider than the cell and centered on it
CENTER_Y = 300  # vertical center of the glyph, mid text line

parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
parser.add_argument("image", help="source image (PNG with a white or transparent background)")
parser.add_argument("output", help="font file to write, e.g. MyIcon.ttf")
parser.add_argument("--family", default="Icon Font", help="font family name shown to the OS")
parser.add_argument("--codepoint", default="F9000", help="private-use codepoint in hex (default F9000)")
parser.add_argument("--sharp", action="store_true", help="keep hard corners (for pixel art)")
parser.add_argument("--preview", help="also write a PNG rendering of the glyph")
parser.add_argument("--color", default="ffffff", help="preview tint as RRGGBB (default ffffff)")
args = parser.parse_args()
codepoint = int(args.codepoint, 16)

pixels = np.asarray(Image.open(args.image).convert("RGBA")).astype(float)
rgb, alpha = pixels[..., :3], pixels[..., 3]
mask = (alpha > 128) & (rgb.min(axis=2) < 215)
if not mask.any():
    parser.error("no shape found: the image is entirely white or transparent")

# Crop to the shape so it fills the glyph box.
ys, xs = np.where(mask)
mask = mask[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
h, w = mask.shape
scale = SIZE / max(h, w)

# potracer treats False pixels as the filled shape.
alphamax = 0.0 if args.sharp else 1.0
paths = potrace.Bitmap(~mask).trace(
    turdsize=20, alphamax=alphamax, opticurve=not args.sharp, opttolerance=0.4)

# Pixel space (y down) to font units (y up), centered in the advance width.
ox = (ADVANCE - w * scale) / 2
oy = CENTER_Y + h * scale / 2


def tx(p):
    return (ox + p.x * scale, oy - p.y * scale)


glyph_pen = TTGlyphPen(None)
pen = Cu2QuPen(glyph_pen, max_err=1.0)
for curve in paths:
    pen.moveTo(tx(curve.start_point))
    for seg in curve.segments:
        if seg.is_corner:
            pen.lineTo(tx(seg.c))
            pen.lineTo(tx(seg.end_point))
        else:
            pen.curveTo(tx(seg.c1), tx(seg.c2), tx(seg.end_point))
    pen.closePath()

fb = FontBuilder(UPM, isTTF=True)
fb.setupGlyphOrder([".notdef", "icon"])
fb.setupCharacterMap({codepoint: "icon"})
fb.setupGlyf({".notdef": TTGlyphPen(None).glyph(), "icon": glyph_pen.glyph()})
fb.setupHorizontalMetrics({".notdef": (ADVANCE, 0), "icon": (ADVANCE, 0)})
fb.setupHorizontalHeader(ascent=800, descent=-200)
fb.setupNameTable({"familyName": args.family, "styleName": "Regular"})
fb.setupOS2(sTypoAscender=800, sTypoDescender=-200, usWinAscent=800, usWinDescent=200)
fb.setupPost(isFixedPitch=1)
fb.font["OS/2"].panose.bProportion = 9  # monospaced, so terminals accept it
fb.save(args.output)
print(f"wrote {args.output} ({args.family}, U+{codepoint:04X})")

if args.preview:
    tint = tuple(int(args.color[i:i + 2], 16) for i in (0, 2, 4))
    img = Image.new("RGB", (320, 320), (30, 30, 46))
    draw = ImageDraw.Draw(img)
    draw.text((40, 30), chr(codepoint), font=ImageFont.truetype(args.output, 240), fill=tint)
    draw.text((250, 30), chr(codepoint), font=ImageFont.truetype(args.output, 36), fill=tint)
    img.save(args.preview)
    print(f"wrote {args.preview}")

escaped = "".join(f"\\x{b:02x}" for b in chr(codepoint).encode())
print("icons.conf line for an agent (replace AGENT with its id):")
print(f"  printf 'AGENT={escaped}\\n' >> \"$(herdr plugin config-dir blockedpath.agent-icons)/icons.conf\"")
