# -*- coding: utf-8 -*-
"""Цветные иконки 18 гаджетов (эскиз): значок на плашке, заливка с градиентом, тёмный контур и блик. Сетка 100x100."""
import math
import os
import sys
from PIL import Image, ImageDraw, ImageFont, ImageChops, ImageFilter

OUT = sys.argv[1]
S = 8
N = 100

DARK = (38, 28, 18)
STEEL = (118, 132, 138); STEEL_L = (190, 202, 206); STEEL_D = (66, 78, 84)
BRASS = (196, 154, 72); BRASS_L = (240, 208, 128); BRASS_D = (128, 92, 36)
GREEN = (74, 118, 86); GREEN_L = (122, 168, 120); GREEN_D = (40, 70, 52)
CREAM = (246, 236, 212); CREAM_D = (206, 190, 150)
RED = (206, 70, 50); RED_D = (140, 40, 30)
ORANGE = (244, 150, 46); YELLOW = (255, 224, 96)
BLUE = (84, 156, 214); BLUE_L = (170, 214, 244)
COAL = (52, 50, 56); COAL_L = (104, 100, 110)
WOOD = (156, 104, 56); WOOD_L = (206, 150, 92)

class Canvas:
    def __init__(self):
        self.im = Image.new("RGBA", (N * S, N * S), (0, 0, 0, 0))
    def P(self, pts): return [(x * S, y * S) for x, y in pts]
    def _grad(self, box, c1, c2, vertical=True):
        w, h = int(box[2] - box[0]) + 2, int(box[3] - box[1]) + 2
        g = Image.new("RGBA", (max(w, 2), max(h, 2)))
        px = g.load()
        for y in range(g.height):
            for x in range(g.width):
                t = (y / max(1, g.height - 1)) if vertical else (x / max(1, g.width - 1))
                px[x, y] = tuple(int(c1[i] + (c2[i] - c1[i]) * t) for i in range(3)) + (255,)
        return g, (int(box[0]), int(box[1]))
    def fill_mask(self, mask, box, c1, c2, vertical=True):
        g, pos = self._grad(box, c1, c2, vertical)
        layer = Image.new("RGBA", self.im.size, (0, 0, 0, 0))
        layer.paste(g, pos)
        layer.putalpha(ImageChops.multiply(layer.getchannel("A"), mask))
        self.im.alpha_composite(layer)
    def poly(self, pts, c1, c2=None, ol=True, w=2.2, vertical=True):
        c2 = c2 or c1
        pp = self.P(pts)
        mask = Image.new("L", self.im.size, 0)
        ImageDraw.Draw(mask).polygon(pp, fill=255)
        xs = [p[0] for p in pp]; ys = [p[1] for p in pp]
        self.fill_mask(mask, (min(xs), min(ys), max(xs), max(ys)), c1, c2, vertical)
        if ol: self.line(pts + [pts[0]], DARK, w)
    def circle(self, x, y, r, c1, c2=None, ol=True, w=2.2, vertical=True):
        c2 = c2 or c1
        mask = Image.new("L", self.im.size, 0)
        b = [(x - r) * S, (y - r) * S, (x + r) * S, (y + r) * S]
        ImageDraw.Draw(mask).ellipse(b, fill=255)
        self.fill_mask(mask, b, c1, c2, vertical)
        if ol: ImageDraw.Draw(self.im).ellipse(b, outline=DARK, width=int(w * S))
    def rect(self, x0, y0, x1, y1, c1, c2=None, r=2.0, ol=True, w=2.2, vertical=True):
        c2 = c2 or c1
        mask = Image.new("L", self.im.size, 0)
        b = [x0 * S, y0 * S, x1 * S, y1 * S]
        ImageDraw.Draw(mask).rounded_rectangle(b, radius=r * S, fill=255)
        self.fill_mask(mask, b, c1, c2, vertical)
        if ol: ImageDraw.Draw(self.im).rounded_rectangle(b, radius=r * S, outline=DARK, width=int(w * S))
    def line(self, pts, color=DARK, w=2.2):
        pp = self.P(pts)
        d = ImageDraw.Draw(self.im)
        d.line(pp, fill=color, width=int(w * S), joint="curve")
        for q in (pp[0], pp[-1]):
            d.ellipse([q[0] - w * S / 2, q[1] - w * S / 2, q[0] + w * S / 2, q[1] + w * S / 2], fill=color)
    def arc(self, x, y, r, a0, a1, color=DARK, w=2.2):
        ImageDraw.Draw(self.im).arc([(x - r) * S, (y - r) * S, (x + r) * S, (y + r) * S], a0, a1, fill=color, width=int(w * S))
    def shine(self, x, y, r, a=110):
        layer = Image.new("RGBA", self.im.size, (0, 0, 0, 0))
        ImageDraw.Draw(layer).ellipse([(x - r) * S, (y - r * 0.6) * S, (x + r) * S, (y + r * 0.6) * S], fill=(255, 255, 255, a))
        layer = layer.filter(ImageFilter.GaussianBlur(S * 0.6))
        # clip to what is already drawn
        layer.putalpha(ImageChops.multiply(layer.getchannel("A"), self.im.getchannel("A")))
        self.im.alpha_composite(layer)
    def text_none(self): pass

