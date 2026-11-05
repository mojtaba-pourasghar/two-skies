## اتاق نقاشی‌شده — لایه‌های صحنه (M1، سند ۱۱ §۱ و سند ۱۲ §۲)
##
## ترتیب لایه‌ها دقیقاً همان چیزی است که سند می‌گوید و **اهمیت دارد**:
##
##   ۰ نقاشی پس‌زمینه      تمام کف و دیوار و سایه و نور در خود تصویر است
##   ۱ ماسک برخورد/خطر     چندضلعی، نامرئی؛ از روی تصویر کشیده شده
##   ۲ پراپ با Y-sort      صندوق، مجسمه، جمع‌شدنی
##   ۳ بازیگران            کایرو و ایلارا، هم‌سطح پراپ‌ها در همان Y-sort
##   ۴ occluder            طاق، ستون، پرده — شخصیت از پشتشان رد می‌شود
##   ۵ نور و ذره (Add)     هالهٔ پنجره، اخگر، گرد
##   ۶ HUD                 جدا، در CanvasLayer
##
## اگر occluder زیر بازیگر بیاید شخصیت روی ستون کشیده می‌شود، و اگر نور زیر
## occluder بیاید هاله پشت پرده گیر می‌کند. هر دو را دیده‌ایم.
class_name PaintedRoom
extends Node2D

signal built(room_id: String)
signal door_reached(door: Dictionary)
signal hazard_entered(hazard: Dictionary)

const ASSETS := "res://assets/"
## لرزش هالهٔ نور: ۲ هرتز (سند ۰۴ «سوسوی ۲ تا ۳ هرتز»).
const FLICKER_HZ: float = 2.0

var data: Dictionary = {}
var missing_art: Array[String] = []

var world: Node2D          ## لایه‌های ۰ تا ۵ که با دوربین حرکت می‌کنند
var actors: Node2D         ## لایهٔ ۳ — بیرون می‌نشاندش

var _bg: Sprite2D
var _props: Node2D
var _occluders: Node2D
var _light: Node2D
var _mask_debug: Node2D
var _flicker_t: float = 0.0
var _glows: Array[Sprite2D] = []


func build(room: Dictionary) -> void:
	data = room
	world = Node2D.new()
	world.name = "World"
	# Y-sort روی ریشهٔ دنیا، تا پراپ و بازیگر با هم مرتب شوند
	world.y_sort_enabled = true
	add_child(world)

	_build_background()
	_build_props()
	actors = _layer("Actors", 3)
	actors.y_sort_enabled = true
	_build_occluders()
	_build_light()
	built.emit(String(room.get("id", "?")))


func _layer(name: String, z: int) -> Node2D:
	var n := Node2D.new()
	n.name = name
	n.z_index = z
	world.add_child(n)
	return n


func _note_missing(path: String) -> void:
	if path not in missing_art:
		missing_art.append(path)


func _load_tex(rel: String) -> Texture2D:
	var p := ASSETS + rel
	if not ResourceLoader.exists(p):
		_note_missing(rel)
		return null
	return load(p)


func _build_background() -> void:
	var holder := _layer("Background", 0)
	var tex := _load_tex(String(data.get("bg", "")))
	if tex == null:
		return
	_bg = Sprite2D.new()
	_bg.texture = tex
	_bg.centered = false
	_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	holder.add_child(_bg)


func _build_props() -> void:
	_props = _layer("Props", 2)
	_props.y_sort_enabled = true
	for raw in data.get("props", []):
		var p: Dictionary = raw
		var pid := String(p.get("id", ""))
		var rel := String(p.get("img", "explore/props/%s.png" % pid))
		var tex := _load_tex(rel)
		if tex == null:
			continue
		var at: Array = p.get("at", [0, 0])
		var s := Sprite2D.new()
		s.name = "Prop_%s" % pid
		s.texture = tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.centered = false
		# پراپ از **پایش** می‌نشیند تا Y-sort درست کار کند
		s.position = Vector2(float(at[0]) - tex.get_width() * 0.5,
			float(at[1]) - tex.get_height())
		_props.add_child(s)


