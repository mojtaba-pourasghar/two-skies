## پلتفرم شکننده — docs/02_godot_spec.md §۷ (نماد ~)
##
## سند ۰۲: ۰٫۳ ثانیه بعد از اولین تماس می‌لرزد، ۰٫۵ ثانیه بعد می‌افتد، ۲ ثانیه بعد
## دوباره ظاهر می‌شود. سند ۰۱ اعداد دیگری می‌دهد؛ هر دو در tuning.json هستند.
class_name Crumble
extends AnimatableBody2D

enum Phase { IDLE, SHAKING, GONE }

var phase: Phase = Phase.IDLE

var _shape: CollisionShape2D
var _visual: Sprite2D
var _timer: float = 0.0
var _home := Vector2.ZERO
var _shake_time: float
var _fall_time: float
var _respawn_time: float


func _ready() -> void:
	collision_layer = Layers.GROUND
	collision_mask = 0
	sync_to_physics = false
	_home = position

	_shake_time = Settings.hazard("crumble_shake", 0.3)
	_fall_time = Settings.hazard("crumble_fall", 0.5)
	_respawn_time = Settings.hazard("crumble_respawn", 2.0)

	_shape = CollisionShape2D.new()
	var r := RectangleShape2D.new()
	# ۱۶×۸ (§۷) — نیمهٔ بالای تایل، تا بازیکن روی لبه‌اش بایستد
	r.size = Vector2(16, 8)
	_shape.shape = r
	_shape.position = Vector2(0, -4)
	add_child(_shape)

	_visual = Art.sprite(Art.CRUMBLE)
	_visual.position = Vector2(0, -4)
	add_child(_visual)

	var detector := Area2D.new()
	detector.collision_layer = 0
	detector.collision_mask = Layers.ACTORS
	var ds := CollisionShape2D.new()
	var dr := RectangleShape2D.new()
	dr.size = Vector2(16, 6)
	ds.shape = dr
	ds.position = Vector2(0, -11)
	detector.add_child(ds)
	add_child(detector)
	detector.body_entered.connect(_on_stepped)


func _on_stepped(body: Node2D) -> void:
	if phase != Phase.IDLE or not (body is PlatformActor):
		return
	phase = Phase.SHAKING
	_timer = _shake_time + _fall_time


func _process(delta: float) -> void:
	match phase:
		Phase.SHAKING:
			_timer -= delta
			# در مدت لرزش فقط تکان می‌خورد؛ پس از _fall_time می‌افتد
			if _timer > _fall_time:
				_visual.position.x = sin(_timer * 60.0) * 1.0
			else:
				_visual.position.x = sin(_timer * 90.0) * 1.5
			if _timer <= 0.0:
				_fall()
		Phase.GONE:
			_timer -= delta
			if _timer <= 0.0:
				_restore()


func _fall() -> void:
	phase = Phase.GONE
	_timer = _respawn_time
	_shape.set_deferred("disabled", true)
	_visual.visible = false
	_visual.position.x = 0.0
	Audio.play_sfx("crumble")


func _restore() -> void:
	phase = Phase.IDLE
	_shape.set_deferred("disabled", false)
	_visual.visible = true
	position = _home


func reset() -> void:
	_restore()
	_timer = 0.0
