## دربارهٔ بازی و اعتبارات — سند ۱۷ بند ۱۴
##
## نسخه، سازندگان، و **مجوز فونت‌ها**: هر سه فونت OFL‌اند و متن مجوزشان
## کنار فایل‌هاست؛ اینجا نشان داده می‌شود (دستور کاربر، گام ۵۹).
extends Screen

const LICENSES := [
	["Aref Ruqaa", "res://assets/fonts/LICENSE-aref-ruqaa.txt"],
	["Vazirmatn", "res://assets/fonts/LICENSE-vazirmatn.txt"],
	["El Messiri", "res://assets/fonts/LICENSE-el-messiri.txt"],
]


func _ready() -> void:
	panel_kind = "panel_xl"
	super()


func build() -> VBoxContainer:
	var box := UIKit.make_root("ui_about")
	box.add_child(UiKit.label("%s — %s" % [Fa.t("game_title"), Fa.t("ui_chapter_one")],
			"Hud", HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UiKit.label("v1.0", "Small", HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UIKit.make_spacer(12))
	box.add_child(UiKit.label(Fa.t("ui_licenses"), "Name", HORIZONTAL_ALIGNMENT_CENTER))

	for spec in LICENSES:
		var name := String(spec[0])
		var path := String(spec[1])
		var head := UiKit.label("%s — SIL Open Font License 1.1" % name, "Small",
				HORIZONTAL_ALIGNMENT_CENTER)
		box.add_child(head)
		var body := _first_lines(path, 3)
		if body != "":
			var l := UiKit.label(body, "Tiny", HORIZONTAL_ALIGNMENT_CENTER, true)
			l.custom_minimum_size = Vector2(0, 52)
			box.add_child(l)
		else:
			box.add_child(UiKit.label("%s: %s" % [name, path], "Tiny",
					HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(UIKit.make_spacer(10))
	box.add_child(UiKit.label("پروفایل اعداد: %s" % KairoConst.active_profile, "Tiny",
			HORIZONTAL_ALIGNMENT_CENTER))

	var back := UiKit.button("ui_back", "", Vector2(240, 66))
	back.pressed.connect(func(): SceneRouter.back())
	var row := UIKit.make_row()
	row.add_child(back)
	box.add_child(row)
	return box


## چند خط اول فایل مجوز — متن کامل در خود فایل می‌ماند.
func _first_lines(path: String, n: int) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f := FileAccess.open(path, FileAccess.READ)
	var out: Array[String] = []
	while out.size() < n and not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line != "":
			out.append(line)
	return "\n".join(out)
