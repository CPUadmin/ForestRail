"""Draws the pneumatic train body (side elevation, no wheels).

Two riveted steel air cylinders lie one above the other behind a copper-piped
front, a cab with a window at the back, a brass valve wheel and manometer on top.
Everything is in metres above the rail (x to the right, front on the right), drawn
at 2x and reduced for clean edges, on the same 3.0 m platform and axle places as the
steam locomotive. Wheels, rods, the manometer needle, the frost on the pipes and the
air puffs are drawn live by the game (art_v3.gd), so the body leaves them out.

Run:  python tools/make_pneumatic_art.py
Writes ForestRail/assets/art_p2/pneumatic_body.png and prints the region/axle
numbers for object_dimensions.json.
"""
import math
import random

from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "ForestRail/assets/art_p2/pneumatic_body.png"

S = 256            # output pixels per metre
SS = 2             # supersampling
MARGIN = 60        # output px
LENGTH = 3.0
HEIGHT = 2.40
W = int(LENGTH * S + 2 * MARGIN)
H = int(HEIGHT * S + 2 * MARGIN)
RAIL_Y = H - MARGIN            # pixel row of the rail (output px)

STEEL_D = (24, 30, 32)
STEEL = (50, 60, 62)
STEEL_L = (104, 118, 118)
GREEN_D = (36, 60, 50)
GREEN = (64, 100, 82)
GREEN_L = (104, 142, 112)
BLUE_D = (28, 52, 72)
BLUE = (62, 98, 124)
BLUE_L = (128, 168, 190)
OAK_D = (112, 72, 36)
OAK = (176, 122, 62)
OAK_L = (216, 162, 94)
BRASS_D = (116, 86, 36)
BRASS = (196, 156, 76)
BRASS_L = (244, 216, 146)
COPPER_D = (110, 56, 30)
COPPER = (184, 104, 58)
COPPER_L = (236, 160, 104)

random.seed(11)
canvas = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))


def px(x: float, y: float):
    """Metres (x right of centre, y above rail) to supersampled pixels."""
    return ((x + LENGTH / 2) * S + MARGIN) * SS, (RAIL_Y - y * S) * SS


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(3))


def gradient(box, top, bottom, horizontal=False):
    x0, y0, x1, y1 = [int(v) for v in box]
    w, h = max(1, x1 - x0), max(1, y1 - y0)
    layer = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(layer)
    steps = w if horizontal else h
    for i in range(steps):
        c = lerp(top, bottom, i / max(1, steps - 1))
        if horizontal:
            d.line([(i, 0), (i, h)], fill=c + (255,))
        else:
            d.line([(0, i), (w, i)], fill=c + (255,))
    return layer, (x0, y0)


def paint(mask_fn, top, bottom, horizontal=False, edge=None):
    """Fill a shape (drawn by mask_fn on an L mask) with a gradient and a thin edge."""
    global canvas
    mask = Image.new("L", canvas.size, 0)
    mask_fn(ImageDraw.Draw(mask))
    bbox = mask.getbbox()
    if not bbox:
        return
    layer, origin = gradient(bbox, top, bottom, horizontal)
    full = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    full.paste(layer, origin)
    full.putalpha(ImageChops.multiply(full.getchannel("A"), mask))
    canvas = Image.alpha_composite(canvas, full)
    if edge:
        outline = mask.filter(ImageFilter.MaxFilter(3))
        ring = ImageChops.subtract(outline, mask)
        edge_layer = Image.new("RGBA", canvas.size, edge + (255,))
        edge_layer.putalpha(ring)
        canvas = Image.alpha_composite(canvas, edge_layer)


def rect(x0, y0, x1, y1, top, bottom, horizontal=False, radius=0.0, edge=STEEL_D):
    a = px(x0, y1)
    b = px(x1, y0)
    r = radius * S * SS

    def mask(d):
        if r > 0:
            d.rounded_rectangle([a, b], radius=r, fill=255)
        else:
            d.rectangle([a, b], fill=255)
    paint(mask, top, bottom, horizontal, edge=edge)


def poly(points, top, bottom, horizontal=False, edge=STEEL_D):
    pts = [px(*p) for p in points]
    paint(lambda d: d.polygon(pts, fill=255), top, bottom, horizontal, edge=edge)


def ellipse(cx, cy, rx, ry, top, bottom, horizontal=False, edge=STEEL_D):
    cxp, cyp = px(cx, cy)
    a = (cxp - rx * S * SS, cyp - ry * S * SS)
    b = (cxp + rx * S * SS, cyp + ry * S * SS)
    paint(lambda d: d.ellipse([a, b], fill=255), top, bottom, horizontal, edge=edge)


