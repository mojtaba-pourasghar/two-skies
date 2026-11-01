## نقطهٔ خروج و چک‌پوینت — docs/02_godot_spec.md §۸ (نماد X)
##
## ماشهٔ Area2D. در مرحله‌های دونفره با رسیدن **هر دو** شخصیت فعال می‌شود (§۸ و
## «پایان مرحله: هر دو باید به خروجی برسند» سند ۰۱).
class_name ExitPoint
extends Area2D

signal reached
signal occupancy_changed(kairo_in: bool, ilara_in: bool)

## اگر true، این نقطه چک‌پوینت است نه خروج (مرحلهٔ ۷ فصل‌ها)
@export var is_checkpoint: bool = false
## اگر false، فقط رسیدن کایرو کافی است (مرحله‌های بدون همراه)
@export var needs_both: bool = true

var _kairo_in: bool = false
var _ilara_in: bool = false
var _fired: bool = false


func _ready() -> void:
	collision_layer = Layers.TRIGGER
	collision_mask = Layers.ACTORS
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(16, 24)
	shape.shape = r
	add_child(shape)

	var poly := Polygon2D.new()
	poly.color = Color(0.55, 1.0, 0.6) if not is_checkpoint else Color(0.6, 0.8, 1.0)
	poly.polygon = PackedVector2Array([
		Vector2(-7, -12), Vector2(7, -12), Vector2(7, 12), Vector2(-7, 12)])
	add_child(poly)

	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(body: Node2D) -> void:
	if body is Kairo:
		_kairo_in = true
	elif body.is_in_group("ilara"):
		_ilara_in = true
	else:
		return
	occupancy_changed.emit(_kairo_in, _ilara_in)
	_try_fire()


func _on_exit(body: Node2D) -> void:
	if body is Kairo:
		_kairo_in = false
	elif body.is_in_group("ilara"):
		_ilara_in = false
	else:
		return
	occupancy_changed.emit(_kairo_in, _ilara_in)


func _try_fire() -> void:
	if _fired:
		return
	if needs_both and not (_kairo_in and _ilara_in):
		return
	if not needs_both and not _kairo_in:
		return
	_fired = true
	reached.emit()


func reset() -> void:
	_fired = false
	_kairo_in = false
	_ilara_in = false


func both_present() -> bool:
	return _kairo_in and _ilara_in
