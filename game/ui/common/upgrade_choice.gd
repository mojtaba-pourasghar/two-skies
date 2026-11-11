## صفحهٔ انتخاب ارتقا پس از اوج فصل (سند ۱۲ §۲، M5-ج)
##
## سه گزینه، یکی برداشته می‌شود و در `GameState.data["upgrades"]` می‌ماند.
## هنر از `ui/upgrade_choice/` می‌آید (دستهٔ تحویلی مدیر هنر).
##
## **چیدمان راست‌به‌چپ:** مثل جعبهٔ گفت‌وگو، مختصات مطلق در این پروژه
## آینه می‌شود؛ پس همه‌چیز با لنگر قرینه چیده شده است.
class_name UpgradeChoice
extends CanvasLayer

signal picked(id: String)

const CHOICES := [
	{"id": "heart", "icon": "icon_heart", "name": "up_heart", "desc": "up_heart_desc"},
	{"id": "chip", "icon": "icon_chip", "name": "up_chip", "desc": "up_chip_desc"},
	{"id": "boot", "icon": "icon_boot", "name": "up_boot", "desc": "up_boot_desc"},
]

var _chosen: String = ""
var _buttons: Array[Button] = []


func _init() -> void:
	layer = 90
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	add_child(root)

	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.05, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.anchor_right = 1.0
	dim.anchor_bottom = 1.0
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var title := Label.new()
	title.text = Fa.t("upgrade_title")
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.anchor_right = 1.0
	title.offset_top = 60
	title.offset_bottom = 104
	root.add_child(title)

	# **پنل یک‌بار، نه سه‌بار.** `upgrade_panel.png` خودش قاب سه‌خانه است؛
	# اولین‌بار آن را پس‌زمینهٔ هر کارت گذاشتم و سه قاب سه‌خانه کنار هم
	# درآمد. در عکس دیده شد.
	var panel := TextureRect.new()
	panel.texture = AssetPath.texture("ui/upgrade_choice/upgrade_panel.png")
	panel.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	panel.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	panel.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 0.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 110
	panel.offset_right = -110
	panel.offset_top = 150
	panel.offset_bottom = -90
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 38)
	row.set_anchors_preset(Control.PRESET_CENTER)
	row.anchor_left = 0.0
	row.anchor_right = 1.0
	row.anchor_top = 0.0
	row.anchor_bottom = 1.0
	# روی **خانه‌های خود قاب** می‌نشیند، نه وسط صفحه: جای خانه‌ها از
	# رندر خود پنل اندازه گرفته شد (x تقریبی ۳۵۰، ۵۵۵، ۷۶۰).
	row.offset_left = 345
	row.offset_right = -345
	row.offset_top = 330
	row.offset_bottom = -135
	root.add_child(row)

	for c in CHOICES:
		row.add_child(_make_card(c))
	if not _buttons.is_empty():
		_buttons[0].grab_focus()


func _make_card(c: Dictionary) -> Control:
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(168, 240)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 6)

	var icon := TextureRect.new()
	icon.texture = AssetPath.texture("ui/upgrade_choice/%s.png" % String(c["icon"]))
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	icon.custom_minimum_size = Vector2(160, 74)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(icon)

	var name_label := Label.new()
	name_label.text = Fa.t(String(c["name"]))
	name_label.add_theme_font_size_override("font_size", 19)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(name_label)

	var desc := Label.new()
	desc.text = Fa.t(String(c["desc"]))
	desc.add_theme_font_size_override("font_size", 14)
	desc.add_theme_color_override("font_color", Color(0.78, 0.85, 0.95))
	desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(160, 36)
	box.add_child(desc)

	var btn := Button.new()
	btn.text = Fa.t("upgrade_hint")
	btn.custom_minimum_size = Vector2(150, 40)
	btn.pressed.connect(func(): choose(String(c["id"])))
	box.add_child(btn)
	_buttons.append(btn)
	return box


## انتخاب — هم از دکمه و هم از آزمون صدا زده می‌شود.
func choose(id: String) -> void:
	if _chosen != "":
		return
	_chosen = id
	var ups: Array = GameState.data.get("upgrades", [])
	if id not in ups:
		ups.append(id)
	GameState.data["upgrades"] = ups
	GameState.save_game()
	Audio.play_sfx("ui_sfx_level_up", "UI")
	picked.emit(id)


## تا انتخاب شدن صبر می‌کند و شناسه را برمی‌گرداند.
func pick() -> String:
	var before := GameMode.control
	GameMode.set_control(GameMode.ControlMode.MENU)
	if _chosen == "":
		await picked
	GameMode.set_control(before)
	return _chosen
