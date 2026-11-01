## کارت مرحله — docs/02_godot_spec.md §۱۳
extends Screen

var _level: Dictionary = {}

func build() -> VBoxContainer:
	_level = _peek_level()
	var box := UIKit.make_root(String(_level.get("title_key", "ui_play")))
	var par := float(_level.get("par_time", 0.0))
	var rec := GameState.level_record(String(_level.get("id", "")))
	box.add_child(UIKit.make_label("%s: %s" % [Fa.t("ui_par_time"), Fa.time(par)], 10))
	var best := float(rec.get("best_time", 0.0))
	if best > 0.0:
		box.add_child(UIKit.make_label("%s: %s" % [Fa.t("ui_time"), Fa.time(best)], 10))
	box.add_child(UIKit.make_spacer(8))
	var go := UIKit.make_button("ui_play")
	go.pressed.connect(func(): SceneRouter.goto("game"))
	box.add_child(go)
	add_back_button(box)
	return box

## فقط برای نمایش کارت، بدون ساختن اتاق
func _peek_level() -> Dictionary:
	var path := SceneRouter.pending_level
	if path == "" or not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}
