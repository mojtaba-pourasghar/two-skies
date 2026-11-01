## کلاس پایهٔ ابزار — docs/02_godot_spec.md §۶ و §۱۷-۱
##
## §۱۷ می‌خواهد همهٔ ابزارهای فصل‌های بعد از همین پایه بیایند، تا وقتی قلاب و EMP و
## تیر بذر اضافه شدند چیزی بازنویسی نشود. سه متد و یک سیگنال، دقیقاً طبق §۱۷-۱.
class_name Tool
extends Node

signal used
signal ready_again

@export var tool_id: String = ""

var _cooldown_left: float = 0.0
var owner_actor: PlatformActor = null


func can_use() -> bool:
	return _cooldown_left <= 0.0 and GameState.is_tool_unlocked(tool_id)


func use() -> bool:
	if not can_use():
		return false
	_cooldown_left = cooldown()
	used.emit()
	EventBus.tool_used.emit(tool_id)
	return true


func cooldown() -> float:
	return 0.0


func cooldown_left() -> float:
	return _cooldown_left


func _process(delta: float) -> void:
	if _cooldown_left <= 0.0:
		return
	_cooldown_left -= delta
	if _cooldown_left <= 0.0:
		_cooldown_left = 0.0
		ready_again.emit()
