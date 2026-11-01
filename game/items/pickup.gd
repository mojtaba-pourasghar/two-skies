## پایهٔ اقلام جمع‌شدنی — docs/02_godot_spec.md §۸
##
## سکه در همان اتاق ثبت می‌شود و فقط پس از رسیدن به خروج یا چک‌پوینت در ذخیره
## قطعی می‌شود؛ در مرگ، سکه‌های جمع‌شدهٔ اتاق دوباره ظاهر می‌شوند.
class_name Pickup
extends Area2D

signal picked(kind: String, id: String)

## "coin" یا "gem" یا "page"
@export var kind: String = "coin"
@export var id: String = ""
## مغناطیس شعاع ۱۲ برای سکه (§۸)
@export var magnet_radius: float = 12.0

var _taken: bool = false
var _home: Vector2
var _visual: Node2D


func _ready() -> void:
	collision_layer = Layers.ITEM
	collision_mask = Layers.ACTORS
	monitoring = true
	_home = position
	_build_visual()
	body_entered.connect(_on_body_entered)


func _build_visual() -> void:
	var poly := Polygon2D.new()
	match kind:
		"coin":
			poly.color = Color(1.0, 0.84, 0.3)
			poly.polygon = _diamond(4.0)
		"gem":
			poly.color = Color(0.45, 0.95, 0.75)
			poly.polygon = _diamond(5.5)
		"page":
			poly.color = Color(0.95, 0.95, 0.85)
			poly.polygon = PackedVector2Array([
				Vector2(-3, -4), Vector2(3, -4), Vector2(3, 4), Vector2(-3, 4)])
		_:
			poly.color = Color(1, 1, 1)
			poly.polygon = _diamond(4.0)
	add_child(poly)
	_visual = poly

	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = maxf(magnet_radius, 5.0) if kind == "coin" else 6.0
	shape.shape = c
	add_child(shape)


func _diamond(r: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)])


func _on_body_entered(body: Node2D) -> void:
	if _taken:
		return
	# فقط کایرو اقلام را جمع می‌کند؛ ایلارا مسیر او را بازپخش می‌کند و
	# اگر او هم جمع می‌کرد شمارش دو برابر می‌شد.
	if not (body is Kairo):
		return
	_taken = true
	visible = false
	monitoring = false
	picked.emit(kind, id)
	Audio.play_sfx(kind)


## با مرگ در همان اتاق، سکه‌ها برمی‌گردند (§۸)
func respawn() -> void:
	_taken = false
	visible = true
	monitoring = true
	position = _home


func is_taken() -> bool:
	return _taken
