"""Draws the small forest steam locomotive body (side elevation, no wheels).

The cab, frame, floor, bunker and bucket are drawn here in code. The boiler with
its water tank and dome, the chimney, the headlamp and the front buffer are cut
from the artist's sheet tools/art_sources/steam_sheet_v2.webp (made by the
project owner from an earlier render of this script) and fitted to the game's
metric layout. Everything is in
metres above the rail (x to the right, front of the engine on the right) and
rendered at 2x then reduced for clean edges. Wheels, rods, crosshead, fire glow,
smoke and the manometer needle are drawn live by the game (art_v3.gd), so the
body leaves them out.

Run:  python tools/make_steam_art.py
Writes ForestRail/assets/art_p2/steam_locomotive_body.png and prints the
region/axle numbers for object_dimensions.json.
"""
import math
import random

import cv2
import numpy as np
from pathlib import Path
from PIL import Image, ImageChops, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "ForestRail/assets/art_p2/steam_locomotive_body.png"

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
OAK_D = (112, 72, 36)
OAK = (176, 122, 62)
OAK_L = (216, 162, 94)
BRASS_D = (116, 86, 36)
BRASS = (196, 156, 76)
BRASS_L = (244, 216, 146)
COAL = (20, 20, 22)
COAL_L = (62, 62, 68)
RED = (150, 40, 34)

random.seed(7)
canvas = Image.new("RGBA", (W * SS, H * SS), (0, 0, 0, 0))


# The art is laid out on a 4.0 m drawing; XMAP squeezes or stretches stretches of it
# to the standard platform length of this class (old x -> new x, piecewise linear).
XMAP = [(-2.0, -1.5), (-0.3, -0.3), (1.94, 1.44), (2.0, 1.5)]


def mx(x: float) -> float:
    pts = XMAP
    if x <= pts[0][0]:
        i = 0
    elif x >= pts[-1][0]:
        i = len(pts) - 2
    else:
        i = max(k for k in range(len(pts) - 1) if pts[k][0] <= x)
    (a0, b0), (a1, b1) = pts[i], pts[i + 1]
    return b0 + (x - a0) * (b1 - b0) / (a1 - a0)


def inv_mx(xn: float) -> float:
    pts = XMAP
    i = 0
    for k in range(len(pts) - 1):
        if pts[k][1] <= xn:
            i = k
    (a0, b0), (a1, b1) = pts[i], pts[i + 1]
    return a0 + (xn - b0) * (a1 - a0) / (b1 - b0)


def px(x: float, y: float):
    """Metres (x right of centre, y above rail) to supersampled pixels."""
    return ((mx(x) + LENGTH / 2) * S + MARGIN) * SS, (RAIL_Y - y * S) * SS


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


def paint(mask_fn, top, bottom, horizontal=False, grain=6, edge=None):
    """Fill a shape (drawn by mask_fn on an L mask) with a gradient and grain."""
    global canvas
    mask = Image.new("L", canvas.size, 0)
    mask_fn(ImageDraw.Draw(mask))
    bbox = mask.getbbox()
    if not bbox:
        return
    layer, origin = gradient(bbox, top, bottom, horizontal)
    full = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    full.paste(layer, origin)
    if grain:
        noise = Image.effect_noise(canvas.size, 18).convert("L")
        noise = noise.point(lambda v: int((v - 128) * grain / 128 + 128))
        tint = Image.merge("RGBA", (noise, noise, noise, Image.new("L", canvas.size, 255)))
        full = ImageChops.add(ImageChops.multiply(full, tint), Image.new("RGBA", canvas.size, (0, 0, 0, 0)), 1, -0) if False else full
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
    # Centre is mapped, radii stay true so round parts remain round.
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



# --- cutting parts out of the artist's sheet --------------------------------------
SHEET = np.asarray(Image.open(ROOT / "tools/art_sources/steam_sheet_v2.webp").convert("RGB")).astype(np.int32)
SHEET_BG = np.array([235, 230, 220])


def cut(x, y, w, h):
    """Crop a part from the sheet; the beige page becomes transparent."""
    sub = SHEET[y:y + h, x:x + w]
    d = np.abs(sub - SHEET_BG).sum(axis=2)
    page = (d < 34).astype(np.uint8)
    n, lab = cv2.connectedComponents(page, connectivity=4)
    outside = np.zeros_like(page)
    border = set(lab[0, :]) | set(lab[-1, :]) | set(lab[:, 0]) | set(lab[:, -1])
    for k in border:
        if k != 0 and page[lab == k][0] == 1:
            outside[lab == k] = 1
    solid = (1 - outside).astype(np.uint8) * 255
    solid = cv2.GaussianBlur(solid, (3, 3), 0)
    core = cv2.erode((1 - outside).astype(np.uint8), np.ones((3, 3), np.uint8)).astype(bool)
    rgb = sub.astype(np.uint8).copy()
    # pull edge colours inward so the beige page does not leave a halo
    inner = cv2.inpaint(np.where(core[..., None], rgb, 0).astype(np.uint8), (~core).astype(np.uint8) * 255, 3, cv2.INPAINT_TELEA)
    rgb = np.where(core[..., None], rgb, inner)
    return Image.fromarray(np.dstack([rgb, solid]), "RGBA")


