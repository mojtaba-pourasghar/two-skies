#!/usr/bin/env python3
"""پیش‌نمایش ماسک اتاق روی تصویر مرجع.

ماسک چندضلعی از روی **تصویر** کشیده می‌شود (سند ۱۱ §۱ بند ۲). خواندن
مختصات از روی شبکه و بعد اجرای بازی برای دیدن نتیجه، حلقهٔ کندی است.
این ابزار ماسک را مستقیم روی تصویر می‌کشد تا در چند ثانیه معلوم شود با
گوشه‌ها و مبلمان می‌خواند یا نه.

    python3 -I tools/mask_preview.py r1a_living
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
ROOMS = ROOT / "game" / "rooms"
ASSETS = ROOT / "game" / "assets"
OUT = ROOT / "game" / "docs_screens"

WALK = (60, 255, 120, 70)
BLOCK = (20, 20, 40, 150)
HAZARD = (255, 70, 50, 110)
DOOR = (80, 160, 255, 120)
EDGE = (255, 255, 255, 190)


def poly(flat: list) -> list:
	return [(float(flat[i]), float(flat[i + 1])) for i in range(0, len(flat) - 1, 2)]


def draw(room_id: str) -> Path:
	data = json.loads((ROOMS / (room_id + ".json")).read_text(encoding="utf-8"))
	bg_path = ASSETS / str(data.get("bg", ""))
	size = data.get("size", [1280, 720])
	if bg_path.exists():
		base = Image.open(bg_path).convert("RGBA")
	else:
		base = Image.new("RGBA", (int(size[0]), int(size[1])), (30, 30, 36, 255))
		print("  ⚠ تصویر پیدا نشد: %s" % bg_path)

	layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
	d = ImageDraw.Draw(layer)

	for flat in data.get("walkable", []):
		d.polygon(poly(flat), fill=WALK, outline=EDGE)
	for flat in data.get("blocked", []):
		d.polygon(poly(flat), fill=BLOCK, outline=(255, 180, 60, 220))
	for h in data.get("hazard", []):
		d.polygon(poly(h.get("poly", [])), fill=HAZARD, outline=(255, 120, 90, 230))
	for door in data.get("doors", []):
		r = door.get("rect", [])
		if len(r) == 4:
			d.rectangle([r[0], r[1], r[0] + r[2], r[1] + r[3]],
						fill=DOOR, outline=(160, 210, 255, 230))
	sp = data.get("spawn", [0, 0])
	d.ellipse([sp[0] - 9, sp[1] - 9, sp[0] + 9, sp[1] + 9],
			  fill=(255, 255, 255, 220), outline=(0, 0, 0, 255))

	out = Image.alpha_composite(base, layer).convert("RGB")
	dd = ImageDraw.Draw(out)
	dd.text((10, 10), "%s — walkable=green  blocked=dark  hazard=red  door=blue"
			% room_id, fill=(255, 255, 255))
	OUT.mkdir(parents=True, exist_ok=True)
	path = OUT / ("mask_%s.png" % room_id)
	out.save(path)
	return path


def main(argv: list[str]) -> int:
	if not argv:
		print("استفاده: python3 -I tools/mask_preview.py <room_id>")
		return 1
	for rid in argv:
		p = draw(rid)
		print("  ساخته شد: %s" % p.relative_to(ROOT))
	return 0


if __name__ == "__main__":
	raise SystemExit(main(sys.argv[1:]))
