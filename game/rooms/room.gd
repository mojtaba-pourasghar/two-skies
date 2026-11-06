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

## نوع‌های جریان ذره (سند ۱۳ بند ۴). هر اتاق دست‌کم یکی لازم دارد.
##
## `scale` ضریب **بافت** است نه پیکسل: بافت‌های `overlays/particles` حدود
## ۱۹۰ پیکسل عرض دارند، پس ضریب کوچک است وگرنه هر «ذره» یک لکهٔ درشت
## می‌شود. (پاسخ مدیر هنر REQ-003: نیم‌مقیاس، آلفا از روشنایی، مد Add.)
const PARTICLE_KINDS := {
	"dust": {"lifetime": 7.0, "direction": Vector2(0, -1), "spread": 35.0,
		"gravity": Vector2(4, -6), "speed": 9.0, "scale": 0.16,
		"color": Color(0.90, 0.88, 0.78, 0.30), "additive": true},
	"ember": {"lifetime": 2.8, "direction": Vector2(0, -1), "spread": 20.0,
		"gravity": Vector2(0, -26), "speed": 26.0, "scale": 0.13,
		"color": Color(1.00, 0.62, 0.26, 0.75), "additive": true},
	"ash": {"lifetime": 9.0, "direction": Vector2(0.2, 1), "spread": 30.0,
		"gravity": Vector2(3, 10), "speed": 8.0, "scale": 0.18,
		"color": Color(0.80, 0.78, 0.74, 0.35), "additive": false},
	"spark": {"lifetime": 1.2, "direction": Vector2(0, -1), "spread": 80.0,
		"gravity": Vector2(0, 90), "speed": 48.0, "scale": 0.12,
		"color": Color(0.70, 0.92, 1.00, 0.85), "additive": true},
	"fog": {"lifetime": 12.0, "direction": Vector2(1, 0), "spread": 12.0,
		"gravity": Vector2(2, 0), "speed": 5.0, "scale": 0.9,
		"color": Color(0.72, 0.84, 0.88, 0.12), "additive": false},
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
var _sway_nodes: Array[Node2D] = []
var _dust_puff: GPUParticles2D = null
var _last_react := Vector2.ZERO
var _glows: Array[Sprite2D] = []
var _pulses: Array[Node2D] = []


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


## منبع‌های حرکت محیطی: انیمیشن حلقه‌ای، تکان برگ و پرده، آب، مه.
## همه در گروه `LivingLayer` می‌نشینند تا سنجهٔ پذیرش بتواند بشمارد.
##
## قاعدهٔ بودجهٔ زندگی (سند ۱۳ بند ۱): **دست‌کم ۳ منبع همزمان** در هر
## اتاق. `is_living()` همین را می‌سنجد و `RoomData` اگر کم باشد هشدار
## می‌دهد — «تمام» گفتن یک اتاق ساکن اشتباهی است که باید صدا کند.
func _build_motion() -> void:
	_motion = _layer("Motion", 1)
	var amb: Dictionary = data.get("ambient", {})
	var scene := LivingScene.new()
	var bg_tex: Texture2D = _bg.texture if _bg != null else null

	for raw in amb.get("motion", []):
		if raw is Dictionary:
			_place(scene.make_anim(raw), raw)
	for raw in amb.get("sway", []):
		if raw is Dictionary:
			var n := scene.make_sway(bg_tex, raw)
			if n != null:
				n.set_meta("react_rect", _rect_of(raw))
				_sway_nodes.append(n)
			_place(n, raw)
	for raw in amb.get("water", []):
		if raw is Dictionary:
			_place(scene.make_water(bg_tex, raw), raw)
	for raw in amb.get("fog", []):
		if raw is Dictionary:
			_place(scene.make_fog(raw), raw)

	for rel in scene.missing:
		_note_missing(rel)


func _rect_of(d: Dictionary) -> Rect2:
	var r: Array = d.get("rect", [])
	if r.size() != 4:
		return Rect2()
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


## گره را در لایهٔ درست می‌نشاند. `occluder: true` یعنی شخصیت از **پشتش**
## رد می‌شود (پردهٔ جلوی صحنه، شاخهٔ آویزان)، پس می‌رود بالای بازیگران.
func _place(n: Node2D, d: Dictionary) -> void:
	if n == null:
		return
	if bool(d.get("occluder", false)):
		n.z_index = maxi(n.z_index, 4)
	_motion.add_child(n)


## جریان ذره — GPUParticles2D با بافت‌های `overlays/particles` (دستور
## کاربر و سند ۱۳ بند ۴). اتاق بی‌ذره حتی با همه‌چیز درست، ساکن است.
##
## بافت‌ها نیم‌مقیاس و آلفاشان از روشنایی است (پاسخ مدیر هنر، REQ-003)،
## پس مد Add می‌خواهند و مقیاس کوچک.
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
		var tex := _load_tex("overlays/particles/%s_%d.png"
			% [kind, int(d.get("variant", 0))])

		var ps := GPUParticles2D.new()
		ps.name = "Particles_%s" % String(d.get("id", kind))
		ps.amount = maxi(1, int(d.get("count", 8)))
		ps.lifetime = float(preset["lifetime"])
		ps.position = rect.get_center()
		ps.local_coords = false
		ps.texture = tex
		# بدون preprocess همهٔ ذره‌ها با هم از صفر می‌زنند و ورود به اتاق
		# یک موج ناگهانی گرد می‌شود
		ps.preprocess = ps.lifetime
		ps.randomness = 0.6

		var m := ParticleProcessMaterial.new()
		m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		m.emission_box_extents = Vector3(rect.size.x * 0.5, rect.size.y * 0.5, 0.0)
		m.direction = Vector3(preset["direction"].x, preset["direction"].y, 0.0)
		m.spread = float(preset["spread"])
		m.gravity = Vector3(preset["gravity"].x, preset["gravity"].y, 0.0)
		m.initial_velocity_min = float(preset["speed"]) * 0.4
		m.initial_velocity_max = float(preset["speed"])
		# بافت‌ها ~۱۹۰ پیکسل‌اند و ذره‌اند نه تکه‌ابر: کوچک می‌شوند
		m.scale_min = float(preset["scale"]) * 0.5
		m.scale_max = float(preset["scale"])
		m.color = preset["color"]
		ps.process_material = m
		if bool(preset["additive"]):
			ps.material = _additive()
		ps.add_to_group(LivingScene.GROUP)
		_particles.add_child(ps)

	_build_dust_puff()


## گردی که از پای بازیکن بلند می‌شود. یک گره است که دنبال پا می‌رود، نه
## یکی به‌ازای هر قدم: ساختن و دور انداختن گره در حلقهٔ فیزیک گران است.
func _build_dust_puff() -> void:
	var tex := _load_tex("overlays/particles/dust_1.png")
	if tex == null:
		return
	var ps := GPUParticles2D.new()
	ps.name = "DustPuff"
	ps.amount = 6
	ps.lifetime = 0.7
	ps.texture = tex
	ps.local_coords = false
	ps.emitting = false
	ps.z_index = 3
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 6.0
	m.direction = Vector3(0, -1, 0)
	m.spread = 55.0
	m.gravity = Vector3(0, 26, 0)
	m.initial_velocity_min = 6.0
	m.initial_velocity_max = 18.0
	m.scale_min = 0.05
	m.scale_max = 0.11
	m.color = Color(0.86, 0.82, 0.72, 0.30)
	ps.process_material = m
	ps.material = _additive()
	ps.add_to_group(LivingScene.GROUP)
	_particles.add_child(ps)
	_dust_puff = ps


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


## نور اتاق. دو راه دارد، و هر دو نبض می‌گیرند:
##   `light.overlays`  — هالهٔ ساده از یک تصویر، با `flicker`
##   `light.pulses`    — نور تحویلی `overlays/lights/<نام>_0..2`،
##                       ۲ هرتز، ±۱۵٪، فاز تصادفی (سند ۱۳ بند ۲)
func _build_light() -> void:
	_light = _layer("Light", 5)
	var light: Dictionary = data.get("light", {})
	var scene := LivingScene.new()

	for raw in light.get("pulses", []):
		if not (raw is Dictionary):
			continue
		var n := scene.make_pulse(raw)
		if n != null:
			_light.add_child(n)
			_pulses.append(n)
	for rel in scene.missing:
		_note_missing(rel)

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
			s.add_to_group(LivingScene.GROUP)
			_glows.append(s)


func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


func _process(delta: float) -> void:
	if _glows.is_empty() and _pulses.is_empty():
		return
	_flicker_t += delta
	for s in _glows:
		var hz: float = float(s.get_meta("flicker", FLICKER_HZ))
		var base: float = float(s.get_meta("base_alpha", 1.0))
		# دامنهٔ کم: سوسو باید حس زنده بدهد، نه چشمک بزند
		var a := base * (0.88 + 0.12 * sin(_flicker_t * TAU * hz))
		s.modulate.a = a
	for n in _pulses:
		LivingScene.tick_pulse(n, _flicker_t)


## شعاعی که عبور بازیکن در آن حس می‌شود، و چقدر طول می‌کشد تا بخوابد.
const REACT_PX: float = 86.0
const REACT_PUSH: float = 5.0
const REACT_DECAY: float = 0.90
## زیر این سرعت، رد شدن «عبور» نیست و گرد بلند نمی‌کند.
const REACT_SPEED: float = 40.0


## محیط به عبور بازیکن واکنش نشان می‌دهد (سند ۱۳ بند ۷): برگ و پرده‌ای
## که نزدیکش رد می‌شود تکان بیشتری می‌خورد، و از پا گرد بلند می‌شود.
##
## بدون این، صحنه زنده هست ولی **بی‌اعتنا**؛ بازیکن حس نمی‌کند در آن
## اتاق حضور دارد.
func react_to(foot: Vector2, speed: float) -> void:
	for n in _sway_nodes:
		var mat := n.material as ShaderMaterial
		if mat == null:
			continue
		var rect: Rect2 = n.get_meta("react_rect", Rect2())
		var raw_push = mat.get_shader_parameter("push")
		var push: float = float(raw_push) if raw_push != null else 0.0
		var near: float = _distance_to_rect(foot, rect)
		if near < REACT_PX and speed > REACT_SPEED:
			# نزدیک‌تر، تکان بیشتر — نه روشن/خاموش
			push = maxf(push, REACT_PUSH * (1.0 - near / REACT_PX))
		push *= REACT_DECAY
		mat.set_shader_parameter("push", push)

	if _dust_puff != null:
		var moved := foot.distance_to(_last_react)
		_dust_puff.position = foot
		# فقط وقتی واقعاً راه می‌رود، نه وقتی ایستاده می‌لرزد
		_dust_puff.emitting = speed > REACT_SPEED and moved > 0.5
	_last_react = foot


static func _distance_to_rect(p: Vector2, r: Rect2) -> float:
	if r.size == Vector2.ZERO:
		return INF
	var dx: float = maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy: float = maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return sqrt(dx * dx + dy * dy)


## رنگ نور اتاق، برای گذار در به در: پردهٔ گذار به‌جای سیاه خالص، به رنگ
## نور اتاق می‌رود، پس عبور از در **تغییر نور** دیده می‌شود نه خاموشی.
func light_tint() -> Color:
	var t: Array = (data.get("light", {}) as Dictionary).get("tint", [])
	if t.size() != 3:
		return Color(0, 0, 0)
	return Color(float(t[0]), float(t[1]), float(t[2]))


## نواحی زوم اتاق، به شکلی که دوربین می‌خواهد (D-ART-42).
func zoom_zones() -> Array:
	return RoomData.zoom_zones(data)


## بودجهٔ زندگی این اتاق — از **گره‌های ساخته‌شده** شمرده می‌شود، نه از
## روی JSON. تفاوتش مهم است: اگر هنر یک حلقه نرسیده باشد، JSON می‌گوید
## سه منبع دارم و صحنه ساکن است. اینجا همان چیزی شمرده می‌شود که روی
## صفحه حرکت می‌کند.
func living_layers() -> Dictionary:
	var motion := 0
	var particles := 0
	var lights := 0
	for n in get_tree().get_nodes_in_group(LivingScene.GROUP) if is_inside_tree() else []:
		if not is_ancestor_of(n):
			continue
		# گردِ پای بازیکن **منبع محیطی نیست**: واکنش است و تا کسی راه
		# نرود چیزی نمی‌بارد. اگر شمرده شود، اتاق کاملاً ساکن هم شرط
		# «ذره دارد» را برآورده می‌کند و بودجه بی‌معنا می‌شود.
		if n == _dust_puff:
			continue
		if n is GPUParticles2D or n is CPUParticles2D:
			particles += 1
		elif n.has_meta("pulse_base") or n.has_meta("flicker"):
			lights += 1
		else:
			motion += 1
	return {
		"motion": motion,
		"particles": particles,
		"variable_light": lights > 0,
		"lights": lights,
		"sources": motion + particles + lights,
	}


## «≥۳ منبع حرکت محیطی همزمان» (سند ۱۳ بند ۱) و نور نبض‌دار و ذره.
const LIVING_MIN_SOURCES: int = 3


func is_living() -> bool:
	var l := living_layers()
	return int(l["sources"]) >= LIVING_MIN_SOURCES \
		and int(l["particles"]) > 0 \
		and bool(l["variable_light"]) \
		and int(l["motion"]) > 0


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
