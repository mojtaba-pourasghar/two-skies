## افکت‌های اتاق از روی نقشهٔ تصویر — سند ۱۴ (D-ART-46)
##
## کاربر ضبط قبلی را دید: «افکت‌ها غیرطبیعی‌اند.» علتش لایه‌های **سراسری
## و هم‌فاز** بود که به هیچ چیزِ تصویر وصل نبودند: مهی که روی کل اتاق
## کشیده می‌شد، نوری که سینوس ۲ هرتز خالص می‌زد، تکانی که همه‌جا بود.
##
## حالا هر افکت از نقشهٔ `rooms/effects/<اتاق>.json` می‌آید و به یک منبع
## دیدنی وصل است. افکتی که در نقشه نیست، ساخته نمی‌شود.
##
## هفت نوع:
##   flicker_light  نور آتش و فانوس — مجموع ۳ فرکانس + نویز، ±۶ تا ۱۲٪
##   glow_pulse     نور آرام مهتاب — یک دورهٔ بلند (۵ تا ۹ ثانیه)
##   embers         اخگر از منبع (گودال، اجاق)، با fade ورود و خروج
##   dust_in_beam   گرد **فقط داخل پرتو نور**، مد Add
##   fog_patch      مه فقط در ورطه و لبه و دهانهٔ باز
##   sway           تکان با لولا در ریشه، ≤۲ پیکسل، دورهٔ ۳ تا ۶ ثانیه
##   anim           حلقهٔ تصویری از `ambient/ch1/<نام>`
class_name RoomEffects
extends Node2D

const ASSETS := "res://assets/"
const MAPS := "res://rooms/effects/"
const GROUP := "LivingLayer"

## فضای مختصات نقشه‌ها. نسخهٔ hires ۱٫۳۱۲۵ برابر است و مختصات همان می‌ماند.
const SPACE := Vector2(1280, 720)

var missing: Array[String] = []
var effects: Array[Dictionary] = []

var _bg: Texture2D = null
var _bg_scale: float = 1.0
var _t: float = 0.0
## سیگنال هر نور، برای `same_as:` و تأخیر لکهٔ کف
var _signals: Dictionary = {}
var _history: Dictionary = {}
var _glow_nodes: Array[Dictionary] = []
var _fog_nodes: Array[Dictionary] = []
var _sway_nodes: Array[Node2D] = []


## نقشهٔ افکت اتاق. نام فایل گاهی با شناسهٔ اتاق فرق دارد (`r1a_living`
## در برابر `r1a_house`)، پس اتاق می‌تواند صریح بگوید کدام نقشه.
static func map_path(name: String) -> String:
	return MAPS + name + ".json"


func load_map(name: String) -> bool:
	var p := map_path(name)
	if not FileAccess.file_exists(p):
		push_warning("RoomEffects: نقشهٔ افکت «%s» نیست." % name)
		return false
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
	if not (parsed is Dictionary):
		push_warning("RoomEffects: نقشهٔ «%s» خراب است." % name)
		return false
	effects.clear()
	for raw in (parsed as Dictionary).get("effects", []):
		if raw is Dictionary:
			effects.append(raw)
	return true


func build(bg: Texture2D, bg_scale: float = 1.0) -> void:
	_bg = bg
	_bg_scale = bg_scale
	# ترتیب مهم است: نور و مه باید **روی** تکان بنشینند، وگرنه هالهٔ
	# چراغ زیر پردهٔ تکان‌خورنده گم می‌شود
	for e in effects:
		match String(e.get("type", "")):
			"sway": _add(_make_sway(e), e)
			"anim": _add(_make_anim(e), e)
			"embers": _add(_make_embers(e), e)
			"dust_in_beam": _add(_make_dust(e), e)
			"fog_patch": _add(_make_fog(e), e)
			"flicker_light", "glow_pulse": _add(_make_glow(e), e)
			_: push_warning("RoomEffects: نوع ناشناختهٔ «%s»" % e.get("type", ""))


