"""پردازش پس از تولید: تصویر بزرگِ مدل → پیکسل‌آرت پالت‌بندی‌شدهٔ بازی.

تنها جایی از این ابزار که به Pillow نیاز دارد (بقیه کتابخانهٔ استاندارد است).
"""

from __future__ import annotations

import colorsys
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

import palette as P  # noqa: E402
from pixel import hex_rgba  # noqa: E402

#: سقف رنگ هر دنیا (سند ۰۴: «حداکثر ۶۴ رنگ برای هر دنیا»).
MAX_WORLD_COLORS = 64


def world_palette(chapter: int = 1) -> list[tuple[int, int, int]]:
	"""لوحهٔ مجاز دنیا: ۳۴ رنگ پایه به‌علاوهٔ سه پلهٔ سایه و دو پلهٔ هایلایت.

	سند ۰۴: «سه پله برای هر ماده: سایه، میانه، روشن». این مجموعه را به ۶۴ رنگ
	می‌بَرد، که دقیقاً سقف همان سند است.
	"""
	seen: dict[tuple[int, int, int], None] = {}
	for code in P.ALL.values():
		for rgba in (
			hex_rgba(code),
			P.shade(code, 0.40),
			P.shade(code, 0.70),
			P.light(code, 0.30),
		):
			seen[(rgba[0], rgba[1], rgba[2])] = None
			if len(seen) >= MAX_WORLD_COLORS:
				return list(seen)
	return list(seen)


def downscale(img: Image.Image, size: tuple[int, int], *, box: bool = True) -> Image.Image:
	"""کوچک‌کردن. box برای پس‌زمینه (نرم)، nearest برای چیزی که باید تیز بماند."""
	return img.convert("RGB").resize(size, Image.BOX if box else Image.NEAREST)


def quantize(img: Image.Image, colors: list[tuple[int, int, int]], *, dither: bool = False) -> Image.Image:
	"""رنگ‌بندی با لوحهٔ دنیا.

	سند ۰۴ پراکندگی نقطه‌ای را «فقط روی پس‌زمینه» مجاز می‌داند، پس dither
	پیش‌فرض خاموش است و فقط فراخوان پس‌زمینه روشنش می‌کند.
	"""
	pal = Image.new("P", (1, 1))
	flat: list[int] = []
	for c in colors[:256]:
		flat += [c[0], c[1], c[2]]
	flat += [0, 0, 0] * (256 - len(colors[:256]))
	pal.putpalette(flat)
	mode = Image.FLOYDSTEINBERG if dither else Image.NONE
	return img.convert("RGB").quantize(palette=pal, dither=mode).convert("RGB")


def despeckle(img: Image.Image) -> Image.Image:
	"""پیکسل تکی که با هیچ‌کدام از چهار همسایه‌اش هم‌رنگ نیست را به رنگ
	پرتکرارترین همسایه می‌برد — نویز تک‌پیکسلی مدل را برمی‌دارد."""
	src = img.convert("RGB")
	w, h = src.size
	px = src.load()
	out = src.copy()
	dst = out.load()
	for y in range(1, h - 1):
		for x in range(1, w - 1):
			here = px[x, y]
			neigh = [px[x - 1, y], px[x + 1, y], px[x, y - 1], px[x, y + 1]]
			if here in neigh:
				continue
			counts: dict[tuple[int, int, int], int] = {}
			for n in neigh:
				counts[n] = counts.get(n, 0) + 1
			dst[x, y] = max(counts.items(), key=lambda kv: kv[1])[0]
	return out


def aerial(img: Image.Image, depth: int, sky: str = P.RUST_RED) -> Image.Image:
	"""پرسپکتیو رنگی سند ۰۴: «هر لایهٔ دورتر ۱۵٪ روشن‌تر و ۲۰٪ کم‌اشباع‌تر و
	به رنگ آسمان نزدیک‌تر». depth=0 نزدیک‌ترین لایه است."""
	if depth <= 0:
		return img.convert("RGB")
	lighten = min(0.85, 0.15 * depth)
	desat = min(0.90, 0.20 * depth)
	toward = min(0.60, 0.12 * depth)
	sky_rgb = hex_rgba(sky)
	src = img.convert("RGB")
	px = src.load()
	w, h = src.size
	for y in range(h):
		for x in range(w):
			r, g, b = px[x, y]
			hh, ll, ss = colorsys.rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)
			ll = ll + (1.0 - ll) * lighten
			ss = ss * (1.0 - desat)
			r2, g2, b2 = colorsys.hls_to_rgb(hh, ll, ss)
			r2, g2, b2 = r2 * 255, g2 * 255, b2 * 255
			px[x, y] = (
				int(r2 + (sky_rgb[0] - r2) * toward),
				int(g2 + (sky_rgb[1] - g2) * toward),
				int(b2 + (sky_rgb[2] - b2) * toward),
			)
	return src


