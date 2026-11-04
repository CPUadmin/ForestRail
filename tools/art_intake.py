#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Приёмка картинок от GPT для «Лесной колеи» (Веха 9, В9.4).

Папки в tools/art_sources/:
  briefs/<пакет>/    комплект для GPT (BRIEF_RU.md, кадры-образцы, PROMPTS_FOR_GPT.txt)
  inbox/<пакет>/     сюда владелец кладёт файлы от GPT (любые имена в inbox/_unsorted/)
  accepted/<пакет>/  результат: вырезанный фон, обрезка, листы нарезаны на ячейки
  rejected/<пакет>/  что вернули и почему (reason.txt)
  reports/           отчёты приёмки и контактные листы
  art_tracker.json   статусы всех картинок

Команды:
  python tools/art_intake.py status
  python tools/art_intake.py scan [пакет]       проверить входящие, ничего не менять
  python tools/art_intake.py process [пакет]    вырезать фон, обрезать, нарезать листы, обновить трекер
  python tools/art_intake.py prompts <пакет>    собрать briefs/<пакет>/PROMPTS_FOR_GPT.txt из BRIEF_RU.md
  python tools/art_intake.py assign <файл из _unsorted> <id картинки>   положить файл под ожидаемым именем
  python tools/art_intake.py accept <id> | reject <id> "причина"