func _add(n: Node2D, e: Dictionary) -> void:
	if n == null:
		return
	n.name = "Fx_%s" % String(e.get("id", "x"))
	n.add_to_group(GROUP)
	add_child(n)


func _tex(rel: String) -> Texture2D:
	var p := ASSETS + rel
	if not ResourceLoader.exists(p):
		if rel not in missing:
			missing.append(rel)
		return null
	return load(p)


## نقشه‌ها در فضای ۱۲۸۰×۷۲۰ نوشته شده‌اند و `rect` با **گوشه** می‌آید
## (x1,y1,x2,y2) نه با عرض و ارتفاع.
static func corners(a: Array) -> Rect2:
	if a.size() != 4:
		return Rect2()
	var x1: float = minf(float(a[0]), float(a[2]))
	var y1: float = minf(float(a[1]), float(a[3]))
	var x2: float = maxf(float(a[0]), float(a[2]))
	var y2: float = maxf(float(a[1]), float(a[3]))
	return Rect2(x1, y1, x2 - x1, y2 - y1)


static func color_of(e: Dictionary, fallback := Color(1, 1, 1)) -> Color:
	var s := String(e.get("color", ""))
	return Color(s) if s.begins_with("#") else fallback


# ------------------------------------------------------------------- نور

## سیگنال سوسو: **مجموع سه فرکانس ناهم‌اندازه به‌علاوهٔ نویز پایین‌گذر**.
##
## سند ۱۴ بند ۲ سینوس ۲ هرتز خالص را ممنوع می‌کند، و درست می‌گوید: شعلهٔ
## واقعی دوره ندارد. نسبت فرکانس‌ها عمداً گنگ است (۱، ۱٫۶۱۸، ۲٫۷۱۸) تا
## الگو در ده ثانیه تکرار نشود.
func _flicker(id: String, amp: float) -> float:
	var f1 := sin(_t * TAU * 1.7 + float(id.hash() % 100) * 0.07)
	var f2 := sin(_t * TAU * 1.7 * 1.618 + 2.1)
	var f3 := sin(_t * TAU * 1.7 * 2.718 + 4.3)
	var n: float = _noise(id)
	var s: float = 0.45 * f1 + 0.28 * f2 + 0.12 * f3 + 0.35 * n
	return 1.0 + amp * clampf(s, -1.0, 1.0)


## نویز پایین‌گذر: تصادفی، ولی هموار. نویز خام هر فریم «چشمک» می‌شود،
## که سند ۱۴ بند ۶ ممنوعش کرده.
func _noise(id: String) -> float:
	var st: Dictionary = _history.get(id, {"v": 0.0, "target": 0.0, "left": 0})
	st["left"] = int(st["left"]) - 1
	if int(st["left"]) <= 0:
		st["target"] = randf_range(-1.0, 1.0)
		# هر ۸ تا ۲۰ فریم یک هدف تازه: یعنی ۰٫۱۳ تا ۰٫۳۳ ثانیه
		st["left"] = randi_range(8, 20)
	st["v"] = lerpf(float(st["v"]), float(st["target"]), 0.12)
	_history[id] = st
	return float(st["v"])


