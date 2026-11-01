## ماژول هک — docs/02_godot_spec.md §۶
##
## در برد ۴۸ پیکسل نزدیک‌ترین هدف قابل‌هک انتخاب می‌شود؛ نگه‌داشتن دکمهٔ عمل به مدت
## ۰٫۶ ثانیه (نوار پر می‌شود) و در این مدت کایرو ثابت است. خنک‌شدن ۱ ثانیه.
##
## هدف‌ها در گروه "hackable" هستند و متد `on_hacked()` دارند:
## در و قفل دیجیتال باز می‌شوند، پهپاد ۳ ثانیه خاموش می‌شود.
class_name HackModule
extends Tool

signal target_changed(target: Node2D)
signal progress(value: float)

var current_target: Node2D = null

var _range: float
var _hold_needed: float
var _cooldown: float
var _held: float = 0.0


func _ready() -> void:
	tool_id = "hack"
	_range = Settings.param("hack", "range_px", 48.0)
	_hold_needed = Settings.param("hack", "hold_time", 0.6)
	_cooldown = Settings.param("hack", "cooldown", 1.0)


func cooldown() -> float:
	return _cooldown


## هر فریم از کایرو صدا زده می‌شود. `holding` یعنی دکمهٔ عمل نگه داشته شده است.
func update_hold(delta: float, holding: bool) -> void:
	var target := _find_target()
	if target != current_target:
		current_target = target
		target_changed.emit(target)

	if not holding or target == null or not can_use():
		if _held > 0.0:
			_held = 0.0
			progress.emit(0.0)
		return

	if _held == 0.0:
		Audio.play_sfx("hack_start")
	_held += delta
	progress.emit(clampf(_held / _hold_needed, 0.0, 1.0))

	if _held >= _hold_needed:
		_held = 0.0
		progress.emit(0.0)
		_fire(target)


func _fire(target: Node2D) -> void:
	if not use():
		return
	if target.has_method("on_hacked"):
		target.call("on_hacked")
	Audio.play_sfx("hack_success")


## نزدیک‌ترین هدف در برد (§۶)
func _find_target() -> Node2D:
	if owner_actor == null:
		return null
	var best: Node2D = null
	var best_d := _range
	for node in owner_actor.get_tree().get_nodes_in_group("hackable"):
		if not (node is Node2D):
			continue
		var d: float = owner_actor.global_position.distance_to((node as Node2D).global_position)
		if d <= best_d:
			best_d = d
			best = node
	return best


func hold_progress() -> float:
	return clampf(_held / _hold_needed, 0.0, 1.0)


func is_charging() -> bool:
	return _held > 0.0
