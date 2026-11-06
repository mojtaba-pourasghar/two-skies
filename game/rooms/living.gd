## بودجهٔ زندگی اتاق — سند ۱۳ (هنر) و سند ۱۳ دوربین (موتور)
##
## «هیچ پس‌زمینهٔ مرده‌ای نداریم.» این کلاس همهٔ منبع‌های حرکت یک اتاق را
## می‌سازد و **همه را در گروه `LivingLayer`** می‌گذارد، تا سنجهٔ پذیرش
## بتواند بشمارد نه حدس بزند.
##
## پنج منبع:
##   ۱ anim    انیمیشن حلقه‌ای از `ambient/ch1/<نام>/` (شمع، فانوس، پرده…)
##   ۲ sway    تکان یک **بریده از خود نقاشی** با شیدر وزن‌دار (ریشه ثابت)
##   ۳ water   جابه‌جایی UV روی بریدهٔ آب
##   ۴ fog     دو لایهٔ مه رانشی
##   ۵ pulse   نور نبض‌دار ۲ هرتز با فاز تصادفی، مد Add
##
## ذره‌ها جدا در `PaintedRoom` ساخته می‌شوند چون گره‌شان GPUParticles2D است
## و عمر و شکلشان به نوع اتاق بستگی دارد.
class_name LivingScene
extends RefCounted

const ASSETS := "res://assets/"
const GROUP := "LivingLayer"

## «نور زنده: ۲ هرتز، دامنهٔ ±۱۵٪، فازهای تصادفی» (سند ۱۳ بند ۲).
const PULSE_HZ: float = 2.0
const PULSE_AMP: float = 0.15

## انیمیشن‌های تحویل‌شده همه ۶ فریم و ۸ فریم بر ثانیه‌اند (گام ۴۹).
const ANIM_FRAMES: int = 6
const ANIM_FPS: float = 8.0

## چه انیمیشن‌هایی در `ambient/ch1/` هست. نئون هنوز نیامده (گام ۴۹).
const KINDS := ["candle", "lantern", "curtain", "smoke", "drip",
	"plant", "vines", "moth", "drone", "water"]

var missing: Array[String] = []


func _tex(rel: String) -> Texture2D:
	var p := ASSETS + rel
	if not ResourceLoader.exists(p):
		if rel not in missing:
			missing.append(rel)
		return null
	return load(p)


func _live(n: Node) -> Node:
	n.add_to_group(GROUP)
	return n


# ---------------------------------------------------------------- انیمیشن

## یک حلقهٔ محیطی روی جای نقاشی‌شده‌اش. لنگر **پایین-وسط** است (asset.json)،
## پس `at` پای شیء است نه گوشه‌اش: شمع روی میز، گیاه روی زمین.
func make_anim(d: Dictionary) -> Node2D:
	var kind := String(d.get("kind", ""))
	if kind not in KINDS:
		push_warning("LivingScene: انیمیشن «%s» در ambient/ch1 نیست." % kind)
		return null
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", float(d.get("fps", ANIM_FPS)))
	frames.set_animation_loop("default", true)
	var n := int(d.get("frames", ANIM_FRAMES))
	for i in n:
		var tex := _tex("ambient/ch1/%s/%s_%d.png" % [kind, kind, i])
		if tex == null:
			return null
		frames.add_frame("default", tex)

	var spr := AnimatedSprite2D.new()
	spr.name = "Anim_%s" % String(d.get("id", kind))
	spr.sprite_frames = frames
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.centered = false
	var at: Array = d.get("at", [0, 0])
	var size := frames.get_frame_texture("default", 0).get_size()
	var sc := float(d.get("scale", 1.0))
	var flip := bool(d.get("flip", false))
	spr.scale = Vector2(-sc if flip else sc, sc)
	# لنگر پایین-وسط (asset.json): `at` پای شیء است. با آینه‌کردن، گره از
	# موقعیتش به **چپ** کشیده می‌شود، پس نیم‌عرض باید اضافه شود نه کم —
	# وگرنه پردهٔ آینه‌شده یک عرض کامل جابه‌جا می‌نشیند.
	var half: float = size.x * sc * 0.5
	spr.position = Vector2(float(at[0]) + (half if flip else -half),
		float(at[1]) - size.y * sc)
	spr.modulate.a = float(d.get("alpha", 1.0))
	spr.z_index = int(d.get("z", 1))
	# هر حلقه فاز خودش را دارد، وگرنه دو شمع کنار هم مثل ساعت با هم
	# می‌سوزند و مصنوعی دیده می‌شوند
	spr.play("default")
	spr.frame = int(d.get("phase_frame", randi() % maxi(1, n)))
	return _live(spr) as Node2D