func _make_glow(e: Dictionary) -> Node2D:
	var radius := float(e.get("radius", 100.0))
	var pos := Vector2(float(e.get("pos", [0, 0])[0]), float(e.get("pos", [0, 0])[1]))
	var spr := Sprite2D.new()
	spr.texture = _radial()
	spr.centered = true
	spr.position = pos
	# بافت ۱۲۸ است و باید قطر ۲r را بپوشاند
	spr.scale = Vector2.ONE * (radius * 2.0 / 128.0)
	spr.z_index = 5

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/glow.gdshader")
	var c := color_of(e, Color(1, 0.8, 0.5))
	# **پایهٔ هاله باید کم باشد.** نور خودش در نقاشی هست؛ کار این لایه
	# نفس کشیدن آن است، نه گذاشتن چراغ تازه. با پایهٔ ۰٫۵ کل نیمهٔ چپ
	# R1a زیر یک پردهٔ نارنجی ثابت رفت و کنتراست نقاشی صاف شد — در
	# مقایسهٔ ON/OFF فوراً دیده می‌شد.
	#
	# سند ۱۴ بند ۲ دامنه را ±۶ تا ۱۲٪ می‌خواهد؛ آن درصدِ **همین پایه**
	# است، پس پایه هرچه کمتر، افکت کمتر دیده می‌شود و فضا بیشتر.
	var base := float(e.get("base_alpha", 0.14))
	mat.set_shader_parameter("tint", Vector4(c.r, c.g, c.b, base))
	mat.set_shader_parameter("node_rect",
		Vector4(pos.x - radius, pos.y - radius, radius * 2.0, radius * 2.0))
	var clip: Array = e.get("clip_rect", [])
	if clip.size() == 4:
		var r := corners(clip)
		mat.set_shader_parameter("clip_rect",
			Vector4(r.position.x, r.position.y, r.size.x, r.size.y))
	spr.material = mat

	var kind := String(e.get("type", ""))
	_glow_nodes.append({
		"node": spr, "mat": mat, "id": String(e.get("id", "")),
		"amp": float(e.get("amp", 0.08)), "base": base, "rgb": c,
		"pulse": kind == "glow_pulse",
		"period": float(e.get("period_s", 6.0)),
		"same_as": String(e.get("signal", "")).trim_prefix("same_as:")
			if String(e.get("signal", "")).begins_with("same_as:") else "",
	})
	return spr


## بافت افت شعاعی، یک بار ساخته و بین همهٔ نورها مشترک می‌شود.
static var _radial_tex: Texture2D = null


static func _radial() -> Texture2D:
	if _radial_tex != null:
		return _radial_tex
	var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	_radial_tex = ImageTexture.create_from_image(img)
	return _radial_tex


# ------------------------------------------------------------------ ذره

func _make_embers(e: Dictionary) -> Node2D:
	var tex := _tex(_sprite_of(e, "overlays/particles/ember_1.png"))
	if tex == null:
		return null
	var pos: Array = e.get("pos", [0, 0])
	var size: Array = e.get("spawn_size", [40, 20])
	var life: Array = e.get("life_s", [3, 7])
	var life_max := float(life[life.size() - 1])
	var rate := float(e.get("rate_per_s", 2.0))
	var rise := float(e.get("rise_px_s", 12.0))

	var ps := GPUParticles2D.new()
	# تعداد از نرخ و عمر درمی‌آید، نه از عددی که من بپسندم: سند ۱۴ بند ۵
	# سقف ۳۰ در هر منبع می‌گذارد.
	ps.amount = clampi(int(ceil(rate * life_max)), 1, 30)
	ps.lifetime = life_max
	ps.position = Vector2(float(pos[0]), float(pos[1]))
	ps.local_coords = false
	ps.texture = tex
	ps.preprocess = life_max
	ps.randomness = 0.8
	ps.z_index = 5

	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	m.emission_box_extents = Vector3(float(size[0]) * 0.5, float(size[1]) * 0.5, 0.0)
	# `rise_px_s` منفی یعنی می‌بارد، نه بالا می‌رود (خاکستر بیرون پنجره)
	m.direction = Vector3(0, -1 if rise >= 0.0 else 1, 0)
	m.spread = 24.0
	m.gravity = Vector3(randf_range(-3.0, 3.0), -rise * 0.4, 0.0)
	m.initial_velocity_min = absf(rise) * 0.6
	m.initial_velocity_max = absf(rise) * 1.4
	m.scale_min = 0.05
	m.scale_max = 0.12
	m.color = color_of(e, Color(1, 0.5, 0.2))
	# fade ورود و خروج (سند ۱۴ بند ۵): ذره نباید ناگهان ظاهر و ناپدید شود
	m.alpha_curve = _fade_curve()
	ps.process_material = m
	ps.material = _additive()
	return ps


