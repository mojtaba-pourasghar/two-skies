#!/usr/bin/env python3
"""مقایسهٔ کیفیت هر تصویرِ تبدیل‌شده با اصل PNG آن.

شرط ۲ کاربر (۱۴۰۵/۰۸/۲۱): «هر اتاق تازه‌ای که اضافه می‌شود، یک بار
مقایسهٔ PNG و WebP بگیرد.» به‌جای عادت دستی، اینجا **خودکار** است و در
`run_tests.sh` اجرا می‌شود — پس اتاق تازه هم خودش سنجیده می‌شود.

    python3 -I tools/check_webp.py
    python3 -I tools/check_webp.py --report   # جدول همهٔ فایل‌ها

شرط عبور:
  * میانگین اختلاف هر کانال ≤ ۳ از ۲۵۵ (R1c که کاربر دید ۲٫۰ داشت)
  * سهم پیکسل‌هایی با اختلاف >۲۴ ≤ ۱٪

**چرا بیشینه معیار نیست:** اولین نسخه «بیشینهٔ اختلاف ≤۹۰» می‌گذاشت و
۲۳ فایل از ۶۷ را رد می‌کرد، بعضی با بیشینهٔ ۲۵۵. ولی بیشینه **یک پیکسل**
است و روی لبهٔ سیاه‑به‑سفید هر کدک اتلافی آن را می‌ترکاند. چیزی که به چشم
می‌آید «چند پیکسل جابه‌جا شده‌اند»، نه «بدترین پیکسل چقدر». R1c که کاربر
با چشم تأیید کرد بیشینهٔ ۷۹ داشت.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

#: خاکستری میانه برای ترکیب؛ نه سیاه و نه سفید، تا هیچ سمتی لطف نبیند.
FLATTEN_BG = (128, 128, 128)

ROOT = Path(__file__).resolve().parent.parent
DROP = ROOT / "art_drop"
DEST = ROOT / "game" / "assets"

MEAN_MAX = 3.0
#: اختلافی که روی صفحه به چشم می‌آید، و چند درصد تصویر اجازه دارد.
VISIBLE_DELTA = 24
VISIBLE_PCT_MAX = 1.0


def _flatten(im):
	"""تصویر را روی پس‌زمینهٔ مات می‌نشاند و RGB می‌دهد."""
	from PIL import Image
	if im.mode in ("RGBA", "LA") or (im.mode == "P" and "transparency" in im.info):
		im = im.convert("RGBA")
		bg = Image.new("RGB", im.size, FLATTEN_BG)
		bg.paste(im, mask=im.split()[3])
		return bg
	return im.convert("RGB")


def compare(png: Path, webp: Path) -> tuple[float, float]:
	"""(میانگین اختلاف کانال، درصد پیکسل‌های آشکارا جابه‌جا).

	**هر دو روی یک پس‌زمینهٔ مات ترکیب می‌شوند.** مقایسهٔ خام RGB غلط
	است: زیر پیکسل کاملاً شفاف، PNG هر رنگی می‌تواند داشته باشد و
	کدگذار آن را صفر می‌کند — رنگی که هرگز روی صفحه نمی‌آید. با مقایسهٔ
	خام، یک تصویر **بی‌اتلاف** میانگین ۲۱٫۶ گرفت و بدتر از نسخهٔ اتلافی
	دیده شد. آنچه بازیکن می‌بیند نتیجهٔ ترکیب است، پس همان سنجیده می‌شود.
	"""
	from PIL import Image, ImageChops
	with Image.open(png) as _a, Image.open(webp) as _b:
		a = _flatten(_a)
		b = _flatten(_b)
		if a.size != b.size:
			return (999.0, 999.0)
		d = ImageChops.difference(a, b)
		hist = d.histogram()
	total = 0.0
	count = 0
	loud = 0
	for ch in range(3):
		band = hist[ch * 256:(ch + 1) * 256]
		for v, n in enumerate(band):
			total += v * n
			count += n
			if v > VISIBLE_DELTA:
				loud += n
	mean = total / count if count else 0.0
	pct = (loud / count * 100.0) if count else 0.0
	return (mean, pct)


def main(argv: list[str] | None = None) -> int:
	ap = argparse.ArgumentParser()
	ap.add_argument("--report", action="store_true", help="جدول همهٔ فایل‌ها")
	args = ap.parse_args(argv)

	if not DEST.exists():
		print("game/assets/ نیست — اول import_art.py را اجرا کن.")
		return 1

	rows = []
	for webp in sorted(DEST.rglob("*.webp")):
		rel = webp.relative_to(DEST)
		png = DROP / rel.with_suffix(".png")
		if not png.exists():
			continue
		mean, pct = compare(png, webp)
		rows.append((mean, pct, str(rel)))

	if not rows:
		print("هیچ تصویر تبدیل‌شده‌ای نبود (شاید --no-webp اجرا شده).")
		return 0

	bad = [r for r in rows if r[0] > MEAN_MAX or r[1] > VISIBLE_PCT_MAX]
	rows.sort(reverse=True)

	if args.report:
		print("%-9s %-8s %s" % ("میانگین", "٪آشکار", "فایل"))
		for mean, pct, rel in rows:
			print("%-9.2f %-8.2f %s" % (mean, pct, rel))
		print()

	worst = rows[0]
	print("— کیفیت WebP —")
	print("  %d تصویر تبدیل‌شده سنجیده شد" % len(rows))
	print("  بدترین: میانگین %.2f، %.2f٪ پیکسل آشکار — %s" % worst)
	print("  آستانه: میانگین ≤%.1f، پیکسل آشکار (>%d) ≤%.1f٪"
		  % (MEAN_MAX, VISIBLE_DELTA, VISIBLE_PCT_MAX))

	if bad:
		print("  ✘ %d فایل از آستانه گذشت:" % len(bad))
		for mean, pct, rel in sorted(bad, reverse=True)[:10]:
			print("      میانگین %.2f، %.2f٪ آشکار — %s" % (mean, pct, rel))
		print("  رفع: مسیرشان را در WEBP_OVERRIDES در tools/import_art.py")
		print("       با کیفیت ۹۵ یا \"lossless\" بگذار و دوباره import کن.")
		return 1
	print("  ✔ همه زیر آستانه")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
