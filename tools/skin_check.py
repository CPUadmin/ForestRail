"""Checks a skin folder before the game does and draws a preview with the wheels.

    python tools/skin_check.py <folder with body.png> [--kind steam|motorcar|locomotive]

The class is taken from the folder name unless --kind is given. Prints the scale
the game will use and writes preview.png next to body.png: the picture fitted to
the standard platform length, the wheels at the standard axle places and a rail.
"""
import argparse
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.stdout.reconfigure(encoding="utf-8", errors="replace")

ROOT = Path(__file__).resolve().parents[1]
DIMS = json.loads((ROOT / "ForestRail/data/object_dimensions.json").read_text(encoding="utf-8"))["bodies"]
KINDS = ("steam", "motorcar", "locomotive")

parser = argparse.ArgumentParser()
parser.add_argument("folder", type=Path)
parser.add_argument("--kind", choices=KINDS)
args = parser.parse_args()
kind = args.kind or args.folder.resolve().name
if kind not in KINDS:
    raise SystemExit("Не понял класс машины: назови папку steam, motorcar или locomotive, либо передай --kind")
body_path = args.folder / "body.png"
if not body_path.exists():
    raise SystemExit("Нет файла " + str(body_path))

config = {}
if (args.folder / "skin.json").exists():
    config = json.loads((args.folder / "skin.json").read_text(encoding="utf-8"))
image = Image.open(body_path).convert("RGBA")
used = image.getchannel("A").getbbox()
if not used:
    raise SystemExit("Картинка полностью прозрачная")
spec = DIMS[kind]
length = float(spec["length_m"])
width_px = used[2] - used[0]
height_px = used[3] - used[1]
per_m = width_px / length
old_region = spec["region_px"]
old_per_m = old_region[2] / length
old_center = old_region[0] + old_region[2] / 2
radius = float(spec["wheel_diameter_m"]) / 2
bottom_m = float(config.get("bottom_m", 0.03))
offset_x = float(config.get("offset_x_m", 0.0))
axles_m = [(p[0] - old_center) / old_per_m + offset_x for p in spec["axles_px"]]
deck_above_axle = (spec["axles_px"][0][1] - spec["deck_y_px"]) / old_per_m

print("Класс: %s, платформа %.1f м" % (kind, length))
print("Картинка: %dx%d px (без пустых полей), масштаб %.0f px/м, высота машины %.2f м" % (width_px, height_px, per_m, height_px / per_m))
print("Оси колёс: %+.2f и %+.2f м от центра, колесо диаметром %.2f м, пол на %.2f м над осью" % (axles_m[0], axles_m[1], radius * 2, deck_above_axle))
problems = []
if per_m < 120:
    problems.append("Мало пикселей: меньше 120 px на метр, вид будет мыльным. Лучше 250 и больше.")
if height_px / per_m > 3.0:
    problems.append("Машина выше 3 м: не пролезет в ворота депо и закроет обзор.")
if height_px / per_m < 1.2:
    problems.append("Машина ниже 1.2 м: кабина будет слишком маленькой для рычагов.")
if image.getchannel("A").getextrema()[0] > 0 and used == (0, 0, image.width, image.height):
    problems.append("Нет прозрачных полей: фон, наверное, залит. Нужен PNG с прозрачным фоном.")
for p in problems:
    print("ВНИМАНИЕ:", p)

# Preview: the picture on a rail with the wheels where the game puts them.
margin = 40
canvas = Image.new("RGBA", (width_px + margin * 2, height_px + margin * 2 + 20), (112, 150, 160, 255))
draw = ImageDraw.Draw(canvas)
canvas.alpha_composite(image.crop(used), (margin, margin))
axle_y = margin + height_px - (radius - bottom_m) * per_m
for m in axles_m:
    cx = margin + width_px / 2 + m * per_m
    r = radius * per_m
    draw.ellipse([cx - r, axle_y - r, cx + r, axle_y + r], fill=(60, 40, 36, 255), outline=(220, 190, 110, 255), width=3)
rail_y = axle_y + radius * per_m
draw.line([(0, rail_y), (canvas.width, rail_y)], fill=(70, 60, 55, 255), width=6)
deck_y = axle_y - deck_above_axle * per_m
draw.line([(margin, deck_y), (margin + width_px, deck_y)], fill=(255, 220, 90, 160), width=2)
out = args.folder / "preview.png"
canvas.convert("RGB").save(out)
print("Превью:", out)
