"""خط فرمان ابزار هنر.

    python3 -I tools/art_gen/cli.py list
    python3 -I tools/art_gen/cli.py build --only kairo_idle
    python3 -I tools/art_gen/cli.py build --dry-run
    python3 -I tools/art_gen/cli.py cost

`--dry-run` هیچ فراخوانی تازه‌ای نمی‌کند: فقط از کش و از `specs/` می‌خواند و
می‌گوید چه چیزی ساخته می‌شد. پس می‌شود بدون خرج کردن، کل خط لوله را سنجید.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
sys.path.insert(0, str(Path(__file__).resolve().parent.parent.parent))

from art_gen import budget, claude_path, cloudflare, config, matrix  # noqa: E402
from art_gen import godot_export, postprocess  # noqa: E402

#: قرارداد دارایی‌ها. هنرمند بعداً فایل‌ها را با **همین نام و اندازه** عوض
#: می‌کند و هیچ کدی دست نمی‌خورد. شرح کامل در game/assets/README.md.
MATRIX_ASSETS: dict[str, dict] = {
	"kairo_3q": {
		"out": "sprites/td/kairo.png",
		"brief": "کایرو در نمای سه‌چهارم، سه جهت (پایین، بالا، پهلو)، ایستاده. "
		"روسری کوتاه نارنجی-قرمز با خط دوخت سفید، ژاکت تیره، ماژول هک آبی روی "
		"بازوی چپ، سر یک‌سوم قد. بوم ۳۲×۴۰، پا روی سطر ۳۶.",
	},
	"ilara_3q": {
		"out": "sprites/td/ilara.png",
		"brief": "ایلارا در نمای سه‌چهارم، سه جهت (پایین، بالا، پهلو)، ایستاده. "
		"روسری بلند فیروزه‌ای با خط دوخت سفید، ژاکت کهربایی، کمان بذر روی پشت، "
		"سر یک‌سوم قد. بوم ۳۲×۴۰، پا روی سطر ۳۶.",
	},
	"tiles_3q": {
		"out": "tilesets/ch1_3q.png",
		"brief": "هشت کاشی ۱۶×۱۶ نمای سه‌چهارم فصل ۱: سطح خاک، سطح سنگ، لبهٔ "
		"صخرهٔ گرد، دیوارهٔ جلوی صخره، علف روی لبه، سکوی شکننده، لبهٔ چاله، آب "
		"فیروزه‌ای با خط کف سفید.",
	},
	"ui_3q": {
		"out": "ui/td/hud.png",
		"brief": "یک صفحهٔ نمونهٔ رابط: پنل آبی تیره با لبهٔ روشن نازک، نوار "
		"سلامت و انرژی، شمارندهٔ سکه، دکمهٔ لمسی گرد، و مکان‌نمای ستارهٔ "
		"هشت‌پر. اصیل و بدون هیچ نماد مشهور.",
	},
	"hazards_3q": {
		"out": "sprites/td/hazards.png",
		"brief": "تیغه و فرستندهٔ لیزر در نمای سه‌چهارم، ۱۶×۱۶ هر کدام. خطر گرم "
		"و اشباع با راه‌راه زرد-تیره.",
	},
}

#: پس‌زمینه‌ها از Cloudflare. پرامپت فقط توصیف متنی سبک است.
CF_ASSETS: dict[str, dict] = {
	"ch1_sky_3q": {
		"out": "fx/td/ch1_sky.png",
		# آسمان خودش دورترین چیز است؛ پرسپکتیو رنگی عمق ۳ آن را به سه نوار
		# تخت می‌بُرد. عمق ۱ گرادیان را نگه می‌دارد. (DECISIONS.md: D-068)
		"depth": 1,
		"prompt": "painterly high-detail pixel art background, three-quarter "
		"top-down view, burning night sky over a ruined city, rust red fading "
		"to ash grey, soft volumetric fog, warm rim light from upper left, "
		"low contrast distant haze, 16-bit era limited palette, "
		"no text, no logo, no characters, no watermark",
	},
	"ch1_far_3q": {
		"out": "fx/td/ch1_far.png",
		"depth": 2,
		"despeckle": 3,
		"prompt": "painterly high-detail pixel art, three-quarter top-down "
		"view, distant rooftops and broken towers seen from above, purple blue "
		"low contrast haze, volumetric fog layer, 16-bit era limited palette, "
		"no text, no logo, no characters, no watermark",
	},
	"ch1_mid_3q": {
		"out": "fx/td/ch1_mid.png",
		"depth": 1,
		"prompt": "painterly high-detail pixel art, three-quarter top-down "
		"view, rounded rock cliffs with three-step shading, moss and grass on "
		"the edges, turquoise water with a white foam line at the rock edge, "
		"warm directional light from upper left, 16-bit era limited palette, "
		"no text, no logo, no characters, no watermark",
	},
}


def cmd_list(_args) -> int:
	print("— ماتریس (مسیر مدل متنی) —")
	for name, spec in MATRIX_ASSETS.items():
		have = (config.SPECS / ("%s.json" % name)).exists()
		print("  %-14s → %-26s %s" % (name, spec["out"], "spec دارد" if have else "spec ندارد"))
	print("— Cloudflare (پس‌زمینه) —")
	for name, spec in CF_ASSETS.items():
		print("  %-14s → %-26s عمق %d" % (name, spec["out"], spec["depth"]))
	print("\nپشتیبان مدل متنی: %s" % claude_path.pick_backend().name)
	print("Cloudflare در دسترس: %s" % ("بله" if cloudflare.available() else "خیر"))
	return 0


def _build_matrix(name: str, spec: dict, led: budget.Ledger, dry: bool) -> bool:
	try:
		res = claude_path.build(name, spec["brief"], ledger=led)
	except FileNotFoundError as exc:
		print("  ⊘ %s: %s" % (name, exc))
		return False
	sheet = matrix.render_sheet(res.sprite)
	out = config.ART / spec["out"]
	if dry:
		print("  ○ %s: %d فریم %dx%d، %s (نوشته نشد: --dry-run)"
			  % (name, res.sprite.frame_count, res.sprite.width, res.sprite.height,
				 "بی‌عیب" if res.report.ok else "%d خطا" % len(res.report.errors)))
		return res.report.ok
	out.parent.mkdir(parents=True, exist_ok=True)
	sheet.save(str(out))
	status = "✔" if res.report.ok else "✘"
	print("  %s %s → %s (%d فریم، %d دور نقد)"
		  % (status, name, spec["out"], res.sprite.frame_count, res.rounds))
	if not res.report.ok:
		print(res.report.text())
		_log_failure(name, res.report.errors)
	return res.report.ok


def _build_cf(name: str, spec: dict, led: budget.Ledger, dry: bool) -> bool:
	try:
		raw = cloudflare.generate(spec["prompt"], steps=4, ledger=led, dry_run=dry)
	except cloudflare.CloudflareUnavailable as exc:
		print("  ⊘ %s: %s" % (name, exc))
		_log_failure(name, [str(exc)])
		return False
	img = postprocess.pipeline_background(
		raw, depth=spec["depth"], despeckle_passes=spec.get("despeckle", 1)
	)
	if dry:
		print("  ○ %s: %dx%d از کش (نوشته نشد: --dry-run)" % (name, img.width, img.height))
		return True
	out = config.ART / spec["out"]
	out.parent.mkdir(parents=True, exist_ok=True)
	img.convert("RGB").save(str(out))
	cloudflare.log_prompt(name, spec["prompt"], 4)
	colors = len(set(img.convert("RGB").getdata()))
	print("  ✔ %s → %s (%d رنگ)" % (name, spec["out"], colors))
	return True


def _log_failure(name: str, reasons: list[str]) -> None:
	config.ensure_dirs()
	p = config.LOGS / "failures.md"
	with p.open("a", encoding="utf-8") as fh:
		fh.write("\n## %s\n\n" % name)
		for r in reasons:
			fh.write("- %s\n" % r)


def cmd_build(args) -> int:
	led = budget.load()
	only = args.only
	ok = True
	print("— ماتریس —")
	for name, spec in MATRIX_ASSETS.items():
		if only and name != only:
			continue
		ok = _build_matrix(name, spec, led, args.dry_run) and ok
	print("— Cloudflare —")
	for name, spec in CF_ASSETS.items():
		if only and name != only:
			continue
		ok = _build_cf(name, spec, led, args.dry_run) and ok
	if not args.dry_run:
		budget.save(led)
	print()
	print(led.report())
	return 0 if ok else 1


def cmd_cost(_args) -> int:
	print(budget.load().report())
	return 0


def main(argv: list[str] | None = None) -> int:
	ap = argparse.ArgumentParser(description="ابزار تولید هنر «دو آسمان»")
	sub = ap.add_subparsers(dest="cmd", required=True)

	sub.add_parser("list", help="فهرست دارایی‌ها و وضعیتشان").set_defaults(fn=cmd_list)

	b = sub.add_parser("build", help="ساخت دارایی‌ها")
	b.add_argument("--only", help="فقط همین دارایی")
	b.add_argument("--dry-run", action="store_true", help="بدون فراخوانی تازه و بدون نوشتن")
	b.set_defaults(fn=cmd_build)

	sub.add_parser("cost", help="گزارش هزینهٔ تجمعی").set_defaults(fn=cmd_cost)

	args = ap.parse_args(argv)
	config.ensure_dirs()
	return args.fn(args)


if __name__ == "__main__":
	raise SystemExit(main())