## گرد **فقط داخل پرتو نور** (سند ۱۴ بند ۵). چندضلعی پرتو از نقشه می‌آید؛
## ذره‌ها روی نقاط داخل همان چندضلعی زاده می‌شوند، نه در مستطیل دور آن.
func _make_dust(e: Dictionary) -> Node2D:
	var tex := _tex(_sprite_of(e, "overlays/particles/dust_1.png"))
	if tex == null:
		return null
	var poly := PackedVector2Array()
	for p in e.get("poly", []):
		if p is Array and (p as Array).size() == 2:
			poly.append(Vector2(float(p[0]), float(p[1])))
	if poly.size() < 3:
		return null
	var drift: Array = e.get("drift_px_s", [2, 6])

	var ps := GPUParticles2D.new()
	ps.amount = clampi(int(e.get("count", 14)), 1, 30)
	ps.lifetime = 7.0
	ps.local_coords = false
	ps.texture = tex
	ps.preprocess = 7.0
	ps.randomness = 0.9
	ps.z_index = 5

	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINTS
	# گودو نقاط زایش را به شکل **بافت** می‌گیرد، نه آرایه: هر پیکسل
	# RGBF یک موقعیت است.
	var pts := _points_in(poly, 96)
	m.emission_point_count = pts.size()
	m.emission_point_texture = _points_texture(pts)
	m.direction = Vector3(0.3, -1, 0)
	m.spread = 50.0
	m.gravity = Vector3(1.0, -2.0, 0.0)
	m.initial_velocity_min = float(drift[0])
	m.initial_velocity_max = float(drift[drift.size() - 1])
	m.scale_min = 0.05
	m.scale_max = 0.10
	m.color = Color(0.95, 0.90, 0.78, 0.5)
	m.alpha_curve = _fade_curve()
	ps.process_material = m
	ps.material = _additive()
	return ps


## نقاط تصادفی **داخل** چندضلعی. رد کردن نقاط بیرون، شکل پرتو را حفظ
## می‌کند؛ مستطیل دور پرتو، گرد را روی دیوار تاریک هم می‌پاشد.
static func _points_in(poly: PackedVector2Array, want: int) -> PackedVector3Array:
	var box := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	var out := PackedVector3Array()
	var tries := 0
	while out.size() < want and tries < want * 40:
		tries += 1
		var p := Vector2(randf_range(box.position.x, box.end.x),
			randf_range(box.position.y, box.end.y))
		if Geometry2D.is_point_in_polygon(p, poly):
			out.append(Vector3(p.x, p.y, 0.0))
	if out.is_empty():
		out.append(Vector3(box.get_center().x, box.get_center().y, 0.0))
	return out


## نقاط را در یک بافت RGBF می‌ریزد، همان شکلی که ParticleProcessMaterial
## می‌خواهد.
static func _points_texture(pts: PackedVector3Array) -> ImageTexture:
	var img := Image.create(maxi(1, pts.size()), 1, false, Image.FORMAT_RGBF)
	for i in pts.size():
		img.set_pixel(i, 0, Color(pts[i].x, pts[i].y, pts[i].z))
	return ImageTexture.create_from_image(img)


static func _fade_curve() -> CurveTexture:
	var c := Curve.new()
	c.add_point(Vector2(0.0, 0.0))
	c.add_point(Vector2(0.18, 1.0))
	c.add_point(Vector2(0.72, 1.0))
	c.add_point(Vector2(1.0, 0.0))
	var t := CurveTexture.new()
	t.curve = c
	return t


static func _sprite_of(e: Dictionary, fallback: String) -> String:
	var s := String(e.get("sprite", ""))
	if s == "":
		return fallback
	# نقشه با ستاره می‌نویسد (`ember_*`)؛ یک نمونه برمی‌داریم
	return s.replace("_*", "_1") + (".png" if not s.ends_with(".png") else "")


# -------------------------------------------------------------------- مه

