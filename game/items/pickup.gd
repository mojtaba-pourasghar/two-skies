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
	set_deferred("monitoring", true)
	_home = position
	_build_visual()
	body_entered.connect(_on_body_entered)


func _build_visual() -> void:
	# اطلس ۳ فریمی: ۰ سکه، ۱ زمرد، ۲ تراشه
	var frame := 0
	match kind:
		"coin":
			frame = 0
		"gem":
			frame = 1
		"page":
			frame = 2
		_:
			frame = 0
	var art := Art.sprite(Art.PICKUPS, 3, frame)
	add_child(art)
	_visual = art

	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = maxf(magnet_radius, 5.0) if kind == "coin" else 6.0
	shape.shape = c
	add_child(shape)


func _on_body_entered(body: Node2D) -> void:
	if _taken:
		return
	# فقط کایرو اقلام را جمع می‌کند؛ ایلارا مسیر او را بازپخش می‌کند و
	# اگر او هم جمع می‌کرد شمارش دو برابر می‌شد.
	if not (body is Kairo):
		return
	_taken = true
	visible = false
	# `monitoring` را نمی‌شود داخل callback خود سیگنال عوض کرد؛ موتور خطای
	# «Function blocked during in/out signal» می‌دهد (DECISIONS.md: D-028).
	set_deferred("monitoring", false)
	picked.emit(kind, id)
	Audio.play_sfx(kind)


## با مرگ در همان اتاق، سکه‌ها برمی‌گردند (§۸)
func respawn() -> void:
	_taken = false
	visible = true
	set_deferred("monitoring", true)
	position = _home


func is_taken() -> bool:
	return _taken
