"""Draws the small petrol locomotive body (side elevation, no wheels).

Style after the owner's reference sheet tools/art_sources/petrol_ref_v1.webp
(inspiration only, nothing is copied): a green cab behind a black hood with
louvres and brass bands, a brass headlamp nose, a green fuel canister and a thin
exhaust stack. Everything is drawn here in code in metres above the rail, with
the same helpers and rendering as tools/make_steam_art.py (run in this
module's namespace with different constants). Wheels, side rod, exhaust smoke
and the headlamp glow are drawn live by the game (art_v3.gd).

Run:  python tools/make_petrol_art.py
"""
from pathlib import Path

_ROOT = Path(__file__).resolve().parent
_src = (_ROOT / "make_steam_art.py").read_text(encoding="utf-8")
_header = _src[:_src.index("# --- 1. far cab wall")]
_header = (_header.replace("steam_locomotive_body.png", "petrol_locomotive_body.png")
           .replace("LENGTH = 4.0", "LENGTH = 2.8").replace("HEIGHT = 2.40", "HEIGHT = 2.20"))
exec(compile(_header, "make_steam_art_header", "exec"), globals())

RED_W = (150, 40, 34)
AXLE_X = 0.80          # wheel centres at +-0.80 m
DECK = 0.55            # floor height above the rail

# --- far cab wall with window and door (see-through window) -------------------------
CAB_L, CAB_R, ROOF = -1.40, -0.40, 1.90
rect(CAB_L, DECK, CAB_R, ROOF, GREEN, GREEN_D, edge=STEEL_D)
planks(CAB_L, DECK, CAB_R, ROOF, GREEN_D, 0.14)
hole = Image.new("L", canvas.size, 0)
ImageDraw.Draw(hole).rectangle([px(-1.28, 1.70), px(-0.88, 1.18)], fill=255)
canvas.putalpha(ImageChops.subtract(canvas.getchannel("A"), hole))
for a, b in [((-1.28, 1.70), (-0.88, 1.70)), ((-1.28, 1.18), (-0.88, 1.18)), ((-1.28, 1.18), (-1.28, 1.70)), ((-0.88, 1.18), (-0.88, 1.70))]:
    line(a, b, BRASS, 0.026)
glass = Image.new("L", canvas.size, 0)
ImageDraw.Draw(glass).rectangle([px(-1.27, 1.69), px(-0.89, 1.19)], fill=255)
glass_layer = Image.new("RGBA", canvas.size, (118, 150, 164, 255))
glass_layer.putalpha(glass)
canvas = Image.alpha_composite(canvas, glass_layer)
line((-1.08, 1.18), (-1.08, 1.70), BRASS_D, 0.014)
# door outline on the far wall with a brass handle
for a, b in [((-0.78, DECK + 0.04), (-0.78, 1.62)), ((-0.78, 1.62), (-0.46, 1.62)), ((-0.46, 1.62), (-0.46, DECK + 0.04))]:
    line(a, b, GREEN_L, 0.014)
rect(-0.52, 1.00, -0.49, 1.14, BRASS_L, BRASS_D, edge=BRASS_D)

# --- frame: bottom beam, braces, axle boxes -----------------------------------------------
rect(-1.40, 0.03, 1.40, 0.13, STEEL, STEEL_D)
for x in (-1.10, -0.35, 0.35, 1.10):
    poly([(x - 0.06, 0.13), (x + 0.06, 0.13), (x + 0.24, 0.43), (x + 0.12, 0.43)], STEEL, STEEL_D)
    poly([(x + 0.06, 0.13), (x - 0.06, 0.13), (x - 0.24, 0.43), (x - 0.12, 0.43)], STEEL, STEEL_D)
for x in (-AXLE_X, AXLE_X):
    rect(x - 0.14, 0.02, x + 0.14, 0.18, STEEL_L, STEEL_D, radius=0.03)
    ellipse(x, 0.21, 0.05, 0.05, BRASS_L, BRASS_D, edge=BRASS_D)

# --- floor beam with green straps ----------------------------------------------------------------
rect(-1.40, 0.43, 1.40, 0.57, OAK_L, OAK_D, edge=OAK_D)
for x in (-1.36, -0.68, 0.0, 0.68, 1.36):
    rect(x - 0.04, 0.36, x + 0.04, 0.64, GREEN, GREEN_D)
    rivet(x, 0.55)
    rivet(x, 0.42)

# --- black hood with louvres, brass bands and rivets -----------------------------------------
HOOD_L, HOOD_R, HOOD_T = -0.40, 0.98, 1.40
rect(HOOD_L, 0.57, HOOD_R, HOOD_T, (88, 96, 100), (18, 22, 24), radius=0.07, edge=STEEL_D)
rect(HOOD_L + 0.02, 1.26, HOOD_R - 0.02, 1.34, (130, 142, 142), (60, 70, 72), radius=0.03, edge=STEEL)
for i in range(7):
    y = 0.70 + i * 0.075
    rect(0.02, y, 0.76, y + 0.034, (6, 8, 9), (26, 30, 32), edge=STEEL_D)
    line((0.02, y - 0.004), (0.76, y - 0.004), (92, 104, 104), 0.008)
