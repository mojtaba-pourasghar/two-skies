#!/usr/bin/env python3
"""تبدیل تصویر ماسک به چندضلعی‌های JSON اتاق (REQ-011).

مدیر هنر کنار هر اتاق یک `<اتاق>_mask.png` می‌دهد با رنگ‌های تخت:

    سبز  #00FF00  کف قابل‌راه‌رفتن
    مشکی #000000  دیوار / بیرون
    قرمز #FF0000  خطر
    آبی  #0000FF  در
    زرد  #FFFF00  پایهٔ مبلمان (سوراخ کف)

این ابزار هر ناحیهٔ هم‌رنگ را پیدا می‌کند، مرزش را دنبال می‌کند و به
چندضلعی سبک می‌دهد. دلیلش: خواندن مرز با چشم از روی تصویر نقاشی‌شده
خطاخیز است — ماسک اول R1a دیوار پشتی را کف شمرد و نردهٔ بالکن را ندید.

    python3 -I tools/mask_trace.py r1a_living
    python3 -I tools/mask_trace.py r1a_living --write
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
ROOMS = ROOT / "game" / "rooms"
ASSETS = ROOT / "game" / "assets"

#: رنگ → کلید در JSON اتاق. رواداری دارد چون PNG ممکن است کمی فشرده شود.
CLASSES = {
	"walkable": (0, 255, 0),
	"hazard": (255, 0, 0),
	"door": (0, 0, 255),
	"blocked": (255, 255, 0),
}
TOLERANCE = 60
#: ناحیهٔ کوچک‌تر از این (پیکسل) نویز است، نه هندسه.
MIN_AREA = 400
#: ساده‌سازی مرز: نقطه‌ای که از خط میان همسایه‌هایش کمتر از این فاصله دارد
#: حذف می‌شود. چندضلعی سبک بهتر از دقت یک‌پیکسلی است.
EPSILON = 3.0


def classify(px: tuple[int, int, int]) -> str | None:
	for name, ref in CLASSES.items():
		if all(abs(px[i] - ref[i]) <= TOLERANCE for i in range(3)):
			return name
	return None


def regions(img: Image.Image) -> dict[str, list[list[tuple[int, int]]]]:
	"""ناحیه‌های هم‌رنگ پیوسته (پر کردن سیل، چهارهمسایه)."""
	w, h = img.size
	px = img.convert("RGB").load()
	seen = bytearray(w * h)
	out: dict[str, list] = {k: [] for k in CLASSES}
	for y in range(h):
		for x in range(w):
			if seen[y * w + x]:
				continue
			name = classify(px[x, y])
			if name is None:
				seen[y * w + x] = 1
				continue
			stack = [(x, y)]
			seen[y * w + x] = 1
			cells: list[tuple[int, int]] = []
			while stack:
				cx, cy = stack.pop()
				cells.append((cx, cy))
				for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
					nx, ny = cx + dx, cy + dy
					if 0 <= nx < w and 0 <= ny < h and not seen[ny * w + nx]:
						if classify(px[nx, ny]) == name:
							seen[ny * w + nx] = 1
							stack.append((nx, ny))
			if len(cells) >= MIN_AREA:
				out[name].append(cells)
	return out


def outline(cells: list[tuple[int, int]]) -> list[tuple[int, int]]:
	"""مرز بیرونی ناحیه با دنبال کردن لبه (مربع متحرک سادهٔ چهارجهته)."""
	grid = set(cells)
	start = min(cells, key=lambda c: (c[1], c[0]))
	# جهت‌ها ساعت‌گرد از راست
	dirs = [(1, 0), (0, 1), (-1, 0), (0, -1)]
	path: list[tuple[int, int]] = []
	cur = start
	d = 0
	for _ in range(len(cells) * 8 + 16):
		path.append(cur)
		# سعی کن به چپ بپیچی، وگرنه مستقیم، وگرنه راست، وگرنه برگرد
		for turn in (-1, 0, 1, 2):
			nd = (d + turn) % 4
			nxt = (cur[0] + dirs[nd][0], cur[1] + dirs[nd][1])
			if nxt in grid:
				cur, d = nxt, nd
				break
		else:
			break
		if cur == start and len(path) > 2:
			break
	return path


def simplify(points: list[tuple[int, int]], eps: float) -> list[tuple[int, int]]:
	"""Ramer–Douglas–Peucker."""
	if len(points) < 3:
		return points
	a, b = points[0], points[-1]
	worst, idx = 0.0, 0
	for i in range(1, len(points) - 1):
		d = _dist(points[i], a, b)
		if d > worst:
			worst, idx = d, i
	if worst <= eps:
		return [a, b]
	left = simplify(points[: idx + 1], eps)
	right = simplify(points[idx:], eps)
	return left[:-1] + right


def _dist(p, a, b) -> float:
	if a == b:
		return ((p[0] - a[0]) ** 2 + (p[1] - a[1]) ** 2) ** 0.5
	num = abs((b[0] - a[0]) * (a[1] - p[1]) - (a[0] - p[0]) * (b[1] - a[1]))
	den = ((b[0] - a[0]) ** 2 + (b[1] - a[1]) ** 2) ** 0.5
	return num / den


def bbox(cells: list[tuple[int, int]]) -> list[int]:
	xs = [c[0] for c in cells]
	ys = [c[1] for c in cells]
	return [min(xs), min(ys), max(xs) - min(xs) + 1, max(ys) - min(ys) + 1]


def trace(room_id: str) -> dict:
	data = json.loads((ROOMS / (room_id + ".json")).read_text(encoding="utf-8"))
	bg = str(data.get("bg", ""))
	# دو جایگزینی پشت‌سرهم «house_mask_mask.png» می‌ساخت
	if bg.endswith("_1280x720.png"):
		mask_rel = bg[: -len("_1280x720.png")] + "_mask.png"
	elif bg.endswith("_1776x896.png"):
		mask_rel = bg[: -len("_1776x896.png")] + "_mask.png"
	else:
		mask_rel = bg[: -len(".png")] + "_mask.png"
	mask_path = ASSETS / mask_rel
	if not mask_path.exists():
		raise FileNotFoundError("تصویر ماسک نیست: %s (REQ-011)" % mask_rel)

	found = regions(Image.open(mask_path))
	out: dict = {"walkable": [], "blocked": [], "hazard": [], "doors": []}
	for name, blobs in found.items():
		for i, cells in enumerate(blobs):
			if name == "door":
				# در را مستطیل می‌گیریم: گذار در به در با کادر ساده‌تر است
				out["doors"].append({
					"id": "door_%d" % (len(out["doors"]) + 1),
					"rect": bbox(cells), "to": "", "spawn": [0, 0],
				})
				continue
			poly = simplify(outline(cells), EPSILON)
			flat: list[int] = []
			for p in poly:
				flat += [int(p[0]), int(p[1])]
			if name == "hazard":
				out["hazard"].append({
					"id": "hazard_%d" % (len(out["hazard"]) + 1),
					"kind": "pit", "damage_pct": 10, "safe": [0, 0], "poly": flat,
				})
			else:
				out[name].append(flat)
	return out


def main(argv: list[str]) -> int:
	ap = argparse.ArgumentParser(description="استخراج چندضلعی از تصویر ماسک")
	ap.add_argument("room")
	ap.add_argument("--write", action="store_true",
					help="نتیجه را در JSON اتاق بنویس (مقصد در و جای امن خطر دست‌نخورده می‌ماند)")
	args = ap.parse_args(argv)

	try:
		result = trace(args.room)
	except FileNotFoundError as exc:
		print("  ⊘ %s" % exc)
		return 1

	print("— %s —" % args.room)
	print("  کف: %d چندضلعی" % len(result["walkable"]))
	print("  مانع: %d" % len(result["blocked"]))
	print("  خطر: %d" % len(result["hazard"]))
	print("  در: %d" % len(result["doors"]))
	if not args.write:
		print("  (برای نوشتن: --write)")
		return 0

	path = ROOMS / (args.room + ".json")
	data = json.loads(path.read_text(encoding="utf-8"))
	data["walkable"] = result["walkable"]
	data["blocked"] = result["blocked"]
	# مقصد در و جای امن خطر دستی‌اند و از ماسک درنمی‌آیند
	for i, h in enumerate(result["hazard"]):
		if i < len(data.get("hazard", [])):
			h["id"] = data["hazard"][i]["id"]
			h["kind"] = data["hazard"][i].get("kind", h["kind"])
			h["safe"] = data["hazard"][i].get("safe", h["safe"])
	data["hazard"] = result["hazard"]
	old_doors = {i: d for i, d in enumerate(data.get("doors", []))}
	for i, d in enumerate(result["doors"]):
		if i in old_doors:
			d["id"] = old_doors[i].get("id", d["id"])
			d["to"] = old_doors[i].get("to", "")
			d["spawn"] = old_doors[i].get("spawn", [0, 0])
	data["doors"] = result["doors"]
	path.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
	print("  نوشته شد: %s" % path.relative_to(ROOT))
	return 0


if __name__ == "__main__":
	raise SystemExit(main(sys.argv[1:]))
