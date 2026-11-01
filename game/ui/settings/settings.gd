## تنظیمات — docs/02_godot_spec.md §۲، §۹، §۱۴
extends Screen

func build() -> VBoxContainer:
	var box := UIKit.make_root("ui_settings")
	box.add_child(UIKit.make_slider("ui_volume_master", Settings.volume["Master"], 0.0, 1.0,
		func(v): _set_volume("Master", v)))
	box.add_child(UIKit.make_slider("ui_volume_music", Settings.volume["Music"], 0.0, 1.0,
		func(v): _set_volume("Music", v)))
	box.add_child(UIKit.make_slider("ui_volume_sfx", Settings.volume["SFX"], 0.0, 1.0,
		func(v): _set_volume("SFX", v)))
	# مقیاس دکمه‌های لمسی ۰٫۸ تا ۱٫۳ (§۲)
	box.add_child(UIKit.make_slider("ui_touch_scale", Settings.touch_scale, 0.8, 1.3,
		func(v):
			Settings.touch_scale = v
			Settings.changed.emit()
			GameState.save_game()))
	box.add_child(UIKit.make_toggle("ui_haptics", Settings.haptics_enabled,
		func(on):
			Settings.haptics_enabled = on
			Settings.changed.emit()
			GameState.save_game()))
	box.add_child(UIKit.make_toggle("ui_camera_shake", Settings.camera_shake_enabled,
		func(on):
			Settings.camera_shake_enabled = on
			Settings.changed.emit()
			GameState.save_game()))
	add_back_button(box)
	return box

func _set_volume(bus: String, v: float) -> void:
	Settings.volume[bus] = v
	Settings.changed.emit()
	GameState.save_game()