func _build_occluders() -> void:
	_occluders = _layer("Occluders", 4)
	for raw in data.get("occluders", []):
		var o: Dictionary = raw
		var tex := _load_tex(String(o.get("img", "")))
		if tex == null:
			continue
		var at: Array = o.get("at", [0, 0])
		var s := Sprite2D.new()
		s.texture = tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.centered = false
		s.position = Vector2(float(at[0]), float(at[1]))
		_occluders.add_child(s)


func _build_light() -> void:
	_light = _layer("Light", 5)
	var light: Dictionary = data.get("light", {})
	for raw in light.get("overlays", []):
		var o: Dictionary = raw
		var tex := _load_tex(String(o.get("img", "")))
		if tex == null:
			continue
		var at: Array = o.get("at", [0, 0])
		var s := Sprite2D.new()
		s.texture = tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.centered = false
		s.position = Vector2(float(at[0]), float(at[1]))
		# نور **جمع‌شونده** است، نه رویی: روی تصویر نقاشی‌شده می‌نشیند و
		# روشنش می‌کند، نه اینکه رنگش را بپوشاند (سند ۰۴: مد Add).
		s.modulate = Color(1, 1, 1, float(o.get("alpha", 1.0)))
		s.material = _additive()
		s.set_meta("flicker", float(o.get("flicker", 0.0)))
		s.set_meta("base_alpha", float(o.get("alpha", 1.0)))
		_light.add_child(s)
		if float(o.get("flicker", 0.0)) > 0.0:
			_glows.append(s)


func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


func _process(delta: float) -> void:
	if _glows.is_empty():
		return
	_flicker_t += delta
	for s in _glows:
		var hz: float = float(s.get_meta("flicker", FLICKER_HZ))
		var base: float = float(s.get_meta("base_alpha", 1.0))
		# دامنهٔ کم: سوسو باید حس زنده بدهد، نه چشمک بزند
		var a := base * (0.88 + 0.12 * sin(_flicker_t * TAU * hz))
		s.modulate.a = a


## اندازهٔ اتاق بر حسب پیکسل — حد دوربین از همین می‌آید.
func bounds() -> Rect2:
	var size: Array = data.get("size", [1280, 720])
	return Rect2(0, 0, float(size[0]), float(size[1]))


func spawn_position() -> Vector2:
	var sp: Array = data.get("spawn", [0, 0])
	return Vector2(float(sp[0]), float(sp[1]))


func is_walkable(p: Vector2) -> bool:
	return RoomData.point_walkable(data, p)


func hazard_at(p: Vector2) -> Dictionary:
	return RoomData.hazard_at(data, p)


func door_at(p: Vector2) -> Dictionary:
	return RoomData.door_at(data, p)


## ماسک را برای بازبینی چشمی نشان می‌دهد — فقط در اسکرین‌شات عیب‌یابی.
func show_mask(on: bool) -> void:
	if _mask_debug != null:
		_mask_debug.queue_free()
		_mask_debug = null
	if not on:
		return
	_mask_debug = _layer("MaskDebug", 6)
	for flat in data.get("walkable", []):
		var poly := Polygon2D.new()
		poly.polygon = RoomData.to_polygon(flat)
		poly.color = Color(0.2, 1.0, 0.4, 0.22)
		_mask_debug.add_child(poly)
	for flat in data.get("blocked", []):
		var poly := Polygon2D.new()
		poly.polygon = RoomData.to_polygon(flat)
		poly.color = Color(0.15, 0.15, 0.2, 0.55)
		_mask_debug.add_child(poly)
	for raw in data.get("hazard", []):
		var h: Dictionary = raw
		var poly := Polygon2D.new()
		poly.polygon = RoomData.to_polygon(h.get("poly", []))
		poly.color = Color(1.0, 0.25, 0.2, 0.30)
		_mask_debug.add_child(poly)
	for raw in data.get("doors", []):
		var d: Dictionary = raw
		var r: Array = d.get("rect", [])
		if r.size() != 4:
			continue
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(float(r[0]), float(r[1])),
			Vector2(float(r[0]) + float(r[2]), float(r[1])),
			Vector2(float(r[0]) + float(r[2]), float(r[1]) + float(r[3])),
			Vector2(float(r[0]), float(r[1]) + float(r[3]))])
		poly.color = Color(0.3, 0.6, 1.0, 0.30)
		_mask_debug.add_child(poly)