def gear(c, x, y, r, teeth, c1=BRASS_L, c2=BRASS_D, hole=0.34):
    pts = []
    for i in range(teeth * 2):
        a = math.pi * i / teeth
        rr = r if i % 2 == 0 else r * 0.80
        for da in (-0.42, 0.42):
            aa = a + da * math.pi / teeth
            pts.append((x + rr * math.cos(aa), y + rr * math.sin(aa)))
    c.poly(pts, c1, c2, w=1.8)
    c.circle(x, y, r * hole, STEEL_D, DARK, w=1.6)
    c.shine(x - r * 0.3, y - r * 0.45, r * 0.3, 60)

def flame(c, x, y, h, wd, rotate=0.0):
    def pts(sc, dy=0.0):
        base = [(0, -h), (0.5, -h * 0.55), (0.62, 0.0), (0.3, 0.08), (0, 0.18), (-0.3, 0.08), (-0.62, 0.0), (-0.46, -h * 0.5 / h * 0.9 * h / h)]
        out = []
        for px, py in [(0, -h), (wd * 0.5, -h * 0.5), (wd * 0.62, 0), (wd * 0.3, h * 0.08), (0, h * 0.18), (-wd * 0.3, h * 0.08), (-wd * 0.62, 0), (-wd * 0.46, -h * 0.45)]:
            px, py = px * sc, py * sc + dy
            out.append((x + px * math.cos(rotate) - py * math.sin(rotate), y + px * math.sin(rotate) + py * math.cos(rotate)))
        return out
    c.poly(pts(1.0), RED, ORANGE, w=1.8)
    c.poly(pts(0.66, h * 0.1), ORANGE, YELLOW, ol=False)
    c.poly(pts(0.34, h * 0.2), YELLOW, (255, 250, 210), ol=False)

def cloud(c, x, y, s=1.0):
    for dx, dy, r in ((0, 0, 5), (6, -1, 6), (12, 0, 5), (6, 3, 5)):
        c.circle(x + dx * s, y + dy * s, r * s, CREAM, CREAM_D, w=1.4)

ICONS = []
def icon(caption):
    def deco(fn): ICONS.append((caption, fn)); return fn
    return deco

