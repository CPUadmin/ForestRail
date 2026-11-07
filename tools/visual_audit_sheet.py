# -*- coding: utf-8 -*-
# Склеивает кадры probe_visual_audit в листы по машинам (по строке на состояние), чтобы смотреть глазами при увеличении.
# Использование: python tools/visual_audit_sheet.py <папка_со_снимками>
import sys
from pathlib import Path
from PIL import Image
folder = Path(sys.argv[1])
kinds = sorted({p.name.split("_")[0] for p in folder.glob("*_1_day.png")})
for kind in kinds:
    frames = [Image.open(p) for p in sorted(folder.glob(kind + "_?_*.png"))]
    if not frames: continue
    w, h = frames[0].size
    sheet = Image.new("RGB", (w * 2, h * 2))
    for i, f in enumerate(frames[:4]): sheet.paste(f, ((i % 2) * w, (i // 2) * h))
    sheet.save(folder / ("sheet_%s.png" % kind))
    print("sheet", kind)
