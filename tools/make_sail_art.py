"""Draws the sail car body (side elevation, no wheels, no mast and no sail: those are live).

A light plank deck on a steel frame, bow and stern beams with rings, a mast step with a brass
band at the front, a cleat and a coil of rope and a small bench at the stern. Same scale and axle
places as the handcar picture (810 px per metre, platform 2.4 m), so it fits the same slot.

Run:  python tools/make_sail_art.py
Writes ForestRail/assets/art_p2/sail_body.png and prints the numbers for object_dimensions.json.
"""
import random
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "ForestRail/assets/art_p2/sail_body.png"

PPM = 810.4        # pixels per metre
SS = 2
W, H = 2034, 800
RAIL_Y = 800       # pixel row of the rail
CENTER_X = 1017.0  # picture x of the platform centre (as in the handcar picture)

STEEL_D = (24, 30, 32)
STEEL = (58, 68, 70)
STEEL_L = (112, 126, 126)
OAK_D = (104, 70, 36)
OAK = (172, 122, 64)
OAK_L = (214, 164, 98)
PINE = (190, 150, 92)
BRASS_D = (116, 86, 36)
BRASS = (196, 156, 76)
BRASS_L = (244, 216, 146)
ROPE = (176, 142, 96)
ROPE_D = (110, 84, 52)

random.seed(5)
canvas = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))


def px(x, y):
    return (CENTER_X + x * PPM) * SS, (RAIL_Y - y * PPM) * SS


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def paint(mask_fn, top, bottom, edge=None, horizontal=False):
    global canvas
    mask = Image.new("L", canvas.size, 0)
    mask_fn(ImageDraw.Draw(mask))
    bbox = mask.getbbox()
    if not bbox:
        return
    x0, y0, x1, y1 = bbox
    layer = Image.new("RGBA", (x1 - x0, y1 - y0))
    d = ImageDraw.Draw(layer)
    steps = (x1 - x0) if horizontal else (y1 - y0)
    for i in range(steps):
        c = lerp(top, bottom, i / max(1, steps - 1)) + (255,)
        if horizontal:
            d.line([(i, 0), (i, y1 - y0)], fill=c)
        else:
            d.line([(0, i), (x1 - x0, i)], fill=c)
    full = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    full.paste(layer, (x0, y0))
    full.putalpha(ImageChops.multiply(full.getchannel("A"), mask))
    canvas = Image.alpha_composite(canvas, full)
    if edge:
        ring = ImageChops.subtract(mask.filter(ImageFilter.MaxFilter(3)), mask)
        e = Image.new("RGBA", canvas.size, edge + (255,))
        e.putalpha(ring)
        canvas = Image.alpha_composite(canvas, e)


def rect(x0, y0, x1, y1, top, bottom, radius=0.0, edge=STEEL_D, horizontal=False):
    a = px(x0, y1)
    b = px(x1, y0)
    r = radius * PPM * SS
    paint(lambda d: d.rounded_rectangle([a, b], radius=r, fill=255) if r > 0 else d.rectangle([a, b], fill=255), top, bottom, edge, horizontal)


def poly(points, top, bottom, edge=STEEL_D):
    pts = [px(*p) for p in points]
    paint(lambda d: d.polygon(pts, fill=255), top, bottom, edge)


def circle(cx, cy, r, top, bottom, edge=STEEL_D):
    c = px(cx, cy)
    rr = r * PPM * SS
    paint(lambda d: d.ellipse([c[0] - rr, c[1] - rr, c[0] + rr, c[1] + rr], fill=255), top, bottom, edge)


def line(p0, p1, color, width_m):
    ImageDraw.Draw(canvas).line([px(*p0), px(*p1)], fill=color + (255,), width=max(1, int(width_m * PPM * SS)))


def bolt(x, y, r=0.014):
    d = ImageDraw.Draw(canvas)
    cx, cy = px(x, y)
    rr = r * PPM * SS
    d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=BRASS_D + (255,))
    d.ellipse([cx - rr * 0.75, cy - rr * 0.75, cx + rr * 0.5, cy + rr * 0.5], fill=BRASS + (255,))
    d.ellipse([cx - rr * 0.5, cy - rr * 0.55, cx - rr * 0.05, cy - rr * 0.1], fill=BRASS_L + (255,))


DECK = 0.57
HALF = 1.2

# 1. steel frame: two beams, braces, axle boxes
rect(-HALF, 0.28, HALF, 0.40, STEEL, STEEL_D)
for x in (-0.95, -0.35, 0.35, 0.95):
    poly([(x - 0.05, 0.40), (x + 0.05, 0.40), (x + 0.24, 0.50), (x + 0.14, 0.50)], STEEL, STEEL_D)
    poly([(x + 0.05, 0.40), (x - 0.05, 0.40), (x - 0.24, 0.50), (x - 0.14, 0.50)], STEEL, STEEL_D)
