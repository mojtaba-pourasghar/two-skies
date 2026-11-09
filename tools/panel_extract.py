#!/usr/bin/env python3
"""استخراج پنل‌های برق‌دار فیروزه‌ای از تصویر اتاق (REQ-027 بند ۲، گام ۵۳).

مدیر هنر ماسک رنگی نمی‌کشد و خواسته پنل‌ها **از خود تصویر** درآیند:

    آستانهٔ فیروزه‌ای روشن → مؤلفه‌های همبند → چهارضلعی هر پنل

خروجی دو چیز است:
  ۱. چندضلعی خطر هر پنل در `game/rooms/<room>.json` (جای ماسک دستی تقریبی)
  ۲. تصویر ماسک نرم `game/rooms/masks/<room>/panel_cyan_components.png`
     که نورهای `clip_mask: panel_cyan_components` نقشهٔ افکت با آن بریده
     می‌شوند (نور فقط روی پنل، نه کف تاریک بین پنل‌ها).

فقط داخل ناحیهٔ قابل‌راه‌رفتن جست‌وجو می‌شود: سیم‌پیچ‌های تسلای فیروزه‌ای
روی دیوارها خطر کف نیستند.

    python3 -I tools/panel_extract.py c3_electric_hall           # پیش‌نمایش
    python3 -I tools/panel_extract.py c3_electric_hall --write   # نوشتن
"""

from __future__ import annotations

import json
import math
import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent
ROOMS = ROOT / "game" / "rooms"
ASSETS = ROOT / "game" / "assets"
SHOTS = ROOT / "game" / "docs_screens"

# فیروزه‌ای روشن: سبز و آبی بالا، قرمز پایین، و سبز/آبی هر دو خیلی بیشتر از قرمز
MIN_GB = 150
MAX_R = 150
MIN_GAP = 60
# پنل کوچک‌تر از این لکهٔ نور است نه پنل
MIN_AREA = 600
MASK_BLUR = 3


def cyan_mask(img: Image.Image) -> np.ndarray:
    a = np.asarray(img.convert("RGB")).astype(np.int32)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    return (g >= MIN_GB) & (b >= MIN_GB + 10) & (r <= MAX_R) & (g - r >= MIN_GAP) & (b - r >= MIN_GAP)


def walk_mask(room: dict, size: tuple[int, int]) -> np.ndarray:
    m = Image.new("L", size, 0)
    d = ImageDraw.Draw(m)
    for poly in room.get("walkable", []):
        d.polygon(list(zip(poly[0::2], poly[1::2])), fill=255)
    for poly in room.get("blocked", []):
        d.polygon(list(zip(poly[0::2], poly[1::2])), fill=0)
    return np.asarray(m) > 0


def components(mask: np.ndarray) -> list[list[tuple[int, int]]]:
    h, w = mask.shape
    seen = np.zeros_like(mask, dtype=bool)
    out = []
    ys, xs = np.nonzero(mask)
    for y0, x0 in zip(ys, xs):
        if seen[y0, x0]:
            continue
        q = deque([(y0, x0)])
        seen[y0, x0] = True
        comp = []
        while q:
            y, x = q.popleft()
            comp.append((x, y))
            for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                ny, nx = y + dy, x + dx
                if 0 <= ny < h and 0 <= nx < w and mask[ny, nx] and not seen[ny, nx]:
                    seen[ny, nx] = True
                    q.append((ny, nx))
        out.append(comp)
    return out


def hull(points: list[tuple[int, int]]) -> list[tuple[int, int]]:
    pts = sorted(set(points))
    if len(pts) <= 2:
        return pts

    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])

    lower, upper = [], []
    for p in pts:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    return lower[:-1] + upper[:-1]