func _make_fog(e: Dictionary) -> Node2D:
	var sheet := _tex(String(e.get("sheet", "overlays/fog/sheet_thin.png")))
	if sheet == null:
		return null
	var r := corners(e.get("rect", []))
	if r.size == Vector2.ZERO:
		return null
	var spr := Sprite2D.new()
	spr.texture = _white()
	spr.centered = false
	spr.position = r.position
	spr.scale = r.size
	spr.z_index = 5

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/fog_patch.gdshader")
	mat.set_shader_parameter("sheet", sheet)
	mat.set_shader_parameter("rect_px", r.size)
	mat.set_shader_parameter("feather_px", float(e.get("edge_feather", 80.0)))
	# سند ۱۴: آلفا حداکثر ۰٫۱۲. رنگ را کد می‌زند، ورقه سفید است.
	var a: float = minf(float(e.get("alpha", 0.08)), 0.12)
	var c := color_of(e, Color(0.82, 0.86, 0.90))
	mat.set_shader_parameter("tint", Vector4(c.r, c.g, c.b, a))
	spr.material = mat

	var dir: Array = e.get("dir", [1, 0])
	var v := Vector2(float(dir[0]), float(dir[1]))
	if v.length() > 0.001:
		v = v.normalized()
	_fog_nodes.append({
		"mat": mat,
		"vel": v * float(e.get("speed_px_s", 5.0)),
	})
	return spr


static var _white_tex: Texture2D = null


static func _white() -> Texture2D:
	if _white_tex != null:
		return _white_tex
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	_white_tex = ImageTexture.create_from_image(img)
	return _white_tex


# ------------------------------------------------------------------ تکان

func _make_sway(e: Dictionary) -> Node2D:
	if _bg == null:
		return null
	var r := corners(e.get("rect", []))
	if r.size == Vector2.ZERO:
		return null
	var spr := Sprite2D.new()
	spr.texture = _bg
	spr.region_enabled = true
	# بریده در فضای **بافت** است؛ با hires تصویر بزرگ‌تر است
	spr.region_rect = Rect2(r.position * _bg_scale, r.size * _bg_scale)
	spr.centered = false
	spr.position = r.position
	spr.scale = Vector2.ONE / _bg_scale
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.z_index = 1

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/sway.gdshader")
	# سند ۱۴: دامنه ≤۲ پیکسل، دوره ۳ تا ۶ ثانیه
	mat.set_shader_parameter("amp_px", minf(float(e.get("amp_px", 2.0)), 2.0))
	mat.set_shader_parameter("period_s",
		clampf(float(e.get("period_s", 4.5)), 3.0, 7.0))
	# فاز هر نمونه متفاوت، وگرنه همهٔ گیاهان اتاق با هم خم می‌شوند
	mat.set_shader_parameter("phase", randf() * TAU)
	mat.set_shader_parameter("gust", 0.35 if bool(e.get("gusts", false)) else 0.0)
	mat.set_shader_parameter("push", 0.0)

	var size := _bg.get_size()
	mat.set_shader_parameter("region_px", r.size)
	mat.set_shader_parameter("uv_rect", Vector4(
		r.position.x * _bg_scale / size.x, r.position.y * _bg_scale / size.y,
		r.size.x * _bg_scale / size.x, r.size.y * _bg_scale / size.y))
	var piv: Array = e.get("pivot", [r.get_center().x, r.end.y])
	mat.set_shader_parameter("pivot_local", Vector2(
		clampf((float(piv[0]) - r.position.x) / maxf(r.size.x, 1.0), 0.0, 1.0),
		clampf((float(piv[1]) - r.position.y) / maxf(r.size.y, 1.0), 0.0, 1.0)))
	mat.set_shader_parameter("tint", Vector4(1, 1, 1, 1))
	spr.material = mat
	spr.set_meta("react_rect", r)
	_sway_nodes.append(spr)
	return spr


# -------------------------------------------------------------- انیمیشن