for x in (-0.6625, 0.6625):
    rect(x - 0.15, 0.10, x + 0.15, 0.30, STEEL_L, STEEL_D, radius=0.025)
    circle(x, 0.21, 0.05, BRASS_L, BRASS_D, BRASS_D)
    bolt(x - 0.10, 0.14)
    bolt(x + 0.10, 0.14)

# 2. deck: planks along the platform with seams, end grain at the ends
rect(-HALF, 0.47, HALF, DECK, OAK_L, OAK_D, edge=OAK_D)
d = ImageDraw.Draw(canvas)
for k in range(1, 4):
    y = 0.47 + 0.025 * k
    d.line([px(-HALF + 0.01, y), px(HALF - 0.01, y)], fill=OAK_D + (255,), width=3)
for x in [-1.1 + i * 0.37 for i in range(7)]:
    d.line([px(x, 0.48), px(x + 0.02, DECK - 0.01)], fill=OAK_D + (255,), width=3)
# side lip along the deck edge
rect(-HALF, DECK, HALF, DECK + 0.025, OAK, OAK_D, edge=OAK_D)

# 3. bow and stern beams with rings and brass corner plates
for sign in (-1, 1):
    x0, x1 = (HALF - 0.09, HALF) if sign > 0 else (-HALF, -HALF + 0.09)
    rect(x0, 0.36, x1, 0.64, OAK, OAK_D, edge=OAK_D)
    circle(sign * (HALF - 0.045), 0.50, 0.032, STEEL_L, STEEL_D)
    bolt(sign * (HALF - 0.045), 0.60)
    bolt(sign * (HALF - 0.045), 0.40)

# 4. the mast step at the bow third: oak block, brass band, two knees
MAST_X = 0.5
rect(MAST_X - 0.11, DECK, MAST_X + 0.11, DECK + 0.20, OAK_L, OAK_D, radius=0.01, edge=OAK_D)
rect(MAST_X - 0.125, DECK + 0.07, MAST_X + 0.125, DECK + 0.10, BRASS_L, BRASS_D, edge=BRASS_D)
for sx in (-1, 1):
    poly([(MAST_X + sx * 0.11, DECK), (MAST_X + sx * 0.30, DECK), (MAST_X + sx * 0.11, DECK + 0.18)], OAK, OAK_D, OAK_D)
bolt(MAST_X - 0.07, DECK + 0.085)
bolt(MAST_X + 0.07, DECK + 0.085)

# 5. a bench aft for the sailor, a cleat and a coil of rope
rect(-1.02, DECK, -0.58, DECK + 0.20, OAK_L, OAK_D, edge=OAK_D)
rect(-1.04, DECK + 0.20, -0.56, DECK + 0.235, PINE, OAK_D, radius=0.01, edge=OAK_D)
poly([(-0.20, DECK), (-0.08, DECK), (-0.10, DECK + 0.07), (-0.18, DECK + 0.07)], BRASS_L, BRASS_D, BRASS_D)
for k in range(4):
    c = px(-0.34 + 0.02 * k, DECK + 0.03)
    rx, ry = 0.09 * PPM * SS, 0.032 * PPM * SS
    ImageDraw.Draw(canvas).ellipse([c[0] - rx, c[1] - ry - k * 4, c[0] + rx, c[1] + ry - k * 4], outline=ROPE_D + (255,), width=5, fill=ROPE + (255,) if k == 3 else None)

# 6. grain and light, as on the other bodies
alpha = canvas.getchannel("A")
rgb = canvas.convert("RGB")
grain = Image.effect_noise(canvas.size, 40).convert("RGB")
rgb = Image.blend(rgb, ImageChops.soft_light(rgb, grain), 0.5)
light = Image.linear_gradient("L").rotate(45, expand=False).resize(canvas.size)
rgb = Image.blend(rgb, ImageChops.soft_light(rgb, Image.merge("RGB", (light, light, light)).point(lambda v: 255 - v)), 0.30)
canvas = Image.merge("RGBA", (*rgb.split(), alpha))
final = canvas.resize((W, H), Image.LANCZOS)
OUT.parent.mkdir(parents=True, exist_ok=True)
final.save(OUT)
box = final.getbbox()
print("saved", OUT, final.size, "bbox", box)
ax1 = round(CENTER_X - 0.6625 * PPM)
ax2 = round(CENTER_X + 0.6625 * PPM)
axle_y = round(RAIL_Y - 0.21 * PPM)
print("region_px", [45, box[1], 1945, box[3] - box[1]])
print("axles_px", [[ax1, axle_y], [ax2, axle_y]], "deck_y_px", round(RAIL_Y - DECK * PPM))
