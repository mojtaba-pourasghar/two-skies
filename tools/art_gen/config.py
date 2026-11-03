"""تنظیمات، مسیرها و کلیدها — کلید فقط از متغیر محیطی."""

from __future__ import annotations

import os
from pathlib import Path

PKG = Path(__file__).resolve().parent
ROOT = PKG.parent.parent
GAME = ROOT / "game"
ART = GAME / "art"
ASSETS = GAME / "assets"
SPECS = PKG / "specs"
LOGS = PKG / "logs"
CACHE = PKG / "cache"
SCREENS = GAME / "docs_screens"

#: مدل متنی. اگر در دسترس نبود، در DECISIONS.md ثبت و با مدل موجود ادامه.
CLAUDE_MODEL = os.environ.get("ART_CLAUDE_MODEL", "claude-opus-5-5")

#: مدل تصویر Cloudflare Workers AI.
CF_MODEL = os.environ.get("ART_CF_MODEL", "@cf/black-forest-labs/flux-1-schnell")

#: سقف هزینه. هر دو شمارنده دارند و خودکار متوقف می‌شوند.
BUDGET_USD = float(os.environ.get("ART_BUDGET_USD", "20"))
CF_NEURONS = float(os.environ.get("ART_CF_NEURONS", "5000"))

#: برآورد مصرف نورون هر گام flux. عدد دقیق را Cloudflare در پاسخ برنمی‌گرداند،
#: پس این برآورد است و سقف واقعی را خود Cloudflare هم جدا اعمال می‌کند.
#: (DECISIONS.md: D-065)
NEURONS_PER_STEP = float(os.environ.get("ART_CF_NEURONS_PER_STEP", "9.6"))

#: قیمت هر میلیون توکن مدل متنی (ورودی/خروجی/نوشتن کش/خواندن کش).
CLAUDE_PRICE = {
	"input": float(os.environ.get("ART_PRICE_IN", "5.0")),
	"output": float(os.environ.get("ART_PRICE_OUT", "25.0")),
	"cache_write": float(os.environ.get("ART_PRICE_CW", "6.25")),
	"cache_read": float(os.environ.get("ART_PRICE_CR", "0.5")),
}


def anthropic_key() -> str | None:
	return os.environ.get("ANTHROPIC_API_KEY") or None


def cf_token() -> str | None:
	# هر دو نام پذیرفته می‌شود چون کاربر ممکن است CF_API_TOKEN بگذارد
	return os.environ.get("CLOUDFLARE_API_TOKEN") or os.environ.get("CF_API_TOKEN") or None


def cf_account() -> str | None:
	return os.environ.get("CLOUDFLARE_ACCOUNT_ID") or os.environ.get("CF_ACCOUNT_ID") or None


def redact(text: str) -> str:
	"""هر چیزی که شبیه کلید باشد از متن لاگ برداشته می‌شود."""
	out = text
	for value in (anthropic_key(), cf_token(), cf_account()):
		if value and len(value) > 7:
			out = out.replace(value, "<کلید-پنهان>")
	return out


def ensure_dirs() -> None:
	for d in (SPECS, LOGS, CACHE, ASSETS, SCREENS):
		d.mkdir(parents=True, exist_ok=True)
