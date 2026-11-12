## صفحهٔ مکث — بازنویسی گام ۵۹ (سند ۱۷ بند ۳)
##
## پشتش بازی است، پس پنل **متوسط** وسط می‌نشیند و بقیهٔ صفحه فقط تیره
## می‌شود؛ قاب بزرگ `Screen` اینجا غلط بود، چون کل صحنه را می‌پوشاند.
extends Screen


func _ready() -> void:
	panel_kind = "panel_l"
	frame_margin = Vector2(300, 28)
	super()


## پشت مکث، **بازی** است نه نقاشی منو: فقط تیره می‌شود.
func _build_backdrop() -> void:
	add_child(UiKit.dim(0.62))


func build() -> VBoxContainer:
	var box := UIKit.make_root("ui_pause")
	box.add_child(_entry("ui_resume", "play", func():
		get_tree().paused = false
		queue_free()))
	box.add_child(_entry("ui_inventory", "backpack", func():
		SceneRouter.goto("inventory")))
	box.add_child(_entry("ui_status", "companions", func():
		SceneRouter.goto("status")))
	box.add_child(_entry("ui_settings", "settings", func():
		SceneRouter.goto("settings")))
	box.add_child(_entry("ui_save", "save", func():
		GameState.save_game()
		Ui.toast(Fa.t("ui_saved_toast"), "save")))
	box.add_child(_entry("ui_to_menu", "home", func():
		get_tree().paused = false
		SceneRouter.goto("main_menu", false)))
	return box


func _entry(key: String, icon_name: String, cb: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var ic := TextureRect.new()
	ic.texture = UiKit.icon(icon_name)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ic.custom_minimum_size = Vector2(40, 40)
	var b := UiKit.button(key, "", Vector2(300, 56))
	b.pressed.connect(cb)
	row.add_child(ic)
	row.add_child(b)
	return row