func _make_anim(e: Dictionary) -> Node2D:
	var rel := String(e.get("anim", ""))
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", float(e.get("fps", 8.0)))
	frames.set_animation_loop("default", true)
	var n := 0
	for i in 12:
		var tex := _tex("%s/%s_%d.png" % [rel, rel.get_file(), i])
		if tex == null:
			missing.erase("%s/%s_%d.png" % [rel, rel.get_file(), i])
			break
		frames.add_frame("default", tex)
		n += 1
	if n == 0:
		missing.append(rel)
		return null

	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = frames
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = false
	var sc := float(e.get("scale", 1.0))
	spr.scale = Vector2(sc, sc)
	var size := frames.get_frame_texture("default", 0).get_size()
	var pos: Array = e.get("pos", [0, 0])
	# لنگر پایین-وسط (asset.json دستهٔ ۴۹)
	spr.position = Vector2(float(pos[0]) - size.x * sc * 0.5,
		float(pos[1]) - size.y * sc)
	spr.z_index = 2
	spr.play("default")
	if bool(e.get("random_start", false)):
		spr.frame = randi() % maxi(1, n)
	return spr


func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


# -------------------------------------------------------------------- تیک

func _process(delta: float) -> void:
	_t += delta
	_signals.clear()
	for g in _glow_nodes:
		var id: String = g["id"]
		var v: float
		if bool(g["pulse"]):
			v = 1.0 + float(g["amp"]) * sin(_t * TAU / maxf(float(g["period"]), 0.1))
		else:
			v = _flicker(id, float(g["amp"]))
		_signals[id] = v

	for g in _glow_nodes:
		var v: float = float(_signals.get(g["id"], 1.0))
		var src: String = g["same_as"]
		if src != "":
			# لکهٔ نور کف **همان سیگنال** شعله است با ~۱۰۰ms تأخیر
			# (سند ۱۴ بند ۲). جدا بودنشان یعنی دو چیز بی‌ربط سوسو بزنند.
			v = _delayed(src, float(_signals.get(src, 1.0)))
		var c: Color = g["rgb"]
		var a: float = float(g["base"]) * v
		(g["mat"] as ShaderMaterial).set_shader_parameter("tint",
			Vector4(c.r, c.g, c.b, a))

	for f in _fog_nodes:
		var off: Vector2 = f["vel"] * _t
		(f["mat"] as ShaderMaterial).set_shader_parameter("offset_a", off)
		# لایهٔ دوم کندتر و با زاویهٔ کمی متفاوت
		(f["mat"] as ShaderMaterial).set_shader_parameter("offset_b",
			off.rotated(0.4) * -0.55)


const DELAY_FRAMES: int = 6   # ~۱۰۰ms در ۶۰ فریم


func _delayed(id: String, v: float) -> float:
	var key := "delay_" + id
	var q: Array = _history.get(key, [])
	q.append(v)
	while q.size() > DELAY_FRAMES:
		q.pop_front()
	_history[key] = q
	return float(q[0])


## تصویر پس‌زمینه عوض شد (نسخهٔ پرجزئیات). تکان‌ها بریده‌ای از همان
## تصویرند، پس باید با آن برود؛ وگرنه برگ‌ها تکه‌ای از جای غلط نشان
## می‌دهند.
func set_background(bg: Texture2D, bg_scale: float) -> void:
	if bg == null or bg == _bg:
		return
	_bg = bg
	_bg_scale = bg_scale
	var size := bg.get_size()
	for n in _sway_nodes:
		var spr := n as Sprite2D
		if spr == null:
			continue
		var r: Rect2 = spr.get_meta("react_rect", Rect2())
		spr.texture = bg
		spr.region_rect = Rect2(r.position * bg_scale, r.size * bg_scale)
		spr.scale = Vector2.ONE / bg_scale
		var mat := spr.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("uv_rect", Vector4(
				r.position.x * bg_scale / size.x, r.position.y * bg_scale / size.y,
				r.size.x * bg_scale / size.x, r.size.y * bg_scale / size.y))


## برای واکنش به عبور بازیکن (سند ۱۳ بند ۷) — فقط روی تکان‌ها.
func sway_nodes() -> Array[Node2D]:
	return _sway_nodes
