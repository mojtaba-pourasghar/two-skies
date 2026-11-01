## نتیجهٔ مرحله — docs/02_godot_spec.md §۸ و §۱۳، تبلیغ پاداشی §۱۵
extends Screen

func build() -> VBoxContainer:
	var r: Dictionary = SceneRouter.last_result
	var box := UIKit.make_root("ui_result_title")
	var stars := int(r.get("stars", 0))
	box.add_child(UIKit.make_label("★".repeat(stars) + "☆".repeat(3 - stars), 16, UIKit.ACCENT))
	box.add_child(UIKit.make_label("%s: %s" % [Fa.t("ui_coins"), Fa.num(int(r.get("coins", 0)))], 10))
	box.add_child(UIKit.make_label("%s: %s" % [Fa.t("ui_gems"), Fa.num(int((r.get("gems", []) as Array).size()))], 10))
	box.add_child(UIKit.make_label("%s: %s" % [Fa.t("ui_time"), Fa.time(float(r.get("time", 0.0)))], 10))
	box.add_child(UIKit.make_label("%s: %s" % [Fa.t("ui_deaths"), Fa.num(int(r.get("deaths", 0)))], 10, UIKit.MUTED))
	box.add_child(UIKit.make_label("%s: %s" % [Fa.t("ui_ilara_falls"), Fa.num(int(r.get("ilara_falls", 0)))], 10, UIKit.MUTED))
	box.add_child(UIKit.make_spacer(6))

	# تبلیغ پاداشی اختیاری: دو برابر کردن سکهٔ پایان مرحله (§۱۵).
	# اگر آماده نباشد دکمه خاکستری است و پیام نشان داده می‌شود.
	if not GameState.owns("double_reward"):
		var ready := Ads.is_loaded("rewarded_double_coins")
		var ad := UIKit.make_button("ui_double_coins", ready,
			"" if ready else "  (" + Fa.t("ui_no_ad") + ")")
		ad.pressed.connect(_double_coins)
		box.add_child(ad)

	var next := UIKit.make_button("ui_next_level")
	next.pressed.connect(func(): SceneRouter.goto("world_map", false))
	box.add_child(next)
	return box

func _double_coins() -> void:
	# پاداش فقط در سیگنال rewarded_completed داده می‌شود (§۱۵)
	Ads.rewarded_completed.connect(_on_ad_done, CONNECT_ONE_SHOT)
	Ads.show("rewarded_double_coins")

func _on_ad_done(_placement: String) -> void:
	var r: Dictionary = SceneRouter.last_result
	GameState.add_coins(int(r.get("coins", 0)))
	SceneRouter.reload_current()