@icon("0 Пого-шест")
def _(c):
    c.rect(46, 6, 54, 56, STEEL_L, STEEL_D, r=3)
    c.rect(34, 6, 66, 14, WOOD_L, WOOD, r=3)                        # рукоять
    c.rect(40, 52, 60, 58, BRASS_L, BRASS_D, r=2)
    for i in range(6):                                              # витки пружины
        y = 60 + i * 5.2
        c.line([(36, y), (64, y + 3.2)], DARK, 4.6)
        c.line([(36, y), (64, y + 3.2)], STEEL_L if i % 2 else BRASS_L, 2.4)
    c.rect(32, 88, 68, 96, STEEL, STEEL_D, r=3)
    c.arc(22, 84, 9, 200, 340, DARK, 2.4); c.arc(78, 84, 9, 200, 340, DARK, 2.4)

@icon("I Механический кочегар")
def _(c):
    c.rect(8, 44, 72, 70, STEEL, STEEL_D, r=4)                      # корпус шнека
    for i in range(6):
        c.line([(14 + i * 10, 46), (22 + i * 10, 68)], BRASS_D, 4.2)
        c.line([(14 + i * 10, 46), (22 + i * 10, 68)], BRASS_L, 2.2)
    c.shine(30, 48, 14, 90)
    c.poly([(70, 30), (96, 30), (96, 84), (70, 84)], COAL_L, COAL, w=2.0)                 # топка
    c.circle(83, 66, 9, ORANGE, YELLOW, w=1.6)
    c.poly([(20, 36), (60, 36), (54, 24), (26, 24)], GREEN, GREEN_D, w=2.0)           # бункер
    for x, y in ((30, 20), (40, 16), (50, 20), (36, 22)): c.circle(x, y, 4, COAL_L, COAL, w=1.4)
    c.circle(83, 66, 3, YELLOW, w=0, ol=False)

@icon("II Флюгер-автопилот")
def _(c):
    c.rect(47, 38, 53, 94, STEEL, STEEL_D, r=2)
    c.rect(34, 90, 66, 98, WOOD_L, WOOD, r=2)
    c.poly([(8, 26), (60, 16), (88, 30), (60, 44), (8, 34)], RED, RED_D, w=2.0)           # флюгер
    c.circle(50, 30, 6, BRASS_L, BRASS_D, w=1.8)
    c.poly([(8, 26), (8, 34), (22, 30)], CREAM, CREAM_D, w=1.4)
    c.arc(80, 62, 12, 200, 340, BLUE, 3); c.arc(86, 76, 9, 200, 340, BLUE_L, 3); c.arc(18, 62, 10, 200, 340, BLUE_L, 3)

@icon("III Запасной баллон")
def _(c):
    c.rect(28, 28, 72, 92, GREEN, GREEN_D, r=14, vertical=False)
    c.rect(44, 12, 56, 28, BRASS_L, BRASS_D, r=2)
    c.rect(38, 6, 62, 14, BRASS, BRASS_D, r=2)
    c.line([(62, 10), (78, 10), (78, 20)], BRASS_D, 3.4)
    c.rect(28, 50, 72, 56, BRASS, BRASS_D, r=1, w=1.4); c.rect(28, 68, 72, 74, BRASS, BRASS_D, r=1, w=1.4)
    c.circle(50, 38, 8, CREAM, CREAM_D, w=1.6); c.line([(50, 38), (55, 34)], RED_D, 2)
    c.shine(38, 56, 7, 120)

@icon("IV Автоматическая КПП")
def _(c):
    gear(c, 38, 60, 26, 10)
    gear(c, 74, 34, 16, 8, STEEL_L, STEEL_D)
    c.line([(12, 38), (12, 8)], STEEL_D, 4.6); c.line([(12, 38), (12, 8)], STEEL_L, 2.2)
    c.circle(12, 8, 6, RED, RED_D, w=1.8)
    c.rect(4, 36, 24, 42, BRASS, BRASS_D, r=2)

