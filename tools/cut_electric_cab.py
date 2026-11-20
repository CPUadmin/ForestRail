#!/usr/bin/env python3
"""1.12: cut the GPT packs P34 (the electric cab) and P33 (its cabinet) into game pictures.

  python tools/cut_electric_cab.py

Magenta is keyed out with the intake tool (tools/art_intake.py), sheets are cut into cells and trimmed.
Pairs that change state in place (toggles, the knife switch) are cut with one common box, so the picture does not
jump when the state changes; for the toggles the centre of the brass nut is written into the manifest as the pivot.
Everything stays lossless PNG (owner's rule).
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import art_intake as ai  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]
INBOX = ROOT / "tools" / "art_sources" / "inbox"
CAB = ROOT / "ForestRail" / "assets" / "art_cab" / "electric"
CABINET = ROOT / "ForestRail" / "assets" / "art_electric" / "cabinet"
manifest = {}


def keyed(path):
    return ai.apply_key(ai.load_rgba(path), "magenta")


def save(img, folder, name, extra=None):
    folder.mkdir(parents=True, exist_ok=True)
    img.save(folder / (name + ".png"), optimize=True)
    entry = {"size": list(img.size)}
    if extra:
        entry.update(extra)
    manifest[str((folder / (name + ".png")).relative_to(ROOT / "ForestRail")).replace("\\", "/")] = entry
    print(f"  {name}: {img.size[0]}x{img.size[1]}")


def union_box(images, pad=4):
    boxes = [ai.content_bbox(im) for im in images]
    x0 = min(b[0] for b in boxes); y0 = min(b[1] for b in boxes)
    x1 = max(b[2] for b in boxes); y1 = max(b[3] for b in boxes)
    w, h = images[0].size
    return max(0, x0 - pad), max(0, y0 - pad), min(w, x1 + pad), min(h, y1 + pad)


def nut_centre(img):
    """Centre of the brass hex nut of a toggle: brass pixels, not the cream porcelain lever."""
    a = np.array(img).astype(np.int32)
    r, g, b, al = a[:, :, 0], a[:, :, 1], a[:, :, 2], a[:, :, 3]
    brass = (al > 128) & (r > 120) & (r - b > 60) & (g > 70)
    ys, xs = np.where(brass)
    return [float(xs.mean()), float(ys.mean())]


def sheet(path, cols, rows):
    return [c for _, c in ai.cells(keyed(path), cols, rows)]


print("P34 -> " + str(CAB))
p34 = INBOX / "P34_electric_cab_parts"
save(keyed(p34 / "electric_window_wall.png"), CAB, "window_wall")
save(keyed(p34 / "electric_board.png"), CAB, "board")
save(keyed(p34 / "electric_hood_forward.png"), CAB, "hood_forward")
controls = sheet(p34 / "electric_controls.png", 4, 2)
for cell, name in zip(controls[:3] + [controls[5]], ["brake_handle", "traction_handle", "slot_plate", "horn_button"]):
    save(ai.trim(cell), CAB, name)
for pair, names in [((controls[3], controls[4]), ("toggle_left", "toggle_right")), ((controls[6], controls[7]), ("toggle_down", "toggle_up"))]:
    box = union_box(list(pair))
    for cell, name in zip(pair, names):
        piece = cell.crop(box)
        save(piece, CAB, name, {"pivot": nut_centre(piece)})
instruments = sheet(p34 / "electric_instruments.png", 3, 2)
for cell, name in zip(instruments, ["speedometer", "ammeter", "thermometer", "charge_bar", "clock", "lamp_socket"]):
    save(ai.trim(cell), CAB, name)
power = sheet(p34 / "electric_power_parts.png", 3, 1)
for cell, name in zip(power, ["cabinet_door", "emergency_button", "hv_plate"]):
    save(ai.trim(cell), CAB, name)

print("P33 -> " + str(CABINET))
p33 = INBOX / "P33_electric_cabinet"
save(ai.trim(keyed(p33 / "cabinet_inside.png")), CABINET, "inside")
switch = sheet(p33 / "knife_switch.png", 2, 1)
box = union_box(switch)
save(switch[0].crop(box), CABINET, "switch_off")
save(switch[1].crop(box), CABINET, "switch_on")
for cell, name in zip(sheet(p33 / "fuses.png", 3, 1), ["fuse_whole", "fuse_burnt", "fuse_bug"]):
    save(ai.trim(cell), CABINET, name)
save(ai.trim(keyed(p33 / "wire_scrap.png")), CABINET, "wire_scrap")
for cell, name in zip(sheet(p33 / "spare_box.png", 2, 1), ["spare_closed", "spare_open"]):
    save(ai.trim(cell), CABINET, name)

(CAB / "manifest.json").write_text(json.dumps(manifest, indent=1) + "\n", encoding="utf-8")
print("manifest: " + str(CAB / "manifest.json"))
