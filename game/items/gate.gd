## در و دروازه (G) و قفل دیجیتال (T) — docs/02_godot_spec.md §۷
##
## پیش از باز شدن مانع جامد است؛ پس از هک با انیمیشن ۰٫۵ ثانیه باز می‌شود.
## در امنیتی پس از مدتی دوباره قفل می‌شود — مدتش از پروفایل اعداد می‌آید
## (سند ۰۲: ۲ ثانیه، سند ۰۱: ۵ ثانیه).
class_name Gate
extends StaticBody2D

signal opened
signal closed

## "gate" برای G یا "lock" برای T
@export var gate_kind: String = "gate"
## اگر ۰ یا کمتر باشد، در باز می‌ماند و دوباره قفل نمی‌شود
@export var auto_close_after: float = -1.0

var is_open: bool = false
var _shape: CollisionShape2D
var _visual: Polygon2D
var _close_timer: float = 0.0


func _ready() -> void:
	collision_layer = Layers.GROUND
	collision_mask = 0
	add_to_group("hackable")

	_shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(16, 16)
	_shape.shape = r
	add_child(_shape)

	_visual = Polygon2D.new()
	_visual.color = _closed_color()
	_visual.polygon = PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	add_child(_visual)

	if auto_close_after < 0.0:
		auto_close_after = Settings.param("hazards", "door_open_duration", 2.0)


func _closed_color() -> Color:
	return Color(0.35, 0.55, 0.9) if gate_kind == "gate" else Color(0.9, 0.55, 0.3)


func _process(delta: float) -> void:
	if not is_open or auto_close_after <= 0.0:
		return
	_close_timer -= delta
	if _close_timer <= 0.0:
		close()


## با هک باز می‌شود. انیمیشن باز شدن ۰٫۵ ثانیه است (§۷) ولی برخورد فوراً برداشته
## می‌شود تا بازیکن در میانهٔ انیمیشن گیر نکند.
func open() -> void:
	if is_open:
		return
	is_open = true
	_shape.disabled = true
	_close_timer = auto_close_after
	Audio.play_sfx("gate_open")
	var tw := create_tween()
	tw.tween_property(_visual, "modulate:a", 0.15, 0.5)
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	_shape.disabled = false
	_visual.modulate.a = 1.0
	closed.emit()


func reset() -> void:
	is_open = false
	_shape.disabled = false
	_visual.modulate.a = 1.0
	_close_timer = 0.0


## قرارداد هک‌شدنی — tools/hack_module.gd در گام ۴ این را صدا می‌زند
func on_hacked() -> void:
	open()


func hack_label() -> String:
	return "gate" if gate_kind == "gate" else "lock"