"""
import argparse
import datetime
import json
import re
import shutil
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
DEFAULT_ROOT = HERE / "art_sources"
IMG_EXT = {".png", ".jpg", ".jpeg", ".webp"}
FORMATS = {"1:1": 1.0, "3:2": 1.5, "2:3": 2.0 / 3.0}
MARGIN_WARN = 0.03          # доля стороны: ближе к краю считаем «обрезано»
KEY_NEAR, KEY_FAR = 70.0, 150.0   # расстояние до цвета ключа: ниже полностью прозрачно, выше полностью видно


# ---------------------------------------------------------------- tracker
def load_tracker(root):
    p = root / "art_tracker.json"
    return json.loads(p.read_text(encoding="utf-8")) if p.exists() else {"schema": 1, "packages": {}, "assets": []}


def save_tracker(root, tr):
    (root / "art_tracker.json").write_text(json.dumps(tr, ensure_ascii=False, indent=1) + "\n", encoding="utf-8", newline="\n")


def assets_of(tr, pkg):
    return [a for a in tr["assets"] if pkg is None or a["package"] == pkg]


def packages_of(tr, pkg):
    return [pkg] if pkg else sorted({a["package"] for a in tr["assets"]})


def pkg_dir_name(tr, pkg):
    # папка пакета берётся из пути inbox в трекере: tools/art_sources/inbox/P2_pole_sail/
    info = tr.get("packages", {}).get(pkg, {})
    inbox = info.get("inbox", "")
    return Path(inbox.rstrip("/")).name if inbox else pkg


# ---------------------------------------------------------------- image helpers
def load_rgba(path):
    im = Image.open(path)
    im.load()
    return im.convert("RGBA")


def border_pixels(arr, frac=0.02, top_only=False):
    h, w = arr.shape[:2]
    t = max(2, int(min(h, w) * frac))
    # a tile has the ground at the bottom and the sides, so only its top edge shows the background
    parts = [arr[:t, :, :]] if top_only else [arr[:t, :, :], arr[-t:, :, :], arr[:, :t, :], arr[:, -t:, :]]
    return np.concatenate([p.reshape(-1, p.shape[2]) for p in parts], axis=0)


def detect_background(arr, top_only=False):
    """transparent / magenta / black / other, плюс признак «шахматки» вместо прозрачности."""
    b = border_pixels(arr, top_only=top_only)
    rgb = b[:, :3].astype(np.int32)
    alpha = b[:, 3]
    if (alpha < 16).mean() > 0.9:
        return "transparent", False
    magenta = ((rgb[:, 0] > 200) & (rgb[:, 2] > 200) & (rgb[:, 1] < 90)).mean()
    if magenta > 0.9:
        return "magenta", False
    black = (rgb.max(axis=1) < 24).mean()
    if black > 0.9:
        return "black", False
    # шахматка: в углу два серых уровня (светлый и чуть темнее), чередующиеся квадратами
    h, w = arr.shape[:2]
    patch = arr[:min(56, h // 3), :min(56, w // 3), :3].astype(np.int32)
    gray = patch.mean(axis=2)
    neutral = np.abs(patch[:, :, 0] - patch[:, :, 2]).mean() < 5 and np.abs(patch[:, :, 0] - patch[:, :, 1]).mean() < 5
    q = (gray / 8).astype(int)
    vals, counts = np.unique(q, return_counts=True)
    order = np.argsort(counts)[::-1]
    top2 = counts[order[:2]].sum() / counts.sum()
    gap = abs(int(vals[order[0]]) - int(vals[order[1]])) * 8 if len(vals) > 1 else 0
    flips = np.abs(np.diff((gray > gray.mean()).astype(int), axis=1)).mean() if gray.size else 0
    checker = bool(neutral and len(vals) > 1 and top2 > 0.9 and 8 <= gap <= 90 and flips > 0.01)
    return "other", bool(checker)


def key_alpha(arr, kind):
    rgb = arr[:, :, :3].astype(np.float32)
    if kind == "magenta":
        d = np.sqrt((rgb[:, :, 0] - 255) ** 2 + rgb[:, :, 1] ** 2 + (rgb[:, :, 2] - 255) ** 2)
        a = np.clip((d - KEY_NEAR) / (KEY_FAR - KEY_NEAR), 0.0, 1.0)
    elif kind == "black":
        a = np.clip(rgb.max(axis=2) / 255.0 * 1.15, 0.0, 1.0)
    else:
        a = arr[:, :, 3].astype(np.float32) / 255.0
    return a


def dilate(mask, n):
    out = mask.copy()
    for _ in range(n):
        p = np.pad(out, 1, mode="edge")
        out = out | p[:-2, 1:-1] | p[2:, 1:-1] | p[1:-1, :-2] | p[1:-1, 2:]
    return out


def apply_key(img, kind):
    """Возвращает RGBA с вырезанным фоном. magenta: альфа по расстоянию + снятие розовой каймы; black: свет в альфу."""
    arr = np.array(img.convert("RGBA"))
    if kind in ("transparent", "other", "full-bleed"):
        return Image.fromarray(arr, "RGBA")
    a = key_alpha(arr, kind)
    rgb = arr[:, :, :3].astype(np.float32)
    if kind == "magenta":
        edge = dilate(a < 0.98, 3)
        spill = np.maximum(0.0, np.minimum(rgb[:, :, 0], rgb[:, :, 2]) - rgb[:, :, 1])
        k = np.where(edge, 0.9, 0.0)
        rgb[:, :, 0] -= spill * k
        rgb[:, :, 2] -= spill * k
    else:
        safe = np.maximum(a, 1e-3)[:, :, None]
        rgb = np.clip(rgb / safe, 0, 255)
    out = np.dstack([np.clip(rgb, 0, 255), a * 255.0]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def content_bbox(rgba, thr=12):
    a = np.array(rgba)[:, :, 3]
    ys, xs = np.where(a > thr)
    if len(xs) == 0:
        return None
    return xs.min(), ys.min(), xs.max() + 1, ys.max() + 1


def trim(rgba, pad=4):
    box = content_bbox(rgba)
    if box is None:
        return rgba
    x0, y0, x1, y1 = box
    w, h = rgba.size
    return rgba.crop((max(0, x0 - pad), max(0, y0 - pad), min(w, x1 + pad), min(h, y1 + pad)))


def touches_edge(rgba, frac=MARGIN_WARN):
    box = content_bbox(rgba)
    if box is None:
        return False
    w, h = rgba.size
    x0, y0, x1, y1 = box
    return x0 < w * frac or y0 < h * frac or x1 > w * (1 - frac) or y1 > h * (1 - frac)


def seam_ratio(rgba):
    """Насколько левый и правый края различаются по сравнению с обычным соседним столбцом (чем больше, тем заметнее шов)."""
    a = np.array(rgba).astype(np.float32)
    w = a.shape[1]
    edge = np.abs(a[:, 0, :] - a[:, -1, :]).mean()
    adj = np.abs(a[:, w // 2, :] - a[:, w // 2 + 1, :]).mean()
    return float(edge), float(adj)


def make_seamless(rgba, frac=0.06):
    """Сглаживает шов бесшовного тайла: последние k столбцов плавно переходят в первые, ширина уменьшается на k."""
    a = np.array(rgba).astype(np.float32)
    h, w = a.shape[:2]
    k = max(2, int(w * frac))
    out = a[:, : w - k].copy()
    for i in range(k):
        t = i / k
        out[:, i] = a[:, w - k + i] * (1 - t) + a[:, i] * t
    return Image.fromarray(np.clip(out, 0, 255).astype(np.uint8), "RGBA")


def format_ok(size, fmt):
    if fmt not in FORMATS:
        return True
    ratio = size[0] / size[1]
    return abs(ratio - FORMATS[fmt]) / FORMATS[fmt] < 0.08


def cells(rgba, cols, rows):
    w, h = rgba.size
    cw, ch = w / cols, h / rows
    out = []
    for r in range(rows):
        for c in range(cols):
            out.append(((r, c), rgba.crop((int(c * cw), int(r * ch), int((c + 1) * cw), int((r + 1) * ch)))))
    return out


# ---------------------------------------------------------------- scan / process
def find_file(inbox, name):
    stem = Path(name).stem.lower()
    cands = []
    if inbox.exists():
        for p in inbox.iterdir():
            if p.is_file() and p.suffix.lower() in IMG_EXT and p.stem.lower() == stem:
                cands.append(p)
    # самый новый, PNG предпочтительнее
    cands.sort(key=lambda p: (p.suffix.lower() == ".png", p.stat().st_mtime), reverse=True)
    return cands[0] if cands else None


def check_asset(asset, path):
    notes = []
    img = load_rgba(path)
    arr = np.array(img)
    bg, checker = detect_background(arr, top_only=bool(asset.get("tile")))
    want = asset.get("background", "magenta")
    info = {"size": list(img.size), "background": bg}
    if checker:
        notes.append("ПРОБЛЕМА: вместо прозрачности нарисована шахматка; просить плоский пурпурный фон")
    if want in ("magenta", "black", "transparent") and bg != want and not checker:
        if bg == "transparent" and want in ("magenta", "black"):
            pass  # прозрачный лучше, чем ожидали
        else:
            notes.append("ПРОБЛЕМА: фон «%s», ожидали «%s»" % (bg, want))
    if not format_ok(img.size, asset.get("format", "")):
        notes.append("ПРЕДУПРЕЖДЕНИЕ: пропорция %dx%d не %s" % (img.size[0], img.size[1], asset.get("format")))
    keyed = apply_key(img, bg if bg in ("magenta", "black", "transparent") else "other")
    sheet = asset.get("sheet")
    if asset.get("tile"):
        edge, adj = seam_ratio(keyed)
        if edge > 2.0 * adj + 8.0:
            keyed = make_seamless(keyed)
            notes.append("ШОВ был заметен (край %.0f против соседнего %.0f), сглажен, ширина уменьшена на 6%%" % (edge, adj))
        else:
            notes.append("шов тайла в порядке")
    if bg in ("magenta", "black", "transparent") and want != "full-bleed":
        if sheet:
            empty = []
            touch = []
            for (r, c), cell in cells(keyed, sheet["cols"], sheet["rows"]):
                if content_bbox(cell) is None:
                    empty.append("%d,%d" % (r + 1, c + 1))
                elif touches_edge(cell, 0.02):
                    touch.append("%d,%d" % (r + 1, c + 1))
            if empty:
                notes.append("ПРОБЛЕМА: пустые ячейки листа (ряд,колонка): " + "; ".join(empty))
            if touch:
                notes.append("ПРЕДУПРЕЖДЕНИЕ: предмет упирается в край ячейки: " + "; ".join(touch))
        elif touches_edge(keyed) and not asset.get("tile"):
            notes.append("ПРЕДУПРЕЖДЕНИЕ: предмет близко к краю кадра, возможно обрезан")
    info["notes"] = notes
    return info, keyed


def write_outputs(asset, keyed, out_dir):
    out_dir.mkdir(parents=True, exist_ok=True)
    stem = Path(asset["file"]).stem
    written = []
    if asset.get("background") == "full-bleed":
        p = out_dir / (stem + ".png")
        keyed.convert("RGB").save(p)
        return [p]
    sheet = asset.get("sheet")
    if sheet:
        p = out_dir / (stem + "_sheet.png")
        keyed.save(p)
        written.append(p)
        cdir = out_dir / stem
        cdir.mkdir(exist_ok=True)
        for (r, c), cell in cells(keyed, sheet["cols"], sheet["rows"]):
            t = trim(cell)
            if content_bbox(t) is None:
                continue
            q = cdir / ("cell_%d_%d.png" % (r + 1, c + 1))
            t.save(q)
            written.append(q)
    else:
        p = out_dir / (stem + ".png")
        trim(keyed).save(p)
        written.append(p)
    return written


def contact_sheet(items, out, thumb=360):
    """items: [(подпись, RGBA)], фон серый, чтобы видеть прозрачность."""
    if not items:
        return
    cols = min(4, len(items))
    rows = (len(items) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * thumb, rows * (thumb + 18)), (118, 118, 118))
    d = ImageDraw.Draw(sheet)
    for i, (label, im) in enumerate(items):
        t = im.copy()
        t.thumbnail((thumb - 8, thumb - 8))
        bg = Image.new("RGBA", t.size, (118, 118, 118, 255))
        bg.alpha_composite(t.convert("RGBA"))
        x, y = (i % cols) * thumb, (i // cols) * (thumb + 18)
        sheet.paste(bg.convert("RGB"), (x + 4, y + 18))
        d.text((x + 4, y + 3), label[:48], fill=(255, 255, 0))
    out.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out, quality=85)


def cmd_status(root, tr, _):
    print("%-8s %-24s %-14s %-12s %s" % ("id", "файл", "статус", "фон", "замечания"))
    for a in tr["assets"]:
        print("%-8s %-24s %-14s %-12s %s" % (a["id"], a["file"], a["status"], a.get("background", ""), "; ".join(a.get("notes", []))[:60]))


def cmd_scan(root, tr, pkg, apply=False):
    stamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    lines = []
    total_new = 0
    for p in packages_of(tr, pkg):
        folder = pkg_dir_name(tr, p)
        inbox = root / "inbox" / folder
        unsorted = root / "inbox" / "_unsorted"
        items = []
        lines.append("## Пакет %s (%s)\n" % (p, folder))
        lines.append("| id | файл | найден | размер | фон | замечания |\n|---|---|---|---|---|---|")
        for a in assets_of(tr, p):
            f = find_file(inbox, a["file"])
            if f is None:
                lines.append("| %s | %s | нет | | | ждём |" % (a["id"], a["file"]))
                continue
            info, keyed = check_asset(a, f)
            total_new += 1
            lines.append("| %s | %s | %s | %dx%d | %s | %s |" % (a["id"], a["file"], f.name, info["size"][0], info["size"][1], info["background"], "; ".join(info["notes"]) or "в порядке"))
            items.append((a["id"] + " " + a["file"], load_rgba(f)))
            if apply:
                out = root / "accepted" / folder
                paths = write_outputs(a, keyed, out)
                items.append((a["id"] + " (cut)", Image.open(paths[0]).convert("RGBA")))
                a["status"] = "получено" if not any(n.startswith("ПРОБЛЕМА") for n in info["notes"]) else "получено с проблемами"
                a["notes"] = info["notes"]
                a["received"] = datetime.datetime.now().strftime("%Y-%m-%d %H:%M")
                a["outputs"] = [str(x.relative_to(root)).replace("\\", "/") for x in paths]
        lines.append("")
        if unsorted.exists():
            extra = [x.name for x in unsorted.iterdir() if x.is_file() and x.suffix.lower() in IMG_EXT]
            if extra:
                lines.append("Неразобранные файлы в `inbox/_unsorted/`: " + ", ".join(extra) + ". Привязать: `art_intake.py assign <файл> <id>`.\n")
        stray = [x.name for x in inbox.iterdir()] if inbox.exists() else []
        known = {Path(a["file"]).stem.lower() for a in assets_of(tr, p)}
        unknown = [n for n in stray if Path(n).suffix.lower() in IMG_EXT and Path(n).stem.lower() not in known]
        if unknown:
            lines.append("Файлы в inbox с неожиданными именами: " + ", ".join(unknown) + ".\n")
        if items:
            contact_sheet(items, root / "reports" / ("%s_%s_contact.jpg" % (folder, stamp)))
    text = "\n".join(lines)
    print(text)
    if apply:
        rep = root / "reports" / ("%s_%s.md" % (pkg or "all", stamp))
        rep.parent.mkdir(parents=True, exist_ok=True)
        rep.write_text("# Отчёт приёмки %s\n\n%s\n" % (stamp, text), encoding="utf-8", newline="\n")
        save_tracker(root, tr)
        print("Отчёт:", rep)
    return total_new


def cmd_prompts(root, tr, pkg, base_url):
    folder = pkg_dir_name(tr, pkg)
    brief = root / "briefs" / folder / "BRIEF_RU.md"
    text = brief.read_text(encoding="utf-8")
    blocks = re.findall(r"```text\n(.*?)```", text, re.S)
    heads = re.findall(r"^###? (A\d+[^\n]*)$", text, re.M)
    out = ["ПРОМПТЫ ДЛЯ GPT: пакет %s. Копируйте блок целиком. Сначала блок 0, затем по одному." % pkg, ""]
    out.append("=== 0. Первое сообщение (приложите все файлы ref_* из этой папки) ===\n")
    out.append(blocks[0].strip() + "\n")
    for i, b in enumerate(blocks[1:]):
        title = heads[i] if i < len(heads) else "Картинка %d" % (i + 1)
        out.append("=== %s ===\n" % title)
        out.append(b.strip() + "\n")
    dst = root / "briefs" / folder / "PROMPTS_FOR_GPT.txt"
    dst.write_text("\n".join(out), encoding="utf-8", newline="\n")
    print("Записано:", dst, "(%d блоков)" % len(blocks))
    # одно самодостаточное задание на английском: его можно открыть по ссылке или вставить целиком
    info = tr.get("packages", {}).get(pkg, {})
    refs = sorted(x.name for x in (root / "briefs" / folder).iterdir() if x.name.startswith("ref_"))
    assets = assets_of(tr, pkg)
    lines = ["# TASK FOR GPT: pack %s (%s)\n" % (pkg, info.get("name", ""))]
    lines.append("You are the art generator for \"Лесная колея\" (Forest Rail), a cozy 2D side-view narrow-gauge forest railway game. Produce the images below ONE BY ONE, one finished image per message, following the style rules in the project instructions (hand-painted painterly look, warm and slightly worn, forest green #466c51, charcoal steel #29383b, honey wood, cream #f5ecd6, aged brass #bb964f, soft light from the upper left, strict flat side view, no letters or numbers, subject centered with margins, flat pure magenta #FF00FF background unless another is named, no shadows or glow touching the background).\n")
    lines.append("## References\nOpen each reference (or use the files the owner attached). The two ref_style_* images are the STYLE ANCHORS; match them exactly.\n")
    lines.append("If you read the repository through a GitHub connection, the same files are in the repo at tools/art_sources/briefs/%s/ :\n" % folder)
    for r in refs:
        lines.append("- tools/art_sources/briefs/%s/%s" % (folder, r))
    lines.append("\nIf the repository is public, the direct links are:\n")
    for r in refs:
        lines.append("- %s/briefs/%s/%s" % (base_url, folder, r))
    lines.append("\n## First message of the pack\n")
    lines.append("```text\n" + blocks[0].strip() + "\n```\n")
    lines.append("## Images\n")
    for i, b in enumerate(blocks[1:]):
        a = assets[i] if i < len(assets) else {"file": "image_%d.png" % (i + 1), "format": "", "background": ""}
        lines.append("### %d. %s\n\nFormat: %s. Background: %s.\n\n```text\n%s\n```\n" % (i + 1, a["file"], a.get("format", ""), a.get("background", ""), b.strip()))
    lines.append("## Delivery\nAfter each image say its exact file name (as above) and which background you used. When all are done, list the file names in order. The owner saves them into `tools/art_sources/inbox/%s/` with exactly these names. If an image fails the checks in the brief (letters, shadows, cropped subject, checkerboard instead of a flat background), redo it once before showing it.\n" % folder)
    task = root / "briefs" / folder / "TASK_FOR_GPT.md"
    task.write_text("\n".join(lines), encoding="utf-8", newline="\n")
    print("Записано:", task)


def cmd_assign(root, tr, args):
    src, asset_id = args
    asset = next((a for a in tr["assets"] if a["id"] == asset_id), None)
    if asset is None:
        sys.exit("нет такого id: " + asset_id)
    folder = pkg_dir_name(tr, asset["package"])
    p = Path(src)
    if not p.exists():
        p = root / "inbox" / "_unsorted" / src
    if not p.exists():
        sys.exit("нет файла: " + src)
    dst = root / "inbox" / folder / (Path(asset["file"]).stem + p.suffix.lower())
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.move(str(p), str(dst))
    print("Перенесён:", dst)


def cmd_mark(root, tr, status, args):
    asset = next((a for a in tr["assets"] if a["id"] == args[0]), None)
    if asset is None:
        sys.exit("нет такого id: " + args[0])
    asset["status"] = status
    if status == "отклонено":
        reason = args[1] if len(args) > 1 else ""
        asset["note"] = reason
        folder = pkg_dir_name(tr, asset["package"])
        rej = root / "rejected" / folder
        rej.mkdir(parents=True, exist_ok=True)
        f = find_file(root / "inbox" / folder, asset["file"])
        if f:
            shutil.copy2(f, rej / f.name)
        with (rej / "reason.txt").open("a", encoding="utf-8", newline="\n") as fh:
            fh.write("%s %s: %s\n" % (datetime.datetime.now().strftime("%Y-%m-%d %H:%M"), asset["file"], reason))
    save_tracker(root, tr)
    print(asset["id"], "->", status)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("cmd", choices=["status", "scan", "process", "prompts", "assign", "accept", "reject"])
    ap.add_argument("args", nargs="*")
    ap.add_argument("--root", default=str(DEFAULT_ROOT))
    ap.add_argument("--base-url", default="https://raw.githubusercontent.com/CPUadmin/ForestRail/main/tools/art_sources")
    ns = ap.parse_args()
    root = Path(ns.root)
    tr = load_tracker(root)
    if ns.cmd == "status":
        cmd_status(root, tr, None)
    elif ns.cmd == "scan":
        cmd_scan(root, tr, ns.args[0] if ns.args else None, apply=False)
    elif ns.cmd == "process":
        cmd_scan(root, tr, ns.args[0] if ns.args else None, apply=True)
    elif ns.cmd == "prompts":
        cmd_prompts(root, tr, ns.args[0], ns.base_url)
    elif ns.cmd == "assign":
        cmd_assign(root, tr, ns.args)
    elif ns.cmd == "accept":
        cmd_mark(root, tr, "принято", ns.args)
    elif ns.cmd == "reject":
        cmd_mark(root, tr, "отклонено", ns.args)


if __name__ == "__main__":
    main()
