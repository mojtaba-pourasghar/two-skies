## پردهٔ پایان فصل — M5-د
##
## بعد از صحنهٔ پایانی می‌آید: «پایان فصل ۱»، و دو راه — ادامه در فصل ۲
## (هنوز ساخته نشده، پس دکمه‌اش توضیح می‌دهد و به منو برمی‌گردد) یا
## بازگشت به منو. چیدمان با لنگر قرینه است، چون پروژه راست‌به‌چپ است.
class_name ChapterEnd
extends CanvasLayer

signal chose(id: String)

var _picked: String = ""


func _init() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.01, 0.02, 0.04, 0.92)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var title := Label.new()
	title.text = Fa.t("ui_chapter_end")
	title.add_theme_font_size_override("font_size", 44)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.anchor_right = 1.0
	title.offset_top = 180
	title.offset_bottom = 240
	root.add_child(title)

	var sub := Label.new()
	sub.text = Fa.t("c1_end_03")
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.72, 0.82, 0.95))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.set_anchors_preset(Control.PRESET_TOP_WIDE)
	sub.anchor_right = 1.0
	sub.offset_top = 250
	sub.offset_bottom = 284
	root.add_child(sub)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 40)
	row.anchor_left = 0.0
	row.anchor_right = 1.0
	row.anchor_top = 0.0
	row.anchor_bottom = 1.0
	row.offset_left = 180
	row.offset_right = -180
	row.offset_top = 380
	row.offset_bottom = -180
	root.add_child(row)

	row.add_child(_button("continue", "ui_continue_ch2"))
	row.add_child(_button("menu", "ui_back_menu"))


func _button(id: String, key: String) -> Button:
	var b := Button.new()
	b.text = Fa.t(key)
	b.custom_minimum_size = Vector2(260, 64)
	b.add_theme_font_size_override("font_size", 22)
	b.pressed.connect(func(): choose(id))
	return b


func choose(id: String) -> void:
	if _picked != "":
		return
	_picked = id
	Audio.play_sfx("ui_sfx_confirm", "UI")
	GameState.set_flag("ch1_done", true)
	GameState.save_game()
	chose.emit(id)
	# فصل ۲ هنوز نیست؛ هر دو راه فعلاً به منو می‌روند و این **عمدی** است،
	# نه فراموش‌شده: دکمه هست تا مسیرش بعداً وصل شود.
	SceneRouter.goto("main_menu", false)


func wait_choice() -> String:
	var before := GameMode.control
	GameMode.set_control(GameMode.ControlMode.MENU)
	if _picked == "":
		await chose
	GameMode.set_control(before)
	return _picked
