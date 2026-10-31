"""Draws the steam engine driving wheel: brass tyre, black spoked disc, brass hub.

Written to ForestRail/assets/art_v3/vehicles/steam_wheel.png (square, wheel
centred). Style follows the artist's sheet tools/art_sources/steam_sheet_v2.webp.
"""
import math
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "ForestRail/assets/art_v3/vehicles/steam_wheel.png"
N = 512
SS = 4
C = N * SS / 2

BRASS_D = (112, 82, 32)
BRASS = (196, 156, 76)
BRASS_L = (244, 216, 146)
IRON_D = (14, 18, 20)
IRON = (34, 40, 44)
IRON_L = (78, 88, 92)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


img = Image.new("RGBA", (N * SS, N * SS), (0, 0, 0, 0))


def disc(r, color_fn):
    """Fill a disc of radius r (0..1 of the wheel) with colour_fn(x, y) in -1..1."""
    global img
    size = N * SS
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse([C - r * C, C - r * C, C + r * C, C + r * C], fill=255)
    layer = Image.new("RGBA", (size, size))
    px = layer.load()
    step = 4
    for y in range(0, size, step):
        for x in range(0, size, step):
            col = color_fn((x - C) / C, (y - C) / C)
            for dy in range(step):
                for dx in range(step):
                    if x + dx < size and y + dy < size:
                        px[x + dx, y + dy] = col + (255,)
    layer.putalpha(mask)
    img = Image.alpha_composite(img, layer)


def brass_light(x, y):
    # warm light from the upper left
    t = 0.5 + 0.5 * (-x - y) / 1.4
    return lerp(BRASS_D, BRASS_L, max(0.0, min(1.0, t)))


# tyre, then the iron disc inside it, then a thin dark inner ring
disc(1.0, lambda x, y: IRON_D)
disc(0.97, brass_light)
disc(0.84, lambda x, y: lerp(BRASS_D, BRASS, 0.5))
disc(0.80, lambda x, y: IRON_D)
disc(0.77, lambda x, y: lerp(IRON, IRON_L, max(0.0, min(1.0, 0.5 + 0.3 * (-x - y)))))
disc(0.70, lambda x, y: lerp(IRON_D, IRON, max(0.0, min(1.0, 0.5 + 0.3 * (-x - y)))))

# spokes
d = ImageDraw.Draw(img)
spokes = 14
for i in range(spokes):
    a = 2 * math.pi * i / spokes + 0.12
    x0, y0 = C + math.cos(a) * 0.20 * C, C + math.sin(a) * 0.20 * C
    x1, y1 = C + math.cos(a) * 0.72 * C, C + math.sin(a) * 0.72 * C
    d.line([(x0, y0), (x1, y1)], fill=IRON_D + (255,), width=int(0.075 * C))
    d.line([(x0 - 2, y0 - 2), (x1 - 2, y1 - 2)], fill=IRON_L + (255,), width=int(0.032 * C))

# hub
disc(0.24, lambda x, y: IRON_D)
disc(0.22, brass_light)
disc(0.13, lambda x, y: lerp(BRASS_D, BRASS, 0.4))
disc(0.07, lambda x, y: IRON_D)

img = img.resize((N, N), Image.LANCZOS)
OUT.parent.mkdir(parents=True, exist_ok=True)
img.save(OUT)
print("saved", OUT, img.size)
