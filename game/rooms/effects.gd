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
##   arc_pop        جرقهٔ کوتاه و **تصادفی** سر کویل یا تیر برق
##   neon_buzz      نئون ثابت است و فقط گاهی یک لرزش کوتاه دارد
##   laser_hum      نبض ±۵٪ روی پرتوها؛ خطر بصری هرگز محو نمی‌شود
##   led_blink      نقطه‌های ۲ پیکسلی تصادفی روی رک‌ها
class_name RoomEffects
extends Node2D

const ASSETS := "res://assets/"
const MAPS := "res://rooms/effects/"
const GROUP := "LivingLayer"

## فضای مختصات نقشه‌ها. نسخهٔ hires ۱٫۳۱۲۵ برابر است و مختصات همان می‌ماند.
const SPACE := Vector2(1280, 720)

var missing: Array[String] = []
var effects: Array[Dictionary] = []
## شناسهٔ اتاق، برای پیدا کردن ماسک‌های `clip_mask` در `rooms/masks/<اتاق>/`
var room_id: String = ""

var _bg: Texture2D = null
var _bg_scale: float = 1.0
var _t: float = 0.0
## سیگنال هر نور، برای `same_as:` و تأخیر لکهٔ کف
var _signals: Dictionary = {}
var _history: Dictionary = {}
var _glow_nodes: Array[Dictionary] = []
var _fog_nodes: Array[Dictionary] = []
var _sway_nodes: Array[Node2D] = []
var _burst_nodes: Array[Dictionary] = []
var _laser_nodes: Array[Dictionary] = []
var _led_nodes: Array[Dictionary] = []


## نقشهٔ افکت اتاق. نام فایل گاهی با شناسهٔ اتاق فرق دارد (`r1a_living`
## در برابر `r1a_house`)، پس اتاق می‌تواند صریح بگوید کدام نقشه.
## ماسک تصویری `clip_mask` (ابزار: tools/panel_extract.py).
static func clip_mask_path(room: String, mask: String) -> String:
	return "res://rooms/masks/%s/%s.png" % [room, mask]


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
			"arc_pop": _add(_make_arc(e), e)
			"neon_buzz": _add(_make_neon(e), e)
			"laser_hum": _add(_make_laser(e), e)
			"led_blink": _add(_make_leds(e), e)
			_: push_warning("RoomEffects: نوع ناشناختهٔ «%s»" % e.get("type", ""))


func _add(n: Node2D, e: Dictionary) -> void:
	if n == null:
		return
	n.name = "Fx_%s" % String(e.get("id", "x"))
	n.add_to_group(GROUP)
	add_child(n)


