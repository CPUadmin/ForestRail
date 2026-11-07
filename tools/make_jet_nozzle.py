# -*- coding: utf-8 -*-
# The afterburner gadget picture has a flame painted forward. Make a clean nozzle: the mouth is dark inside, nothing sticks out of the ring.
from pathlib import Path
from PIL import Image
import numpy as np
ROOT = Path(__file__).resolve().parents[1]
src = Image.open(str(ROOT / "ForestRail/assets/art_gadgets/jet_afterburner.png")).convert("RGBA")
W, H = src.size
im = src.crop((0, 0, 203, H))
# 1. clear everything that sticks out right of the ring
a = np.array(im)
# 2. the dark inside of the mouth (an ellipse inside the ring)
cx, cy, rx, ry = 165.0, 112.0, 25.5, 73.5
yy, xx = np.mgrid[0:H, 0:203]
d = ((xx - cx) / rx) ** 2 + ((yy - cy) / ry) ** 2
inside = d <= 1.0
shade = np.clip(d, 0, 1)
core = np.array([20, 12, 10], dtype=float)
rim = np.array([58, 30, 20], dtype=float)
col = core[None, None, :] * (1 - shade[:, :, None]) + rim[None, None, :] * shade[:, :, None]
# a touch of ember in the depth, on the left side of the ellipse (the inside wall)
ember = np.clip(1.0 - np.hypot((xx - (cx - 8)) / (rx * 0.8), (yy - cy) / (ry * 0.6)), 0, 1) ** 2
col = col + ember[:, :, None] * np.array([70, 22, 6], dtype=float)
edge = np.clip((1.0 - d) * 6.0, 0, 1)   # soft edge
for c in range(3):
    a[:, :, c] = np.where(inside, a[:, :, c] * (1 - edge) + col[:, :, c] * edge, a[:, :, c]).astype(np.uint8)
# 3. flame tongues outside the ring: clear the pixels right of the ring that are flame coloured
# 4. the right side of the brass ring was hidden by the flame: paint it as an annulus of brass taking the colours of the rim on the left side
ocx, ocy, orx, ory = 160.0, 111.5, 40.0, 93.5
dout = ((xx - ocx) / orx) ** 2 + ((yy - ocy) / ory) ** 2
rim_col = np.array(src.crop((126, 0, 131, H)).convert("RGB"), dtype=float).mean(axis=1)   # one colour per row: the rim on the left side
rim_alpha = np.array(src.crop((126, 0, 131, H)))[:, :, 3].mean(axis=1)
gold = np.repeat(rim_col[:, None, :], 203, axis=1)
# rows where the left rim is missing (top and bottom tips): take the nearest row that has it
valid = np.where(rim_alpha > 200)[0]
for y in range(H):
    if rim_alpha[y] <= 200:
        near = valid[np.argmin(np.abs(valid - y))]
        gold[y, :, :] = rim_col[near]
shade_out = np.clip((dout - 0.80) / 0.20, 0, 1)
gold = gold * (1 - 0.30 * shade_out[:, :, None])
right = (xx >= 172) & (dout <= 1.0) & (~inside)
for c in range(3):
    a[:, :, c] = np.where(right, gold[:, :, c], a[:, :, c]).astype(np.uint8)
a[:, :, 3] = np.where(right, 255, a[:, :, 3])
# flame tongues beyond the ring
a[:, :, 3] = np.where((xx >= 186) & (dout > 1.0), 0, a[:, :, 3])
out = Image.fromarray(a, "RGBA")
out.save(str(ROOT / "ForestRail/assets/art_gadgets/jet_afterburner_nozzle.png"))
print(out.size)
