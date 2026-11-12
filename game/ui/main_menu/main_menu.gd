## منوی اصلی — بازنویسی گام ۵۹ روی نقاشی «دو آسمان» (سند ۱۷ بند ۱)
##
## این صفحه از `Screen` ارث نمی‌برد و قاب پنل ندارد: نقاشی منو خودش
## صحنه است و پنل روی آن، آن را می‌پوشاند. به‌جایش ستون دکمه‌ها
## پایین-وسط می‌نشیند و عنوان روی ناحیهٔ تیرهٔ بالا-وسط نقاشی.
##
## **زندگی (قاعدهٔ ۹ CLAUDE.md):** پس‌زمینهٔ منو تصویر ثابت نیست —
## مه آرام روی تصویر می‌لغزد، کرم‌شب‌تاب‌های فیروزه‌ای سمت راست و
## جرقه‌های نارنجی سمت چپ نفس می‌کشند، و دوربین بسیار آهسته از ۱٫۰ تا
## ۱٫۰۴ زوم می‌کند. هیچ‌کدام چشمک‌زن یا رنگ‌چرخان نیست.
extends Control

const ZOOM_MIN := 1.0
const ZOOM_MAX := 1.04
## یک رفت‌وبرگشت زوم: آهسته‌تر از آنی که چشم «حرکت» ببیند.
const ZOOM_SECONDS := 48.0
const FOG_SPEED := 0.006
const SPARK_COUNT := 8

var _art: TextureRect
var _fog: TextureRect
var _t: float = 0.0
var _buttons: Array[Button] = []


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_right = 1.0
	anchor_bottom = 1.0
	_build_background()
	_build_title()
	_build_buttons()
	_build_version()
	Audio.play_music("music_menu")
	# ورود: محو از سیاه ۱٫۵ ثانیه (سند ۱۷)
	var fade := ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.anchor_right = 1.0
	fade.anchor_bottom = 1.0
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	create_tween().tween_property(fade, "color:a", 0.0, 1.5)


func _build_background() -> void:
	_art = TextureRect.new()
	_art.name = "MenuArt"
	_art.texture = UiKit.tex("ui/menu/menu_two_skies.png")
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.pivot_offset = Vector2(640, 360)
	_full(_art)
	add_child(_art)

	# مه: همان ورق سند ۱۴، آلفای ≤۰٫۱۲، فقط می‌لغزد
	_fog = TextureRect.new()
	_fog.name = "Fog"
	_fog.texture = UiKit.tex("overlays/fog/sheet_thin.png")
	_fog.stretch_mode = TextureRect.STRETCH_TILE
	_fog.modulate = Color(0.72, 0.84, 0.95, 0.10)
	_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full(_fog)
	if _fog.texture != null:
		add_child(_fog)

	add_child(_sparks())


## کرم‌شب‌تاب فیروزه‌ای (راست) و جرقهٔ نارنجی (چپ، کنار لوله).
func _sparks() -> Node2D:
	var holder := Node2D.new()
	holder.name = "Sparks"
	for i in SPARK_COUNT:
		var right := i % 2 == 0
		var p := GPUParticles2D.new()
		var mat := ParticleProcessMaterial.new()
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		mat.emission_box_extents = Vector3(120, 90, 0)
		mat.gravity = Vector3(0, -6 if right else -14, 0)
		mat.initial_velocity_min = 2.0
		mat.initial_velocity_max = 9.0
		# **اندازه بر حسب خود تصویر است، نه پیکسل.** `sparkle_star` یک
		# ستارهٔ ۲۵۶ پیکسلی است؛ با مقیاس ۱ تمام صفحه ستاره می‌شود —
		# در اولین عکس دقیقاً همین شد.
		mat.scale_min = 0.03
		mat.scale_max = 0.09
		mat.color = Color("#6FE6D8") if right else Color("#FF9A3A")
		p.process_material = mat
		p.amount = 5
		p.lifetime = 5.0 if right else 3.2
		p.randomness = 1.0
		p.preprocess = 3.0
		p.texture = UiKit.ornament("sparkle_star")
		p.position = Vector2(
			randf_range(980, 1230) if right else randf_range(60, 330),
			randf_range(300, 660))
		p.modulate.a = 0.34
		holder.add_child(p)
	return holder


