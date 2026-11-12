## وضعیت و یاران — سند ۱۷ بند ۵
##
## دو قاب پرتره (کایرو، ایلارا) با نوار جان و انرژی، ارتقاهای گرفته‌شده،
## و مهارت‌ها با آیکن. اعداد از `GameState` و `battle.json` می‌آیند.
extends Screen


func _ready() -> void:
	panel_kind = "panel_xl"
	super()


func build() -> VBoxContainer:
	var box := UIKit.make_root("ui_status")
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 26)
	row.add_child(_card("kairo"))
	row.add_child(_card("ilara"))
	box.add_child(row)

	var ups: Array = GameState.data.get("upgrades", [])
	var line := HBoxContainer.new()
	line.alignment = BoxContainer.ALIGNMENT_CENTER
	line.add_theme_constant_override("separation", 16)
	if ups.is_empty():
		line.add_child(UiKit.label(Fa.t("ui_no_items"), "Small"))
	for up in ups:
		var ic := TextureRect.new()
		ic.texture = UiKit.tex("ui/upgrade_choice/icon_%s.png" %
			{"heart": "heart", "chip": "chip", "boot": "boot"}.get(String(up), "chip"))
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.custom_minimum_size = Vector2(52, 52)
		line.add_child(ic)
		line.add_child(UiKit.label(Fa.t("up_%s" % String(up)), "Small"))
	box.add_child(line)

	var back := UiKit.button("ui_back", "", Vector2(240, 66))
	back.pressed.connect(func(): SceneRouter.back())
	var brow := UIKit.make_row()
	brow.add_child(back)
	box.add_child(brow)
	return box


func _card(who: String) -> Control:
	var holder := UiKit.panel("panel_m")
	holder.custom_minimum_size = Vector2(390, 330)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 8)
	v.anchor_right = 1.0
	v.anchor_bottom = 1.0
	v.offset_left = 44
	v.offset_right = -44
	v.offset_top = 42
	v.offset_bottom = -34
	holder.add_child(v)

	var p := TextureRect.new()
	p.texture = UiKit.tex("portraits/%s/neutral_alpha.png" % who)
	p.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	p.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	p.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	p.custom_minimum_size = Vector2(0, 150)
	v.add_child(p)
	v.add_child(UiKit.label(Fa.t("name_%s" % who), "Name",
			HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(_bar("heart", GameState.hp_percent() / 100.0 if who == "kairo" else 1.0))
	v.add_child(_bar("energy", 0.3))
	return holder


func _bar(icon_name: String, ratio: float) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var ic := TextureRect.new()
	ic.texture = UiKit.icon(icon_name)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.custom_minimum_size = Vector2(34, 34)
	row.add_child(ic)
	var back := TextureRect.new()
	back.texture = UiKit.tex("ui/kit/controls/bar_empty.png")
	back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	back.stretch_mode = TextureRect.STRETCH_SCALE
	back.custom_minimum_size = Vector2(210, 22)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var fill := TextureRect.new()
	fill.texture = UiKit.tex("ui/kit/controls/bar_fill.png")
	fill.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fill.stretch_mode = TextureRect.STRETCH_SCALE
	fill.anchor_left = 0.0
	fill.anchor_right = clampf(ratio, 0.04, 1.0)
	fill.anchor_top = 0.0
	fill.anchor_bottom = 1.0
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	back.add_child(fill)
	row.add_child(back)
	return row
