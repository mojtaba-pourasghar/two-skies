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



# ============================ کاشی سه‌چهارم ============================

TILE = 16

TILE_PAL = {
	"e": P.AURA_SOIL,                                  # خاک
	"E": _hex(P.light(P.AURA_SOIL, 0.30)),             # خاک روشن (نور بالا-چپ)
	"d": _hex(P.shade(P.AURA_SOIL, 0.40)),             # خاک سایه
	"r": P.BURNT_STEEL,                                # سنگ
	"R": _hex(P.light(P.BURNT_STEEL, 0.30)),           # سنگ روشن
	"k": _hex(P.shade(P.BURNT_STEEL, 0.40)),           # سنگ سایه
	"K": _hex(P.shade(P.BURNT_STEEL, 0.70)),           # دیوارهٔ جلو، تیره‌ترین
	"g": P.MOSS_GREEN,                                 # خزه و علف
	"G": P.LIGHT_GREEN,
	"m": _hex(P.shade(P.MOSS_GREEN, 0.40)),            # علف سایه
	"n": P.LIGHT_DUST,                                 # طناب
	"w": P.WATER_TEAL,                                 # آب
	"W": P.WHITE,                                      # خط کف سفید لبهٔ آب
	"h": P.UI_PANEL,                                   # ته چاله
	"l": P.LIGHT_DUST,                                 # لبهٔ روشن سکو
}


def _tile() -> Grid:
	return [["." for _ in range(TILE)] for _ in range(TILE)]


def _trow(t: Grid, x: int, y: int, w: int, ch: str) -> None:
	for i in range(w):
		if 0 <= y < TILE and 0 <= x + i < TILE:
			t[y][x + i] = ch


def _tbox(t: Grid, x: int, y: int, w: int, h: int, ch: str) -> None:
	for j in range(h):
		_trow(t, x, y + j, w, ch)


def _speckle(t: Grid, ch: str, step: int, offset: int = 0) -> None:
	for y in range(TILE):
		for x in range(TILE):
			if (x * 3 + y * 7 + offset) % step == 0:
				t[y][x] = ch


def tile_surface(base: str, light: str, dark: str, *, speck: int = 11) -> Grid:
	"""سطح ۱۶×۱۶ با سه پلهٔ سایه و نور جهت‌دار از بالا-چپ."""
	t = _tile()
	_tbox(t, 0, 0, TILE, TILE, base)
	_speckle(t, dark, speck, 2)
	_trow(t, 0, 0, TILE, light)        # لبهٔ بالا روشن
	for y in range(TILE):
		t[y][0] = light                # لبهٔ چپ روشن
		t[y][TILE - 1] = dark          # لبهٔ راست سایه
	_trow(t, 0, TILE - 1, TILE, dark)  # لبهٔ پایین سایه
	return t


def tile_front_face() -> Grid:
	"""دیوارهٔ جلوی صخره: ۱۶ پیکسل ارتفاع، خطوط عمودی، تیره‌تر از سطح."""
	t = _tile()
	# تودهٔ دیواره باید از سطحِ بالایش تیره‌تر ولی از چالهٔ کنارش روشن‌تر باشد،
	# وگرنه دیوار و چاله یک سیاهی یکدست می‌شوند و بازیکن عمق را نمی‌خواند.
	_tbox(t, 0, 0, TILE, TILE, "k")
	for x in range(1, TILE, 4):
		for y in range(2, TILE - 1):
			t[y][x] = "K"
	_trow(t, 0, 0, TILE, "R")          # بالای دیواره نور می‌گیرد
	_trow(t, 0, 1, TILE, "r")
	_trow(t, 0, TILE - 1, TILE, "K")   # پای دیواره تیره‌ترین
	return t


def tile_grass() -> Grid:
	"""علف‌زار: سطح سبز با خوشه‌های کوچک، نه پوشش لبه."""
	t = tile_surface("g", "G", "m", speck=13)
	for x, y in ((3, 4), (9, 7), (13, 11), (6, 13)):
		t[y][x] = "G"
		if y - 1 >= 0:
			t[y - 1][x] = "G"
	return t


