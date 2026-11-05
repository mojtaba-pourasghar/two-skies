## ثابت‌های نمای سه‌چهارم — game/TOPDOWN_SPEC.md
##
## اعداد از پروفایل `topdown` در data/tuning.json می‌آیند، نه از وسط کد؛ مثل
## KairoConst که همین الگو را برای نمای کناری داشت.
class_name TdConst
extends RefCounted

## اندازهٔ کاشی. باید با `WorldScale.TILE` یکی باشد؛ GDScript در مقدار
## `const` به ثابت کلاس دیگر تکیه نمی‌کند (ترتیب بارگذاری)، پس عدد
## صریح است و `test_camera.gd` یکی بودنشان را می‌سنجد.
const TILE: int = 32
const FPS: int = 60

## جعبهٔ بدن همان ۱۰×۱۶ §۳ است و هنر بر پایهٔ آن کشیده می‌شود.
const BODY := Vector2(10, 16)

## ولی در نمای سه‌چهارم فقط **پا** با دیوار و چاله برخورد می‌کند: سر شخصیت
## جلوی دیوارِ پشتش کشیده می‌شود، پس اگر کل بدن برخورد کند بازیکن یک کاشی
## زودتر از آنچه می‌بیند می‌ایستد.
static var FOOT := Vector2(10, 8)
static var FOOT_OFFSET_Y: float = 4.0

static var RUN_SPEED: float = 96.0
static var ILARA_RUN_SPEED: float = 105.0
static var GROUND_ACCEL: float = 900.0
static var GROUND_DECEL: float = 1200.0

## جهش: کمان ثابت، بدون گرانش. ۳ کاشی در ۰٫۴ ثانیه.
static var HOP_DISTANCE: float = 48.0
static var HOP_TIME: float = 0.4
static var HOP_ARC_PX: float = 8.0

## دش ۲ کاشی دقیق: ۲۴۰ px/s × ۸ فریم = ۳۲ px.
static var DASH_SPEED: float = 240.0
static var DASH_TIME: float = 0.1333
static var DASH_COOLDOWN: float = 0.6

static var RESPAWN_TIME: float = 0.28
static var COMPANION_DELAY_FRAMES: int = 48

static var active_profile: String = "topdown"


## تعداد فریم یک بازهٔ زمانی. شمارندهٔ فریمی است نه delta انباشته، تا اجرای
## headless و اجرای واقعی دقیقاً یک نتیجه بدهند.
static func frames(seconds: float) -> int:
	return int(round(seconds * float(FPS)))


static func hop_frames() -> int:
	return frames(HOP_TIME)


static func dash_frames() -> int:
	return frames(DASH_TIME)


static func respawn_frames() -> int:
	return frames(RESPAWN_TIME)


static func apply_profile(tuning: Dictionary, profile_name: String = "topdown") -> void:
	var profiles: Dictionary = tuning.get("profiles", {})
	if not profiles.has(profile_name):
		push_warning("TdConst: پروفایل «%s» در tuning.json نیست." % profile_name)
		return
	var p: Dictionary = profiles[profile_name]
	var k: Dictionary = p.get("kairo", {})
	if k.has("RUN_SPEED"): RUN_SPEED = float(k["RUN_SPEED"])
	if k.has("GROUND_ACCEL"): GROUND_ACCEL = float(k["GROUND_ACCEL"])
	if k.has("GROUND_DECEL"): GROUND_DECEL = float(k["GROUND_DECEL"])
	if k.has("DASH_SPEED"): DASH_SPEED = float(k["DASH_SPEED"])
	if k.has("DASH_TIME"): DASH_TIME = float(k["DASH_TIME"])
	if k.has("DASH_COOLDOWN"): DASH_COOLDOWN = float(k["DASH_COOLDOWN"])
	if k.has("RESPAWN_TIME"): RESPAWN_TIME = float(k["RESPAWN_TIME"])

	var il: Dictionary = p.get("ilara", {})
	if il.has("RUN_SPEED"): ILARA_RUN_SPEED = float(il["RUN_SPEED"])

	var td: Dictionary = p.get("topdown", {})
	if td.has("HOP_DISTANCE"): HOP_DISTANCE = float(td["HOP_DISTANCE"])
	if td.has("HOP_TIME"): HOP_TIME = float(td["HOP_TIME"])
	if td.has("HOP_ARC_PX"): HOP_ARC_PX = float(td["HOP_ARC_PX"])
	if td.has("FOOT_BOX"):
		var fb: Array = td["FOOT_BOX"]
		FOOT = Vector2(float(fb[0]), float(fb[1]))
	if td.has("FOOT_OFFSET_Y"): FOOT_OFFSET_Y = float(td["FOOT_OFFSET_Y"])
	if td.has("COMPANION_DELAY_FRAMES"):
		COMPANION_DELAY_FRAMES = int(td["COMPANION_DELAY_FRAMES"])
	active_profile = profile_name


## هشت جهت. ورودی خام را به یکی از هشت جهت واحد می‌برد و قطر را نرمال می‌کند،
## تا حرکت مورب از حرکت محوری تندتر نباشد.
static func snap8(raw: Vector2) -> Vector2:
	if raw.length_squared() < 0.0001:
		return Vector2.ZERO
	var x: float = signf(raw.x) if absf(raw.x) > 0.35 else 0.0
	var y: float = signf(raw.y) if absf(raw.y) > 0.35 else 0.0
	if x == 0.0 and y == 0.0:
		return Vector2.ZERO
	return Vector2(x, y).normalized()


## جهت رویی برای انتخاب فریم: ۰ پایین، ۱ بالا، ۲ پهلو.
static func facing_row(dir: Vector2) -> int:
	if absf(dir.x) > absf(dir.y):
		return 2
	return 1 if dir.y < 0.0 else 0