@icon("V Автоматический редуктор")
def _(c):
    c.circle(50, 52, 40, BRASS_L, BRASS_D, w=2.4)
    c.circle(50, 52, 33, CREAM, CREAM_D, w=1.8)
    c.arc(50, 52, 26, 200, 270, RED, 4); c.arc(50, 52, 26, 270, 320, GREEN, 4); c.arc(50, 52, 26, 320, 340, RED, 4)
    for a in range(205, 340, 22):
        q = math.radians(a); c.line([(50 + 29 * math.cos(q), 52 + 29 * math.sin(q)), (50 + 24 * math.cos(q), 52 + 24 * math.sin(q))], DARK, 1.6)
    c.line([(50, 52), (66, 34)], RED_D, 3.6)
    c.circle(50, 52, 5, BRASS_D, DARK, w=1.4)
    c.rect(40, 90, 60, 98, STEEL, STEEL_D, r=2)

@icon("VI Храповик")
def _(c):
    gear(c, 50, 58, 32, 14, STEEL_L, STEEL_D, hole=0.42)
    c.poly([(50, 34), (38, 14), (62, 14)], BRASS_L, BRASS_D, w=2.0)
    c.rect(44, 4, 56, 16, STEEL, STEEL_D, r=2)
    c.poly([(8, 94), (22, 86), (22, 102)], GREEN, GREEN_D, w=1.6)
    c.poly([(92, 94), (78, 86), (78, 102)], GREEN, GREEN_D, w=1.6)
    c.line([(22, 94), (78, 94)], GREEN_D, 2.4)

@icon("VII Суперконденсатор")
def _(c):
    c.rect(10, 38, 58, 90, BLUE, GREEN_D, r=6, vertical=False)
    c.rect(18, 28, 50, 38, STEEL_L, STEEL_D, r=2)
    c.rect(24, 20, 30, 28, BRASS_L, BRASS_D, r=1, w=1.4); c.rect(38, 20, 44, 28, BRASS_L, BRASS_D, r=1, w=1.4)
    c.shine(26, 52, 10, 110)
    c.poly([(84, 6), (60, 50), (74, 50), (62, 94), (94, 40), (78, 40), (92, 6)], YELLOW, ORANGE, w=2.0)

@icon("VIII Закись азота")
def _(c):
    c.rect(10, 38, 58, 74, BLUE_L, BLUE, r=14, vertical=False)
    c.rect(56, 50, 68, 62, BRASS_L, BRASS_D, r=2)
    c.rect(24, 30, 44, 40, STEEL, STEEL_D, r=2)
    c.line([(68, 56), (74, 56)], STEEL_D, 3.4)
    flame(c, 72, 56, 24, 22, rotate=math.pi / 2)
    c.rect(18, 50, 50, 58, CREAM, CREAM_D, r=2, w=1.4)
    c.shine(24, 46, 9, 130)

@icon("IX Триммер")
def _(c):
    c.circle(50, 48, 36, STEEL_L, STEEL_D, w=2.4)
    c.circle(50, 48, 28, CREAM, CREAM_D, w=1.8)
    for a in range(0, 360, 24):
        q = math.radians(a); c.line([(50 + 28 * math.cos(q), 48 + 28 * math.sin(q)), (50 + 22 * math.cos(q), 48 + 22 * math.sin(q))], DARK, 1.4)
    c.line([(50, 48), (66, 34)], RED_D, 3.0)
    c.circle(50, 48, 4.5, BRASS_L, BRASS_D, w=1.4)
    c.rect(14, 88, 86, 98, BRASS_L, BRASS_D, r=5)
    c.rect(24, 90, 76, 96, GREEN_L, GREEN, r=3, w=1.2)
    c.circle(58, 93, 3.2, CREAM, CREAM_D, w=1.2)

