"""برگ مقایسهٔ سبک — game/docs_screens/style_lock.png

همهٔ آنچه سبک را قفل می‌کند در یک تصویر: پالت فصل ۱، شخصیت‌ها در سه جهت،
هشت کاشی سه‌چهارم، یک صفحهٔ رابط، سه لایهٔ پس‌زمینه، و نمونهٔ خام Cloudflare
کنار نمونهٔ پردازش‌شده، تا بشود پردازش را داوری کرد نه فقط تولید را.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

import palette as P  # noqa: E402
from art_gen import cache, cloudflare, config, postprocess  # noqa: E402
from pixel import hex_rgba  # noqa: E402

ZOOM = 4
PAD = 12
BG = hex_rgba(P.UI_PANEL)[:3]
INK = hex_rgba(P.UI_TEXT)[:3]
RULE = hex_rgba(P.BURNT_STEEL)[:3]


def _open(rel: str) -> Image.Image:
	return Image.open(config.ART / rel).convert("RGBA")


def _z(img: Image.Image, factor: int = ZOOM) -> Image.Image:
	return img.resize((img.width * factor, img.height * factor), Image.NEAREST)


def _label(d: ImageDraw.ImageDraw, x: int, y: int, text: str) -> None:
	d.text((x, y), text, fill=INK)


def build() -> Path:
	config.ensure_dirs()
	kairo = _open("sprites/td/kairo.png")
	ilara = _open("sprites/td/ilara.png")
	tiles = _open("tilesets/ch1_3q.png")
	hud = _open("ui/td/hud.png")
	sky = _open("fx/td/ch1_sky.png")
	far = _open("fx/td/ch1_far.png")
	mid = _open("fx/td/ch1_mid.png")

	# نمونهٔ خام Cloudflare کنار پردازش‌شده‌اش
	raw_img: Image.Image | None = None
	k = cache.key({
		"model": config.CF_MODEL,
		"prompt": _mid_prompt(),
		"steps": 4,
		"variant": 0,
	})
	blob = cache.get_bytes(k, "png")
	if blob:
		raw_img = Image.open(postprocess._buf(blob)).convert("RGB")

	width = max(
		kairo.width * ZOOM,
		tiles.width * ZOOM,
		hud.width * ZOOM,
		480 * 2,
	) + PAD * 2
	height = 1180
	sheet = Image.new("RGB", (width, height), BG)
	d = ImageDraw.Draw(sheet)
	y = PAD

	_label(d, PAD, y, "DO ASEMAN - style lock (3/4 view, chapter 1)")
	y += 18

	# ----- پالت -----
	_label(d, PAD, y, "palette - chapter 1 (doc 04 unified table)")
	y += 14
	sw = 26
	x = PAD
	for name, code in sorted(P.ALL.items()):
		d.rectangle([x, y, x + sw - 2, y + sw - 2], fill=hex_rgba(code)[:3])
		x += sw
		if x + sw > width - PAD:
			x = PAD
			y += sw
	y += sw + 10
	d.line([(PAD, y), (width - PAD, y)], fill=RULE)
	y += 10

	# ----- شخصیت‌ها -----
	_label(d, PAD, y, "characters - 32x40, 3 directions (down / up / side), x4")
	y += 14
	sheet.paste(_z(kairo), (PAD, y), _z(kairo))
	y += kairo.height * ZOOM + 4
	sheet.paste(_z(ilara), (PAD, y), _z(ilara))
	y += ilara.height * ZOOM + 10
	d.line([(PAD, y), (width - PAD, y)], fill=RULE)
	y += 10

	# ----- کاشی -----
	_label(d, PAD, y, "tiles 16x16 x4 - grass / soil / cliff edge / front face / water / rope bridge / crumble / pit")
	y += 14
	sheet.paste(_z(tiles), (PAD, y), _z(tiles))
	y += tiles.height * ZOOM + 10
	d.line([(PAD, y), (width - PAD, y)], fill=RULE)
	y += 10

	# ----- رابط -----
	_label(d, PAD, y, "UI sample - dark blue panels, thin bright edge, star cursor (x4)")
	y += 14
	sheet.paste(_z(hud), (PAD, y), _z(hud))
	y += hud.height * ZOOM + 10
	d.line([(PAD, y), (width - PAD, y)], fill=RULE)
	y += 10

	# ----- پس‌زمینه -----
	_label(d, PAD, y, "background layers - sky (depth 1) / far (depth 2) / mid (depth 1), 480x270 each")
	y += 14
	for img, cap in ((sky, "sky"), (far, "far"), (mid, "mid")):
		sheet.paste(img.convert("RGB"), (PAD, y))
		_label(d, PAD + 486, y + 4, cap)
		y += 274
	d.line([(PAD, y), (width - PAD, y)], fill=RULE)
	y += 10

	# ----- خام در برابر پردازش‌شده -----
	_label(d, PAD, y, "cloudflare flux-1-schnell: raw 1024 (left) vs processed 480x270 (right)")
	y += 14
	if raw_img is not None:
		thumb = raw_img.resize((270, 270), Image.BOX)
		sheet.paste(thumb, (PAD, y))
		sheet.paste(mid.convert("RGB").resize((480, 270), Image.NEAREST), (PAD + 280, y))
	y += 280

	out = config.SCREENS / "style_lock.png"
	sheet.crop((0, 0, width, min(height, y + PAD))).save(out)
	return out


def _mid_prompt() -> str:
	from art_gen.cli import CF_ASSETS

	return CF_ASSETS["ch1_mid_3q"]["prompt"]


if __name__ == "__main__":
	path = build()
	print("ساخته شد: %s" % path.relative_to(config.ROOT))
