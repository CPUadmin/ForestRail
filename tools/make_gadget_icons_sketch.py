# -*- coding: utf-8 -*-
"""Простые чёрно-белые иконки 18 гаджетов (эскиз для владельца). Рисуем в сетке 100x100, печатаем в 4x и сжимаем."""
import math
import os
import sys
from PIL import Image, ImageDraw, ImageFont

OUT = sys.argv[1]
K = 6            # масштаб суперсэмплинга
CELL = 100
W = 5.0          # толщина линии в единицах 100x100

class Pen:
    def __init__(self):
        self.im = Image.new("L", (CELL * K, CELL * K), 255)
        self.d = ImageDraw.Draw(self.im)
    def p(self, x, y): return (x * K, y * K)
    def line(self, pts, w=W, closed=False):
        pts2 = [self.p(*q) for q in pts]
        if closed: pts2.append(pts2[0])
        self.d.line(pts2, fill=0, width=int(w * K), joint="curve")
        for q in pts2: self.d.ellipse([q[0] - w * K / 2, q[1] - w * K / 2, q[0] + w * K / 2, q[1] + w * K / 2], fill=0)
    def circle(self, x, y, r, w=W, fill=False):
        b = [(x - r) * K, (y - r) * K, (x + r) * K, (y + r) * K]
        if fill: self.d.ellipse(b, fill=0)
        else: self.d.ellipse(b, outline=0, width=int(w * K))
    def poly(self, pts, fill=True, w=W):
        if fill: self.d.polygon([self.p(*q) for q in pts], fill=0)
        else: self.line(pts, w, closed=True)
    def arc(self, x, y, r, a0, a1, w=W):
        b = [(x - r) * K, (y - r) * K, (x + r) * K, (y + r) * K]
        self.d.arc(b, a0, a1, fill=0, width=int(w * K))
    def rect(self, x0, y0, x1, y1, w=W, fill=False):
        if fill: self.d.rectangle([x0 * K, y0 * K, x1 * K, y1 * K], fill=0)
        else: self.d.rectangle([x0 * K, y0 * K, x1 * K, y1 * K], outline=0, width=int(w * K))
    def white_circle(self, x, y, r):
        self.d.ellipse([(x - r) * K, (y - r) * K, (x + r) * K, (y + r) * K], fill=255)
    def done(self): return self.im.resize((CELL * 3, CELL * 3), Image.LANCZOS)

def gear(p, x, y, r, teeth=8, w=W, hole=0.35):
    pts = []
    for i in range(teeth * 2):
        a = math.pi * i / teeth
        rr = r if i % 2 == 0 else r * 0.78
        for da in (-0.5, 0.5):
            aa = a + da * math.pi / teeth * 0.8
            pts.append((x + rr * math.cos(aa), y + rr * math.sin(aa)))
    p.poly(pts, fill=True)
    p.white_circle(x, y, r * hole)

def flame(p, x, y, h, wd):
    pts = [(x, y - h), (x + wd * 0.45, y - h * 0.5), (x + wd * 0.6, y), (x + wd * 0.25, y + h * 0.05), (x, y + h * 0.15), (x - wd * 0.25, y + h * 0.05), (x - wd * 0.6, y), (x - wd * 0.4, y - h * 0.45)]
    p.poly(pts, fill=True)
    p.poly([(x, y - h * 0.45), (x + wd * 0.22, y - h * 0.05), (x, y + h * 0.02), (x - wd * 0.22, y - h * 0.05)], fill=False, w=0)  # nothing
    p.d.polygon([p.p(x, y - h * 0.4), p.p(x + wd * 0.2, y - h * 0.02), p.p(x, y + h * 0.05), p.p(x - wd * 0.2, y - h * 0.02)], fill=255)

ICONS = {}

def icon(name, caption):
    def deco(fn): ICONS[name] = (caption, fn); return fn
    return deco

@icon("pogo", "0 Пого-шест")
def _(p):
    p.line([(50, 8), (50, 40)])                         # шест
    p.line([(40, 12), (60, 12)])                        # рукоять
    zz = [(50, 40)]
    for i in range(6): zz.append((38 if i % 2 == 0 else 62, 44 + i * 6))
    zz.append((50, 82)); p.line(zz, w=4)               # пружина
    p.rect(36, 82, 64, 90, fill=True)                   # башмак
    p.line([(30, 70), (22, 62)], w=3.5); p.line([(70, 70), (78, 62)], w=3.5)  # знаки прыжка