@icon("X Маховик-накопитель")
def _(c):
    c.circle(50, 50, 40, STEEL, STEEL_D, w=2.6)
    c.circle(50, 50, 31, GREEN_D, GREEN, w=2.0)
    for a in range(0, 360, 45):
        q = math.radians(a); c.line([(50 + 8 * math.cos(q), 50 + 8 * math.sin(q)), (50 + 30 * math.cos(q), 50 + 30 * math.sin(q))], STEEL_L, 3.6)
    c.circle(50, 50, 10, BRASS_L, BRASS_D, w=2.0)
    c.arc(50, 50, 46, 290, 30, ORANGE, 3.6)
    c.poly([(96, 30), (98, 46), (84, 40)], ORANGE, RED, w=1.4)
    c.shine(38, 28, 14, 90)

@icon("XI Жидкостное охлаждение")
def _(c):
    c.rect(10, 22, 66, 84, BRASS, BRASS_D, r=5)
    for x in range(18, 62, 8): c.rect(x, 28, x + 4, 78, BLUE_L, BLUE, r=1, w=1.0)
    c.rect(4, 30, 12, 44, STEEL, STEEL_D, r=2); c.rect(64, 60, 72, 74, STEEL, STEEL_D, r=2)
    c.poly([(84, 14), (94, 36), (90, 50), (78, 50), (74, 36)], BLUE_L, BLUE, w=1.8)
    c.circle(82, 38, 3, CREAM, w=0, ol=False)
    c.poly([(80, 62), (88, 74), (84, 84), (76, 84), (72, 74)], BLUE_L, BLUE, w=1.4)

@icon("XII Кошка с лебёдкой")
def _(c):
    c.line([(50, 4), (50, 46)], BRASS_D, 4.6); c.line([(50, 4), (50, 46)], BRASS_L, 2.4)
    c.circle(50, 50, 6, STEEL_L, STEEL_D, w=1.8)
    c.line([(50, 56), (50, 70)], STEEL_D, 6); c.line([(50, 56), (50, 70)], STEEL_L, 3)
    c.arc(50, 70, 18, 20, 160, DARK, 6.4); c.arc(50, 70, 18, 20, 160, STEEL_L, 3.4)
    c.poly([(30, 76), (22, 62), (36, 66)], STEEL_L, STEEL_D, w=1.8)
    c.poly([(70, 76), (78, 62), (64, 66)], STEEL_L, STEEL_D, w=1.8)
    c.rect(66, 78, 96, 98, WOOD_L, WOOD, r=3)
    for x in (72, 80, 88): c.line([(x, 80), (x, 96)], WOOD, 1.6)
    c.line([(66, 88), (54, 88), (50, 56)], BRASS_D, 2.4)

@icon("XIII Двойной парашют")
def _(c):
    c.poly([(8, 42), (14, 22), (30, 12), (46, 22), (52, 42)], RED, RED_D, w=2.0)
    c.poly([(48, 36), (54, 16), (70, 6), (86, 16), (92, 36)], CREAM, CREAM_D, w=2.0)
    for p in ((8, 42, 44, 84), (52, 42, 44, 84), (48, 36, 52, 84), (92, 36, 52, 84)):
        c.line([(p[0], p[1]), (p[2], p[3])], DARK, 1.8)
    c.rect(38, 82, 58, 98, GREEN, GREEN_D, r=3)
    c.circle(48, 90, 3, BRASS_L, w=0, ol=False)

@icon("XIV Пароперегреватель")
def _(c):
    for i, y in enumerate((22, 46, 70)):
        c.line([(14, y), (66, y)], DARK, 8.6); c.line([(14, y), (66, y)], BRASS, 5.8); c.line([(14, y - 1.2), (66, y - 1.2)], BRASS_L, 1.8)
        if i < 2:
            sign = 1 if i == 0 else -1
            x = 66 if i == 0 else 14
            c.arc(x, y + 12, 12, 270 if i == 0 else 90, 90 if i == 0 else 270, DARK, 8.6)
            c.arc(x, y + 12, 12, 270 if i == 0 else 90, 90 if i == 0 else 270, BRASS, 5.8)
    c.line([(66, 70), (92, 70)], DARK, 8.6); c.line([(66, 70), (92, 70)], BRASS, 5.8)
    cloud(c, 66, 88, 0.9)
    c.rect(6, 14, 14, 78, STEEL, STEEL_D, r=2)

