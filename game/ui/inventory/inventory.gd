## کیف اقلام — سند ۱۷ بند ۴
##
## تب‌ها (اقلام، کلیدها، یادداشت‌ها)، شبکهٔ ۵×۴ خانه، و پنل توضیح کنار
## آن. خانه‌ها از هنر `slot_normal`/`slot_selected` می‌آیند.
##
## **داده‌اش واقعی است، نه نمایشی:** چیزهایی که بازیکن برداشته از
## پرچم‌های `got_*` و شمارندهٔ سکه و زمرد خوانده می‌شود. اگر چیزی
## برنداشته باشد، همان را می‌گوید.
extends Screen

const COLS := 5
const ROWS := 4

var _tab: String = "items"
var _detail: VBoxContainer
var _grid: GridContainer


func _ready() -> void:
	panel_kind = "panel_xl"
	super()


func build() -> VBoxContainer:
	var box := UIKit.make_root("ui_inventory")
	var tabs := HBoxContainer.new()
	tabs.alignment = BoxContainer.ALIGNMENT_CENTER
	tabs.add_theme_constant_override("separation", 10)
	for spec in [["items", "ui_inventory"], ["keys", "ui_keys"], ["notes", "ui_notes"]]:
		var b := UiKit.button(String(spec[1]), "Tab", Vector2(200, 56))
		b.pressed.connect(func():
			_tab = String(spec[0])
			_fill_grid())
		tabs.add_child(b)
	box.add_child(tabs)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL

	_grid = GridContainer.new()
	_grid.columns = COLS
	_grid.add_theme_constant_override("h_separation", 10)
	_grid.add_theme_constant_override("v_separation", 10)
	row.add_child(_grid)

	var side := UiKit.panel("panel_m")
	side.custom_minimum_size = Vector2(360, 330)
	_detail = VBoxContainer.new()
	_detail.alignment = BoxContainer.ALIGNMENT_CENTER
	_detail.add_theme_constant_override("separation", 10)
	_detail.anchor_right = 1.0
	_detail.anchor_bottom = 1.0
	_detail.offset_left = 44
	_detail.offset_right = -44
	_detail.offset_top = 40
	_detail.offset_bottom = -34
	side.add_child(_detail)
	row.add_child(side)
	box.add_child(row)

	var back := UiKit.button("ui_back", "", Vector2(240, 66))
	back.pressed.connect(func(): SceneRouter.back())
	var brow := UIKit.make_row()
	brow.add_child(back)
	box.add_child(brow)
	_fill_grid()
	return box


## اقلام واقعی بازیکن.
func _items() -> Array:
	var out: Array = []
	var flags: Dictionary = GameState.data.get("flags", {})
	match _tab:
		"keys":
			if bool(flags.get("item_key", false)):
				out.append({"icon": "key", "name": Fa.t("item_key"),
					"desc": Fa.t("c1_r1e_01")})
		"notes":
			if bool(flags.get("item_note", false)):
				out.append({"icon": "paper_note", "name": Fa.t("item_note"),
					"desc": Fa.t("c1_r1a_01")})
		_:
			var coins := int(GameState.data.get("coins", 0))
			var gems := int(GameState.data.get("gems", 0))
			if coins > 0:
				out.append({"icon": "chip", "name": Fa.t("item_coin"),
					"desc": Fa.num(coins)})
			if gems > 0:
				out.append({"icon": "circuit_board", "name": Fa.t("item_gem"),
					"desc": Fa.num(gems)})
			for up in (GameState.data.get("upgrades", []) as Array):
				out.append({"icon": "shield", "name": Fa.t("up_%s" % String(up)),
					"desc": Fa.t("up_%s_desc" % String(up))})
	return out


func _fill_grid() -> void:
	if _grid == null:
		return
	for c in _grid.get_children():
		c.queue_free()
	var items := _items()
	for i in COLS * ROWS:
		var slot := TextureRect.new()
		slot.texture = UiKit.tex("ui/kit/panels/slot_normal.png")
		slot.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		slot.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		slot.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slot.custom_minimum_size = Vector2(78, 78)
		if i < items.size():
			var it: Dictionary = items[i]
			var ic := TextureRect.new()
			ic.texture = UiKit.icon(String(it["icon"]))
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			ic.set_anchors_preset(Control.PRESET_FULL_RECT)
			ic.anchor_right = 1.0
			ic.anchor_bottom = 1.0
			ic.offset_left = 14
			ic.offset_right = -14
			ic.offset_top = 14
			ic.offset_bottom = -14
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_child(ic)
			var btn := Button.new()
			btn.flat = true
			btn.set_anchors_preset(Control.PRESET_FULL_RECT)
			btn.anchor_right = 1.0
			btn.anchor_bottom = 1.0
			btn.pressed.connect(func(): _show(it))
			slot.add_child(btn)
		_grid.add_child(slot)
	if items.is_empty():
		_show({})
	else:
		_show(items[0])


func _show(it: Dictionary) -> void:
	if _detail == null:
		return
	for c in _detail.get_children():
		c.queue_free()
	if it.is_empty():
		_detail.add_child(UiKit.label(Fa.t("ui_no_items"), "Small",
				HORIZONTAL_ALIGNMENT_CENTER, true))
		return
	var ic := TextureRect.new()
	ic.texture = UiKit.icon(String(it.get("icon", "chip")))
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.custom_minimum_size = Vector2(0, 96)
	_detail.add_child(ic)
	_detail.add_child(UiKit.label(String(it.get("name", "")), "Hud",
			HORIZONTAL_ALIGNMENT_CENTER))
	_detail.add_child(UiKit.label(String(it.get("desc", "")), "Small",
			HORIZONTAL_ALIGNMENT_CENTER, true))
