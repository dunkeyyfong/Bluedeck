#!/usr/bin/env python3
"""Draws the Bluedeck app icon (deck of cards + Bluetooth rune) into App/Resources."""
import os
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "App", "Resources")
S = 1024  # drawn large, then downscaled


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def draw():
    img = Image.new("RGB", (S, S))
    top, bottom = (40, 120, 255), (10, 30, 110)
    px = img.load()
    for y in range(S):
        c = lerp(top, bottom, y / (S - 1))
        for x in range(S):
            px[x, y] = c
    d = ImageDraw.Draw(img, "RGBA")
    # three stacked cards
    for i, a in enumerate((60, 110, 255)):
        o = (2 - i) * 46
        d.rounded_rectangle((262 + o, 230 - o, 762 + o, 830 - o), radius=70,
                            fill=(255, 255, 255, a))
    # Bluetooth rune on the front card
    cx, cy, h, w = 512 + 0, 530, 230, 115
    blue = (30, 100, 240, 255)
    pts = [(cx - w, cy - h / 2), (cx + w, cy + h / 2), (cx, cy + h), (cx, cy - h),
           (cx + w, cy - h / 2), (cx - w, cy + h / 2)]
    d.line(pts, fill=blue, width=52, joint="curve")
    return img


def main():
    img = draw()
    for size, name in ((120, "AppIcon60x60@2x.png"), (180, "AppIcon60x60@3x.png")):
        img.resize((size, size), Image.LANCZOS).save(os.path.join(OUT, name))
    print("icons written to", OUT)


if __name__ == "__main__":
    main()