@icon("XV Форсаж")
def _(c):
    c.poly([(4, 24), (40, 14), (40, 86), (4, 76)], STEEL, STEEL_D, w=2.2, vertical=False)
    c.poly([(8, 30), (36, 24), (36, 76), (8, 70)], COAL_L, COAL, w=1.8)
    flame(c, 54, 50, 40, 36, rotate=math.pi / 2)
    c.line([(40, 50), (56, 50)], YELLOW, 4)

@icon("XVI Спинакер")
def _(c):
    c.rect(22, 4, 28, 94, WOOD_L, WOOD, r=2)
    c.poly([(30, 8), (62, 12), (88, 34), (92, 58), (70, 80), (30, 84)], RED, RED_D, w=2.2, vertical=False)
    c.poly([(30, 8), (46, 10), (50, 84), (30, 84)], CREAM, CREAM_D, ol=False)
    c.arc(60, 52, 22, 200, 330, CREAM, 3)
    c.rect(4, 90, 60, 98, WOOD_L, WOOD, r=3)
    c.line([(30, 84), (14, 92)], DARK, 1.8)

@icon("XVII Закрылки")
def _(c):
    c.poly([(6, 48), (22, 32), (64, 32), (72, 44), (22, 54)], STEEL_L, STEEL_D, w=2.2)
    c.poly([(62, 40), (94, 66), (84, 76), (54, 52)], BRASS_L, BRASS_D, w=2.2)
    c.line([(70, 56), (66, 62)], DARK, 2)
    c.arc(34, 20, 10, 200, 340, BLUE_L, 3); c.arc(46, 12, 8, 200, 340, BLUE_L, 3)
    c.arc(76, 92, 12, 190, 350, BLUE, 3)
    c.circle(30, 44, 3.5, RED, RED_D, w=1.2)

def badge(icon_img):
    t = 400
    tile = Image.new("RGBA", (t, t), (0, 0, 0, 0))
    d = ImageDraw.Draw(tile)
    d.rounded_rectangle([4, 4, t - 4, t - 4], radius=46, fill=GREEN_D, outline=BRASS, width=8)
    d.rounded_rectangle([20, 20, t - 20, t - 20], radius=34, outline=BRASS_D, width=3)
    inner = icon_img.resize((int(t * 0.78), int(t * 0.78)), Image.LANCZOS)
    tile.alpha_composite(inner, ((t - inner.width) // 2, (t - inner.height) // 2))
    return tile

def main():
    font = None
    for cand in (r"C:\Windows\Fonts\segoeui.ttf", r"C:\Windows\Fonts\arial.ttf"):
        if os.path.exists(cand): font = ImageFont.truetype(cand, 24); break
    cols, rows = 6, 3
    cw, ch = 330, 460
    sheet = Image.new("RGB", (cols * cw, rows * ch), (24, 18, 12))
    dr = ImageDraw.Draw(sheet)
    for i, (cap, fn) in enumerate(ICONS):
        c = Canvas(); fn(c)
        b = badge(c.im)
        x = (i % cols) * cw + (cw - 400) // 2 + 0; y = (i // cols) * ch + 8
        scaled = b.resize((310, 310), Image.LANCZOS)
        sheet.paste(scaled, ((i % cols) * cw + 10, (i // cols) * ch + 10), scaled)
        w = dr.textlength(cap, font=font)
        dr.text(((i % cols) * cw + (cw - w) / 2, (i // cols) * ch + 335), cap, fill=(245, 236, 214), font=font)
        c.im.resize((256, 256), Image.LANCZOS).save(os.path.join(OUT, "icon_%02d.png" % i))
    sheet.save(os.path.join(OUT, "gadget_icons_color_sheet.png"))
    print("icons:", len(ICONS))

main()
