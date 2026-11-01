## خار — docs/02_godot_spec.md §۷ (نماد ^)
##
## جعبهٔ ۱۶×۸ در پایین تایل؛ کشنده در تماس. فقط وقتی آسیب می‌زند که بازیکن از بالا
## یا کنار با آن تماس بگیرد، پس جعبه پایین تایل است و از زیر بی‌خطر رد می‌شود.
class_name Spike
extends Area2D

func _ready() -> void:
	collision_layer = Layers.HAZARD
	collision_mask = Layers.ACTORS
	add_to_group("hazard")

	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(16, 8)
	shape.shape = r
	# مرکز جعبه ۴ پیکسل پایین‌تر از مرکز تایل، یعنی نیمهٔ پایین تایل
	shape.position = Vector2(0, 4)
	add_child(shape)

	var poly := Polygon2D.new()
	poly.color = Color(0.85, 0.3, 0.35)
	poly.polygon = PackedVector2Array([
		Vector2(-8, 8), Vector2(-4, 0), Vector2(0, 8), Vector2(0, 8),
		Vector2(4, 0), Vector2(8, 8)])
	add_child(poly)

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is PlatformActor:
		(body as PlatformActor).die()
