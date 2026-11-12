## پردهٔ پایان فصل — بازسازی گام ۵۹ (سند ۱۶ و ۱۷ بند ۱۱)
##
## نسخهٔ قبلی دو مستطیل خاکستری روی پس‌زمینهٔ سیاه بود. حالا:
## پس‌زمینهٔ نقاشی با تیرگی، `panel_xl` قاب، `emblem_large` بالا،
## `wreath_arc` دور عنوان، `divider_ornate` زیر آن، آمار بازی، و دو
## دکمهٔ قاب‌دار که یکی‌شان طلایی است.
class_name ChapterEnd
extends CanvasLayer

signal chose(id: String)

var _picked: String = ""


func _init() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var root := UiKit.themed_root()
	add_child(root)

	var art := TextureRect.new()
	art.texture = UiKit.tex("scenes/ch1/launch_platform_1280x720.png")
	if art.texture == null:
		art.texture = UiKit.tex("ui/menu/menu_two_skies.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full(art)
	root.add_child(art)
	root.add_child(UiKit.dim(0.52))

	var frame := UiKit.panel("panel_xl")
	frame.anchor_right = 1.0
	frame.anchor_bottom = 1.0
	frame.offset_left = 150
	frame.offset_right = -150
	frame.offset_top = 48
	frame.offset_bottom = -48
	root.add_child(frame)

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	v.anchor_right = 1.0
	v.anchor_bottom = 1.0
	v.offset_left = 70
	v.offset_right = -70
	v.offset_top = 56
	v.offset_bottom = -44
	frame.add_child(v)

	# تاج دور عنوان: نشان بزرگ روی کمان
	var crown := Control.new()
	crown.custom_minimum_size = Vector2(0, 150)
	var wreath := TextureRect.new()
	wreath.texture = UiKit.ornament("wreath_arc")
	wreath.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	wreath.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	wreath.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_full(wreath)
	crown.add_child(wreath)
	var em := TextureRect.new()
	em.texture = UiKit.ornament("emblem_large")
	em.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	em.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	em.mouse_filter = Control.MOUSE_FILTER_IGNORE
	em.anchor_left = 0.5
	em.anchor_right = 0.5
	em.anchor_top = 0.0
	em.anchor_bottom = 1.0
	em.offset_left = -62
	em.offset_right = 62
	em.offset_top = 6
	em.offset_bottom = -12
	crown.add_child(em)
	v.add_child(crown)

	v.add_child(UiKit.label(Fa.t("ui_chapter_end"), "Title",
			HORIZONTAL_ALIGNMENT_CENTER))
	var sub := UiKit.label(Fa.t("c1_end_03"), "Name", HORIZONTAL_ALIGNMENT_CENTER)
	v.add_child(sub)
	var d := TextureRect.new()
	d.texture = UiKit.ornament("divider_ornate")
	d.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	d.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	d.custom_minimum_size = Vector2(0, 30)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(d)

	v.add_child(_stats())
	v.add_child(UIKit.make_spacer(10))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 30)
	var go := UiKit.button("ui_continue_ch2", "Gold", Vector2(300, 70))
	go.pressed.connect(func(): choose("continue"))
	var menu := UiKit.button("ui_back_menu", "", Vector2(300, 70))
	menu.pressed.connect(func(): choose("menu"))
	row.add_child(go)
	row.add_child(menu)
	v.add_child(row)
	go.grab_focus()
	UiKit.slide_in(frame, Vector2(0, 30))


## آمار فصل: زمان، مرگ، اقلام.
func _stats() -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 42)
	var secs := int(GameState.data.get("playtime_s", 0))
	var items := 0
	for k in (GameState.data.get("flags", {}) as Dictionary).keys():
		if String(k).begins_with("got_"):
			items += 1
	for spec in [["heart", Fa.t("ui_playtime"), "%s:%s" % [
				Fa.num(secs / 60), Fa.num(secs % 60).pad_zeros(2)]],
			["sword", Fa.t("ui_deaths_count"),
				Fa.num(int(GameState.run.get("deaths", 0)))],
			["backpack", Fa.t("ui_items_found"), Fa.num(items)]]:
		var cell := VBoxContainer.new()
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		var ic := TextureRect.new()
		ic.texture = UiKit.icon(String(spec[0]))
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.custom_minimum_size = Vector2(44, 44)
		cell.add_child(ic)
		cell.add_child(UiKit.label(String(spec[1]), "Tiny", HORIZONTAL_ALIGNMENT_CENTER))
		cell.add_child(UiKit.label(String(spec[2]), "Hud", HORIZONTAL_ALIGNMENT_CENTER))
		row.add_child(cell)
	return row


func choose(id: String) -> void:
	if _picked != "":
		return
	_picked = id
	Audio.play_sfx("ui_sfx_confirm", "UI")
	GameState.set_flag("ch1_done", true)
	GameState.save_game()
	chose.emit(id)
	# فصل ۲ هنوز نیست؛ هر دو راه به منو می‌روند و این **عمدی** است.
	SceneRouter.goto("main_menu", false)


func wait_choice() -> String:
	var before := GameMode.control
	GameMode.set_control(GameMode.ControlMode.MENU)
	if _picked == "":
		await chose
	GameMode.set_control(before)
	return _picked


func _full(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = 0
	c.offset_right = 0
	c.offset_top = 0
	c.offset_bottom = 0
