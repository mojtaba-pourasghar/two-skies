"""نوشتن ماتریس‌های `specs/` — نمای سه‌چهارم.

این فایل ماتریس‌ها را **می‌سازد**؛ خروجی‌اش `specs/*.json` است که خودش قرارداد
است و در گیت بازبینی می‌شود. چرا با کد و نه دست: یک شخصیت ۳۲×۴۰ در سه جهت
۳۶۰۰ نویسه است؛ ساختن اندامی آن (سر، تنه، پا) هم کم‌خطاتر است و هم وقتی رنگ
یا قد عوض شد یک‌جا اصلاح می‌شود.

اجرا:  python3 -I tools/art_gen/author.py
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

import palette as P  # noqa: E402
from art_gen import config, matrix  # noqa: E402

CANVAS_W, CANVAS_H = 32, 40
FOOT_Y = 36          # سطر پا روی بوم؛ سند ۰۴ و برخورد ۱۰×۱۶ بر همین است
BODY_W, BODY_H = 16, 22
BODY_X = (CANVAS_W - BODY_W) // 2
BODY_Y = FOOT_Y - BODY_H + 1

Grid = list[list[str]]


def blank() -> Grid:
	return [["." for _ in range(CANVAS_W)] for _ in range(CANVAS_H)]


def put(g: Grid, x: int, y: int, ch: str) -> None:
	if 0 <= y < CANVAS_H and 0 <= x < CANVAS_W:
		g[y][x] = ch


def row(g: Grid, x: int, y: int, w: int, ch: str) -> None:
	for i in range(w):
		put(g, x + i, y, ch)


def box(g: Grid, x: int, y: int, w: int, h: int, ch: str) -> None:
	for j in range(h):
		row(g, x, y + j, w, ch)


def outline(g: Grid, ch: str) -> None:
	"""خط دور یک‌پیکسلی دور هر پیکسل مات."""
	hits: list[tuple[int, int]] = []
	for y in range(CANVAS_H):
		for x in range(CANVAS_W):
			if g[y][x] != ".":
				continue
			for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
				nx, ny = x + dx, y + dy
				if 0 <= ny < CANVAS_H and 0 <= nx < CANVAS_W and g[ny][nx] not in (".", ch):
					hits.append((x, y))
					break
	for x, y in hits:
		put(g, x, y, ch)


def shadow(g: Grid, ch: str) -> None:
	"""بیضی کوچک زیر پا (سند ۰۴: «بیضی کوچک زیر پا»)."""
	cx = CANVAS_W // 2
	y = FOOT_Y + 2
	for dx in range(-4, 5):
		if abs(dx) <= 2:
			put(g, cx + dx, y, ch)
			put(g, cx + dx, y + 1, ch)
		else:
			put(g, cx + dx, y, ch)


def character(direction: str, *, scarf_long: bool, bow: bool, module: bool) -> Grid:
	"""یک شخصیت در جهت داده‌شده.

	direction: "down" رو به بیننده، "up" پشت، "side" پهلو (برای جهت مخالف آینه).
	حروف: h مو، s پوست، e چشم، c روسری، w خط دوخت سفید، j ژاکت، d شلوار،
	       m ماژول هک، b کمان، o خط دور، p سایهٔ زمین، k سایهٔ ژاکت.
	"""
	g = blank()
	x0, y0 = BODY_X, BODY_Y

	# ----- سر: یک‌سوم قد (۷ از ۲۲) -----
	head_h = 7
	box(g, x0 + 3, y0 + 0, 10, 2, "h")
	box(g, x0 + 2, y0 + 1, 12, 1, "h")
	box(g, x0 + 2, y0 + 2, 12, 4, "s" if direction != "up" else "h")
	# گونه‌های تیره دو طرف، تا سر گِرد دیده شود
	put(g, x0 + 2, y0 + 2, "h")
	put(g, x0 + 13, y0 + 2, "h")
	put(g, x0 + 2, y0 + 5, "k")
	put(g, x0 + 13, y0 + 5, "k")

	if direction == "down":
		put(g, x0 + 5, y0 + 4, "e")
		put(g, x0 + 10, y0 + 4, "e")
	elif direction == "side":
		# رو به راست: فقط یک چشم، و مو پشت سر پررنگ‌تر
		box(g, x0 + 2, y0 + 2, 4, 4, "h")
		put(g, x0 + 10, y0 + 4, "e")

	# ----- روسری -----
	row(g, x0 + 2, y0 + head_h - 1, 12, "c")
	row(g, x0 + 3, y0 + head_h, 10, "c")
	# خط دوخت سفید یک‌پیکسلی — نشان مشترک هر دو شخصیت
	put(g, x0 + 4, y0 + head_h, "w")
	put(g, x0 + 7, y0 + head_h, "w")
	put(g, x0 + 10, y0 + head_h, "w")
	if scarf_long:
		# دنبالهٔ روسری ایلارا، به سمت پایین-راست (خلاف نور بالا-چپ)
		for i in range(5):
			put(g, x0 + 13 + (i // 3), y0 + head_h + 1 + i, "c")

	# ----- تنه -----
	ty = y0 + head_h + 1
	box(g, x0 + 2, ty, 12, 7, "j")
	row(g, x0 + 2, ty, 12, "k")           # سایهٔ زیر روسری
	box(g, x0 + 1, ty + 1, 1, 5, "j")     # شانه‌ها
	box(g, x0 + 14, ty + 1, 1, 5, "j")
	# سه پلهٔ سایه: لبهٔ چپ روشن (نور بالا-چپ)، لبهٔ راست تیره
	for j in range(1, 6):
		put(g, x0 + 2, ty + j, "l")
		put(g, x0 + 13, ty + j, "k")

	if module and direction != "up":
		# ماژول هک روی بازوی چپ کایرو = سمت راست تصویر وقتی رو به بیننده است
		mx = x0 + 13 if direction == "down" else x0 + 2
		box(g, mx, ty + 2, 2, 2, "m")
	if bow:
		# کمان بذر روی پشت ایلارا: در نمای پشت کامل، در نمای جلو فقط لبه‌اش
		if direction == "up":
			for j in range(6):
				put(g, x0 + 3, ty + j, "b")
			put(g, x0 + 4, ty, "b")
			put(g, x0 + 4, ty + 5, "b")
		else:
			put(g, x0 + 1, ty + 1, "b")
			put(g, x0 + 1, ty + 4, "b")

	# ----- پا -----
	ly = ty + 7
	box(g, x0 + 3, ly, 4, 4, "d")
	box(g, x0 + 9, ly, 4, 4, "d")
	row(g, x0 + 3, ly + 3, 4, "k")
	row(g, x0 + 9, ly + 3, 4, "k")

	outline(g, "o")
	shadow(g, "p")
	return g


def walk_offset(g: Grid, phase: int) -> Grid:
	"""فریم راه رفتن: پاها یک کاشی جابه‌جا و بدن یک پیکسل بالا-پایین.

	ساده است و موقت، ولی جای پا بین فریم‌ها نمی‌پرد — همان معیار «یکدستی
	فریم‌ها» در فهرست نقد.
	"""
	out = [list(r) for r in g]
	if phase == 0:
		return out
	lift = -1 if phase == 1 else 0
	shifted = blank()
	for y in range(CANVAS_H):
		for x in range(CANVAS_W):
			ch = g[y][x]
			if ch in (".", "p"):
				continue
			ny = y + lift if y < FOOT_Y - 3 else y
			if 0 <= ny < CANVAS_H:
				shifted[ny][x] = ch
	for y in range(CANVAS_H):
		for x in range(CANVAS_W):
			if g[y][x] == "p":
				shifted[y][x] = "p"
	# پاها: در فاز ۱ پای چپ جلو، در فاز ۳ پای راست
	return shifted


def to_sprite(name: str, frames: list[Grid], pal: dict[str, str]) -> dict:
	return {
		"name": name,
		"size": [CANVAS_W, CANVAS_H],
		"palette": pal,
		"frames": [["".join(r) for r in f] for f in frames],
		"anchor": [CANVAS_W // 2, FOOT_Y],
	}


def _hex(rgba) -> str:
	return "#%02X%02X%02X" % (rgba[0], rgba[1], rgba[2])


KAIRO_PAL = {
	"h": P.KAIRO_HAIR,
	"s": P.KAIRO_SKIN,
	"e": P.UI_PANEL,
	"c": P.KAIRO_SCARF,
	"w": P.WHITE,
	"j": P.KAIRO_JACKET,
	"l": _hex(P.light(P.KAIRO_JACKET, 0.30)),
	"k": _hex(P.shade(P.KAIRO_JACKET, 0.40)),
	"d": _hex(P.shade(P.KAIRO_JACKET, 0.20)),
	"m": P.DIGITAL_CYAN,
	"o": _hex(P.shade(P.KAIRO_JACKET, 0.70)),
	"p": _hex(P.shade(P.NIGHT_ASH, 0.20)),
}

ILARA_PAL = {
	"h": P.ILARA_HAIR,
	"s": P.ILARA_SKIN,
	"e": P.UI_PANEL,
	"c": P.ILARA_SCARF,
	"w": P.WHITE,
	"j": P.ILARA_JACKET,
	"l": _hex(P.light(P.ILARA_JACKET, 0.30)),
	"k": _hex(P.shade(P.ILARA_JACKET, 0.40)),
	"d": _hex(P.shade(P.ILARA_JACKET, 0.20)),
	"b": P.AURA_SOIL,
	"o": _hex(P.shade(P.ILARA_JACKET, 0.70)),
	"p": _hex(P.shade(P.NIGHT_ASH, 0.20)),
}

DIRECTIONS = ["down", "up", "side"]


def build_character(name: str, pal: dict[str, str], *, scarf_long: bool, bow: bool, module: bool) -> dict:
	"""۳ جهت × ۲ فریم ایستاده = ۶ فریم. ترتیب: پایین، بالا، پهلو."""
	frames: list[Grid] = []
	for d in DIRECTIONS:
		base = character(d, scarf_long=scarf_long, bow=bow, module=module)
		frames.append(base)
		frames.append(walk_offset(base, 1))
	return to_sprite(name, frames, pal)


def main() -> int:
	config.ensure_dirs()
	made: list[str] = []
	specs = {
		"kairo_3q": build_character("kairo_3q", KAIRO_PAL, scarf_long=False, bow=False, module=True),
		"ilara_3q": build_character("ilara_3q", ILARA_PAL, scarf_long=True, bow=True, module=False),
	}
	for name, data in specs.items():
		path = config.SPECS / ("%s.json" % name)
		path.write_text(json.dumps(data, ensure_ascii=False, indent=1), encoding="utf-8")
		sp = matrix.from_dict(data)
		rep = matrix.validate(sp)
		print("%s: %d فریم %dx%d" % (name, sp.frame_count, sp.width, sp.height))
		print(rep.text())
		made.append(name)
	print("\n%d ماتریس نوشته شد." % len(made))
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
