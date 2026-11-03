"""لوحهٔ رنگ یکپارچهٔ «دو آسمان» — تنها مرجع رنگ.

برگرفته از docs/04_art_and_sound_bible.md بخش «لوحهٔ رنگ یکپارچه و قالب مشترک
صحنه»، که خودش می‌گوید «بر هر کد رنگ دیگری در سند برتری دارد» و «هیچ رنگی خارج
از این جدول‌ها در بازی استفاده نمی‌شود».

هر سایه و هایلایت با فرمول خود سند ساخته می‌شود، نه با چشم:
    سایه    = رنگ پایه روی #1F2230 با ۴۰٪
    هایلایت = رنگ پایه روی #FFFFFF با ۳۰٪
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from pixel import RGBA, hex_rgba, mix  # noqa: E402

# ----- ۶ رنگ پایه: زمین (کایرو) -----
NIGHT_ASH = "#1F2230"      # خاکستر شب — پس‌زمینهٔ تیره
BURNT_STEEL = "#3A3F52"    # فولاد سوخته
RUST_RED = "#B8452F"       # زنگ سرخ
FIRE_ORANGE = "#FF8A3D"    # آتش نارنجی
WARN_YELLOW = "#F2C94C"    # زرد هشدار
LIGHT_DUST = "#C9CCD6"     # خاک روشن

# ----- ۴ رنگ نکسا -----
COLD_WHITE = "#E6F7FF"
DIGITAL_CYAN = "#3AD7FF"
SERVER_BLUE = "#123A66"
ERROR_PURPLE = "#7A4DFF"

# ----- ۷ رنگ اورا (ایلارا) -----
MOSS_GREEN = "#3F8F5A"
LIGHT_GREEN = "#8FD17A"
WATER_TEAL = "#2FB8B0"
AMBER_SUN = "#F2A63B"
AURA_SOIL = "#8A5A3C"
NIGHT_BLUE = "#1B2A4A"
CRYSTAL_PINK = "#C58CFF"

# ----- ۸ رنگ شخصیت -----
ILARA_SCARF = "#2FB8B0"
ILARA_JACKET = "#F2A63B"
ILARA_SKIN = "#C98F68"
ILARA_HAIR = "#3B2418"
KAIRO_SCARF = "#E4572E"
KAIRO_JACKET = "#2B2F3F"
KAIRO_SKIN = "#B97D56"
KAIRO_HAIR = "#2A1B14"

# ----- ۷ رنگ رابط و ترکیب -----
UI_PANEL = "#14161F"       # و «پس‌زمینهٔ دور همیشه #14161F»
UI_TEXT = "#F5F5F7"
COIN = "#FFD34D"
EMERALD = "#34E0A1"
DANGER = "#FF4D4D"         # «خطر همیشه قرمز #FF4D4D با چشمک ۴ هرتز»
SUCCESS = "#4DD08A"
WHITE = "#FFFFFF"          # لبهٔ سفید ۱ پیکسلی چیزهای لمس‌پذیر

# ----- بولت و لومی (رنگ‌هایی که سند جدا آورده) -----
BOLT_BODY = "#C27C45"
LUMI_CALM = "#FFE9A8"

#: فضای رنگی فصل ۱ (ردیف فصل ۱ جدول لوحهٔ یکپارچه)
CH1 = {
    "accent": FIRE_ORANGE,
    "second": WARN_YELLOW,
    "sky_top": RUST_RED,
    "sky_bottom": NIGHT_ASH,
    "danger": DANGER,
}

#: همهٔ رنگ‌های مجاز، برای نگهبان «هیچ رنگی خارج از این جدول».
ALL = {
    name: value
    for name, value in list(globals().items())
    if name.isupper() and isinstance(value, str) and value.startswith("#")
}


def rgba(code: str, alpha: int = 255) -> RGBA:
    return hex_rgba(code, alpha)


def shade(code: str, amount: float = 0.40) -> RGBA:
    """سایه = رنگ پایه روی #1F2230 با ۴۰٪ (فرمول سند ۰۴)."""
    return mix(hex_rgba(code), hex_rgba(NIGHT_ASH), amount)


def light(code: str, amount: float = 0.30) -> RGBA:
    """هایلایت = رنگ پایه روی #FFFFFF با ۳۰٪ (فرمول سند ۰۴)."""
    return mix(hex_rgba(code), hex_rgba(WHITE), amount)


def to_gd_name(name: str) -> str:
    return name
