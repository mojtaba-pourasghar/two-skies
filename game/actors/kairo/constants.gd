## ثابت‌های حرکتی — docs/02_godot_spec.md §۳
##
## همهٔ اعداد بر حسب پیکسل و ثانیه‌اند. مقادیر پیش‌فرض از سند ۰۲ است (پروفایل spec02).
## `data/tuning.json` هر دو مجموعهٔ اعداد (سند ۰۲ و سند ۰۱) را نگه می‌دارد و
## `apply_profile()` در بوت یکی را فعال می‌کند، تا در بازی‌تست با عوض کردن یک رشته
## در tuning.json بشود کل حس بازی را جابه‌جا کرد بدون دست زدن به کد.
##
## به همین دلیل این‌ها `static var` هستند و نه `const`.
class_name KairoConst
extends RefCounted

const TILE: int = 16

## بوم تصویر ۳۲×۴۰ است ولی جعبهٔ برخورد ۱۰×۱۶ (§۳)
const HITBOX := Vector2(10, 16)
const HURTBOX_SHRINK: float = 2.0
const DASH_CHARGES: int = 1

static var GRAVITY: float = 900.0
static var FALL_GRAVITY_MULT: float = 1.25
static var MAX_FALL: float = 360.0
static var RUN_SPEED: float = 120.0
static var GROUND_ACCEL: float = 900.0
static var GROUND_DECEL: float = 1200.0
static var AIR_ACCEL: float = 700.0
static var AIR_DECEL: float = 500.0
static var JUMP_VELOCITY: float = -306.0
static var JUMP_CUT: float = 0.45
static var COYOTE_TIME: float = 0.10
static var JUMP_BUFFER: float = 0.12
static var WALL_SLIDE_MAX: float = 60.0
static var WALL_JUMP_VEL := Vector2(170.0, -280.0)
static var WALL_JUMP_LOCK: float = 0.15
static var DASH_SPEED: float = 260.0
static var DASH_TIME: float = 0.18
static var DASH_COOLDOWN: float = 0.6
static var RESPAWN_TIME: float = 0.35

## ضریب شتاب روی زمین لغزنده (§۳)
const SLIPPERY_ACCEL_MULT: float = 0.3

## ایلارا همان فیزیک را دارد با ثابت‌های خودش (§۵)
static var ILARA_RUN_SPEED: float = 105.0
static var ILARA_JUMP_VELOCITY: float = -290.0

## نام پروفایل فعال، برای نمایش در صفحهٔ توسعه
static var active_profile: String = "spec02"


## یک پروفایل از tuning.json را روی ثابت‌ها اعمال می‌کند.
## پروفایل‌های جزئی (مثل design01) فقط کمیت‌های متفاوت را دارند و بقیه دست‌نخورده می‌مانند،
## پس همیشه اول spec02 و بعد پروفایل خواسته‌شده اعمال می‌شود.
static func apply_profile(tuning: Dictionary, profile_name: String) -> void:
	var profiles: Dictionary = tuning.get("profiles", {})
	if not profiles.has(profile_name):
		push_warning("KairoConst: پروفایل «%s» در tuning.json نیست؛ spec02 استفاده می‌شود." % profile_name)
		profile_name = "spec02"
	if profile_name != "spec02" and profiles.has("spec02"):
		_apply_one(profiles["spec02"])
	_apply_one(profiles.get(profile_name, {}))
	active_profile = profile_name


static func _apply_one(profile: Dictionary) -> void:
	var k: Dictionary = profile.get("kairo", {})
	if k.has("GRAVITY"): GRAVITY = float(k["GRAVITY"])
	if k.has("FALL_GRAVITY_MULT"): FALL_GRAVITY_MULT = float(k["FALL_GRAVITY_MULT"])
	if k.has("MAX_FALL"): MAX_FALL = float(k["MAX_FALL"])
	if k.has("RUN_SPEED"): RUN_SPEED = float(k["RUN_SPEED"])
	if k.has("GROUND_ACCEL"): GROUND_ACCEL = float(k["GROUND_ACCEL"])
	if k.has("GROUND_DECEL"): GROUND_DECEL = float(k["GROUND_DECEL"])
	if k.has("AIR_ACCEL"): AIR_ACCEL = float(k["AIR_ACCEL"])
	if k.has("AIR_DECEL"): AIR_DECEL = float(k["AIR_DECEL"])
	if k.has("JUMP_VELOCITY"): JUMP_VELOCITY = float(k["JUMP_VELOCITY"])
	if k.has("JUMP_CUT"): JUMP_CUT = float(k["JUMP_CUT"])
	if k.has("COYOTE_TIME"): COYOTE_TIME = float(k["COYOTE_TIME"])
	if k.has("JUMP_BUFFER"): JUMP_BUFFER = float(k["JUMP_BUFFER"])
	if k.has("WALL_SLIDE_MAX"): WALL_SLIDE_MAX = float(k["WALL_SLIDE_MAX"])
	if k.has("WALL_JUMP_VEL_X"): WALL_JUMP_VEL.x = float(k["WALL_JUMP_VEL_X"])
	if k.has("WALL_JUMP_VEL_Y"): WALL_JUMP_VEL.y = float(k["WALL_JUMP_VEL_Y"])
	if k.has("WALL_JUMP_LOCK"): WALL_JUMP_LOCK = float(k["WALL_JUMP_LOCK"])
	if k.has("DASH_SPEED"): DASH_SPEED = float(k["DASH_SPEED"])
	if k.has("DASH_TIME"): DASH_TIME = float(k["DASH_TIME"])
	if k.has("DASH_COOLDOWN"): DASH_COOLDOWN = float(k["DASH_COOLDOWN"])
	if k.has("RESPAWN_TIME"): RESPAWN_TIME = float(k["RESPAWN_TIME"])

	var i: Dictionary = profile.get("ilara", {})
	if i.has("RUN_SPEED"): ILARA_RUN_SPEED = float(i["RUN_SPEED"])
	if i.has("JUMP_VELOCITY"): ILARA_JUMP_VELOCITY = float(i["JUMP_VELOCITY"])


## بیشترین ارتفاع پرش بر حسب پیکسل، از خود ثابت‌ها حساب می‌شود.
## اعتبارسنج مرحله از همین استفاده می‌کند تا با حس واقعی بازی بخواند.
static func jump_height_px() -> float:
	return (JUMP_VELOCITY * JUMP_VELOCITY) / (2.0 * GRAVITY)


## بیشترین برد افقی یک پرش کامل در حداکثر سرعت.
static func jump_range_px() -> float:
	var t_up: float = absf(JUMP_VELOCITY) / GRAVITY
	var t_down: float = sqrt(2.0 * jump_height_px() / (GRAVITY * FALL_GRAVITY_MULT))
	return RUN_SPEED * (t_up + t_down)
