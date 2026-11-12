## انتخاب ذخیره — سند ۱۷ بند ۲
##
## سه خانه. هر خانه یک ردیف پهن است: نام ناحیه، زمان بازی، تعداد مرگ،
## و تاریخ؛ خانهٔ خالی «بازی تازه» می‌شود. حذف با تأیید.
##
## **امروز بازی یک ذخیره دارد، نه سه.** پس خانهٔ ۱ ذخیرهٔ واقعی است و
## دو خانهٔ دیگر خالی‌اند و همین را می‌گویند — جای خالی را با داده‌ی
## ساختگی پر نکردم.
extends Screen

const SLOTS := 3

var _confirm_for: int = -1


func _ready() -> void:
	panel_kind = "panel_xl"
	super()


func build() -> VBoxContainer:
	var box := UIKit.make_root("ui_save_select")
	for i in SLOTS:
		box.add_child(_slot_row(i))
	box.add_child(UIKit.make_spacer(10))
	var back := UiKit.button("ui_back", "", Vector2(260, 70))
	back.pressed.connect(func(): SceneRouter.goto("main_menu", false))
	var row := UIKit.make_row()
	row.add_child(back)
	box.add_child(row)
	return box


func _slot_row(i: int) -> Control:
	var used := i == 0 and GameState.explore_room() != ""
	var holder := UiKit.panel("panel_wide")
	holder.custom_minimum_size = Vector2(0, 132)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.anchor_right = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = 54
	row.offset_right = -54
	row.offset_top = 26
	row.offset_bottom = -26
	holder.add_child(row)

	var ic := TextureRect.new()
	ic.texture = UiKit.icon("save" if used else "paper_note")
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.custom_minimum_size = Vector2(64, 64)
	row.add_child(ic)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 2)
	if used:
		col.add_child(UiKit.label("%s %s — %s" % [Fa.t("ui_chapter_one"),
			Fa.num(1), _room_name(GameState.explore_room())], "Hud"))
		col.add_child(UiKit.label("%s: %s   |   %s: %s" % [
			Fa.t("ui_deaths_count"), Fa.num(int(GameState.run.get("deaths", 0))),
			Fa.t("ui_coins"), Fa.num(int(GameState.data.get("coins", 0)))], "Small"))
	else:
		col.add_child(UiKit.label(Fa.t("ui_empty_slot"), "Hud"))
		col.add_child(UiKit.label(Fa.t("ui_new_game"), "Small"))
	row.add_child(col)

	var go := UiKit.button("ui_continue" if used else "ui_new_game",
			"Gold" if used else "", Vector2(220, 68))
	go.pressed.connect(func(): _start(i, used))
	row.add_child(go)

	if used:
		var del := UiKit.icon_button("close", Fa.t("ui_delete"), 68.0)
		del.pressed.connect(func(): _ask_delete(i))
		row.add_child(del)
	return holder


func _room_name(rid: String) -> String:
	var key := "room_%s" % rid
	var t := Fa.t(key)
	return rid if t == key else t


func _start(_i: int, used: bool) -> void:
	if used:
		SceneRouter.goto("game")
		return
	GameState.run["flags"] = {}
	GameState.data["flags"] = {}
	GameState.save_game()
	SceneRouter.goto("game")


func _ask_delete(i: int) -> void:
	_confirm_for = i
	var dim := UiKit.dim(0.7)
	add_child(dim)
	var p := UiKit.panel("panel_m")
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = -260
	p.offset_right = 260
	p.offset_top = -140
	p.offset_bottom = 140
	add_child(p)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	v.anchor_right = 1.0
	v.anchor_bottom = 1.0
	v.offset_left = 46
	v.offset_right = -46
	v.offset_top = 40
	v.offset_bottom = -34
	p.add_child(v)
	v.add_child(UiKit.label(Fa.t("ui_delete"), "Hud", HORIZONTAL_ALIGNMENT_CENTER))
	var row := UIKit.make_row()
	var yes := UiKit.button("ui_yes", "", Vector2(180, 68))
	yes.pressed.connect(func():
		GameState.data["explore"] = {}
		GameState.save_game()
		dim.queue_free()
		p.queue_free()
		SceneRouter.reload_current())
	var no := UiKit.button("ui_no", "", Vector2(180, 68))
	no.pressed.connect(func():
		dim.queue_free()
		p.queue_free())
	row.add_child(yes)
	row.add_child(no)
	v.add_child(row)
	UiKit.slide_in(p)
