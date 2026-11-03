## پهپاد گشت — docs/02_godot_spec.md §۷ (نماد n)
##
## سرعت ۴۰ px/s، حرکت بین دو نقطه با محور افقی؛ لمس کشنده. با ماژول هک ۳ ثانیه
## خاموش می‌شود و می‌توان روی آن ایستاد. چرخش جهت با ۰٫۲ ثانیه مکث.
class_name Drone
extends CharacterBody2D

const DISABLED_SECONDS: float = 3.0

## "h" افقی یا "v" عمودی
@export var axis: String = "h"
## برد گشت بر حسب کاشی از نقطهٔ شروع، به هر طرف
@export var patrol_tiles: int = 6

var is_disabled: bool = false

var _home := Vector2.ZERO
var _min := 0.0
var _max := 0.0
var _dir: int = 1
var _pause: float = 0.0
var _disabled_left: float = 0.0
var _speed: float
var _turn_pause: float
var _visual: Polygon2D
var _hurt: Area2D


func _ready() -> void:
	collision_layer = Layers.ENEMY
	collision_mask = Layers.GROUND
	add_to_group("hackable")
	add_to_group("drone")

	_speed = Settings.hazard("drone_speed", 40.0)
	_turn_pause = Settings.hazard("drone_turn_pause", 0.2)
	_home = position
	var span := float(patrol_tiles * KairoConst.TILE)
	if axis == "v":
		_min = _home.y - span * 0.5
		_max = _home.y + span * 0.5
	else:
		_min = _home.x - span * 0.5
		_max = _home.x + span * 0.5

	# بدنهٔ جامد تا بتوان روی پهپاد خاموش ایستاد (§۷)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(14, 8)
	cs.shape = r
	add_child(cs)

	_visual = Polygon2D.new()
	_visual.color = Color(0.9, 0.45, 0.25)
	_visual.polygon = PackedVector2Array([
		Vector2(-7, -4), Vector2(7, -4), Vector2(7, 4), Vector2(-7, 4)])
	add_child(_visual)

	# ناحیهٔ کشنده جدا از بدنه است، تا وقتی خاموش شد فقط همین خاموش شود
	_hurt = Area2D.new()
	_hurt.collision_layer = Layers.HAZARD
	_hurt.collision_mask = Layers.ACTORS
	_hurt.add_to_group("hazard")
	var hs := CollisionShape2D.new()
	var hr := RectangleShape2D.new()
	hr.size = Vector2(16, 10)
	hs.shape = hr
	_hurt.add_child(hs)
	add_child(_hurt)
	_hurt.body_entered.connect(_on_touch)


func _physics_process(delta: float) -> void:
	if is_disabled:
		_disabled_left -= delta
		velocity = Vector2.ZERO
		if _disabled_left <= 0.0:
			_wake()
		move_and_slide()
		return

	if _pause > 0.0:
		_pause -= delta
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if axis == "v":
		velocity = Vector2(0, _dir * _speed)
		if (_dir > 0 and position.y >= _max) or (_dir < 0 and position.y <= _min):
			_turn()
	else:
		velocity = Vector2(_dir * _speed, 0)
		if (_dir > 0 and position.x >= _max) or (_dir < 0 and position.x <= _min):
			_turn()
	move_and_slide()


func _turn() -> void:
	_dir *= -1
	_pause = _turn_pause


func _on_touch(body: Node2D) -> void:
	if is_disabled:
		return
	if body is PlatformActor:
		(body as PlatformActor).die()


## قرارداد هک‌شدنی (§۷): ۳ ثانیه خاموش، می‌توان روی آن ایستاد
func on_hacked() -> void:
	is_disabled = true
	_disabled_left = DISABLED_SECONDS
	_visual.color = Color(0.4, 0.5, 0.6)
	_hurt.set_deferred("monitoring", false)


func _wake() -> void:
	is_disabled = false
	_visual.color = Color(0.9, 0.45, 0.25)
	_hurt.set_deferred("monitoring", true)


func hack_label() -> String:
	return "drone"


func reset() -> void:
	position = _home
	_dir = 1
	_pause = 0.0
	_disabled_left = 0.0
	if is_disabled:
		_wake()