def min_area_quad(points: list[tuple[int, int]]) -> list[tuple[float, float]]:
    """کوچک‌ترین مستطیل چرخیده دور پوستهٔ محدب (کالیپر چرخان)."""
    h = hull(points)
    best = None
    for i in range(len(h)):
        x1, y1 = h[i]
        x2, y2 = h[(i + 1) % len(h)]
        ang = math.atan2(y2 - y1, x2 - x1)
        c, s = math.cos(-ang), math.sin(-ang)
        rx = [x * c - y * s for x, y in h]
        ry = [x * s + y * c for x, y in h]
        area = (max(rx) - min(rx)) * (max(ry) - min(ry))
        if best is None or area < best[0]:
            best = (area, ang, min(rx), max(rx), min(ry), max(ry))
    _, ang, x0, x1, y0, y1 = best
    c, s = math.cos(ang), math.sin(ang)
    corners = [(x0, y0), (x1, y0), (x1, y1), (x0, y1)]
    return [(x * c - y * s, x * s + y * c) for x, y in corners]


def extract(room_id: str) -> tuple[dict, list[dict], np.ndarray]:
    room = json.loads((ROOMS / f"{room_id}.json").read_text(encoding="utf-8"))
    img = Image.open(ASSETS / room["bg"])
    cm = cyan_mask(img) & walk_mask(room, img.size)
    panels = []
    for comp in components(cm):
        if len(comp) < MIN_AREA:
            continue
        quad = min_area_quad(comp)
        xs = [p[0] for p in comp]
        ys = [p[1] for p in comp]
        panels.append({"quad": quad, "area": len(comp),
                       "center": (sum(xs) / len(xs), sum(ys) / len(ys))})
    # ترتیب خواندنی: بالا به پایین، چپ به راست
    panels.sort(key=lambda p: (round(p["center"][1] / 60), p["center"][0]))
    return room, panels, cm


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__)
        return 2
    global MIN_GB
    room_id = sys.argv[1]
    write = "--write" in sys.argv
    for a in sys.argv:
        if a.startswith("--min-gb="):
            MIN_GB = int(a.split("=")[1])
    room, panels, cm = extract(room_id)
    print(f"  {len(panels)} پنل در «{room_id}»")
    for i, p in enumerate(panels):
        print(f"    panel_{i + 1:02d}: مساحت {p['area']}، مرکز "
              f"({p['center'][0]:.0f},{p['center'][1]:.0f})")

    img = Image.open(ASSETS / room["bg"]).convert("RGBA")
    over = Image.new("RGBA", img.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(over)
    for p in panels:
        d.polygon(p["quad"], fill=(255, 60, 40, 90), outline=(255, 255, 255, 220))
    SHOTS.mkdir(parents=True, exist_ok=True)
    out = SHOTS / f"panels_{room_id}.png"
    Image.alpha_composite(img, over).save(out)
    print(f"  پیش‌نمایش: {out.relative_to(ROOT)}")

    if not write:
        return 0

    old = [h for h in room.get("hazard", []) if h.get("kind") == "electric"]
    safe = old[0]["safe"] if old else room["spawn"]
    keep = [h for h in room.get("hazard", []) if h.get("kind") != "electric"]
    for i, p in enumerate(panels):
        flat = []
        for x, y in p["quad"]:
            flat += [int(round(x)), int(round(y))]
        keep.append({"id": f"panel_{i + 1:02d}", "kind": "electric", "damage_pct": 100,
                     "safe": safe, "poly": flat})
    room["hazard"] = keep
    room["_hazard_note"] = ("پنل‌ها با tools/panel_extract.py از خود تصویر درآمده‌اند "
                            "(REQ-027 بند ۲): فیروزه‌ای روشن → مؤلفهٔ همبند → کوچک‌ترین "
                            "مستطیل چرخیده. دستی ویرایش نکن؛ ابزار را دوباره اجرا کن.")
    (ROOMS / f"{room_id}.json").write_text(
        json.dumps(room, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    m = Image.new("L", Image.open(ASSETS / room["bg"]).size, 0)
    md = ImageDraw.Draw(m)
    for p in panels:
        md.polygon(p["quad"], fill=255)
    m = m.filter(ImageFilter.GaussianBlur(MASK_BLUR))
    mdir = ROOMS / "masks" / room_id
    mdir.mkdir(parents=True, exist_ok=True)
    m.save(mdir / "panel_cyan_components.png")
    print(f"  نوشته شد: rooms/{room_id}.json و rooms/masks/{room_id}/panel_cyan_components.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())
