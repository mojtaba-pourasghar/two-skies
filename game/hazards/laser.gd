## لیزر — docs/02_godot_spec.md §۷ (نماد L)
##
## بازوی ثابت با پرتو عمودی/افقی تا برخورد با دیوار.
## چرخه: روشن / خاموش با هشدار چشمک‌زن پیش از روشن شدن. اعداد از پروفایل فعال.
##
## قاعدهٔ عدالت: پنجرهٔ خاموش ≥ ۱ ثانیه و هشدار ≥ ۰٫۴ ثانیه، تا با «بمان/بیا»
## برای هر دو شخصیت قابل گذر باشد.
class_name Laser
extends Node2D

enum Phase { OFF, WARN, ON }

## "down", "up", "left", "right"
@export var dir: String = "down"
@export var phase_offset: float = 0.0
## طول پرتو بر حسب کاشی — لودر از نقشه حساب می‌کند
@export var length_tiles: int = 10

var phase: Phase = Phase.OFF

var _on_time: float
var _off_time: float
var _warn_time: float
var _t: float = 0.0
var _area: Area2D
var _shape: CollisionShape2D
var _beam: Polygon2D
var _emitter: Polygon2D


func _ready() -> void:
	_on_time = Settings.hazard("laser_on", 1.2)
	_off_time = Settings.hazard("laser_off", 1.2)
	_warn_time = Settings.hazard("laser_warn", 0.4)
	_t = phase_offset

	_emitter = Polygon2D.new()
	_emitter.color = Color(0.7, 0.7, 0.75)
	_emitter.polygon = PackedVector2Array([
		Vector2(-6, -8), Vector2(6, -8), Vector2(6, -2), Vector2(-6, -2)])
	add_child(_emitter)

	var len_px := float(length_tiles * KairoConst.TILE)
	var beam_rect := _beam_rect(len_px)

	_beam = Polygon2D.new()
	_beam.color = Color(1.0, 0.25, 0.3, 0.85)
	_beam.polygon = PackedVector2Array([
		beam_rect.position,
		beam_rect.position + Vector2(beam_rect.size.x, 0),
		beam_rect.end,
		beam_rect.position + Vector2(0, beam_rect.size.y),
	])
	_beam.visible = false
	add_child(_beam)

	_area = Area2D.new()
	_area.collision_layer = Layers.HAZARD
	_area.collision_mask = Layers.ACTORS
	_area.add_to_group("hazard")
	_shape = CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = beam_rect.size
	_shape.shape = rect
	_shape.position = beam_rect.get_center()
	_shape.disabled = true
	_area.add_child(_shape)
	add_child(_area)
	_area.body_entered.connect(_on_body_entered)


func _beam_rect(len_px: float) -> Rect2:
	var w := 6.0
	match dir:
		"up":
			return Rect2(Vector2(-w * 0.5, -len_px), Vector2(w, len_px))
		"left":
			return Rect2(Vector2(-len_px, -w * 0.5), Vector2(len_px, w))
		"right":
			return Rect2(Vector2(0, -w * 0.5), Vector2(len_px, w))
		_:  # down
			return Rect2(Vector2(-w * 0.5, 0), Vector2(w, len_px))


func _process(delta: float) -> void:
	_t += delta
	var cycle := _off_time + _on_time
	var t := fmod(_t, cycle)
	var new_phase: Phase
	if t < _off_time - _warn_time:
		new_phase = Phase.OFF
	elif t < _off_time:
		new_phase = Phase.WARN
	else:
		new_phase = Phase.ON
	if new_phase != phase:
		_set_phase(new_phase)
	if phase == Phase.WARN:
		# چشمک هشدار
		_beam.modulate.a = 0.25 + 0.25 * sin(_t * 30.0)


func _set_phase(p: Phase) -> void:
	phase = p
	match p:
		Phase.OFF:
			_beam.visible = false
			_shape.set_deferred("disabled", true)
		Phase.WARN:
			_beam.visible = true
			_beam.modulate.a = 0.3
			_shape.set_deferred("disabled", true)
			Audio.play_sfx("laser_warn")
		Phase.ON:
			_beam.visible = true
			_beam.modulate.a = 1.0
			_shape.set_deferred("disabled", false)
			Audio.play_sfx("laser_fire")


func _on_body_entered(body: Node2D) -> void:
	if phase == Phase.ON and body is PlatformActor:
		(body as PlatformActor).die()


func reset() -> void:
	_t = phase_offset


## پنجرهٔ امن این لیزر، برای اعتبارسنج قاعدهٔ عدالت.
##
## §۷: «۰٫۴ ثانیه هشدار چشمک‌زن **پیش از روشن‌شدن**» — در مدت هشدار پرتو هنوز
## خاموش است و `_set_phase(Phase.WARN)` جعبهٔ برخورد را غیرفعال نگه می‌دارد،
## پس کل زمان خاموشی پنجرهٔ امن است، نه خاموشی منهای هشدار (DECISIONS.md: D-016).
func safe_window() -> float:
	return _off_time


## چقدر از پنجرهٔ امن بدون هشدار است — برای حس بازی مفید است، نه برای قاعدهٔ عدالت
func calm_window() -> float:
	return _off_time - _warn_time