func _build_title() -> void:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", -6)
	box.anchor_left = 0.0
	box.anchor_right = 1.0
	box.anchor_top = 0.0
	box.anchor_bottom = 0.0
	box.offset_top = 8
	box.offset_bottom = 250
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	var em := TextureRect.new()
	em.texture = UiKit.ornament("emblem_large")
	em.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	em.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	em.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	em.custom_minimum_size = Vector2(0, 118)
	em.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(em)

	var t := UiKit.label(Fa.t("game_title"), "Title", HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_font_size_override("font_size", 78)
	box.add_child(t)


func _build_buttons() -> void:
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_END
	col.add_theme_constant_override("separation", 8)
	# **ستون سمت راست، نه وسط.** سند ۱۷ «وسط-پایین» می‌گفت، ولی کایرو و
	# ایلارا دقیقاً وسط-پایین نقاشی نشسته‌اند و ستون وسط رویشان می‌افتاد
	# (در عکس دیده شد). سمت راست هم با قاعدهٔ «ستون اصلی سمت راست» در
	# همان سند می‌خواند و دو شخصیت دیده می‌مانند.
	col.anchor_left = 1.0
	col.anchor_right = 1.0
	col.anchor_top = 1.0
	col.anchor_bottom = 1.0
	col.offset_left = -376
	col.offset_right = -56
	col.offset_top = -408
	col.offset_bottom = -30
	add_child(col)

	var has_save := GameState.explore_room() != "" \
		or int(GameState.data.get("coins", 0)) > 0
	_add(col, "ui_continue", has_save, func(): _continue(), true)
	_add(col, "ui_new_game", true, func(): _new_game())
	_add(col, "ui_settings", true, func(): SceneRouter.goto("settings"))
	_add(col, "ui_about", true, func(): SceneRouter.goto("about"))
	_add(col, "ui_quit", true, func(): _quit())
	if not _buttons.is_empty():
		_buttons[0].grab_focus()


func _add(col: VBoxContainer, key: String, enabled: bool, cb: Callable,
		gold: bool = false) -> void:
	var b := UiKit.button(key, "Gold" if gold else "", Vector2(320, 62))
	b.disabled = not enabled
	b.pressed.connect(cb)
	col.add_child(b)
	_buttons.append(b)


func _build_version() -> void:
	var v := UiKit.label("v1.0 — %s" % Fa.t("ui_chapter_one"), "Tiny",
			HORIZONTAL_ALIGNMENT_LEFT)
	v.anchor_left = 0.0
	v.anchor_right = 0.0
	v.anchor_top = 1.0
	v.anchor_bottom = 1.0
	v.offset_left = 18
	v.offset_right = 320
	v.offset_top = -34
	v.offset_bottom = -8
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)


func _process(delta: float) -> void:
	_t += delta
	# زوم رفت‌وبرگشتی، بی‌پرش
	var k := 0.5 - 0.5 * cos(TAU * _t / ZOOM_SECONDS)
	var z := lerpf(ZOOM_MIN, ZOOM_MAX, k)
	if _art != null:
		_art.scale = Vector2(z, z)
		_art.position = Vector2(640, 360) * (1.0 - z)
	if _fog != null and _fog.texture != null:
		# لغزش آرام مه با جابه‌جایی ناحیهٔ کاشی
		_fog.position.x = fmod(_t * FOG_SPEED * 240.0, float(_fog.texture.get_width()))
		_fog.position.x -= float(_fog.texture.get_width())


func _continue() -> void:
	if GameState.explore_room() != "":
		SceneRouter.goto("game")
		return
	SceneRouter.goto("world_map")


func _new_game() -> void:
	SceneRouter.goto("save_select")


func _quit() -> void:
	GameState.save_game()
	get_tree().quit()


func _full(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = 0
	c.offset_right = 0
	c.offset_top = 0
	c.offset_bottom = 0
