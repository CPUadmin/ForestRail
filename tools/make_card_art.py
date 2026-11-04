# -*- coding: utf-8 -*-
"""Картины карточек Таро: inbox/P10_tarot_cards/card_NN_имя.png -> ForestRail/assets/art_kazik/cards/<id>.png (900x900).
Запуск: python tools/make_card_art.py   (id берётся из имени файла; wheel_of_fortune и hanged_man в игре зовутся wheel и hanged)."""
import os
import re
import sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "tools", "art_sources", "inbox", "P10_tarot_cards")
DST = os.path.join(ROOT, "ForestRail", "assets", "art_kazik", "cards")
ALIAS = {"wheel_of_fortune": "wheel", "hanged_man": "hanged"}

os.makedirs(DST, exist_ok=True)
done = []
for name in sorted(os.listdir(SRC)):
    m = re.match(r"card_(\d\d)_(.+)\.png$", name)
    if not m:
        continue
    cid = ALIAS.get(m.group(2), m.group(2))
    im = Image.open(os.path.join(SRC, name)).convert("RGB")
    im.thumbnail((900, 900), Image.LANCZOS)
    im.save(os.path.join(DST, cid + ".png"), optimize=True)
    done.append("%s (%dx%d)" % (cid, im.width, im.height))
print("карточек: %d: %s" % (len(done), ", ".join(done)))
