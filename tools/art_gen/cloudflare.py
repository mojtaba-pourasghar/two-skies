"""مسیر Cloudflare Workers AI — تولید پس‌زمینه و صحنه با flux-1-schnell.

کلید و شناسهٔ حساب فقط از متغیر محیطی می‌آیند و هیچ‌جا نوشته نمی‌شوند. هر
پاسخ با hash درخواست کش می‌شود، پس اجرای دوباره هزینه‌ای ندارد.
"""

from __future__ import annotations

import base64
import json
import urllib.error
import urllib.request
from pathlib import Path

from . import budget, cache, config

ENDPOINT = "https://api.cloudflare.com/client/v4/accounts/%s/ai/run/%s"


class CloudflareUnavailable(RuntimeError):
	pass


def available() -> bool:
	return bool(config.cf_token() and config.cf_account())


def generate(
	prompt: str,
	*,
	steps: int = 4,
	variant: int = 0,
	ledger: budget.Ledger | None = None,
	dry_run: bool = False,
) -> bytes:
	"""یک تصویر می‌سازد و بایت PNG/JPEG برمی‌گرداند.

	پرامپت فقط توصیف متنی سبک است: هیچ نام بازی یا شخصیت واقعی در آن نیست و
	هیچ تصویر مرجع بیرونی فرستاده نمی‌شود (قید سبک هنری).
	"""
	# flux-1-schnell روی Workers AI فقط prompt و steps می‌پذیرد و seed ندارد
	# (پاسخ ۴۰۰: «Additional or unevaluated properties '/seed'»)، پس تنوع از
	# تصادفی بودن خود مدل می‌آید. variant فقط وارد کلید کش می‌شود تا هر نمونه
	# جداگانه کش شود، نه اینکه کش نمونهٔ اول را پس بدهد. (DECISIONS.md: D-066)
	payload = {"model": config.CF_MODEL, "prompt": prompt, "steps": steps, "variant": variant}
	k = cache.key(payload)

	hit = cache.get_bytes(k, "png")
	if hit is not None:
		if ledger:
			ledger.cache_hits += 1
		return hit

	if dry_run:
		raise CloudflareUnavailable("--dry-run: تولید تازه انجام نشد (کش خالی بود).")

	if not available():
		raise CloudflareUnavailable(
			"CLOUDFLARE_API_TOKEN و CLOUDFLARE_ACCOUNT_ID در محیط نیستند."
		)

	if ledger:
		ledger.check_cf(steps)

	body = {"prompt": prompt, "steps": steps}
	req = urllib.request.Request(
		ENDPOINT % (config.cf_account(), config.CF_MODEL),
		data=json.dumps(body).encode("utf-8"),
		headers={
			"Authorization": "Bearer %s" % config.cf_token(),
			"Content-Type": "application/json",
		},
		method="POST",
	)
	try:
		with urllib.request.urlopen(req, timeout=180) as resp:
			data = json.loads(resp.read().decode("utf-8"))
	except urllib.error.HTTPError as exc:
		raise CloudflareUnavailable(
			config.redact("HTTP %d: %s" % (exc.code, exc.read().decode("utf-8", "replace")[:300]))
		) from None
	except urllib.error.URLError as exc:
		raise CloudflareUnavailable(config.redact("شبکه: %s" % exc.reason)) from None

	if not data.get("success"):
		msgs = [e.get("message", "") for e in data.get("errors", [])]
		raise CloudflareUnavailable(config.redact("; ".join(msgs) or "پاسخ ناموفق"))

	result = data.get("result") or {}
	img_b64 = result.get("image")
	if not img_b64:
		raise CloudflareUnavailable("پاسخ تصویر نداشت: %s" % list(result.keys()))

	raw = base64.b64decode(img_b64)
	cache.put_bytes(k, raw, "png")
	if ledger:
		ledger.cf_calls += 1
		ledger.cf_steps += steps
	return raw


def log_prompt(name: str, prompt: str, steps: int) -> Path:
	config.ensure_dirs()
	p = config.LOGS / "cloudflare_prompts.md"
	with p.open("a", encoding="utf-8") as fh:
		fh.write("\n## %s (%d گام)\n\n```\n%s\n```\n" % (name, steps, prompt))
	return p
