"""ماتریس پیکسلی JSON — قالب، اعتبارسنج و رندر.

قالب (همان چیزی که مدل تولید می‌کند):

    {
      "name": "kairo_idle",
      "size": [32, 40],          # پهنا، بلندی هر فریم
      "palette": {"h": "#2A1B14", "j": "#2B2F3F", ...},
      "frames": [                # هر فریم: فهرست سطرهای حروف پالت
        ["................", ...],
        ...
      ],
      "anchor": [16, 36]         # اختیاری: نقطهٔ پا، برای جاگذاری روی برخورد
    }

«.» شفاف است. هر حرف دیگری باید در palette باشد.
"""

from __future__ import annotations

import json
import sys
from dataclasses import dataclass
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import palette as P  # noqa: E402
from pixel import CLEAR, Canvas, hex_rgba, mix  # noqa: E402

TRANSPARENT = "."
MAX_COLORS = 16


def allowed_colors() -> set[str]:
	"""رنگ‌های مجاز: خود لوحه، به‌علاوهٔ سایه و هایلایت فرمولی هر کدام.

	سند ۰۴: «هیچ رنگی خارج از این جدول‌ها در بازی استفاده نمی‌شود؛ هر سایه یا
	نور از همین رنگ‌ها با قانون ... ساخته می‌شود». پس مجموعهٔ مجاز بسته و
	قابل محاسبه است و حدس زدن رنگ ممنوع.
	"""
	out: set[str] = set()
	for code in P.ALL.values():
		out.add(code.upper())
		for amount in (0.2, 0.25, 0.3, 0.4, 0.5, 0.55, 0.6, 0.7, 0.75, 0.8):
			out.add(_hex(P.shade(code, amount)))
			out.add(_hex(P.light(code, amount)))
	return out


def _hex(rgba) -> str:
	return "#%02X%02X%02X" % (rgba[0], rgba[1], rgba[2])


@dataclass
class Sprite:
	name: str
	width: int
	height: int
	palette: dict[str, str]
	frames: list[list[str]]
	anchor: tuple[int, int] | None = None

	@property
	def frame_count(self) -> int:
		return len(self.frames)


def load(path: str | Path) -> Sprite:
	data = json.loads(Path(path).read_text(encoding="utf-8"))
	return from_dict(data)


def from_dict(data: dict) -> Sprite:
	size = data["size"]
	anchor = data.get("anchor")
	return Sprite(
		name=str(data["name"]),
		width=int(size[0]),
		height=int(size[1]),
		palette={str(k): str(v).upper() for k, v in data["palette"].items()},
		frames=[[str(row) for row in frame] for frame in data["frames"]],
		anchor=(int(anchor[0]), int(anchor[1])) if anchor else None,
	)


# ----------------------------- اعتبارسنج -----------------------------

@dataclass
class Report:
	errors: list[str]
	warnings: list[str]

	@property
	def ok(self) -> bool:
		return not self.errors

	def text(self) -> str:
		lines = ["  ✘ %s" % e for e in self.errors]
		lines += ["  ⚠ %s" % w for w in self.warnings]
		return "\n".join(lines) if lines else "  ✔ بی‌عیب"


def validate(sp: Sprite, *, strict_palette: bool = True) -> Report:
	errors: list[str] = []
	warnings: list[str] = []

	if sp.frame_count == 0:
		errors.append("هیچ فریمی ندارد.")
		return Report(errors, warnings)

	# ۱) اندازهٔ دقیق هر فریم
	for i, frame in enumerate(sp.frames):
		if len(frame) != sp.height:
			errors.append("فریم %d: %d سطر دارد، باید %d باشد." % (i, len(frame), sp.height))
		for r, row in enumerate(frame):
			if len(row) != sp.width:
				errors.append(
					"فریم %d سطر %d: %d نویسه دارد، باید %d باشد."
					% (i, r, len(row), sp.width)
				)

	# ۲) فقط حروف پالت
	unknown: set[str] = set()
	for frame in sp.frames:
		for row in frame:
			for ch in row:
				if ch != TRANSPARENT and ch not in sp.palette:
					unknown.add(ch)
	if unknown:
		errors.append("حرف بی‌رنگ: %s" % ", ".join(sorted(unknown)))

	# ۳) سقف ۱۶ رنگ برای هر اسپرایت
	used = _used_keys(sp)
	if len(used) > MAX_COLORS:
		errors.append("%d رنگ به‌کار رفته، سقف %d است." % (len(used), MAX_COLORS))

	unused = set(sp.palette) - used
	if unused:
		warnings.append("رنگ تعریف‌شده ولی بی‌استفاده: %s" % ", ".join(sorted(unused)))

	# ۴) رنگ‌ها از لوحهٔ رسمی باشند
	if strict_palette:
		allowed = allowed_colors()
		stray = sorted({sp.palette[k] for k in used if sp.palette[k] not in allowed})
		if stray:
			errors.append(
				"رنگ بیرون از لوحهٔ سند ۰۴: %s (سایه/هایلایت باید با فرمول ساخته شود)"
				% ", ".join(stray)
			)

	# ۵) پیکسل سرگردان
	for i, frame in enumerate(sp.frames):
		lone = _lone_pixels(frame)
		if lone:
			warnings.append(
				"فریم %d: %d پیکسل سرگردان، مثلاً %s"
				% (i, len(lone), lone[0])
			)

	# ۶) خط دور
	for i, frame in enumerate(sp.frames):
		problem = _outline_problem(sp, frame)
		if problem:
			warnings.append("فریم %d: %s" % (i, problem))

	return Report(errors, warnings)