def line(p0, p1, color, width_m):
    d = ImageDraw.Draw(canvas)
    d.line([px(*p0), px(*p1)], fill=color + (255,), width=max(1, int(width_m * S * SS)))


def rivet(x, y, r=0.018, color=BRASS):
    d = ImageDraw.Draw(canvas)
    cx, cy = px(x, y)
    rr = r * S * SS
    d.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], fill=BRASS_D + (255,))
    d.ellipse([cx - rr * 0.8, cy - rr * 0.8, cx + rr * 0.55, cy + rr * 0.55], fill=color + (255,))
    d.ellipse([cx - rr * 0.5, cy - rr * 0.55, cx - rr * 0.05, cy - rr * 0.1], fill=BRASS_L + (255,))


def rivet_row(x0, x1, y, pitch=0.16):
    n = max(1, int(abs(x1 - x0) / pitch))
    for i in range(n + 1):
        rivet(x0 + (x1 - x0) * i / n, y)


def rivet_col(x, y0, y1, pitch=0.16):
    n = max(1, int(abs(y1 - y0) / pitch))
    for i in range(n + 1):
        rivet(x, y0 + (y1 - y0) * i / n)


def planks(x0, y0, x1, y1, dark, pitch=0.16):
    d = ImageDraw.Draw(canvas)
    x = x0 + pitch
    while x < x1 - 0.01:
        d.line([px(x, y0 + 0.01), px(x, y1 - 0.01)], fill=dark + (255,), width=max(1, int(0.006 * S * SS)))
        x += pitch


def pipe(points, width=0.045):
    """A copper pipe through the given points with a lit upper edge and rivet collars."""
    for a, b in zip(points, points[1:]):
        line(a, b, COPPER_D, width + 0.012)
    for a, b in zip(points, points[1:]):
        line(a, b, COPPER, width)
    for a, b in zip(points, points[1:]):
        line((a[0] - 0.008, a[1] + 0.008), (b[0] - 0.008, b[1] + 0.008), COPPER_L, width * 0.28)
    for p in points:
        ellipse(p[0], p[1], width * 0.62, width * 0.62, COPPER_L, COPPER_D, edge=COPPER_D)


# --- 1. far cab wall with a real window (transparent through it) -----------------
CAB_L, CAB_R = -1.46, -0.45
rect(CAB_L, 0.60, CAB_R, 2.02, GREEN, GREEN_D, edge=STEEL_D)
planks(CAB_L, 0.60, CAB_R, 2.02, GREEN_D)
hole = Image.new("L", canvas.size, 0)
ImageDraw.Draw(hole).rectangle([px(-1.34, 1.80), px(-0.96, 1.30)], fill=255)
canvas.putalpha(ImageChops.subtract(canvas.getchannel("A"), hole))
for a, b in [((-1.34, 1.80), (-0.96, 1.80)), ((-1.34, 1.30), (-0.96, 1.30)), ((-1.34, 1.30), (-1.34, 1.80)), ((-0.96, 1.30), (-0.96, 1.80))]:
    line(a, b, BRASS, 0.03)
glass = Image.new("L", canvas.size, 0)
ImageDraw.Draw(glass).rectangle([px(-1.33, 1.79), px(-0.97, 1.31)], fill=255)
glass_layer = Image.new("RGBA", canvas.size, (118, 150, 164, 255))
glass_layer.putalpha(glass)
canvas = Image.alpha_composite(canvas, glass_layer)
line((-1.15, 1.30), (-1.15, 1.80), BRASS_D, 0.016)

# --- 2. frame: bottom beam, braces, axle boxes ---------------------------------------
rect(-1.5, 0.04, 1.5, 0.15, STEEL, STEEL_D)
for x in (-1.20, -0.40, 0.40, 1.20):
    poly([(x - 0.07, 0.15), (x + 0.07, 0.15), (x + 0.30, 0.55), (x + 0.16, 0.55)], STEEL, STEEL_D)
    poly([(x + 0.07, 0.15), (x - 0.07, 0.15), (x - 0.30, 0.55), (x - 0.16, 0.55)], STEEL, STEEL_D)
for x in (-0.8, 0.8):
    rect(x - 0.17, 0.02, x + 0.17, 0.20, STEEL_L, STEEL_D, radius=0.03)
    ellipse(x, 0.275, 0.065, 0.065, BRASS_L, BRASS_D, edge=BRASS_D)
    rivet(x - 0.12, 0.06)
    rivet(x + 0.12, 0.06)