def tile_cliff_edge() -> Grid:
	"""لبهٔ فلات: صخرهٔ گرد با لبهٔ روشن بالا و علف روی لبه (سبک مرجع)."""
	t = tile_surface("e", "E", "d")
	_trow(t, 0, 0, TILE, "l")
	_trow(t, 0, 1, TILE, "E")
	_trow(t, 0, TILE - 2, TILE, "k")   # پایین کاشی به دیوارهٔ جلو می‌رسد
	_trow(t, 0, TILE - 1, TILE, "K")
	# علف و خزه روی لبه
	for x in range(0, TILE, 3):
		t[0][x] = "G"
		t[1][x] = "g"
	# گوشه‌های گرد: دو پیکسل هر طرف برداشته می‌شود
	for dx, dy in ((0, 0), (1, 0), (0, 1), (TILE - 1, 0), (TILE - 2, 0), (TILE - 1, 1)):
		t[dy][dx] = "k"
	return t


def tile_rope_bridge() -> Grid:
	"""پل طناب: طناب یک‌پیکسلی با دو پیکسل سایه و تختهٔ چوبی (سند ۰۴)."""
	t = _tile()
	# دو طناب کناری
	for x in range(TILE):
		t[2][x] = "n"
		t[3][x] = "d"
		t[13][x] = "n"
		t[14][x] = "d"
	# تخته‌ها با میخ چوبی
	for x in range(1, TILE, 5):
		for y in range(3, 14):
			t[y][x] = "e"
			if x + 1 < TILE:
				t[y][x + 1] = "E"
			if x + 2 < TILE:
				t[y][x + 2] = "d"
	return t


def tile_crumble() -> Grid:
	"""سکوی شکننده: خاک با ترک، لبهٔ بالایی روشن تا قابل‌ایستادن دیده شود."""
	t = tile_surface("e", "E", "d", speck=7)
	_trow(t, 0, 0, TILE, "l")
	for x, y in ((4, 4), (5, 5), (5, 6), (10, 4), (11, 5), (11, 6), (3, 9), (12, 10)):
		t[y][x] = "d"
	return t


def tile_pit() -> Grid:
	"""چاله: ته تیره با لبهٔ صخرهٔ دور تا دور، تا با سایه اشتباه نشود."""
	t = _tile()
	_tbox(t, 0, 0, TILE, TILE, "h")
	# لبهٔ بالای چاله نور می‌گیرد و پایینش تیره می‌ماند: همین اختلاف است که
	# چاله را از سایه جدا می‌کند (قاعدهٔ تضاد ۳۰٪ §۴).
	_trow(t, 0, 0, TILE, "k")
	_trow(t, 0, 1, TILE, "K")
	for y in range(TILE):
		t[y][0] = "K"
		t[y][TILE - 1] = "K"
	_trow(t, 1, TILE - 1, TILE - 2, "K")
	return t


def tile_water() -> Grid:
	"""آب فیروزه‌ای با خط کف سفید یک‌پیکسلی روی لبه (سند ۰۴)."""
	t = _tile()
	_tbox(t, 0, 0, TILE, TILE, "w")
	_speckle(t, "W", 23, 5)
	_trow(t, 0, 0, TILE, "W")
	return t


def build_tiles() -> dict:
	# همان هشت کاشی که دستور گام ۱۳ دستهٔ الف می‌خواهد، به همان ترتیب
	frames = [
		tile_grass(),                     # ۰ علف
		tile_surface("e", "E", "d"),      # ۱ خاک
		tile_cliff_edge(),                # ۲ صخرهٔ گرد لبه
		tile_front_face(),                # ۳ دیوارهٔ جلو
		tile_water(),                     # ۴ آب
		tile_rope_bridge(),               # ۵ پل طناب
		tile_crumble(),                   # ۶ سکوی شکننده
		tile_pit(),                       # ۷ چاله
	]
	return {
		"name": "tiles_3q",
		"size": [TILE, TILE],
		"palette": TILE_PAL,
		"frames": [["".join(r) for r in f] for f in frames],
	}



# ============================== رابط ==============================

UI_W, UI_H = 120, 40