for x in (-0.30, 0.90):
    rect(x - 0.025, 0.57, x + 0.025, HOOD_T, BRASS_L, BRASS_D, horizontal=True, edge=BRASS_D)
rect(0.80, 0.57, 0.85, HOOD_T, BRASS_L, BRASS_D, horizontal=True, edge=BRASS_D)
rivet_row(-0.22, -0.04, 1.20, 0.09)
rivet_row(-0.22, -0.04, 0.66, 0.09)

# --- headlamp nose ----------------------------------------------------------------------------------------
rect(0.98, 0.57, 1.34, 1.34, STEEL, (14, 18, 20), radius=0.05, edge=STEEL_D)
rect(1.02, 0.62, 1.30, 1.00, (10, 12, 14), (30, 34, 36), edge=STEEL_D)
for i in range(7):
    x = 1.05 + i * 0.037
    line((x, 0.64), (x, 0.98), (80, 90, 92), 0.008)
rect(0.98, 0.57, 1.04, 1.34, BRASS_L, BRASS_D, horizontal=True, edge=BRASS_D)
ellipse(1.18, 1.17, 0.125, 0.125, BRASS_L, BRASS_D, edge=BRASS_D)
ellipse(1.18, 1.17, 0.095, 0.095, (255, 238, 170), (226, 176, 80), edge=BRASS_D)
rect(1.06, 1.31, 1.30, 1.37, BRASS, BRASS_D, radius=0.02, edge=BRASS_D)

# --- exhaust stack ---------------------------------------------------------------------------------------------
rect(0.50, HOOD_T - 0.02, 0.60, 1.86, BRASS_L, BRASS_D, horizontal=True, edge=BRASS_D)
rect(0.46, 1.84, 0.64, 1.92, STEEL_L, STEEL_D, radius=0.02, edge=STEEL_D)
rect(0.47, HOOD_T - 0.04, 0.63, HOOD_T + 0.04, BRASS, BRASS_D, edge=BRASS_D)

# --- fuel canister on the running board -----------------------------------------------------------------------
rect(0.22, 0.57, 0.64, 0.84, GREEN_L, GREEN_D, radius=0.03, edge=STEEL_D)
line((0.28, 0.62), (0.58, 0.80), BRASS, 0.016)
line((0.28, 0.80), (0.58, 0.62), BRASS, 0.016)
rect(0.36, 0.84, 0.50, 0.89, BRASS_L, BRASS_D, edge=BRASS_D)
rivet(0.26, 0.80, 0.014)
rivet(0.60, 0.80, 0.014)
rivet(0.26, 0.62, 0.014)
rivet(0.60, 0.62, 0.014)

# --- cab posts, roof, front wall -----------------------------------------------------------------------------------
rect(CAB_L - 0.01, DECK, CAB_L + 0.09, ROOF, GREEN_L, GREEN_D, horizontal=True, edge=STEEL_D)
rivet_col(CAB_L + 0.04, DECK + 0.10, ROOF - 0.08, 0.18)
rect(CAB_R - 0.09, DECK, CAB_R + 0.01, ROOF, GREEN, GREEN_D, edge=STEEL_D)
rivet_col(CAB_R - 0.04, DECK + 0.10, ROOF - 0.08, 0.18)
rect(CAB_L - 0.04, ROOF - 0.02, CAB_R + 0.05, ROOF + 0.10, OAK_L, OAK_D, radius=0.03, edge=OAK_D)
rect(CAB_L, ROOF - 0.05, CAB_R, ROOF - 0.01, GREEN, GREEN_D, edge=STEEL_D)
rivet_row(CAB_L + 0.06, CAB_R - 0.06, ROOF - 0.03, 0.14)

# --- buffer beams ----------------------------------------------------------------------------------------------------------
rect(1.30, 0.38, 1.40, 0.70, OAK, OAK_D, edge=OAK_D)
rivet(1.35, 0.44)
rivet(1.35, 0.64)
rect(1.34, 0.50, 1.40, 0.56, BRASS_L, BRASS_D, edge=BRASS_D)
rect(-1.40, 0.38, -1.31, 0.70, OAK, OAK_D, edge=OAK_D)
rivet(-1.355, 0.44)
rivet(-1.355, 0.64)

# --- finish: grain, warm light, save -------------------------------------------------------------------------------------
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
axle_y = RAIL_Y - int(0.21 * S)
cx = MARGIN + int(LENGTH * S / 2)
print("region_px", [MARGIN, box[1], int(LENGTH * S), box[3] - box[1]])
print("axles_px", [[cx - int(AXLE_X * S), axle_y], [cx + int(AXLE_X * S), axle_y]])
print("deck_y_px", RAIL_Y - int(DECK * S))
