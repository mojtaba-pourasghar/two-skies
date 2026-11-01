## منوی اصلی — docs/02_godot_spec.md §۱۳ و قفل‌های سند ۰۵
extends Screen

func _ready() -> void:
	confirm_exit_on_back = true
	super()
	Audio.play_music("music_menu")

func build() -> VBoxContainer:
	var box := UIKit.make_root("c1_title")
	box.add_child(UIKit.make_currency_bar())
	box.add_child(UIKit.make_spacer(6))

	var play := UIKit.make_button("ui_continue")
	play.pressed.connect(func(): SceneRouter.goto("world_map"))
	box.add_child(play)

	# قفل‌های تدریجی سند ۰۵: مأموریت/جعبه بعد از م۱، فروشگاه بعد از م۲،
	# نامه‌ها بعد از م۳.
	var done := _levels_done()

	var daily := UIKit.make_button("ui_daily", done >= 1,
		"" if done >= 1 else "  (" + Fa.t("ui_locked") + ")")
	daily.pressed.connect(_claim_daily)
	box.add_child(daily)

	var shop := UIKit.make_button("ui_shop", done >= 2,
		"" if done >= 2 else "  (" + Fa.t("ui_locked") + ")")
	shop.pressed.connect(func(): SceneRouter.goto("shop"))
	box.add_child(shop)

	var letters := UIKit.make_button("ui_letters", done >= 3,
		"" if done >= 3 else "  (" + Fa.t("ui_locked") + ")")
	letters.pressed.connect(func(): SceneRouter.goto("letters"))
	box.add_child(letters)

	var settings := UIKit.make_button("ui_settings")
	settings.pressed.connect(func(): SceneRouter.goto("settings"))
	box.add_child(settings)

	var about := UIKit.make_button("ui_about")
	about.pressed.connect(func(): SceneRouter.goto("about"))
	box.add_child(about)

	return box

## چند مرحله تمام شده است
func _levels_done() -> int:
	var n := 0
	for i in range(1, 4):
		if int(GameState.level_record("ch1_l%d" % i).get("stars", 0)) > 0:
			n += 1
	return n

func _claim_daily() -> void:
	if not GameState.daily_available():
		return
	var got := GameState.claim_daily(3)
	if got.is_empty():
		return
	Audio.play_sfx("ui_click")
	SceneRouter.reload_current()