UI_PAL = {
	"p": P.UI_PANEL,                                   # پنل آبی تیره
	"b": P.SERVER_BLUE,                                # درون پنل
	"l": P.DIGITAL_CYAN,                               # لبهٔ روشن نازک
	"t": P.UI_TEXT,
	"h": P.DANGER,                                     # نوار سلامت
	"H": _hex(P.shade(P.DANGER, 0.40)),
	"e": P.DIGITAL_CYAN,                               # نوار انرژی
	"E": _hex(P.shade(P.DIGITAL_CYAN, 0.40)),
	"c": P.COIN,
	"s": P.WARN_YELLOW,                                # مکان‌نمای ستاره
	"k": _hex(P.shade(P.UI_PANEL, 0.40)),
}


def _ublank():
	return [["." for _ in range(UI_W)] for _ in range(UI_H)]


def _urow(g, x, y, w, ch):
	for i in range(w):
		if 0 <= y < UI_H and 0 <= x + i < UI_W:
			g[y][x + i] = ch


def _ubox(g, x, y, w, h, ch):
	for j in range(h):
		_urow(g, x, y + j, w, ch)


def _panel(g, x, y, w, h):
	"""پنل آبی تیره با لبهٔ روشن نازک — قالب مشترک همهٔ پنل‌ها."""
	_ubox(g, x, y, w, h, "p")
	_ubox(g, x + 1, y + 1, w - 2, h - 2, "b")
	_urow(g, x, y, w, "l")
	_urow(g, x, y + h - 1, w, "k")
	for j in range(h):
		g[y + j][x] = "l"
		g[y + j][x + w - 1] = "k"


def _bar(g, x, y, w, fill, full, empty):
	_urow(g, x, y, w, empty)
	_urow(g, x, y, int(w * fill), full)
	_urow(g, x, y + 1, int(w * fill), full)
	for i in range(int(w * fill), w):
		g[y + 1][x + i] = empty


def _star_cursor(g, x, y):
	"""مکان‌نمای ایرانی-فانتزی: ستارهٔ هشت‌پر کوچک با پیکان نور.

	عمداً هیچ نماد مشهوری نیست؛ شکل از ستارهٔ هشت‌پرِ کاشی‌کاری گرفته شده.
	"""
	pts = [(0, -3), (0, -2), (0, 2), (0, 3), (-3, 0), (-2, 0), (2, 0), (3, 0),
		   (-1, -1), (1, -1), (-1, 1), (1, 1), (0, 0), (-2, -2), (2, 2)]
	for dx, dy in pts:
		if 0 <= y + dy < UI_H and 0 <= x + dx < UI_W:
			g[y + dy][x + dx] = "s"


def build_ui() -> dict:
	"""یک صفحهٔ نمونهٔ رابط: HUD با نوار سلامت و انرژی، شمارندهٔ سکه، مکان‌نما."""
	g = _ublank()
	_panel(g, 0, 0, 62, 18)
	_bar(g, 3, 4, 54, 0.72, "h", "H")
	_bar(g, 3, 9, 54, 0.45, "e", "E")
	_urow(g, 3, 13, 54, "k")

	# شمارندهٔ سکه
	_panel(g, 66, 0, 30, 18)
	for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)):
		g[8 + dy][73 + dx] = "c"
	_urow(g, 78, 7, 12, "t")
	_urow(g, 78, 9, 9, "t")

	# دکمهٔ لمسی گرد
	_panel(g, 0, 22, 18, 18)
	_ubox(g, 4, 26, 10, 10, "l")
	_ubox(g, 5, 27, 8, 8, "b")

	_star_cursor(g, 104, 10)
	_panel(g, 22, 22, 74, 18)
	_urow(g, 25, 28, 60, "t")
	_urow(g, 25, 32, 44, "t")

	return {
		"name": "ui_3q",
		"size": [UI_W, UI_H],
		"palette": UI_PAL,
		"frames": [["".join(r) for r in g]],
	}


def main() -> int:
	config.ensure_dirs()
	made: list[str] = []
	specs = {
		"kairo_3q": build_character("kairo_3q", KAIRO_PAL, scarf_long=False, bow=False, module=True),
		"ilara_3q": build_character("ilara_3q", ILARA_PAL, scarf_long=True, bow=True, module=False),
		"tiles_3q": build_tiles(),
		"ui_3q": build_ui(),
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
