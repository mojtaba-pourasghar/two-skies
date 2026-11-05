## مقیاس جهان — تنها منبع اندازه (CLAUDE.md قانون ۳)
##
## رزولوشن پایه ۱۲۸۰×۷۲۰، کاشی ۳۲×۳۲، قد بدن شخصیت ~۸۸ پیکسل. مقیاس قدیمی
## ۴۸۰×۲۷۰ با کاشی ۱۶ **منسوخ** است.
##
## چرا یک فایل: اندازهٔ کاشی پیش از این در سه جا جداگانه نوشته شده بود
## (`KairoConst`، `TdConst`، `LevelLoader`). وقتی مقیاس عوض شد، دو تایشان
## عقب ماندند و عددهای «بر حسب کاشی» دو برابر شدند — آزمون حل‌پذیری ۴٫۱ کاشی
## را ۸٫۲ خواند. یک منبع یعنی این دوباره نمی‌تواند پیش بیاید.
class_name WorldScale
extends RefCounted

const TILE: int = 32
const VIEWPORT := Vector2i(1280, 720)

## ضریب تبدیل هر مقدار پیکسلیِ نوشته‌شده در مقیاس قدیم (۴۸۰×۲۷۰، کاشی ۱۶).
const SCALE: float = 2.0

## قد بدن شخصیت روی برگهٔ تأییدشده (`art/approved/`).
const BODY_HEIGHT: int = 88

## بوم اسپرایت شخصیت و خط پا، طبق `BUILD_BRIEF §۶`.
const SPRITE_CANVAS: int = 128
const SPRITE_FOOT_Y: int = 124


## مقدار نوشته‌شده در مقیاس قدیم را به مقیاس امروز می‌برد.
static func px(old_value: float) -> float:
	return old_value * SCALE


## پیکسل به کاشی.
static func tiles(pixels: float) -> float:
	return pixels / float(TILE)
