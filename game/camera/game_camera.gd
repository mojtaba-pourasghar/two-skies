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

## سطح‌های زوم (قاعدهٔ ۹ CLAUDE.md، D-ART-42، سند ۱۳ §۳).
## در Godot زوم بزرگ‌تر یعنی نزدیک‌تر، پس عددها همان‌اند که سند می‌گوید.
const ZOOM_WIDE := "wide"
const ZOOM_NORMAL := "normal"
const ZOOM_CLOSE := "close"
const ZOOM_LEVELS := {
	ZOOM_WIDE: 0.85,
	ZOOM_NORMAL: 1.0,
	ZOOM_CLOSE: 1.25,
}
## گذار پیش‌فرض ۱ ثانیه، در بازهٔ ۰٫۸ تا ۱٫۲ که سند ۱۳ می‌خواهد.
const ZOOM_SECONDS: float = 1.0
const ZOOM_SECONDS_MIN: float = 0.8
const ZOOM_SECONDS_MAX: float = 1.2

## «دوربین هیچ‌وقت کاملاً ثابت نیست» (سند ۱۳ بند ۶).
## لرزش ریز همیشگی: ±۱ پیکسل، آهسته، نامنظم. این با `shake()` فرق دارد؛
## آن رویدادی است و این نفسِ دوربین. بدون آن، اتاقِ قفل‌شده عکس می‌شود.
const IDLE_SWAY_PX: float = 1.0
const IDLE_SWAY_HZ: float = 0.13
## اینرسی: دوربین بعد از ایستادن بازیکن کمی سُر می‌خورد و می‌ایستد.
const INERTIA: float = 0.86
const INERTIA_MAX_PX: float = 2.4

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

var _zoom_level: String = ZOOM_NORMAL
var _zoom_from: float = 1.0
var _zoom_to: float = 1.0
var _zoom_frames_total: int = 0
var _zoom_frames_left: int = 0
## نواحی زوم اتاق: [{rect: Rect2, level: String, seconds: float}]
var _zoom_zones: Array = []
var _sway_t: float = 0.0
var _sway_seed: float = 0.0
var _drift := Vector2.ZERO


func _ready() -> void:
	# دوربین خودش هموارسازی داخلی ندارد: هموارسازی اینجا و فریم‌محور است،
	# وگرنه نتیجهٔ headless و اجرای واقعی یکی نمی‌شود.
	position_smoothing_enabled = false
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	ignore_rotation = true
	# بذر تصادفی: دو بار اجرای بازی نباید لرزش یکسان بدهد، ولی در یک
	# اجرا قطعی بماند
	_sway_seed = randf() * 100.0
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


## زوم را **نرم** به سطح خواسته‌شده می‌برد. هیچ مسیری زوم را پرشی عوض
## نمی‌کند: کاربر صریح گفت «هرگز پرشی» (D-ART-42).
func request_zoom(level: String, seconds: float = ZOOM_SECONDS) -> void:
	if not ZOOM_LEVELS.has(level):
		push_warning("سطح زوم ناشناخته «%s»؛ نادیده گرفته شد." % level)
		return
	# درخواست تکراری همان سطح **هیچ کاری نمی‌کند**. وگرنه ناحیهٔ زوم که هر
	# فریم درخواست می‌دهد، گذار را هر فریم از نو شروع می‌کند و زوم به‌جای
	# یک ثانیه، تا ابر‌فریم‌ها می‌خزد (در آزمون ۶۰ فریم فقط ۰٫۰۲ رفت).
	if level == _zoom_level and is_equal_approx(_zoom_to, float(ZOOM_LEVELS[level])):
		return
	_zoom_level = level
	_zoom_from = zoom.x
	_zoom_to = float(ZOOM_LEVELS[level])
	var secs := clampf(seconds, ZOOM_SECONDS_MIN, ZOOM_SECONDS_MAX)
	# فریم‌محور، نه delta انباشته: نتیجهٔ headless و اجرای واقعی یکی بماند
	_zoom_frames_total = maxi(1, int(round(secs * FPS)))
	_zoom_frames_left = _zoom_frames_total


func zoom_level() -> String:
	return _zoom_level


func zoom_settled() -> bool:
	return _zoom_frames_left <= 0