def _used_keys(sp: Sprite) -> set[str]:
	used: set[str] = set()
	for frame in sp.frames:
		for row in frame:
			for ch in row:
				if ch != TRANSPARENT and ch in sp.palette:
					used.add(ch)
	return used


def _lone_pixels(frame: list[str]) -> list[tuple[int, int]]:
	"""پیکسل ماتی که هیچ همسایهٔ مات چهارجهته ندارد — نویز است، نه جزئیات."""
	out: list[tuple[int, int]] = []
	h = len(frame)
	for y in range(h):
		w = len(frame[y])
		for x in range(w):
			if frame[y][x] == TRANSPARENT:
				continue
			touching = False
			for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
				nx, ny = x + dx, y + dy
				if 0 <= ny < h and 0 <= nx < len(frame[ny]) and frame[ny][nx] != TRANSPARENT:
					touching = True
					break
			if not touching:
				out.append((x, y))
	return out


def _lum(code: str) -> float:
	r, g, b, _ = hex_rgba(code)
	return (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0


def _outline_problem(sp: Sprite, frame: list[str]) -> str | None:
	"""لبهٔ بیرونی باید از میانگین درون روشن‌تر نباشد (خط دور تیره، §۴).

	کاشی‌ها از این قاعده بیرون‌اند: کاشی تمام‌بوم است و باید با کاشی کناری‌اش
	بی‌درز جفت شود، پس اصلاً خط دور ندارد و لبهٔ بالایش هم عمداً روشن است
	(نور جهت‌دار از بالا-چپ). سنجیدن خط دور روی آن هشدار بی‌جا می‌دهد.
	"""
	if all(TRANSPARENT not in row for row in frame):
		return None

	edge: list[float] = []
	inner: list[float] = []
	h = len(frame)
	for y in range(h):
		for x in range(len(frame[y])):
			ch = frame[y][x]
			if ch == TRANSPARENT or ch not in sp.palette:
				continue
			on_edge = False
			for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
				nx, ny = x + dx, y + dy
				if not (0 <= ny < h and 0 <= nx < len(frame[ny])):
					on_edge = True
					break
				if frame[ny][nx] == TRANSPARENT:
					on_edge = True
					break
			(edge if on_edge else inner).append(_lum(sp.palette[ch]))
	if not edge or not inner:
		return None
	e = sum(edge) / len(edge)
	i = sum(inner) / len(inner)
	if e > i:
		return "خط دور از درون روشن‌تر است (لبه %.2f، درون %.2f)" % (e, i)
	return None


# ------------------------------- رندر -------------------------------

def render_frame(sp: Sprite, index: int) -> Canvas:
	c = Canvas(sp.width, sp.height)
	frame = sp.frames[index]
	for y, row in enumerate(frame):
		for x, ch in enumerate(row):
			if ch == TRANSPARENT or ch not in sp.palette:
				continue
			c.set(x, y, hex_rgba(sp.palette[ch]))
	return c


def render_sheet(sp: Sprite) -> Canvas:
	"""اطلس افقی: هر فریم کنار قبلی، همان ترتیب فریم‌ها."""
	sheet = Canvas(sp.width * sp.frame_count, sp.height)
	for i in range(sp.frame_count):
		sheet.blit(render_frame(sp, i), i * sp.width, 0)
	return sheet


def zoom(c: Canvas, factor: int) -> Canvas:
	out = Canvas(c.w * factor, c.h * factor)
	for y in range(c.h):
		for x in range(c.w):
			px = c.get(x, y)
			if px[3] == 0:
				continue
			out.rect(x * factor, y * factor, factor, factor, px)
	return out
