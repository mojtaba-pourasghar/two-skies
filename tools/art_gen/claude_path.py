"""مسیر ماتریس — تولید اسپرایت با مدل متنی، با اعتبارسنج و حلقهٔ نقد.

دو پشتیبان دارد:

  * `ApiBackend` — فراخوانی واقعی Anthropic با `ANTHROPIC_API_KEY`، با
    prompt caching روی راهنمای سبک (که در هر فراخوانی تکرار می‌شود و بیشترین
    توکن ورودی را می‌گیرد) و شمارش هزینه.
  * `SpecBackend` — ماتریس‌هایی که همین‌جا در `specs/` نوشته شده‌اند. هزینهٔ
    صفر، نتیجهٔ قطعی و قابل بازبینی در گیت. وقتی کلید نیست همین کار می‌کند.

هر دو خروجی یکسانی می‌دهند (یک `matrix.Sprite`)، پس بقیهٔ خط لوله نمی‌فهمد
کدام را گرفته است.
"""

from __future__ import annotations

import json
import time
import urllib.error
import urllib.request
from dataclasses import dataclass
from pathlib import Path

from . import budget, cache, config, matrix

API_URL = "https://api.anthropic.com/v1/messages"

#: معیارهای نقد — همان فهرستی که در دستور گام ۱۱الف آمده.
CRITERIA = [
	"سیلوئت: شکل در اندازهٔ واقعی و تک‌رنگ هم خوانا باشد",
	"خط دور: یک پیکسل، تیرهٔ هم‌خانواده، نه مشکی خالص",
	"تضاد: اختلاف روشنایی با پس‌زمینه دست‌کم ۳۰ درصد",
	"خطر: گرم و اشباع، با راه‌راه زرد-تیره یا شکل هشداردهنده",
	"سایه: سه پله (سایه، میانه، روشن) برای هر ماده",
	"یکدستی فریم‌ها: حجم و جای پا بین فریم‌ها نپرد",
	"نور: جهت‌دار از بالا-چپ، سایهٔ ۲ پیکسلی پایین-راست",
	"پالت: هر رنگ از لوحهٔ سند ۰۴، سقف ۱۶ رنگ",
]

MAX_ROUNDS = 3


@dataclass
class Result:
	sprite: matrix.Sprite
	rounds: int
	report: matrix.Report
	source: str


class Backend:
	name = "?"

	def make(self, name: str, brief: str, *, ledger: budget.Ledger) -> matrix.Sprite:
		raise NotImplementedError

	def revise(
		self, sprite: matrix.Sprite, brief: str, notes: list[str], *, ledger: budget.Ledger
	) -> matrix.Sprite:
		raise NotImplementedError


class SpecBackend(Backend):
	"""ماتریس را از `specs/<name>.json` برمی‌دارد."""

	name = "specs"

	def make(self, name: str, brief: str, *, ledger: budget.Ledger) -> matrix.Sprite:
		path = config.SPECS / ("%s.json" % name)
		if not path.exists():
			raise FileNotFoundError(
				"ماتریس «%s» در %s نیست و کلید مدل هم در محیط نیست." % (name, path)
			)
		return matrix.load(path)

	def revise(self, sprite, brief, notes, *, ledger):
		# بازبینی دستی است: یادداشت‌ها در لاگ می‌نشینند و فایل spec اصلاح می‌شود
		return sprite


STYLE_GUIDE = """شما یک هنرمند پیکسل‌آرت هستید که برای بازی «دو آسمان» کار می‌کنید.

سبک: پیکسل‌آرت نقاشی‌وار با نور مدرن، نمای سه‌چهارم حدود ۳۵ درجه. کاملاً اصیل؛
هیچ شخصیت، اسپرایت یا لوگویی از هیچ بازی دیگری کپی نمی‌شود.

قواعد فنی:
- کاشی ۱۶×۱۶ پیکسل، بوم شخصیت ۳۲×۴۰، رزولوشن صحنه ۴۸۰×۲۷۰.
- حداکثر ۱۶ رنگ برای هر اسپرایت.
- خط دور یک پیکسل با رنگ تیرهٔ هم‌خانواده، هرگز مشکی خالص.
- سه پله سایه برای هر ماده: سایه، میانه، روشن.
- نور جهت‌دار از بالا-چپ؛ سایهٔ ۲ پیکسلی پایین-راست و بیضی کوچک زیر پا.
- خطر گرم و اشباع؛ امن سرد و کم‌اشباع؛ لمس‌پذیر لبهٔ سفید یک‌پیکسلی.
- کاشی سه‌چهارم دو بخش دارد: سطح ۱۶×۱۶ و دیوارهٔ جلو ۱۶ پیکسل.

قالب پاسخ: فقط یک شیء JSON، بدون توضیح پیرامونش:
{"name": "...", "size": [w, h], "palette": {"a": "#RRGGBB", ...},
 "frames": [["...", ...], ...], "anchor": [x, y]}
«.» شفاف است. هر حرف دیگر باید در palette باشد. هر فریم دقیقاً h سطر و هر سطر
دقیقاً w نویسه دارد."""


