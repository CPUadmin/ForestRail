import csv, sys
from PIL import Image, ImageDraw, ImageFont
src, out = sys.argv[1], sys.argv[2]
rows = list(csv.DictReader(open(src)))
def col(k): return [float(r[k]) for r in rows]
t = col("t")
W, H = 1500, 1000
im = Image.new("RGB", (W, H), (22, 20, 16)); d = ImageDraw.Draw(im)
f = ImageFont.truetype(r"C:\Windows\Fonts\segoeui.ttf", 18)
panels = [("скорость, м/с", ["v"], 1.0), ("подъём кузова (мм): голова, 1-й, 2-й вагон", ["lift0", "lift1", "lift2"], 1000.0),
          ("наклон кузова (градусы)", ["rock0", "rock1", "rock2"], 57.2958), ("люфт сцепки (мм): вагон 1, вагон 2", ["slack1", "slack2"], 1000.0)]
cols = [(240, 200, 90), (120, 200, 240), (240, 120, 120)]
ph = (H - 20) // len(panels)
for pi, (title, keys, k) in enumerate(panels):
    y0 = 10 + pi * ph; y1 = y0 + ph - 28
    d.rectangle([60, y0 + 24, W - 20, y1], outline=(90, 80, 60))
    d.text((64, y0 + 2), title, fill=(245, 236, 214), font=f)
    vals = [[float(r[kk]) * k for r in rows] for kk in keys]
    lo = min(min(v) for v in vals); hi = max(max(v) for v in vals)
    if hi - lo < 1e-6: hi = lo + 1
    pad = (hi - lo) * 0.08; lo -= pad; hi += pad
    for ci, v in enumerate(vals):
        pts = [(60 + (tt / t[-1]) * (W - 80), y1 - (x - lo) / (hi - lo) * (y1 - y0 - 24)) for tt, x in zip(t, v)]
        d.line(pts, fill=cols[ci % 3], width=2)
    d.text((W - 150, y0 + 26), "%.2f … %.2f" % (lo + pad, hi - pad), fill=(200, 190, 160), font=f)
for sec, name in ((8, "разгон → ход"), (15, "ход → торможение")):
    x = 60 + sec / t[-1] * (W - 80)
    d.line([(x, 10), (x, H - 10)], fill=(120, 120, 120)); d.text((x + 4, 10), name, fill=(200, 200, 200), font=f)
im.save(out)
