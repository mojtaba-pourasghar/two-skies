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
## لایهٔ حرکت طبیعت (برگ، پرده، آب) z خودش را دارد: پیش‌فرض ۱، یعنی روی
## نقاشی و زیر پراپ؛ با `"occluder": true` می‌رود به ۴ تا شخصیت از پشتش رد
## شود. قاعدهٔ ۹ CLAUDE.md: اتاق بی‌حرکت «تمام» نیست.
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

## نوع‌های جریان ذره (سند ۱۳ §۴). هر اتاق دست‌کم یکی لازم دارد.
const PARTICLE_KINDS := {
	"dust": {"lifetime": 6.0, "direction": Vector2(0, -1), "spread": 35.0,
		"gravity": Vector2(4, -6), "speed": 9.0, "scale": 1.6,
		"color": Color(0.90, 0.88, 0.78, 0.35), "additive": true},
	"ember": {"lifetime": 2.6, "direction": Vector2(0, -1), "spread": 20.0,
		"gravity": Vector2(0, -26), "speed": 26.0, "scale": 1.8,
		"color": Color(1.00, 0.62, 0.26, 0.85), "additive": true},
	"pollen": {"lifetime": 8.0, "direction": Vector2(1, -0.2), "spread": 50.0,
		"gravity": Vector2(6, -3), "speed": 7.0, "scale": 2.0,
		"color": Color(0.96, 0.95, 0.70, 0.45), "additive": true},
	"spark": {"lifetime": 1.2, "direction": Vector2(0, -1), "spread": 80.0,
		"gravity": Vector2(0, 90), "speed": 48.0, "scale": 1.2,
		"color": Color(0.70, 0.92, 1.00, 0.90), "additive": true},
	"mist": {"lifetime": 10.0, "direction": Vector2(1, 0), "spread": 15.0,
		"gravity": Vector2(2, 0), "speed": 5.0, "scale": 7.0,
		"color": Color(0.72, 0.84, 0.88, 0.14), "additive": false},
}

var data: Dictionary = {}
var missing_art: Array[String] = []

var world: Node2D          ## لایه‌های ۰ تا ۵ که با دوربین حرکت می‌کنند
var actors: Node2D         ## لایهٔ ۳ — بیرون می‌نشاندش

var _bg: Sprite2D
var _props: Node2D
var _occluders: Node2D
var _light: Node2D
var _mask_debug: Node2D
var _motion: Node2D
var _particles: Node2D
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
	_build_motion()
	_build_occluders()
	_build_light()
	_build_particles()
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


## حرکت طبیعت: شیت افقی هم‌اندازه، حلقه‌ای (REQ-019).
func _build_motion() -> void:
	_motion = _layer("Motion", 1)
	var amb: Dictionary = data.get("ambient", {})
	for raw in amb.get("motion", []):
		if not (raw is Dictionary):
			continue
		var m: Dictionary = raw
		var tex := _load_tex(String(m.get("img", "")))
		if tex == null:
			continue
		var frames := maxi(1, int(m.get("frames", 1)))
		var fps := maxf(1.0, float(m.get("fps", 8.0)))
		var sheet := SpriteFrames.new()
		sheet.set_animation_speed("default", fps)
		sheet.set_animation_loop("default", true)
		var fw := int(tex.get_width() / frames)
		var fh := tex.get_height()
		for i in frames:
			var at := AtlasTexture.new()
			at.atlas = tex
			at.region = Rect2(i * fw, 0, fw, fh)
			sheet.add_frame("default", at)
		var spr := AnimatedSprite2D.new()
		spr.name = "Motion_%s" % String(m.get("id", "x"))
		spr.sprite_frames = sheet
		spr.centered = false
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var at_pos: Array = m.get("at", [0, 0])
		spr.position = Vector2(float(at_pos[0]), float(at_pos[1]))
		spr.play("default")
		# پرده و برگِ جلوی صحنه باید شخصیت را بپوشانند، نه برعکس
		if bool(m.get("occluder", false)):
			spr.z_index = 4
		_motion.add_child(spr)


## جریان ذره: گرد و اخگر و گردهٔ گل. اتاق بی‌ذره ساکن به نظر می‌رسد حتی
## اگر همه‌چیزش درست باشد.
func _build_particles() -> void:
	_particles = _layer("Particles", 5)
	var amb: Dictionary = data.get("ambient", {})
	for raw in amb.get("particles", []):
		if not (raw is Dictionary):
			continue
		var d: Dictionary = raw
		var kind := String(d.get("kind", "dust"))
		var r: Array = d.get("rect", [])
		if r.size() != 4:
			warnings_note("جریان ذرهٔ «%s» ناحیه ندارد." % kind)
			continue
		var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
		var preset: Dictionary = PARTICLE_KINDS.get(kind, PARTICLE_KINDS["dust"])
		# CPUParticles2D نه GPU: در headless و روی گوشی‌های ارزان هم کار
		# می‌کند، و اینجا تعداد ذره‌ها کم است
		var ps := CPUParticles2D.new()
		ps.name = "Particles_%s" % kind
		ps.amount = maxi(1, int(d.get("count", 8)))
		ps.lifetime = float(preset["lifetime"])
		ps.position = rect.get_center()
		ps.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		ps.emission_rect_extents = rect.size * 0.5
		ps.direction = preset["direction"]
		ps.spread = float(preset["spread"])
		ps.gravity = preset["gravity"]
		ps.initial_velocity_min = float(preset["speed"]) * 0.5
		ps.initial_velocity_max = float(preset["speed"])
		ps.scale_amount_min = float(preset["scale"]) * 0.6
		ps.scale_amount_max = float(preset["scale"])
		ps.color = preset["color"]
		ps.local_coords = false
		# ذره‌ها از لحظهٔ ورود پخش‌شده باشند، نه اینکه با هم از صفر بزنند
		ps.preprocess = ps.lifetime
		if bool(preset["additive"]):
			ps.material = _additive()
		_particles.add_child(ps)


func warnings_note(msg: String) -> void:
	push_warning("اتاق «%s»: %s" % [String(data.get("id", "?")), msg])


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


## نواحی زوم اتاق، به شکلی که دوربین می‌خواهد (D-ART-42).
func zoom_zones() -> Array:
	return RoomData.zoom_zones(data)


## آیا این اتاق طبق قاعدهٔ ۹ زنده است؟ سه چیز لازم است: حرکت طبیعت،
## جریان ذره، نور متغیر.
func living_layers() -> Dictionary:
	var amb: Dictionary = data.get("ambient", {})
	var pulsing := false
	for raw in (data.get("light", {}) as Dictionary).get("overlays", []):
		if raw is Dictionary and float((raw as Dictionary).get("flicker", 0.0)) > 0.0:
			pulsing = true
			break
	return {
		"motion": (amb.get("motion", []) as Array).size(),
		"particles": (amb.get("particles", []) as Array).size(),
		"variable_light": pulsing,
	}


func is_living() -> bool:
	var l := living_layers()
	return int(l["motion"]) > 0 and int(l["particles"]) > 0 and bool(l["variable_light"])


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