## بریده را در مختصات نرمال‌شدهٔ بافت به شیدر می‌دهد و رنگ را صریح.
func _set_region_uniforms(mat: ShaderMaterial, tex: Texture2D, rect: Rect2,
		color: Color) -> void:
	var size := tex.get_size()
	mat.set_shader_parameter("region_px", rect.size)
	mat.set_shader_parameter("uv_rect", Vector4(
		rect.position.x / size.x, rect.position.y / size.y,
		rect.size.x / size.x, rect.size.y / size.y))
	mat.set_shader_parameter("tint", Vector4(color.r, color.g, color.b, color.a))

# ------------------------------------------------------------------ تکان

## یک بریده از **خود نقاشی** که با شیدر وزن‌دار تکان می‌خورد. هنر تازه‌ای
## لازم ندارد: ناحیه از تصویر اتاق بریده می‌شود.
func make_sway(bg: Texture2D, d: Dictionary) -> Node2D:
	if bg == null:
		return null
	var r: Array = d.get("rect", [])
	if r.size() != 4:
		push_warning("LivingScene: تکان بدون ناحیه رد شد.")
		return null
	var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	var spr := Sprite2D.new()
	spr.name = "Sway_%s" % String(d.get("id", "x"))
	spr.texture = bg
	spr.region_enabled = true
	spr.region_rect = rect
	spr.centered = false
	spr.position = rect.position
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.z_index = int(d.get("z", 1))

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/sway.gdshader")
	mat.set_shader_parameter("amplitude", float(d.get("amplitude", 2.0)))
	mat.set_shader_parameter("speed", float(d.get("speed", 1.1)))
	mat.set_shader_parameter("phase", float(d.get("phase", randf() * TAU)))
	_set_region_uniforms(mat, bg, rect, Color(1, 1, 1, float(d.get("alpha", 1.0))))
	# پرده از میله آویزان است، برگ از ریشه بالا می‌آید
	mat.set_shader_parameter("root_top", 1 if bool(d.get("root_top", false)) else 0)
	# `push` باید از همان اول مقدار داشته باشد. اگر تنظیم نشود،
	# `get_shader_parameter` نول می‌دهد و اولین واکنش به عبور بازیکن
	# با خطای سازندهٔ float می‌افتد — یعنی دقیقاً وقتی لازم است.
	mat.set_shader_parameter("push", 0.0)
	spr.material = mat
	return _live(spr) as Node2D


func make_water(bg: Texture2D, d: Dictionary) -> Node2D:
	if bg == null:
		return null
	var r: Array = d.get("rect", [])
	if r.size() != 4:
		return null
	var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	var spr := Sprite2D.new()
	spr.name = "Water_%s" % String(d.get("id", "x"))
	spr.texture = bg
	spr.region_enabled = true
	spr.region_rect = rect
	spr.centered = false
	spr.position = rect.position
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.z_index = int(d.get("z", 1))
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")
	mat.set_shader_parameter("amp_px", float(d.get("amplitude", 1.6)))
	mat.set_shader_parameter("speed", float(d.get("speed", 0.6)))
	_set_region_uniforms(mat, bg, rect, Color(1, 1, 1, float(d.get("alpha", 1.0))))
	spr.material = mat
	return _live(spr) as Node2D


# -------------------------------------------------------------------- مه