def split_depth_layers(img: Image.Image, layers: int = 3) -> list[Image.Image]:
	"""تصویر را به لایه‌های عمق می‌بُرد.

	مدل سایه‌نمای شهر را به‌طور طبیعی پله‌پله روشن می‌کشد (هرچه دورتر، روشن‌تر)،
	پس برش بر پایهٔ روشنایی تودهٔ غیرآسمان انجام می‌شود. هر لایه RGBA است و
	بقیهٔ تصویر در آن شفاف می‌ماند، تا بشود روی هم چید.
	"""
	src = img.convert("RGB")
	w, h = src.size
	px = src.load()
	lums: list[float] = []
	for y in range(h):
		for x in range(w):
			r, g, b = px[x, y]
			lums.append(0.2126 * r + 0.7152 * g + 0.0722 * b)
	lums.sort()
	# مرزها را از صدک‌ها می‌گیریم تا به روشنایی مطلق تصویر وابسته نباشد
	bounds = [lums[int(len(lums) * (i + 1) / layers) - 1] for i in range(layers)]

	out: list[Image.Image] = []
	for i in range(layers):
		low = 0.0 if i == 0 else bounds[i - 1]
		high = bounds[i]
		layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
		lp = layer.load()
		for y in range(h):
			for x in range(w):
				r, g, b = px[x, y]
				lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
				if low <= lum <= high:
					lp[x, y] = (r, g, b, 255)
		out.append(layer)
	# لایهٔ ۰ تیره‌ترین است یعنی نزدیک‌ترین؛ از نزدیک به دور برمی‌گردانیم
	return out


def make_seamless_x(img: Image.Image, blend: int = 24) -> Image.Image:
	"""لبهٔ راست را در لبهٔ چپ محو می‌کند تا لایهٔ پارالاکس بی‌درز تکرار شود."""
	src = img.convert("RGBA")
	w, h = src.size
	blend = min(blend, w // 4)
	if blend <= 0:
		return src
	out = src.copy()
	right = src.crop((w - blend, 0, w, h))
	for x in range(blend):
		alpha = 1.0 - (x / float(blend))
		col = right.crop((x, 0, x + 1, h)).copy()
		strip = out.crop((x, 0, x + 1, h))
		out.paste(Image.blend(strip.convert("RGBA"), col.convert("RGBA"), alpha), (x, 0))
	return out


def pipeline_background(
	raw: bytes | Image.Image,
	*,
	size: tuple[int, int] = (480, 270),
	depth: int = 0,
	seamless: bool = True,
	chapter: int = 1,
	dither: bool = False,
) -> Image.Image:
	"""زنجیرهٔ کامل یک لایهٔ پس‌زمینه."""
	img = raw if isinstance(raw, Image.Image) else Image.open(_buf(raw))
	# برش به نسبت ۱۶:۹ پیش از کوچک‌کردن، تا تصویر مربعی کشیده نشود
	w, h = img.size
	want = size[0] / float(size[1])
	if w / float(h) > want:
		new_w = int(h * want)
		img = img.crop(((w - new_w) // 2, 0, (w + new_w) // 2, h))
	else:
		new_h = int(w / want)
		img = img.crop((0, (h - new_h) // 2, w, (h + new_h) // 2))
	img = downscale(img, size, box=True)
	if depth:
		img = aerial(img, depth)
	# ترتیب مهم است: بی‌درزکردن با آلفا رنگ میانی می‌سازد، پس باید **پیش از**
	# رنگ‌بندی بیاید وگرنه شمار رنگ از سقف ۶۴ سند ۰۴ بیرون می‌زند.
	if seamless:
		img = make_seamless_x(img.convert("RGBA")).convert("RGB")
	# سند ۰۴ پراکندگی نقطه‌ای را روی پس‌زمینه **مجاز** می‌داند، نه واجب. با
	# dither=True تصویر ۴۸۰×۲۷۰ پر از نقطهٔ ریز می‌شود و پشت صحنهٔ بازی مثل
	# برفک دیده می‌شود (۲۴ رنگ پرنویز در برابر ۱۵ رنگ تمیز). پس پیش‌فرض خاموش
	# است و نوارهای نقاشی‌وار می‌ماند. (DECISIONS.md: D-067)
	img = quantize(img, world_palette(chapter), dither=dither)
	img = despeckle(img)
	return img.convert("RGBA")


def _buf(raw: bytes):
	import io

	return io.BytesIO(raw)
