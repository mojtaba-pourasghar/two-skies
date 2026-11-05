## کارگردان دوربین — تغییر خودکار حالت وسط ناحیه (D-ART-09d، T3)
##
## بازی دو حالت دارد: `topdown` (اکتشاف، نقشه، نبرد) و `side` (اتاق چالش).
## تا پیش از D-ART-09d حالت برای کل مرحله ثابت بود؛ حالا **تابع جای شخصیت**
## است: با ورود پا به یک `camera_zone`، حالت خودش و نرم عوض می‌شود — بدون
## دکمه، بدون صفحهٔ بارگذاری، وسط همان ناحیه (سند ۰۹ §۲ب).
##
## این گره فقط **تصمیم و زمان‌بندی** را نگه می‌دارد و سیگنال می‌دهد؛ دوربین
## واقعی (T6) و فیزیک بازیگر (T15) به سیگنال‌ها گوش می‌دهند. این‌طور زمان‌بندی
## بدون صحنه و بدون رندر آزمودنی است.
class_name CameraDirector
extends Node

## گذار شروع شد. `from` و `to` یکی از MODE_* هستند.
signal mode_changing(from: String, to: String)
## گذار تمام شد.
signal mode_changed(mode: String)
## نگاشت کنترل‌ها کامل شد (۰٫۲ ثانیه پس از شروع گذار).
signal controls_remapped(mode: String)

const MODE_TOPDOWN := "topdown"
const MODE_SIDE := "side"

## ۰٫۶ ثانیه: عدد صریح D-ART-09d.
const BLEND_TIME: float = 0.6
## ۰٫۲ ثانیه: «کنترل‌ها با ۰٫۲ث تغییر نگاشت می‌شوند» (سند ۰۹ §۲ب).
const REMAP_TIME: float = 0.2
## «در تغییر، یک فریم ورودی نادیده گرفته می‌شود تا اشتباه نشود» (سند ۰۹ §۲ب).
const SKIP_INPUT_FRAMES: int = 1

const FPS: int = 60

## حاشیهٔ هیسترزیس مرز ناحیه، بر حسب پیکسل.
##
## بدون آن، ایستادن **دقیقاً روی لبه** حالت را هر فریم عوض می‌کند: بازیکن
## یک پیکسل تکان می‌خورد، داخل می‌شود، گذار ۰٫۶ث شروع می‌شود، یک پیکسل
## برمی‌گردد، گذار برعکس… و دوربین می‌لرزد. با این حاشیه، ناحیهٔ فعال تا
## وقتی رها نمی‌شود که پا واقعاً از آن دور شود.
## (DECISIONS.md: D-ART-23)
const ZONE_HYSTERESIS: float = 12.0

## نمای هر حالت. دوربین واقعی (T6) این‌ها را درون‌یابی می‌کند.
const PRESENTATION := {
	MODE_TOPDOWN: {"rotation": 0.0, "zoom": 1.0, "offset_y": 0.0},
	MODE_SIDE: {"rotation": 0.0, "zoom": 1.15, "offset_y": -24.0},
}

## پروفایل tuning هر حالت — دستی انتخاب نمی‌شود (T3).
const PROFILE := {
	MODE_TOPDOWN: "topdown",
	MODE_SIDE: "challenge_side",
}

var mode: String = MODE_TOPDOWN
var default_mode: String = MODE_TOPDOWN
var zones: Array[Dictionary] = []

var _blend_frames_left: int = 0
var _remap_frames_left: int = 0
var _skip_frames_left: int = 0
var _from_mode: String = MODE_TOPDOWN
var _active_zone: String = ""


static func blend_frames() -> int:
	return int(round(BLEND_TIME * float(FPS)))


static func remap_frames() -> int:
	return int(round(REMAP_TIME * float(FPS)))


