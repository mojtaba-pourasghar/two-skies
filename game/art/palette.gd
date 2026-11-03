## لوحهٔ رنگ یکپارچهٔ «دو آسمان».
##
## این فایل با tools/gen_art.py از tools/palette.py ساخته می‌شود — دستی ویرایشش
## نکن. سند ۰۴ می‌گوید «هیچ رنگی خارج از این جدول‌ها در بازی استفاده نمی‌شود»،
## پس هر رنگی در کد باید از اینجا بیاید.
class_name Palette
extends RefCounted

const AMBER_SUN := Color("#F2A63B")
const AURA_SOIL := Color("#8A5A3C")
const BOLT_BODY := Color("#C27C45")
const BURNT_STEEL := Color("#3A3F52")
const COIN := Color("#FFD34D")
const COLD_WHITE := Color("#E6F7FF")
const CRYSTAL_PINK := Color("#C58CFF")
const DANGER := Color("#FF4D4D")
const DIGITAL_CYAN := Color("#3AD7FF")
const EMERALD := Color("#34E0A1")
const ERROR_PURPLE := Color("#7A4DFF")
const FIRE_ORANGE := Color("#FF8A3D")
const ILARA_HAIR := Color("#3B2418")
const ILARA_JACKET := Color("#F2A63B")
const ILARA_SCARF := Color("#2FB8B0")
const ILARA_SKIN := Color("#C98F68")
const KAIRO_HAIR := Color("#2A1B14")
const KAIRO_JACKET := Color("#2B2F3F")
const KAIRO_SCARF := Color("#E4572E")
const KAIRO_SKIN := Color("#B97D56")
const LIGHT_DUST := Color("#C9CCD6")
const LIGHT_GREEN := Color("#8FD17A")
const LUMI_CALM := Color("#FFE9A8")
const MOSS_GREEN := Color("#3F8F5A")
const NIGHT_ASH := Color("#1F2230")
const NIGHT_BLUE := Color("#1B2A4A")
const RUST_RED := Color("#B8452F")
const SERVER_BLUE := Color("#123A66")
const SUCCESS := Color("#4DD08A")
const UI_PANEL := Color("#14161F")
const UI_TEXT := Color("#F5F5F7")
const WARN_YELLOW := Color("#F2C94C")
const WATER_TEAL := Color("#2FB8B0")
const WHITE := Color("#FFFFFF")

## سایه = رنگ پایه روی #1F2230 با ۴۰٪ (فرمول سند ۰۴).
static func shade(base: Color, amount: float = 0.40) -> Color:
	return base.lerp(NIGHT_ASH, amount)


## هایلایت = رنگ پایه روی #FFFFFF با ۳۰٪ (فرمول سند ۰۴).
static func light(base: Color, amount: float = 0.30) -> Color:
	return base.lerp(WHITE, amount)