## بدون گذار — فقط برای شروع اتاق و آزمون.
func snap_zoom(level: String) -> void:
	if not ZOOM_LEVELS.has(level):
		return
	_zoom_level = level
	var z := float(ZOOM_LEVELS[level])
	_zoom_from = z
	_zoom_to = z
	_zoom_frames_left = 0
	_zoom_frames_total = 0
	zoom = Vector2(z, z)


## نواحی زوم اتاق را می‌گیرد: وقتی بازیکن داخل مستطیلی رفت، زوم آرام عوض
## می‌شود. داده‌محور است تا هر اتاق بتواند نفس خودش را داشته باشد.
func set_zoom_zones(zones: Array) -> void:
	_zoom_zones = zones


func clear_zoom_zones() -> void:
	_zoom_zones = []


func snap_to_target() -> void:
	if target == null:
		return
	_desired = _target_point()
	global_position = _clamped(_desired).round()
	# اینرسی باید از صفر شروع شود، وگرنه ورود به اتاق با یک سُر خوردن
	# شروع می‌شود که کسی نخواسته
	_last_target = global_position
	_drift = Vector2.ZERO


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
	_tick_zoom()
	_tick_zoom_zones()
	var want := _clamped(_desired)
	global_position = want + _shake_offset() + _idle_sway() + _inertia(want)
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


## نفس دوربین: دو سینوس ناهم‌فرکانس، پس الگویش تکرار آشکار ندارد.
## گرد می‌شود، چون نیم‌پیکسل روی پیکسل‌آرت کل صحنه را تار می‌کند.
func _idle_sway() -> Vector2:
	_sway_t += 1.0 / FPS
	var a := _sway_t * TAU * IDLE_SWAY_HZ + _sway_seed
	return Vector2(sin(a) * IDLE_SWAY_PX,
		sin(a * 0.73 + 1.3) * IDLE_SWAY_PX * 0.6).round()


## اینرسی: دوربین وقتی هدف می‌ایستد یک‌باره قفل نمی‌شود، کمی می‌سُرد.
## سقف دارد (±۲٫۴ پیکسل) تا به «شناور بودن» نرسد.
func _inertia(want: Vector2) -> Vector2:
	var moved := want - _last_target
	_last_target = want
	_drift = (_drift + moved * 0.25) * INERTIA
	_drift.x = clampf(_drift.x, -INERTIA_MAX_PX, INERTIA_MAX_PX)
	_drift.y = clampf(_drift.y, -INERTIA_MAX_PX, INERTIA_MAX_PX)
	return _drift.round()


func _shake_offset() -> Vector2:
	if _shake_frames <= 0:
		_shake_px = 0.0
		return Vector2.ZERO
	_shake_frames -= 1
	var a := _shake_px
	return Vector2(randf_range(-a, a), randf_range(-a, a)).round()


## گذار نرم زوم. منحنی smoothstep است تا نه شروعش تکان داشته باشد و نه
## پایانش: زوم خطی در لحظهٔ ایستادن دیده می‌شود.
func _tick_zoom() -> void:
	if _zoom_frames_left <= 0:
		return
	_zoom_frames_left -= 1
	var done := float(_zoom_frames_total - _zoom_frames_left) / float(_zoom_frames_total)
	var e := done * done * (3.0 - 2.0 * done)
	var z: float = lerpf(_zoom_from, _zoom_to, e)
	if _zoom_frames_left <= 0:
		z = _zoom_to
	zoom = Vector2(z, z)


## اگر هدف داخل ناحیهٔ زوم رفت، همان سطح را بخواه؛ بیرون همهٔ نواحی،
## برگرد به `normal`.
func _tick_zoom_zones() -> void:
	if _zoom_zones.is_empty() or target == null:
		return
	var p := target.global_position
	for raw in _zoom_zones:
		if not (raw is Dictionary):
			continue
		var zone: Dictionary = raw
		var r = zone.get("rect", null)
		if not (r is Rect2) or not (r as Rect2).has_point(p):
			continue
		request_zoom(String(zone.get("level", ZOOM_NORMAL)),
			float(zone.get("seconds", ZOOM_SECONDS)))
		return
	request_zoom(ZOOM_NORMAL, ZOOM_SECONDS)


func _apply_presentation() -> void:
	pass