# --- 3. floor beam ----------------------------------------------------------------------
rect(-1.5, 0.50, 1.5, 0.64, OAK_L, OAK_D, edge=OAK_D)
d = ImageDraw.Draw(canvas)
for x in [-1.40 + i * 0.37 for i in range(8)]:
    d.line([px(x, 0.51), px(x + 0.02, 0.63)], fill=OAK_D + (255,), width=3)
for x in (-1.46, -0.73, 0.0, 0.73, 1.46):
    rect(x - 0.045, 0.42, x + 0.045, 0.70, GREEN, GREEN_D)
    rivet(x, 0.62)
    rivet(x, 0.48)

# --- 4. the two air cylinders: riveted bands, saddle straps, a lit stripe -----------------
TANK_X0, TANK_X1 = -0.32, 1.10
for y0, y1 in ((0.68, 1.18), (1.24, 1.74)):
    rect(TANK_X0, y0, TANK_X1, y1, BLUE_L, BLUE_D, radius=0.25, edge=STEEL_D)
    # the long highlight along the upper third of the shell
    line((TANK_X0 + 0.22, y1 - 0.10), (TANK_X1 - 0.22, y1 - 0.10), (176, 208, 224), 0.03)
    # riveted bands
    for bx in (0.0, 0.34, 0.68, 0.92):
        rect(bx - 0.035, y0 + 0.01, bx + 0.035, y1 - 0.01, STEEL_L, STEEL, horizontal=True, edge=STEEL_D)
        rivet(bx, y0 + 0.07, 0.014)
        rivet(bx, y1 - 0.07, 0.014)
        rivet(bx, (y0 + y1) / 2, 0.014)
    # domed end caps with a boss
    for cx in (TANK_X0 + 0.04, TANK_X1 - 0.04):
        ellipse(cx, (y0 + y1) / 2, 0.035, 0.07, BRASS_L, BRASS_D, edge=BRASS_D)
# saddle straps joining the cylinders to each other and the floor
for x in (-0.12, 0.50, 1.00):
    rect(x - 0.025, 0.64, x + 0.025, 1.30, STEEL_L, STEEL, horizontal=True)
    rivet(x, 0.66, 0.010)
    rivet(x, 1.21, 0.010)
# maker's plate on the lower cylinder
rect(0.12, 0.84, 0.30, 1.00, BRASS_L, BRASS_D, radius=0.01, edge=BRASS_D)
for fx in (0.15, 0.27):
    rivet(fx, 0.97, 0.008)
    rivet(fx, 0.87, 0.008)
for fy in (0.88, 0.92, 0.96):
    line((0.15, fy), (0.27, fy), BRASS_D, 0.008)

# --- 5. cab front wall (valve side) ---------------------------------------------------------
rect(-0.62, 0.64, -0.45, 2.02, GREEN, GREEN_D, edge=STEEL_D)
rivet_col(-0.535, 0.74, 1.94, 0.18)

# --- 6. copper pipes: the frosting places are the joints and the valve ------------------
# crossover on the cylinders' front, down to the working cylinder, and a rear feed
pipe([(TANK_X1, 1.49), (1.20, 1.49), (1.20, 0.93), (TANK_X1, 0.93)])
pipe([(1.20, 0.93), (1.36, 0.93), (1.36, 0.38)])
pipe([(TANK_X0, 1.49), (-0.38, 1.49), (-0.38, 1.82), (0.10, 1.82), (0.40, 1.82)])
# regulating valve with a brass hand wheel (3 turns, drawn as a wheel seen at an angle)
rect(0.36, 1.74, 0.44, 1.86, BRASS, BRASS_D, horizontal=True, radius=0.01, edge=BRASS_D)
line((0.40, 1.86), (0.40, 1.96), BRASS_D, 0.022)
ellipse(0.40, 1.97, 0.16, 0.05, BRASS_L, BRASS_D, edge=BRASS_D)
ellipse(0.40, 1.97, 0.12, 0.034, (50, 40, 22), (24, 20, 12), edge=BRASS_D)
line((0.40 - 0.12, 1.97), (0.40 + 0.12, 1.97), BRASS, 0.014)
line((0.40 - 0.08, 1.99), (0.40 + 0.08, 1.95), BRASS, 0.012)
line((0.40 - 0.08, 1.95), (0.40 + 0.08, 1.99), BRASS, 0.012)
ellipse(0.40, 1.97, 0.02, 0.012, BRASS_L, BRASS_D, edge=BRASS_D)
# safety valve
rect(0.94, 1.74, 1.00, 1.84, BRASS, BRASS_D, horizontal=True, edge=BRASS_D)
ellipse(0.97, 1.86, 0.045, 0.035, BRASS_L, BRASS_D, edge=BRASS_D)

