## نقشهٔ فصل — docs/02_godot_spec.md §۱۳، قفل‌های سند ۰۵
##
## نسخهٔ ۱ یک دنیا دارد (خانهٔ کایرو و ایلارا). مرحلهٔ ۱ تا ۳ فعال و ۴ تا ۸
## خاکستری با برچسب «به‌زودی». صفحهٔ دوم به‌صورت سایهٔ کم‌رنگ دیده می‌شود.
extends Screen

const LEVELS := [
	{"id": "ch1_l1", "title": "ch1_l1_title"},
	{"id": "ch1_l2", "title": "ch1_l2_title"},
	{"id": "ch1_l3", "title": "ch1_l3_title"},
]
## مرحلهٔ ۴ تا ۸ فصل ۱ در نسخهٔ ۱ نیست (سند ۰۵)
const SOON_COUNT: int = 5

func build() -> VBoxContainer:
	var box := UIKit.make_root("ui_world_map")
	box.add_child(UIKit.make_currency_bar())
	box.add_child(UIKit.make_spacer(4))

	var unlocked := GameState.highest_unlocked_level()
	for i in LEVELS.size():
		var spec: Dictionary = LEVELS[i]
		var rec := GameState.level_record(spec["id"])
		var stars := int(rec.get("stars", 0))
		var open: bool = (i + 1) <= unlocked
		var suffix: String = ""
		if open:
			suffix = "  " + "★".repeat(stars) + "☆".repeat(3 - stars)
		else:
			suffix = "  (" + Fa.t("ui_locked") + ")"
		var b := UIKit.make_button(spec["title"], open, suffix)
		if open:
			b.pressed.connect(func(): _play(spec["id"]))
		box.add_child(b)

	for i in SOON_COUNT:
		var b := UIKit.make_button("ui_soon", false, "  " + Fa.num(4 + i))
		box.add_child(b)

	box.add_child(UIKit.make_spacer(4))
	box.add_child(UIKit.make_label(Fa.t("ui_coming_story"), 9, UIKit.MUTED))
	add_back_button(box)
	return box

func _play(level_id: String) -> void:
	SceneRouter.pending_level = "res://levels/data/%s.json" % level_id
	SceneRouter.goto("level_intro")
