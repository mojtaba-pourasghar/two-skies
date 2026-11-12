## پردهٔ شکست — سند ۱۷ بند ۱۲
##
## «از نو»، نه «باختی». پس‌زمینهٔ نقاشی `ui/menu/defeat_bg`، عنوان آرام
## کهربایی، و سه راه: تلاش دوباره (فوری)، برگشت به آخرین ذخیره، منو.
## **هیچ سرزنشی** — نه عدد مرگ بزرگ، نه رنگ قرمز تند.
class_name DefeatScreen
extends CanvasLayer

signal chose(id: String)

var _picked: String = ""


func _init() -> void:
	layer = 94
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var root := UiKit.themed_root()
	add_child(root)

	var art := TextureRect.new()
	art.texture = UiKit.tex("ui/menu/defeat_bg.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.anchor_right = 1.0
	art.anchor_bottom = 1.0
	root.add_child(art)
	root.add_child(UiKit.dim(0.42))

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	v.anchor_left = 0.5
	v.anchor_right = 0.5
	v.anchor_top = 0.5
	v.anchor_bottom = 0.5
	v.offset_left = -240
	v.offset_right = 240
	v.offset_top = -200
	v.offset_bottom = 220
	root.add_child(v)

	var t := UiKit.label(Fa.t("ui_defeat"), "Title", HORIZONTAL_ALIGNMENT_CENTER)
	t.add_theme_font_size_override("font_size", 64)
	t.add_theme_color_override("font_color", Color("#FFB07A"))
	v.add_child(t)
	var d := TextureRect.new()
	d.texture = UiKit.ornament("divider_ornate")
	d.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	d.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	d.custom_minimum_size = Vector2(0, 30)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(d)
	v.add_child(UIKit.make_spacer(10))

	for spec in [["ui_retry", "Gold"], ["ui_last_save", ""], ["ui_to_menu", ""]]:
		var b := UiKit.button(String(spec[0]), String(spec[1]), Vector2(320, 68))
		b.pressed.connect(func(): choose(String(spec[0])))
		v.add_child(b)
	UiKit.slide_in(v, Vector2(0, 26))


func choose(id: String) -> void:
	if _picked != "":
		return
	_picked = id
	Audio.play_sfx("ui_sfx_confirm", "UI")
	chose.emit(id)
	match id:
		"ui_to_menu":
			SceneRouter.goto("main_menu", false)
		"ui_last_save":
			GameState.load_game()
			SceneRouter.goto("game", false)
		_:
			SceneRouter.reload_current()