@icon("stoker", "I Механический кочегар")
def _(p):
    p.rect(10, 38, 74, 62, w=4.5)                       # труба шнека
    for i in range(5): p.line([(18 + i * 12, 38), (30 + i * 12, 62)], w=4)  # витки
    p.circle(82, 50, 10, w=4.5)                         # топка
    p.circle(82, 50, 3, fill=True)
    p.line([(10, 50), (4, 50)], w=4)
    for x in (24, 40, 56): p.circle(x, 24, 5, fill=True)  # уголь сверху
    p.line([(24, 31), (24, 36)], w=3); p.line([(40, 31), (40, 36)], w=3); p.line([(56, 31), (56, 36)], w=3)

@icon("vane", "II Флюгер-автопилот")
def _(p):
    p.line([(50, 92), (50, 40)])
    p.poly([(14, 28), (70, 20), (88, 30), (70, 40), (14, 34)], fill=True)
    p.circle(50, 30, 5, fill=False)
    p.line([(36, 92), (64, 92)])
    p.arc(78, 66, 12, 200, 340, w=3.5); p.arc(84, 80, 9, 200, 340, w=3.5)

@icon("cylinder", "III Запасной баллон")
def _(p):
    p.rect(30, 30, 70, 88, w=5)
    p.arc(50, 30, 20, 180, 360, w=5)
    p.rect(44, 8, 56, 18, fill=True)
    p.line([(50, 18), (50, 12)])
    p.line([(56, 12), (70, 12)], w=4)
    p.line([(30, 52), (70, 52)], w=3.5)
    p.line([(30, 66), (70, 66)], w=3.5)

@icon("gearbox", "IV Автоматическая КПП")
def _(p):
    gear(p, 36, 56, 24, 9)
    gear(p, 72, 36, 16, 7)
    p.line([(10, 12), (10, 34)], w=4); p.circle(10, 10, 5, fill=True)   # рычаг
    p.line([(6, 34), (14, 34)], w=4)

@icon("reducer", "V Редуктор")
def _(p):
    p.circle(50, 50, 38, w=5)
    p.arc(50, 50, 28, 200, 340, w=4)
    p.line([(50, 50), (66, 30)], w=5)
    p.circle(50, 50, 6, fill=True)
    for a in range(215, 330, 28):
        q = math.radians(a); p.line([(50 + 30 * math.cos(q), 50 + 30 * math.sin(q)), (50 + 24 * math.cos(q), 50 + 24 * math.sin(q))], w=3)
    p.line([(36, 82), (64, 82)], w=4)

@icon("ratchet", "VI Храповик")
def _(p):
    gear(p, 50, 56, 32, 12, hole=0.45)
    p.line([(50, 8), (50, 22)], w=5)
    p.poly([(50, 30), (36, 20), (64, 20)], fill=True)    # собачка
    p.line([(20, 90), (6, 90)], w=3.5); p.line([(80, 90), (94, 90)], w=3.5)  # стрелки в обе стороны
    p.poly([(6, 90), (13, 85), (13, 95)], fill=True); p.poly([(94, 90), (87, 85), (87, 95)], fill=True)

@icon("supercap", "VII Суперконденсатор")
def _(p):
    p.rect(14, 34, 52, 88, w=5)
    p.rect(22, 24, 44, 34, fill=True)
    p.line([(22, 54), (44, 54)], w=3.5); p.line([(22, 68), (44, 68)], w=3.5)
    p.poly([(82, 10), (62, 46), (76, 46), (66, 90), (94, 40), (78, 40), (90, 10)], fill=True)

@icon("nitro", "VIII Закись азота")
def _(p):
    p.rect(14, 44, 54, 68, w=5)
    p.rect(54, 52, 64, 60, fill=True)
    p.line([(64, 56), (74, 56)], w=4)
    flame(p, 84, 56, 26, 18)
    p.rect(26, 38, 42, 44, fill=True)
    p.line([(8, 78), (60, 78)], w=3.5)

@icon("trimmer", "IX Триммер")
def _(p):
    p.circle(50, 50, 32, w=5)
    for a in range(0, 360, 30):
        q = math.radians(a); p.line([(50 + 32 * math.cos(q), 50 + 32 * math.sin(q)), (50 + 24 * math.cos(q), 50 + 24 * math.sin(q))], w=3)
    p.line([(50, 50), (68, 36)], w=4.5)
    p.circle(50, 50, 5, fill=True)
    p.rect(14, 88, 86, 96, w=3.5); p.circle(58, 92, 3.5, fill=True)   # уровень с пузырьком

@icon("flywheel", "X Маховик-накопитель")
def _(p):
    p.circle(50, 50, 36, w=9)
    p.circle(50, 50, 8, fill=True)
    for a in range(0, 360, 60):
        q = math.radians(a); p.line([(50 + 8 * math.cos(q), 50 + 8 * math.sin(q)), (50 + 32 * math.cos(q), 50 + 32 * math.sin(q))], w=4.5)
    p.arc(50, 50, 46, 300, 40, w=3.5)
    p.poly([(94, 40), (96, 54), (84, 50)], fill=True)