class ApiBackend(Backend):
	"""فراخوانی واقعی مدل. راهنمای سبک با prompt caching فرستاده می‌شود."""

	name = "api"

	def __init__(self, model: str | None = None) -> None:
		self.model = model or config.CLAUDE_MODEL

	def _call(self, blocks: list[dict], *, ledger: budget.Ledger, max_tokens: int = 8000) -> str:
		body = {
			"model": self.model,
			"max_tokens": max_tokens,
			"system": [
				{
					"type": "text",
					"text": STYLE_GUIDE,
					# راهنمای سبک در هر فراخوانی تکرار می‌شود، پس کش می‌شود
					"cache_control": {"type": "ephemeral"},
				}
			],
			"messages": [{"role": "user", "content": blocks}],
		}
		k = cache.key({"model": self.model, "body": body})
		hit = cache.get_json(k)
		if hit is not None:
			ledger.cache_hits += 1
			return hit["text"]

		ledger.check_claude()
		key = config.anthropic_key()
		if not key:
			raise RuntimeError("ANTHROPIC_API_KEY در محیط نیست.")

		req = urllib.request.Request(
			API_URL,
			data=json.dumps(body).encode("utf-8"),
			headers={
				"x-api-key": key,
				"anthropic-version": "2023-06-01",
				"content-type": "application/json",
			},
			method="POST",
		)
		for attempt in range(3):
			try:
				with urllib.request.urlopen(req, timeout=180) as resp:
					data = json.loads(resp.read().decode("utf-8"))
				break
			except urllib.error.HTTPError as exc:
				detail = exc.read().decode("utf-8", "replace")[:300]
				if exc.code in (429, 500, 529) and attempt < 2:
					time.sleep(2 ** attempt)
					continue
				raise RuntimeError(config.redact("HTTP %d: %s" % (exc.code, detail))) from None

		usage = data.get("usage", {})
		ledger.claude_calls += 1
		ledger.claude_in += int(usage.get("input_tokens", 0))
		ledger.claude_out += int(usage.get("output_tokens", 0))
		ledger.claude_cache_write += int(usage.get("cache_creation_input_tokens", 0))
		ledger.claude_cache_read += int(usage.get("cache_read_input_tokens", 0))

		text = "".join(b.get("text", "") for b in data.get("content", []))
		cache.put_json(k, {"text": text})
		return text

	def make(self, name: str, brief: str, *, ledger: budget.Ledger) -> matrix.Sprite:
		raw = self._call([{"type": "text", "text": brief}], ledger=ledger)
		return matrix.from_dict(_extract_json(raw))

	def revise(self, sprite, brief, notes, *, ledger):
		msg = (
			"این ماتریس را اصلاح کن. مشکل‌ها:\n- %s\n\nماتریس فعلی:\n%s\n\nشرح اصلی:\n%s"
			% ("\n- ".join(notes), json.dumps(_to_dict(sprite), ensure_ascii=False), brief)
		)
		raw = self._call([{"type": "text", "text": msg}], ledger=ledger)
		return matrix.from_dict(_extract_json(raw))


def _extract_json(text: str) -> dict:
	start = text.find("{")
	end = text.rfind("}")
	if start < 0 or end <= start:
		raise ValueError("پاسخ مدل JSON نداشت: %s" % text[:200])
	return json.loads(text[start : end + 1])


def _to_dict(sp: matrix.Sprite) -> dict:
	out = {
		"name": sp.name,
		"size": [sp.width, sp.height],
		"palette": sp.palette,
		"frames": sp.frames,
	}
	if sp.anchor:
		out["anchor"] = list(sp.anchor)
	return out


def pick_backend() -> Backend:
	"""اگر کلید هست مسیر API، وگرنه ماتریس‌های specs/."""
	return ApiBackend() if config.anthropic_key() else SpecBackend()


def build(
	name: str,
	brief: str,
	*,
	backend: Backend | None = None,
	ledger: budget.Ledger | None = None,
	rounds: int = MAX_ROUNDS,
) -> Result:
	"""تولید → اعتبارسنجی → نقد → اصلاح، حداکثر `rounds` دور.

	هر دور در `logs/critique_<name>.md` ثبت می‌شود: چه ساخته شد، اعتبارسنج چه
	گفت، و چه اصلاحی خواسته شد.
	"""
	be = backend or pick_backend()
	led = ledger if ledger is not None else budget.load()
	config.ensure_dirs()
	log = config.LOGS / ("critique_%s.md" % name)
	lines = ["# نقد «%s» (پشتیبان: %s)\n" % (name, be.name)]

	sprite = be.make(name, brief, ledger=led)
	report = matrix.validate(sprite)
	used = 1
	lines.append("\n## دور ۱\n\n%s\n" % report.text())

	while used < rounds and (report.errors or report.warnings):
		notes = report.errors + report.warnings
		revised = be.revise(sprite, brief, notes, ledger=led)
		if revised is sprite:
			lines.append("\n(پشتیبان اصلاح خودکار ندارد؛ همین‌جا ایستاد.)\n")
			break
		sprite = revised
		report = matrix.validate(sprite)
		used += 1
		lines.append("\n## دور %d\n\n%s\n" % (used, report.text()))

	lines.append("\n## معیارها\n\n" + "\n".join("- " + c for c in CRITERIA) + "\n")
	log.write_text("".join(lines), encoding="utf-8")
	return Result(sprite=sprite, rounds=used, report=report, source=be.name)
