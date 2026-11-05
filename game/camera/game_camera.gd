## دوربین بازی — دنبال‌کنندهٔ نرم با مرز مرحله (T6، BUILD_BRIEF §۳)
##
## دو رفتار دارد و `camera_follow` در JSON مرحله انتخابش می‌کند:
##   `follow` (پیش‌فرض) — دنبال‌کنندهٔ نرم با ناحیهٔ بی‌اثر و مرز نقشه.
##   `room`            — قفل روی یک اتاق، یک اتاق = یک صفحه (رفتار قدیمی).
##
## عددها از جدول «مقدار دوربین» سند ۰۴ می‌آیند، در مقیاس `WORLD_SCALE=2`:
## ناحیهٔ بی‌اثر ۹۶×۶۴ → ۱۹۲×۱۲۸، نگاه به جلو ۴۸ → ۹۶. زمان‌ها (۰٫۱۵ و
## ۰٫۱۲ ثانیه) **مقیاس نمی‌خورند** چون زمان‌اند نه پیکسل.
class_name GameCamera
extends Camera2D

const FOLLOW := "follow"
const ROOM := "room"

## عددهای «مقدار دوربین» سند ۰۴، ستون سه‌چهارم، در WORLD_SCALE=2.
## ستون کناری با D-ART-32 بی‌موضوع شد.
const DEAD_ZONE := Vector2(192, 128)
const LOOK_AHEAD: float = 96.0
## نرمی دنبال کردن: ۰٫۱۵ ثانیه تا ~۶۳٪ راه. زمان است، پس مقیاس نمی‌خورد.
const SMOOTH_TIME: float = 0.15
## شخصیت ۴۵٪ از بالای قاب می‌نشیند، نه وسط (سند ۰۴).
const VERTICAL_BIAS: float = 0.05

const FPS: float = 60.0

@export var follow_mode: String = FOLLOW

var target: Node2D = null
var director: CameraDirector = null

var _bounds := Rect2()
var _has_bounds: bool = false
var _room_rect := Rect2()
var _has_room: bool = false
var _desired := Vector2.ZERO
var _shake_px: float = 0.0
var _shake_frames: int = 0
var _last_target := Vector2.ZERO


func _ready() -> void:
	# دوربین خودش هموارسازی داخلی ندارد: هموارسازی اینجا و فریم‌محور است،
	# وگرنه نتیجهٔ headless و اجرای واقعی یکی نمی‌شود.
	position_smoothing_enabled = false
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	ignore_rotation = true
	if EventBus.has_signal("camera_shake_requested"):
		EventBus.camera_shake_requested.connect(shake)


## مرز حرکت دوربین: لبهٔ نقشه. دوربین هرگز بیرون آن را نشان نمی‌دهد.
func set_bounds(rect: Rect2) -> void:
	_bounds = rect
	_has_bounds = rect.size.x > 0.0 and rect.size.y > 0.0
	limit_left = int(rect.position.x)
	limit_top = int(rect.position.y)
	limit_right = int(rect.position.x + rect.size.x)
	limit_bottom = int(rect.position.y + rect.size.y)


## اتاق فعلی، برای حالت `room`.
func set_room(rect: Rect2) -> void:
	_room_rect = rect
	_has_room = rect.size.x > 0.0 and rect.size.y > 0.0


func snap_to_target() -> void:
	if target == null:
		return
	_desired = _target_point()
	global_position = _clamped(_desired).round()


func shake(pixels: float, seconds: float = 0.12) -> void:
	if not Settings.camera_shake_enabled:
		return
	_shake_px = maxf(_shake_px, pixels)
	_shake_frames = maxi(_shake_frames, int(round(seconds * FPS)))


func _physics_process(_delta: float) -> void:
	if target == null:
		return
	if follow_mode == ROOM and _has_room:
		_desired = _room_rect.get_center()
	else:
		_desired = _follow_point()
	var want := _clamped(_desired)
	global_position = want + _shake_offset()
	# «موقعیت دوربین به عدد صحیح گرد می‌شود؛ نیم‌پیکسل ممنوع» (سند ۰۴)
	global_position = global_position.round()
	_apply_presentation()


func _target_point() -> Vector2:
	var p := target.global_position
	var size := _view_size()
	p.y -= size.y * VERTICAL_BIAS
	return p


## نقطهٔ مطلوب با ناحیهٔ بی‌اثر و نگاه به جلو، سپس هموارسازی نمایی.
func _follow_point() -> Vector2:
	var goal := _target_point()

	var ahead := LOOK_AHEAD
	var vel := Vector2.ZERO
	if target is CharacterBody2D:
		vel = (target as CharacterBody2D).velocity
	if vel.length() > 1.0:
		goal += vel.normalized() * ahead

	# ناحیهٔ بی‌اثر: فقط به اندازهٔ بیرون‌زدگی حرکت کن
	var dz := DEAD_ZONE
	var delta := goal - global_position
	var pull := Vector2.ZERO
	if absf(delta.x) > dz.x * 0.5:
		pull.x = delta.x - signf(delta.x) * dz.x * 0.5
	if absf(delta.y) > dz.y * 0.5:
		pull.y = delta.y - signf(delta.y) * dz.y * 0.5

	# هموارسازی نمایی با گام ثابت ۱/۶۰ — قطعی و مستقل از نرخ فریم واقعی
	var tau := SMOOTH_TIME
	var k: float = 1.0 - exp(-(1.0 / FPS) / maxf(0.0001, tau))
	return global_position + pull * k


func _view_size() -> Vector2:
	var vp := get_viewport_rect().size
	return vp / maxf(0.001, zoom.x)


func _clamped(p: Vector2) -> Vector2:
	if not _has_bounds:
		return p
	var half := _view_size() * 0.5
	var out := p
	# اگر نقشه از صفحه کوچک‌تر است، وسطش را نشان بده نه لبه‌اش
	if _bounds.size.x <= half.x * 2.0:
		out.x = _bounds.position.x + _bounds.size.x * 0.5
	else:
		out.x = clampf(p.x, _bounds.position.x + half.x,
			_bounds.position.x + _bounds.size.x - half.x)
	if _bounds.size.y <= half.y * 2.0:
		out.y = _bounds.position.y + _bounds.size.y * 0.5
	else:
		out.y = clampf(p.y, _bounds.position.y + half.y,
			_bounds.position.y + _bounds.size.y - half.y)
	return out


func _shake_offset() -> Vector2:
	if _shake_frames <= 0:
		_shake_px = 0.0
		return Vector2.ZERO
	_shake_frames -= 1
	var a := _shake_px
	return Vector2(randf_range(-a, a), randf_range(-a, a)).round()


## زوم ثابت است: کل بازی یک حالت دارد (D-ART-32). زوم صحنه‌ها را
## `ScriptedSequence` با گام `zoom` عوض می‌کند، نه دوربین خودش.
func _apply_presentation() -> void:
	pass