@icon("cooling", "XI Жидкостное охлаждение")
def _(p):
    p.rect(14, 20, 66, 80, w=5)
    for x in (26, 40, 54): p.line([(x, 28), (x, 72)], w=4)
    p.poly([(80, 16), (90, 36), (86, 50), (74, 50), (70, 36)], fill=True)   # капля
    p.line([(70, 66), (92, 66)], w=3.5); p.line([(70, 78), (86, 78)], w=3.5)

@icon("grapple", "XII Кошка с лебёдкой")
def _(p):
    p.line([(50, 6), (50, 40)], w=4.5)
    p.circle(50, 46, 6, w=4)
    p.line([(50, 52), (50, 70)], w=5)
    p.arc(50, 68, 20, 20, 160, w=5)
    p.poly([(30, 76), (24, 64), (36, 66)], fill=True); p.poly([(70, 76), (76, 64), (64, 66)], fill=True)
    p.circle(18, 86, 10, w=4); p.circle(18, 86, 3, fill=True)
    p.line([(28, 86), (44, 86)], w=3)

@icon("parachute", "XIII Двойной парашют")
def _(p):
    p.arc(32, 40, 24, 180, 360, w=5); p.line([(8, 40), (56, 40)], w=3.5)
    p.arc(68, 30, 24, 180, 360, w=5); p.line([(44, 30), (92, 30)], w=3.5)
    for x0, y0, x1, y1 in [(8, 40, 44, 82), (56, 40, 44, 82), (44, 30, 50, 82), (92, 30, 50, 82)]:
        p.line([(x0, y0), (x1, y1)], w=2.5)
    p.rect(40, 82, 56, 94, fill=True)

@icon("superheater", "XIV Пароперегреватель")
def _(p):
    pts = [(10, 22), (70, 22)]
    p.line(pts, w=5)
    p.arc(70, 34, 12, 270, 90, w=5)
    p.line([(70, 46), (30, 46)], w=5)
    p.arc(30, 58, 12, 90, 270, w=5)
    p.line([(30, 70), (70, 70)], w=5)
    p.arc(70, 82, 12, 270, 90, w=5)
    p.line([(70, 94), (90, 94)], w=5)
    p.arc(86, 10, 5, 0, 360, w=3); p.arc(76, 8, 4, 0, 360, w=3)

@icon("afterburner", "XV Форсаж")
def _(p):
    p.poly([(6, 26), (36, 20), (36, 80), (6, 74)], fill=True)
    p.line([(36, 50), (50, 50)], w=4)
    flame(p, 70, 50, 40, 36)
    p.line([(42, 14), (90, 14)], w=3.5); p.line([(46, 88), (92, 88)], w=3.5)

@icon("spinnaker", "XVI Спинакер")
def _(p):
    p.line([(24, 94), (24, 8)], w=5)
    p.poly([(26, 14), (70, 22), (90, 50), (66, 82), (26, 84)], fill=False, w=5)
    p.arc(58, 50, 18, 210, 330, w=3.5)
    p.line([(6, 94), (54, 94)], w=4.5)

@icon("flaps", "XVII Закрылки")
def _(p):
    p.poly([(6, 46), (24, 34), (60, 34), (66, 42), (24, 52)], fill=False, w=5)
    p.poly([(60, 40), (92, 62), (82, 72), (56, 50)], fill=True)
    p.line([(70, 86), (94, 86)], w=3); p.line([(58, 94), (84, 94)], w=3)
    p.arc(34, 22, 8, 200, 340, w=3.5)

def main():
    names = list(ICONS.keys())
    font = None
    for cand in (r"C:\Windows\Fonts\segoeui.ttf", r"C:\Windows\Fonts\arial.ttf"):
        if os.path.exists(cand): font = ImageFont.truetype(cand, 22); break
    cols, rows = 6, 3
    cw, ch = 300, 340
    sheet = Image.new("L", (cols * cw, rows * ch), 255)
    dr = ImageDraw.Draw(sheet)
    for i, n in enumerate(names):
        cap, fn = ICONS[n]
        p = Pen(); fn(p)
        im = p.done()
        x = (i % cols) * cw; y = (i // cols) * ch
        sheet.paste(im, (x, y + 8))
        w = dr.textlength(cap, font=font)
        dr.text((x + (cw - w) / 2, y + 312), cap, fill=0, font=font)
        im.save(os.path.join(OUT, "icon_%02d_%s.png" % (i, n)))
    sheet.save(os.path.join(OUT, "gadget_icons_sheet.png"))
    print("icons:", len(names))

main()