def paste(part, x_left, y_bottom, width_m=None, height_m=None):
    """Place a cut part with its bottom-left corner at metres (x_left, y_bottom)."""
    global canvas
    w = int((mx(x_left + width_m) - mx(x_left)) * S * SS) if width_m else part.width * SS * S // 258
    h = int(height_m * S * SS) if height_m else part.height * SS * S // 258
    scaled = part.resize((w, h), Image.LANCZOS)
    left, bottom = px(x_left, y_bottom)
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    layer.paste(scaled, (int(left), int(bottom) - h))
    canvas = Image.alpha_composite(canvas, layer)


# --- 1. far cab wall with a real window (transparent through it) -----------
rect(-1.97, 0.60, -0.36, 2.02, GREEN, GREEN_D, edge=STEEL_D)
planks(-1.97, 0.60, -0.36, 2.02, GREEN_D)
# window opening cut out of the far wall
hole = Image.new("L", canvas.size, 0)
ImageDraw.Draw(hole).rectangle([px(-1.88, 1.80), px(-1.52, 1.30)], fill=255)
canvas.putalpha(ImageChops.subtract(canvas.getchannel("A"), hole))
for a, b in [((-1.88, 1.80), (-1.52, 1.80)), ((-1.88, 1.30), (-1.52, 1.30)), ((-1.88, 1.30), (-1.88, 1.80)), ((-1.52, 1.30), (-1.52, 1.80))]:
    line(a, b, BRASS, 0.03)
glass = Image.new("L", canvas.size, 0)
ImageDraw.Draw(glass).rectangle([px(-1.87, 1.79), px(-1.53, 1.31)], fill=255)
glass_layer = Image.new("RGBA", canvas.size, (118, 150, 164, 255))
glass_layer.putalpha(glass)
canvas = Image.alpha_composite(canvas, glass_layer)
line((-1.70, 1.30), (-1.70, 1.80), BRASS_D, 0.016)

# --- 2. frame: bottom beam, braces, axle boxes ---------------------------------
rect(-2.0, 0.04, 2.0, 0.15, STEEL, STEEL_D)
for x in (-1.58, -0.55, 0.55, 1.58):
    poly([(x - 0.07, 0.15), (x + 0.07, 0.15), (x + 0.30, 0.55), (x + 0.16, 0.55)], STEEL, STEEL_D)
    poly([(x + 0.07, 0.15), (x - 0.07, 0.15), (x - 0.30, 0.55), (x - 0.16, 0.55)], STEEL, STEEL_D)
for x in (inv_mx(-0.8), inv_mx(0.8)):
    rect(x - 0.17, 0.02, x + 0.17, 0.20, STEEL_L, STEEL_D, radius=0.03)
    ellipse(x, 0.275, 0.065, 0.065, BRASS_L, BRASS_D, edge=BRASS_D)
    rivet(x - 0.12, 0.06)
    rivet(x + 0.12, 0.06)

# --- 3. floor beam ------------------------------------------------------------
rect(-2.0, 0.50, 2.0, 0.64, OAK_L, OAK_D, edge=OAK_D)
d = ImageDraw.Draw(canvas)
for x in [-1.85 + i * 0.37 for i in range(11)]:
    d.line([px(x, 0.51), px(x + 0.02, 0.63)], fill=OAK_D + (255,), width=3)
for x in (-1.96, -0.98, 0.0, 0.98, 1.96):
    rect(x - 0.045, 0.42, x + 0.045, 0.70, GREEN, GREEN_D)
    rivet(x, 0.62)
    rivet(x, 0.48)

# --- 4. coal bunker with heap -----------------------------------------------------
heap = [(-1.93, 1.28), (-1.86, 1.42), (-1.74, 1.50), (-1.63, 1.44), (-1.56, 1.30)]
poly(heap, COAL_L, COAL, edge=STEEL_D)
d = ImageDraw.Draw(canvas)
for _ in range(34):
    cx = random.uniform(-1.90, -1.60)
    cy = random.uniform(1.30, 1.46)
    r = random.uniform(0.012, 0.03)
    a = px(cx - r, cy + r)
    b = px(cx + r, cy - r)
    d.ellipse([a, b], fill=lerp(COAL_L, (110, 110, 118), random.random() * 0.5) + (255,))
