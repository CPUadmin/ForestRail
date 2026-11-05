# -*- coding: utf-8 -*-
"""B6.5: cuts the movable parts out of the picture of the rail zeppelin (assets/art_consists/rail_zeppelin_compact_body.png, the file of
the other helper is not changed): the tail plane, the wing pod (the flaps) and the two blades of the propeller. The hole of the wing pod
is filled from the engine around it, the others leave only the empty background. Output: assets/art_zeppelin/*.png and parts.json
(the place of each part and its pivot in pixels of the original picture). Run: python tools/make_zeppelin_wings.py [--debug]."""
import json, sys, pathlib
import numpy as np
import cv2
from PIL import Image, ImageDraw

ROOT = pathlib.Path(__file__).resolve().parent.parent / "ForestRail" / "assets"
SRC = ROOT / "art_consists" / "rail_zeppelin_compact_body.png"
OUT = ROOT / "art_zeppelin"
OUT.mkdir(exist_ok=True)

def z2o(points):
    # the coordinates were read on a 2x enlargement of the crop that starts at (140, 100)
    return [(140 + x / 2.0, 100 + y / 2.0) for x, y in points]

# polygons in pixels of the original picture
TAIL = z2o([(160, 80), (955, 80), (955, 223), (445, 223), (445, 236), (160, 236)])
WING = z2o([(545, 750), (590, 718), (690, 694), (780, 676), (790, 656), (870, 650), (900, 660), (1000, 654), (1120, 664), (1215, 686), (1262, 718),
            (1240, 750), (1130, 778), (1000, 798), (880, 804), (760, 798), (645, 784), (570, 770)])
# the two blades: a vertical strip on the left of the hub, split at the hub line
PROP_X = (172.0, 218.0)
HUB_Y = 447.0

def polygon_mask(size, points):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).polygon(points, fill=255)
    return np.array(mask)

def main():
    debug = "--debug" in sys.argv
    rgba = np.array(Image.open(SRC).convert("RGBA"))
    h, w = rgba.shape[:2]
    alpha = rgba[:, :, 3]
    parts = {}

    def cut(name, mask, pivot):
        m = (mask > 0) & (alpha > 8)
        ys, xs = np.where(m)
        x0, x1, y0, y1 = xs.min() - 1, xs.max() + 2, ys.min() - 1, ys.max() + 2
        piece = rgba.copy()
        piece[:, :, 3] = np.where(m, alpha, 0)
        piece = piece[y0:y1, x0:x1]
        Image.fromarray(piece).save(OUT / (name + ".png"))
        parts[name] = {"x": int(x0), "y": int(y0), "w": int(x1 - x0), "h": int(y1 - y0), "pivot": [float(pivot[0]), float(pivot[1])]}
        return m

    tail_mask = cut("tailplane", polygon_mask((w, h), TAIL), (507.0, 195.0))
    wing_mask = cut("wing", polygon_mask((w, h), WING), (540.0, 467.0))
    prop_region = np.zeros((h, w), np.uint8)
    prop_region[:, int(PROP_X[0]):int(PROP_X[1])] = 255
    prop_region[int(HUB_Y - 52):int(HUB_Y + 52), :] = 0   # the hub stays on the body
    top_mask = cut("prop_top", np.where(prop_region > 0, 255, 0).astype(np.uint8) * (np.arange(h)[:, None] < HUB_Y), (196.0, HUB_Y))
    bottom_mask = cut("prop_bottom", np.where(prop_region > 0, 255, 0).astype(np.uint8) * (np.arange(h)[:, None] >= HUB_Y), (196.0, HUB_Y))

    # the body without the movable parts: the wing pod hole is filled from the engine around it
    body = rgba.copy()
    hole = np.zeros((h, w), np.uint8)
    hole[wing_mask] = 255
    hole = cv2.dilate(hole, np.ones((5, 5), np.uint8))
    # the hole of the wing pod: per column from the engine above to the engine below, and the fine grain copied from the strip above
    hole_b = hole > 0
    base = body[:, :, :3].astype(np.float32)
    shift = 70
    shifted = np.roll(base, shift, axis=0)
    blur = cv2.GaussianBlur(shifted, (0, 0), 3.0)
    detail = shifted - blur
    filled = base.copy()
    for x in range(w):
        ys = np.where(hole_b[:, x])[0]
        if len(ys) == 0: continue
        y0, y1 = ys.min(), ys.max()
        above = base[max(0, y0 - 4):y0 - 1, x].mean(axis=0)
        below = base[y1 + 2:y1 + 5, x].mean(axis=0)
        for y in ys:
            k = (y - y0) / max(1.0, float(y1 - y0))
            filled[y, x] = above * (1.0 - k) + below * k + detail[y, x] * 0.8
    filled = np.clip(filled, 0, 255).astype(np.uint8)
    body[:, :, :3] = np.where(hole_b[:, :, None], filled, body[:, :, :3])
    body[:, :, 3] = np.where(hole_b, 255, body[:, :, 3])
    for m in (tail_mask, top_mask, bottom_mask):
        grown = cv2.dilate(m.astype(np.uint8), np.ones((5, 5), np.uint8)) > 0   # the anti-aliased fringe goes with the part
        body[:, :, 3][grown] = 0
    # the strip of the hole above the engine pipes keeps the alpha of the engine
    Image.fromarray(body).save(OUT / "body_clean.png")
    parts["body"] = {"w": int(w), "h": int(h)}
    (OUT / "parts.json").write_text(json.dumps(parts, indent=1, ensure_ascii=False), encoding="utf-8")
    print(json.dumps(parts))
    if debug:
        bg = Image.new("RGBA", (w, h), (70, 90, 110, 255))
        bg.alpha_composite(Image.fromarray(body))
        bg.crop((140, 100, 900, 620)).resize((1520, 1040), Image.LANCZOS).save(OUT / "_debug_body.png")

if __name__ == "__main__":
    main()