## ناحیه‌های مرحله را می‌نشاند. هر ناحیه:
##   {"id": "challenge_a", "rect": [c, r, w, h], "mode": "side"}
## `rect` بر حسب **کاشی** است، نه پیکسل، چون نقشه‌ها کاشی‌محورند.
func setup(level_default_mode: String, level_zones: Array, tile_px: int = 32) -> void:
	default_mode = _valid(level_default_mode)
	mode = default_mode
	_tile_px = maxi(1, tile_px)
	zones.clear()
	for raw in level_zones:
		var z: Dictionary = raw
		var rect: Array = z.get("rect", [])
		if rect.size() != 4:
			push_warning("CameraDirector: ناحیهٔ «%s» rect چهارتایی ندارد." % z.get("id", "?"))
			continue
		zones.append({
			"id": String(z.get("id", "")),
			"mode": _valid(String(z.get("mode", MODE_SIDE))),
			"rect": Rect2(
				float(rect[0]) * float(_tile_px), float(rect[1]) * float(_tile_px),
				float(rect[2]) * float(_tile_px), float(rect[3]) * float(_tile_px)),
		})
	_blend_frames_left = 0
	_remap_frames_left = 0
	_skip_frames_left = 0
	_active_zone = ""


var _tile_px: int = 32


func _valid(m: String) -> String:
	return m if m in [MODE_TOPDOWN, MODE_SIDE] else MODE_TOPDOWN


## هر فریم فیزیک با **جای پای** شخصیت صدا زده می‌شود.
##
## چرا جای پا و نه مرکز: در نمای سه‌چهارم سر شخصیت یک کاشی بالاتر از جایی است
## که واقعاً ایستاده؛ با مرکز، حالت یک کاشی زودتر از آنچه بازیکن می‌بیند عوض
## می‌شد.
func update(foot_position: Vector2) -> void:
	_tick()
	var want := default_mode
	var zone_id := ""
	for z in zones:
		var r: Rect2 = z["rect"]
		# ناحیه‌ای که همین حالا فعال است، مرز بزرگ‌ترِ خروج دارد
		if String(z["id"]) == _active_zone:
			r = r.grow(ZONE_HYSTERESIS)
		if r.has_point(foot_position):
			want = String(z["mode"])
			zone_id = String(z["id"])
			break
	_active_zone = zone_id
	if want != mode and not is_blending():
		_start(want)


func _tick() -> void:
	if _skip_frames_left > 0:
		_skip_frames_left -= 1
	if _remap_frames_left > 0:
		_remap_frames_left -= 1
		if _remap_frames_left == 0:
			controls_remapped.emit(mode)
	if _blend_frames_left > 0:
		_blend_frames_left -= 1
		if _blend_frames_left == 0:
			mode_changed.emit(mode)


func _start(to_mode: String) -> void:
	_from_mode = mode
	mode = to_mode
	_blend_frames_left = blend_frames()
	_remap_frames_left = remap_frames()
	_skip_frames_left = SKIP_INPUT_FRAMES
	mode_changing.emit(_from_mode, mode)


## گذار دستی (برای توالی اسکریپتی و آزمون).
func force_mode(to_mode: String) -> void:
	var m := _valid(to_mode)
	if m != mode:
		_start(m)


func is_blending() -> bool:
	return _blend_frames_left > 0


## ورودی این فریم باید نادیده گرفته شود؟
func should_ignore_input() -> bool:
	return _skip_frames_left > 0


## پیشرفت گذار، ۰ تا ۱. دوربین واقعی با همین درون‌یابی می‌کند.
func blend_t() -> float:
	if _blend_frames_left <= 0:
		return 1.0
	var total := blend_frames()
	return clampf(float(total - _blend_frames_left) / float(total), 0.0, 1.0)


## نمای فعلی: درون‌یابی نرم میان دو حالت.
func presentation() -> Dictionary:
	var a: Dictionary = PRESENTATION[_from_mode]
	var b: Dictionary = PRESENTATION[mode]
	var t := smoothstep(0.0, 1.0, blend_t())
	return {
		"rotation": lerpf(float(a["rotation"]), float(b["rotation"]), t),
		"zoom": lerpf(float(a["zoom"]), float(b["zoom"]), t),
		"offset_y": lerpf(float(a["offset_y"]), float(b["offset_y"]), t),
	}


## نام پروفایل tuning این حالت — جایی در کد دستی انتخاب نمی‌شود (T3).
func profile_name() -> String:
	return String(PROFILE.get(mode, "topdown"))


func active_zone() -> String:
	return _active_zone