## «۲ لایه با سرعت متفاوت» — خود شیدر دو لایه است، و اتاق **دو نمونه**
## با سرعت و ارتفاع متفاوت می‌گذارد. یک لایه مه نیست، نوار است.
func make_fog(d: Dictionary) -> Node2D:
	var tex := _tex(String(d.get("img", "overlays/particles/fog_0.png")))
	if tex == null:
		return null
	var r: Array = d.get("rect", [])
	if r.size() != 4:
		return null
	var rect := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
	var spr := Sprite2D.new()
	spr.name = "Fog_%s" % String(d.get("id", "x"))
	spr.texture = tex
	spr.centered = false
	spr.position = rect.position
	# کشیده می‌شود تا ناحیه را بپوشاند؛ شیدر داخلش را می‌چرخاند
	spr.scale = rect.size / tex.get_size()
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	# **رنگ لازم است، نه فقط آلفا.** بافت‌های `overlays/particles/fog_*`
	# لکه‌های فیروزه‌ای ذره‌اند، نه ورقهٔ مه. کشیدنشان روی اتاق با رنگ
	# خودشان، دود سبزآبی درخشان می‌دهد که نقاشی گرم اتاق را می‌خورد —
	# در اولین ضبط R1a دقیقاً همین شد و سنجهٔ عددی هم سبز بود.
	# پس رنگ از داده می‌آید و پیش‌فرضش خاکستری گرم کم‌جان است.
	# (REQ-022: ورقهٔ مه واقعی و تکرارشونده.)
	var c: Array = d.get("color", [0.82, 0.78, 0.72])
	var fog_tint := Color(float(c[0]), float(c[1]), float(c[2]),
		float(d.get("alpha", 0.06)))
	spr.z_index = int(d.get("z", 5))
	# یک گره فقط **یک** material دارد، و مد ترکیب و شیدر هر دو همان‌جا
	# می‌نشینند. پس دو نسخه از شیدر هست: `fog_drift` (mix، برای مه سرد
	# که باید پشتش دیده شود) و `fog_drift_add` (برای دود روشن و بخار که
	# نور می‌دهد). `add` در داده انتخابش می‌کند.
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/fog_drift_add.gdshader" if bool(d.get("add", false))
		else "res://shaders/fog_drift.gdshader")
	mat.set_shader_parameter("speed_a", float(d.get("speed", 0.012)))
	mat.set_shader_parameter("speed_b", -float(d.get("speed", 0.012)) * 0.6)
	mat.set_shader_parameter("scale_b", float(d.get("scale_b", 1.7)))
	mat.set_shader_parameter("tint",
		Vector4(fog_tint.r, fog_tint.g, fog_tint.b, fog_tint.a))
	spr.material = mat
	return _live(spr) as Node2D


# -------------------------------------------------------------- نور نبض

## نور نقاشی‌شده نبض می‌گیرد: ۲ هرتز، ±۱۵٪، فاز تصادفی، مد Add.
## سه سطح روشنایی تحویل شده (`_0.._2`)؛ سطح میانه پایه است و آلفا نوسان
## می‌کند. سطح‌ها اندازه‌های متفاوت دارند، پس وسط‌چین می‌نشینند وگرنه با
## عوض شدن سطح، هاله می‌پرد.
func make_pulse(d: Dictionary) -> Node2D:
	var kind := String(d.get("kind", "lamp_pulse"))
	var level := int(d.get("level", 1))
	var tex := _tex("overlays/lights/%s_%d.png" % [kind, level])
	if tex == null:
		return null
	var at: Array = d.get("at", [0, 0])
	var spr := Sprite2D.new()
	spr.name = "Pulse_%s" % String(d.get("id", kind))
	spr.texture = tex
	spr.centered = true
	spr.position = Vector2(float(at[0]), float(at[1]))
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	spr.z_index = int(d.get("z", 5))
	var base := float(d.get("alpha", 0.35))
	spr.modulate = Color(1, 1, 1, base)
	var cm := CanvasItemMaterial.new()
	cm.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	spr.material = cm
	spr.set_meta("pulse_base", base)
	spr.set_meta("pulse_hz", float(d.get("hz", PULSE_HZ)))
	spr.set_meta("pulse_amp", float(d.get("amp", PULSE_AMP)))
	# فاز تصادفی: بدون آن همهٔ چراغ‌های اتاق با هم نبض می‌زنند و چشم
	# فوراً می‌فهمد یک تایمر است
	spr.set_meta("pulse_phase", float(d.get("phase", randf() * TAU)))
	return _live(spr) as Node2D


## نبض هر نور را یک گام جلو می‌برد. زمان از بیرون می‌آید تا همهٔ اتاق یک
## ساعت داشته باشد.
static func tick_pulse(node: Node2D, t: float) -> void:
	var base: float = float(node.get_meta("pulse_base", 0.35))
	var hz: float = float(node.get_meta("pulse_hz", PULSE_HZ))
	var amp: float = float(node.get_meta("pulse_amp", PULSE_AMP))
	var ph: float = float(node.get_meta("pulse_phase", 0.0))
	node.modulate.a = base * (1.0 + amp * sin(t * TAU * hz + ph))
