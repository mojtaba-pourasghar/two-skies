## کمک‌کار متن فارسی — docs/02_godot_spec.md §۱۳ و §۱۹
##
## §۱۹ دو چیز می‌خواهد: شکل‌دهی حروف چسبیده با `shape_fa()` و تبدیل کاف عربی به
## کاف فارسی. §۱۳ هم می‌خواهد اعداد فارسی نشان داده شوند.
##
## نکته: Godot 4 با TextServer Advanced خودش حروف فارسی را می‌چسباند و جهت
## راست‌به‌چپ را درست می‌کند، پس `shape_fa()` اینجا شکل‌دهی دستی نمی‌کند — فقط
## کاراکترهای عربی را به فارسی یکدست می‌کند و اعداد را برمی‌گرداند. اگر روی
## دستگاهی TextServer ساده فعال بود، شکل‌دهی دستی باید همین‌جا اضافه شود.
class_name Fa
extends RefCounted

const DIGITS := ["۰", "۱", "۲", "۳", "۴", "۵", "۶", "۷", "۸", "۹"]

## کاراکترهای عربی که باید به شکل فارسی یکدست شوند (§۱۹)
const NORMALIZE := {
	"ك": "ک",   # کاف عربی → کاف فارسی
	"ي": "ی",   # یای عربی → یای فارسی
	"ؤ": "و",
	"إ": "ا",
	"أ": "ا",
	"ۀ": "ه",
	"‌": "‌",  # نیم‌فاصله حفظ می‌شود
}


## متن را برای نمایش آماده می‌کند.
static func shape(text: String) -> String:
	var out := text
	for k in NORMALIZE.keys():
		out = out.replace(k, NORMALIZE[k])
	return out


## عدد لاتین → عدد فارسی (§۱۳)
static func num(value: int) -> String:
	return digits(str(value))


static func num_f(value: float, decimals: int = 1) -> String:
	return digits(String.num(value, decimals))


static func digits(s: String) -> String:
	var out := ""
	for ch in s:
		var code := ch.unicode_at(0)
		if code >= 48 and code <= 57:
			out += DIGITS[code - 48]
		else:
			out += ch
	return out


## زمان به شکل «۱:۰۵»
static func time(seconds: float) -> String:
	var total := int(round(seconds))
	return "%s:%s" % [num(total / 60), digits("%02d" % (total % 60))]


## متن از جدول رشته با کلید؛ اگر کلید نبود، در بیلد debug خودِ کلید برگردانده
## می‌شود تا سر جایش دیده شود (§۱۹).
static func t(key: String) -> String:
	# `tr()` متد غیر-static شیء است و از تابع static صدا زده نمی‌شود؛
	# TranslationServer همان کار را می‌کند و static است.
	var s := String(TranslationServer.translate(key))
	if s == key and OS.is_debug_build():
		return "⟦%s⟧" % key
	return shape(s)
