## نقطهٔ ذخیره — مجسمهٔ کوچک روشن (T15، سند ۰۹ §۱۱)
##
## «جان و انرژی را پر می‌کند، نقطهٔ بازگشت می‌شود، سفر سریع بین نقاط بازشده».
## در v1 سفر سریع نیست (یک ناحیه داریم)، ولی پر کردن و نقطهٔ بازگشت هست.
class_name SavePoint
extends Area2D

signal used(point_id: String)

@export var point_id: String = "save"

var _used_once: bool = false


func _ready() -> void:
	collision_layer = Layers.TRIGGER
	collision_mask = Layers.ACTORS
	add_to_group("save_point")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not (body is TdActor) or not (body as TdActor).is_in_group("kairo"):
		return
	if GameMode.control != GameMode.ControlMode.PLAY:
		return
	GameState.restore_full()
	GameState.set_respawn_point(global_position)
	if not _used_once:
		_used_once = true
		GameState.save_checkpoint(point_id)
	used.emit(point_id)
	Audio.play_sfx("checkpoint")