func _tex(rel: String) -> Texture2D:
	var tex: Texture2D = AssetPath.texture(rel)
	if tex == null and rel not in missing:
		missing.append(rel)
	return tex


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
	var cm := String(e.get("clip_mask", ""))
	if cm != "":
		var mp := clip_mask_path(room_id, cm)
		var mt: Texture2D = AssetPath.texture(mp)
		if mt != null:
			mat.set_shader_parameter("use_clip_tex", true)
			mat.set_shader_parameter("clip_tex", mt)
			mat.set_shader_parameter("space", SPACE)
		elif mp not in missing:
			# نبودن ماسک یعنی نور روی کف تاریک هم می‌افتد؛ گزارش می‌شود
			missing.append(mp)
	spr.material = mat

	var kind := String(e.get("type", ""))
	# `glow_pulse` پیش‌فرض یک سینوس آرام است، ولی نقشه می‌تواند
	# `signal: noise_lowpass` بخواهد — برای شکاف و دروازه‌ای که نفس
	# می‌کشد ولی دوره ندارد.
	var sig := String(e.get("signal", ""))
	_glow_nodes.append({
		"node": spr, "mat": mat, "id": String(e.get("id", "")),
		"amp": float(e.get("amp", 0.08)), "base": base, "rgb": c,
		"pulse": kind == "glow_pulse" and sig != "noise_lowpass",
		"lowpass": sig == "noise_lowpass",
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
	# رنگ اختیاری: بعضی حلقه‌ها رنگ خودشان را دارند و در اتاقی با پالت
	# دیگر غریبه می‌شوند. در R1e دودِ بنفش روی بخار آبیِ **نقاشی‌شده**
	# می‌نشست و لکهٔ صورتی دیده می‌شد. نقشه می‌تواند `color` بدهد.
	var tc := String(e.get("color", ""))
	if tc.begins_with("#"):
		spr.modulate = Color(tc)
	spr.modulate.a *= float(e.get("alpha", 1.0))
	spr.play("default")
	if bool(e.get("random_start", false)):
		spr.frame = randi() % maxi(1, n)
	return spr


# ------------------------------------------------- جرقه و نئون و لیزر

## جرقهٔ تصادفی سر کویل یا تیر برق: بیشتر وقت‌ها **هیچ** و هر چند ثانیه
## یک بار یک برقِ ۶۰ تا ۱۴۰ میلی‌ثانیه‌ای.
##
## فاصلهٔ بعدی هر بار از نو قرعه می‌خورد؛ فاصلهٔ ثابت یعنی ریتم، و ریتم
## یعنی «افکت» دیده می‌شود نه برق.
func _make_arc(e: Dictionary) -> Node2D:
	var n := _make_glow(e)
	if n == null:
		return null
	# از فهرست نورهای تیک‌خور برداشته می‌شود: روشنایی‌اش را خودش می‌برد
	_glow_nodes.pop_back()
	var iv: Array = e.get("interval_s", [2.0, 6.0])
	var du: Array = e.get("dur_ms", [60, 140])
	var c := color_of(e, Color(0.48, 0.91, 1.0))
	_burst_nodes.append({
		"mat": n.material, "rgb": c, "base": 0.55,
		"min_gap": float(iv[0]), "max_gap": float(iv[iv.size() - 1]),
		"min_dur": float(du[0]) / 1000.0, "max_dur": float(du[du.size() - 1]) / 1000.0,
		"next": randf_range(float(iv[0]), float(iv[iv.size() - 1])),
		"until": -1.0, "idle": 0.0,
	})
	# اسپرایت جرقه، فقط در همان لحظه
	var spark := _tex(_sprite_of(e, "overlays/particles/spark_2.png"))
	if spark != null:
		var s2 := Sprite2D.new()
		s2.texture = spark
		s2.centered = true
		s2.position = n.position
		s2.scale = Vector2.ONE * 0.5
		s2.modulate = Color(c.r, c.g, c.b, 0.0)
		s2.material = _additive()
		s2.z_index = 5
		n.add_child(s2)
		_burst_nodes[-1]["spark"] = s2
	return n


## نئون **روشن و ثابت** است. فقط هر ۸ تا ۲۰ ثانیه یک لرزش ۹۰ تا ۱۸۰
## میلی‌ثانیه‌ای دارد. چشمک مداوم، که اولین کاری است که آدم می‌کند،
## دقیقاً چیزی است که سند ۱۴ بند ۶ ممنوع کرده.
func _make_neon(e: Dictionary) -> Node2D:
	var n := _make_glow(e)
	if n == null:
		return null
	_glow_nodes.pop_back()
	var iv: Array = e.get("interval_s", [8.0, 20.0])
	var du: Array = e.get("dur_ms", [90, 180])
	var c := color_of(e, Color(1.0, 0.23, 0.66))
	_burst_nodes.append({
		"mat": n.material, "rgb": c, "base": 0.16,
		"min_gap": float(iv[0]), "max_gap": float(iv[iv.size() - 1]),
		"min_dur": float(du[0]) / 1000.0, "max_dur": float(du[du.size() - 1]) / 1000.0,
		"next": randf_range(float(iv[0]), float(iv[iv.size() - 1])),
		"until": -1.0,
		# بین لرزش‌ها خاموش نیست، **ثابت روشن** است
		"idle": 1.0, "amp": float(e.get("amp", 0.25)),
	})
	return n


## پرتوهای لیزر: نبض ریز ±۵٪ روی شدتشان. **هرگز محو نمی‌شوند** — خطر
## بصری است و بازیکن باید همیشه ببیندش (نقشهٔ C2 هم همین را می‌گوید).
func _make_laser(e: Dictionary) -> Node2D:
	var holder := Node2D.new()
	var xr: Array = e.get("x_range", [0, 100])
	var c := color_of(e, Color(1.0, 0.23, 0.23))
	var lines: Array = e.get("lines_y", [])
	for y in lines:
		var line := Sprite2D.new()
		line.texture = _white()
		line.centered = false
		line.position = Vector2(float(xr[0]), float(y) - 1.0)
		line.scale = Vector2(float(xr[1]) - float(xr[0]), 2.0)
		line.modulate = Color(c.r, c.g, c.b, 0.55)
		line.material = _additive()
		line.z_index = 5
		holder.add_child(line)
	if holder.get_child_count() == 0:
		holder.free()
		return null
	_laser_nodes.append({
		"node": holder, "amp": float(e.get("amp", 0.05)),
		"id": String(e.get("id", "laser")), "off": {},
		"lines": holder.get_child_count(),
	})
	return holder


## چراغ‌های ریز رک سرور: نقطه‌های ۲ پیکسلی که هر کدام ریتم خودش را دارد.
func _make_leds(e: Dictionary) -> Node2D:
	var holder := Node2D.new()
	var c := color_of(e, Color(0.23, 1.0, 0.78))
	var sz := float(e.get("size_px", 2))
	var per := int(e.get("count_per_box", 6))
	var iv: Array = e.get("interval_s", [0.6, 3.5])
	for raw in e.get("boxes", []):
		var r := corners(raw)
		if r.size == Vector2.ZERO:
			continue
		for i in per:
			var dot := Sprite2D.new()
			dot.texture = _white()
			dot.centered = true
			dot.position = Vector2(randf_range(r.position.x, r.end.x),
				randf_range(r.position.y, r.end.y))
			dot.scale = Vector2.ONE * sz
			dot.modulate = Color(c.r, c.g, c.b, 0.9)
			dot.material = _additive()
			dot.z_index = 5
			holder.add_child(dot)
			_led_nodes.append({
				"node": dot,
				"next": randf_range(float(iv[0]), float(iv[iv.size() - 1])),
				"min_gap": float(iv[0]), "max_gap": float(iv[iv.size() - 1]),
				"on": true,
			})
	if holder.get_child_count() == 0:
		holder.free()
		return null
	return holder


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
		if bool(g.get("lowpass", false)):
			# نویز هموار بدون دوره: «نفس» می‌کشد ولی ریتم ندارد
			v = 1.0 + float(g["amp"]) * _noise(id)
		elif bool(g["pulse"]):
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

	_tick_bursts()
	_tick_lasers()
	_tick_leds(delta)

	for f in _fog_nodes:
		var off: Vector2 = f["vel"] * _t
		(f["mat"] as ShaderMaterial).set_shader_parameter("offset_a", off)
		# لایهٔ دوم کندتر و با زاویهٔ کمی متفاوت
		(f["mat"] as ShaderMaterial).set_shader_parameter("offset_b",
			off.rotated(0.4) * -0.55)


## جرقه و نئون: روشنایی بیشتر وقت‌ها روی `idle` است و فقط در پنجرهٔ
## لرزش بالا می‌رود. فاصلهٔ بعدی هر بار از نو قرعه می‌خورد.
func _tick_bursts() -> void:
	for b in _burst_nodes:
		var firing: bool = _t < float(b["until"])
		if not firing and _t >= float(b["next"]):
			var dur: float = randf_range(float(b["min_dur"]), float(b["max_dur"]))
			b["until"] = _t + dur
			b["next"] = _t + dur + randf_range(float(b["min_gap"]), float(b["max_gap"]))
			firing = true
		var c: Color = b["rgb"]
		var base: float = float(b["base"])
		# نئون بین لرزش‌ها ثابت روشن است؛ جرقه بین پرش‌ها خاموش
		var level: float = float(b.get("idle", 0.0))
		if firing:
			level = 1.0 + float(b.get("amp", 0.0))
		(b["mat"] as ShaderMaterial).set_shader_parameter("tint",
			Vector4(c.r, c.g, c.b, base * level))
		if b.has("spark"):
			(b["spark"] as Sprite2D).modulate.a = 0.85 if firing else 0.0


## نبض ریز روی پرتو لیزر. کف ۰٫۸ است: پرتو **هرگز** محو نمی‌شود، چون
## خطر بصری است و بازیکن باید همیشه ببیندش.
func _tick_lasers() -> void:
	for l in _laser_nodes:
		var v: float = 1.0 + float(l["amp"]) * _noise(String(l["id"]))
		var a: float = clampf(0.55 * v, 0.44, 0.66)
		var off: Dictionary = l["off"]
		var kids: Array = (l["node"] as Node2D).get_children()
		for i in kids.size():
			# نوار تیره و خط فیروزهٔ پرتوهای خاموش بعد از خطوط اصلی
			# اضافه شده‌اند؛ نبض فقط به خطوط اصلی می‌خورد.
			if i >= _laser_line_count(l) or off.has(i):
				continue
			(kids[i] as Sprite2D).modulate.a = a


## پرتوی خاموش‌شده با هک. **محو نمی‌شود** — نقشهٔ افکت می‌گوید خطر بصری
## ثابت می‌ماند — ولی کم‌رنگ و فیروزه‌ای می‌شود تا بازیکن ببیند دیگر
## نمی‌زند. نگاشت نام به خط از ترتیب است: `beam_N` یعنی N اُمین عدد در
## `lines_y`، و همان ترتیب در `hazard`های اتاق هم هست.
## چند خط **اصلی** این افکت است (بدون نوارهای خاموشی که بعداً اضافه شده‌اند).
func _laser_line_count(l: Dictionary) -> int:
	return int(l.get("lines", (l["node"] as Node2D).get_child_count()))


func set_offline(ids: Array) -> void:
	for l in _laser_nodes:
		var kids: Array = (l["node"] as Node2D).get_children()
		for raw in ids:
			var name := String(raw)
			if not name.begins_with("beam_"):
				continue
			var idx := int(name.substr(5)) - 1
			if idx < 0 or idx >= kids.size():
				continue
			if (l["off"] as Dictionary).has(idx):
				continue
			(l["off"] as Dictionary)[idx] = true
			var sp := kids[idx] as Sprite2D
			sp.modulate.a = 0.0
			# **خود پرتو در نقاشی است، نه در این لایه.** کم کردن آلفای
			# خط افکت هیچ تغییری نمی‌دهد — در عکس گام ۵۷ دیده شد: پرتو
			# قرمز ماند و بازیکن جلوی چیزی می‌ایستاد که دیگر نمی‌زد.
			# پس یک نوار تیره روی پیکسل‌های نقاشی کشیده می‌شود تا قرمز
			# خاموش دیده شود، و یک خط نازک فیروزه‌ای رویش: «بود، و حالا
			# قطع است». محو نمی‌شود، رنگ عوض می‌کند.
			var holder := l["node"] as Node2D
			var dark := Sprite2D.new()
			dark.texture = _white()
			dark.centered = false
			dark.position = Vector2(sp.position.x, sp.position.y - 4.0)
			dark.scale = Vector2(sp.scale.x, 11.0)
			dark.modulate = Color(0.06, 0.07, 0.10, 0.58)
			dark.z_index = 6
			holder.add_child(dark)
			var teal := Sprite2D.new()
			teal.texture = _white()
			teal.centered = false
			teal.position = Vector2(sp.position.x, sp.position.y)
			teal.scale = Vector2(sp.scale.x, 2.0)
			teal.modulate = Color(0.35, 1.0, 0.85, 0.5)
			teal.material = _additive()
			teal.z_index = 7
			holder.add_child(teal)


func _tick_leds(_delta: float) -> void:
	for d in _led_nodes:
		if _t < float(d["next"]):
			continue
		d["on"] = not bool(d["on"])
		d["next"] = _t + randf_range(float(d["min_gap"]), float(d["max_gap"]))
		(d["node"] as Sprite2D).modulate.a = 0.9 if bool(d["on"]) else 0.12


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