rect(-1.97, 0.64, -1.54, 1.30, GREEN, GREEN_D, edge=STEEL_D)
planks(-1.97, 0.64, -1.54, 1.30, GREEN_D, 0.14)
rivet_row(-1.93, -1.58, 1.26, 0.12)

# --- 5. bucket ------------------------------------------------------------------------
poly([(-1.52, 0.64), (-1.32, 0.64), (-1.29, 0.88), (-1.55, 0.88)], STEEL, STEEL_D, edge=STEEL_D)
line((-1.52, 0.80), (-1.32, 0.80), STEEL_L, 0.012)
line((-1.50, 0.88), (-1.42, 1.02), BRASS, 0.016)
line((-1.34, 0.88), (-1.42, 1.02), BRASS, 0.016)

# --- 6. boiler, tank and dome from the sheet -------------------------------------------
BOILER = cut(468, 473, 590, 267)
paste(BOILER, -0.30, 0.64, width_m=2.24, height_m=1.12)

# --- 7. cab front wall (backhead side) ------------------------------------------------
rect(-0.47, 0.64, -0.30, 2.02, GREEN, GREEN_D, edge=STEEL_D)
rivet_col(-0.385, 0.74, 1.94, 0.18)
# firebox door seen from the side, brass framed (live glow is drawn by the game)
rect(-0.66, 0.68, -0.40, 0.96, STEEL_D, (8, 8, 10), radius=0.02, edge=BRASS_D)
for a, b in [((-0.66, 0.68), (-0.40, 0.68)), ((-0.66, 0.96), (-0.40, 0.96)), ((-0.66, 0.68), (-0.66, 0.96))]:
    line(a, b, BRASS, 0.022)
rivet(-0.62, 0.92, 0.014)
rivet(-0.62, 0.72, 0.014)

# --- 8. chimney and headlamp from the sheet ---------------------------------------------
CHIMNEY = cut(1098, 479, 129, 229)
paste(CHIMNEY, 1.34, 1.44, height_m=0.84)
LANTERN = cut(560, 758, 76, 149)
paste(LANTERN, 1.92, 1.26, height_m=0.30)

# --- 12. outside cylinder, slide bars, buffer beams ------------------------------------
rect(1.72, 0.17, 1.92, 0.38, STEEL_L, STEEL_D, radius=0.025, edge=STEEL_D)
ellipse(1.92, 0.275, 0.03, 0.095, BRASS_L, BRASS_D, horizontal=True, edge=BRASS_D)
rect(1.72, 0.16, 1.76, 0.39, BRASS, BRASS_D, horizontal=True)
line((1.36, 0.215), (1.72, 0.215), STEEL_L, 0.022)
line((1.36, 0.335), (1.72, 0.335), STEEL_L, 0.022)
rect(1.30, 0.19, 1.37, 0.36, STEEL, STEEL_D)
BUFFER = cut(1250, 318, 112, 78)
paste(BUFFER, 1.565, 0.40, width_m=0.435)
rect(-2.0, 0.40, -1.92, 0.80, OAK, OAK_D, edge=OAK_D)
rivet(-1.96, 0.46)
rivet(-1.96, 0.74)

# --- 13. cab posts, roof, grab rail, manometer bracket ------------------------------
rect(-1.99, 0.60, -1.88, 2.02, GREEN_L, GREEN_D, horizontal=True, edge=STEEL_D)
rivet_col(-1.935, 0.72, 1.94, 0.20)
rect(-2.0, 2.00, -0.20, 2.12, OAK_L, OAK_D, edge=OAK_D)
rect(-1.99, 1.98, -0.26, 2.02, GREEN, GREEN_D, edge=STEEL_D)
rivet_row(-2.0, -0.30, 2.00, 0.2)
line((-0.40, 1.98), (-0.62, 1.86), BRASS_D, 0.018)
ellipse(-0.68, 1.86, 0.105, 0.105, BRASS_L, BRASS_D, edge=BRASS_D)
ellipse(-0.68, 1.86, 0.082, 0.082, (240, 236, 220), (206, 200, 180), edge=BRASS_D)
line((-1.00, 0.70), (-1.00, 1.40), BRASS, 0.018)   # grab rail inside the cab
line((-0.38, 1.96), (-0.38, 1.70), BRASS_D, 0.012)

# --- 14. soft lower shadow line under the frame (kept inside the alpha) ----------------
alpha = canvas.getchannel("A")
rgb = canvas.convert("RGB")
grain = Image.effect_noise(canvas.size, 42).convert("RGB")
rgb = Image.blend(rgb, ImageChops.soft_light(rgb, grain), 0.55)
# warm light from the upper left, darker toward the lower right
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