# --- 7. working cylinder, slide bars, buffer beams ---------------------------------------
rect(1.27, 0.17, 1.46, 0.38, STEEL_L, STEEL_D, radius=0.025, edge=STEEL_D)
ellipse(1.46, 0.275, 0.03, 0.095, BRASS_L, BRASS_D, horizontal=True, edge=BRASS_D)
rect(1.27, 0.16, 1.31, 0.39, BRASS, BRASS_D, horizontal=True)
line((0.95, 0.215), (1.27, 0.215), STEEL_L, 0.022)
line((0.95, 0.335), (1.27, 0.335), STEEL_L, 0.022)
rect(0.88, 0.19, 0.95, 0.36, STEEL, STEEL_D)
rect(1.38, 0.40, 1.46, 0.80, OAK, OAK_D, edge=OAK_D)
rivet(1.42, 0.46)
rivet(1.42, 0.74)
ellipse(1.49, 0.60, 0.035, 0.085, STEEL_L, STEEL_D, horizontal=True, edge=STEEL_D)
rect(-1.50, 0.40, -1.42, 0.80, OAK, OAK_D, edge=OAK_D)
rivet(-1.46, 0.46)
rivet(-1.46, 0.74)

# --- 8. headlamp on a post at the front --------------------------------------------------------
rect(1.40, 0.64, 1.44, 1.22, STEEL, STEEL_D, horizontal=True)
rect(1.32, 1.22, 1.50, 1.44, BRASS_L, BRASS_D, radius=0.02, edge=BRASS_D)
rect(1.40, 1.26, 1.49, 1.40, (240, 226, 160), (206, 176, 96), radius=0.01, edge=BRASS_D)
ellipse(1.41, 1.45, 0.06, 0.02, BRASS, BRASS_D, edge=BRASS_D)

# --- 9. cab posts, roof, grab rail, manometer bracket ----------------------------------
rect(-1.49, 0.60, -1.38, 2.02, GREEN_L, GREEN_D, horizontal=True, edge=STEEL_D)
rivet_col(-1.435, 0.72, 1.94, 0.20)
rect(-1.50, 2.00, -0.40, 2.12, OAK_L, OAK_D, edge=OAK_D)
rect(-1.49, 1.98, -0.46, 2.02, GREEN, GREEN_D, edge=STEEL_D)
rivet_row(-1.50, -0.50, 2.00, 0.2)
line((-0.50, 1.98), (-0.34, 1.90), BRASS_D, 0.018)
ellipse(-0.30, 1.88, 0.105, 0.105, BRASS_L, BRASS_D, edge=BRASS_D)
ellipse(-0.30, 1.88, 0.082, 0.082, (240, 236, 220), (206, 200, 180), edge=BRASS_D)
for k in range(9):          # dial ticks
    a = math.radians(150 + 240 * k / 8)
    cx, cy = -0.30, 1.88
    line((cx + 0.060 * math.cos(a), cy - 0.060 * math.sin(a)), (cx + 0.074 * math.cos(a), cy - 0.074 * math.sin(a)), (60, 56, 48), 0.006)
line((-0.55, 0.70), (-0.55, 1.40), BRASS, 0.018)

# --- 10. grain and light as on the other bodies ----------------------------------------------
alpha = canvas.getchannel("A")
rgb = canvas.convert("RGB")
grain = Image.effect_noise(canvas.size, 42).convert("RGB")
rgb = Image.blend(rgb, ImageChops.soft_light(rgb, grain), 0.55)
light = Image.linear_gradient("L").rotate(45, expand=False).resize(canvas.size)
light_rgb = Image.merge("RGB", (light, light, light))
rgb = Image.blend(rgb, ImageChops.soft_light(rgb, light_rgb.point(lambda v: 255 - v)), 0.35)
canvas = Image.merge("RGBA", (*rgb.split(), alpha))
final = canvas.resize((W, H), Image.LANCZOS)
OUT.parent.mkdir(parents=True, exist_ok=True)
final.save(OUT)
box = final.getbbox()
print("saved", OUT, final.size)
print("bbox", box)
axle_y = RAIL_Y - int(0.275 * S)
cx = MARGIN + int(LENGTH * S / 2)
print("region_px", [MARGIN, box[1], int(LENGTH * S), box[3] - box[1]])
print("axles_px", [[cx - int(0.8 * S), axle_y], [cx + int(0.8 * S), axle_y]])
print("deck_y_px", RAIL_Y - int(0.60 * S))
