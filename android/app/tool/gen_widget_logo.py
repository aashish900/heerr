#!/usr/bin/env python3
"""Extracts the heerr "H + waveform" mark for the hero widget's idle state
from the real app icon (assets/icon.png) instead of a hand-drawn
approximation, so the widget matches the actual brand mark exactly.

assets/icon.png is the mark on an opaque black disc (on transparent
corners). The widget tile interior is itself near-black, so the disc would
double up as a visible circle; this script keys out near-black opaque
pixels back to transparent, keeping only the gradient mark, then crops
tightly to its bounding box. Run from android/app/:

    python3 tool/gen_widget_logo.py
"""
from pathlib import Path

from PIL import Image

SRC = Path(__file__).resolve().parent.parent / "assets/icon.png"
OUT = (
    Path(__file__).resolve().parent.parent
    / "android/app/src/main/res/drawable-nodpi/widget_logo_gradient.png"
)
BLACK_THRESHOLD = 24
PADDING_PX = 12


def main() -> None:
    im = Image.open(SRC).convert("RGBA")
    px = im.load()
    w, h = im.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            # Also zero out the disc's anti-aliased edge ring (near-black,
            # partially transparent), not just fully-opaque black.
            if r < BLACK_THRESHOLD and g < BLACK_THRESHOLD and b < BLACK_THRESHOLD:
                px[x, y] = (r, g, b, 0)

    bbox = im.getbbox()
    if bbox is None:
        raise SystemExit("no opaque pixels left after keying out the disc")
    left, top, right, bottom = bbox
    left = max(left - PADDING_PX, 0)
    top = max(top - PADDING_PX, 0)
    right = min(right + PADDING_PX, w)
    bottom = min(bottom + PADDING_PX, h)
    cropped = im.crop((left, top, right, bottom))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    cropped.save(OUT)
    print(f"wrote {OUT} ({cropped.size[0]}x{cropped.size[1]})")


if __name__ == "__main__":
    main()
