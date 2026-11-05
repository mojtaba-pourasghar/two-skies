## آزمون ناحیهٔ اکتشافی — T15
##
##   godot --headless res://tools/tests/test_explore.tscn
##
## سه چیز را می‌سنجد که اگر بشکنند بازیکن گیر می‌کند و هیچ خطایی هم نمی‌بیند:
## اعتبارسنجی داده (تلهٔ بی‌کاشی امن)، قاعدهٔ مرگِ **متفاوت** در اکتشاف و
## اتاق چالش، و اینکه ناحیهٔ واقعی با هنر واقعی ساخته شود.
extends Node2D

const AREA := "res://levels/data/areas/ch1_a1.json"

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	_t_loader_validation()
	_t_real_area()
	await _t_trap_rule()
	await _t_challenge_rule()
	_report()


func _t_loader_validation() -> void:
	print("— اعتبارسنجی دادهٔ ناحیه —")
	var l := AreaLoader.new()
	var area := l.load_area(AREA)
	_check("ناحیهٔ ch1_a1 بار شد", not area.is_empty(),
		"" if area.is_empty() else "= %dx%d کاشی" % [area["width"], area["height"]])
	if area.is_empty():
		for e in l.errors:
			print("      %s" % e)
		return
	_check("هیچ خطایی ندارد", l.errors.is_empty(), "= %s" % str(l.errors))
	_check("دست‌کم ۲ صفحه پهناست (سند ۰۹ §۵)",
		area["width"] * AreaLoader.TILE >= 2560,
		"= %d پیکسل" % (area["width"] * AreaLoader.TILE))
	_check("حالت دوربین topdown است", String(area["camera_mode"]) == "topdown")
	_check("یک ناحیهٔ چالش side دارد",
		(area["camera_zones"] as Array).size() == 1
		and String(((area["camera_zones"] as Array)[0] as Dictionary)["mode"]) == "side")
	_check("ماشهٔ مقدمه وصل است", (area["triggers"] as Array).size() >= 1)
	_check("تله کاشی امن دارد",
		((area["traps"] as Array)[0] as Dictionary).has("safe"))

	# دادهٔ خراب باید خطا بدهد، نه بی‌صدا رد شود
	var bad := AreaLoader.new()
	# GDScript ضرب آرایه ندارد؛ سطرها را صریح می‌سازیم
	var blank_rows: Array = []
	for i in 23:
		blank_rows.append(".".repeat(40))
	var fake := {
		"id": "bad", "size": [40, 23],
		"layers": {"floor": blank_rows, "walls": blank_rows.duplicate()},
		"spawn": [1, 1],
		"traps": [
			{"id": "no_safe", "rect": [2, 2, 2, 2], "damage_pct": 10},
			{"id": "safe_in_trap", "rect": [10, 10, 4, 4], "safe": [11, 11]},
		],
	}
	bad._normalize(fake)
	bad._validate(fake)
	var msgs := ", ".join(bad.errors)
	_check("تلهٔ بی‌کاشی امن خطا داد", msgs.contains("no_safe"), "= %s" % msgs)
	_check("کاشی امنی که داخل خود تله است خطا داد",
		msgs.contains("safe_in_trap"), "= %s" % msgs)


func _t_real_area() -> void:
	print("— ساخت ناحیه با هنر واقعی —")
	var l := AreaLoader.new()
	var area := l.load_area(AREA)
	if area.is_empty():
		return
	var node := ExploreArea.new()
	add_child(node)
	node.build(area)
	_check("مرز نقشه درست است",
		node.bounds().size == Vector2(area["width"] * 32, area["height"] * 32),
		"= %s" % str(node.bounds().size))
	_check("تله ساخته شد", node.traps.size() == 1, "= %d" % node.traps.size())
	_check("نقطهٔ ذخیره ساخته شد", node.save_points.size() == 1,
		"= %d" % node.save_points.size())
	_check("اتاق چالش ساخته شد", node.challenge != null)
	# هنر ناقص بازی را نمی‌شکند، ولی باید **گزارش** شود نه پنهان
	if not node.missing_art.is_empty():
		print("    i %d دارایی پیدا نشد: %s"
			% [node.missing_art.size(), ", ".join(node.missing_art.slice(0, 4))])
	_check("کاشی‌های کف و دیوار کشیده شدند",
		node.get_node("Floor").get_child_count() > 100
		and node.get_node("Walls").get_child_count() > 50,
		"= کف %d، دیوار %d" % [node.get_node("Floor").get_child_count(),
			node.get_node("Walls").get_child_count()])
	node.queue_free()


func _t_trap_rule() -> void:
	print("— قاعدهٔ تله در اکتشاف: آسیب، نه مرگ (سند ۰۹ §۱ قاعدهٔ ۲) —")
	GameMode.set_control(GameMode.ControlMode.PLAY)
	GameMode.tick()
	GameState.restore_full()

	var actor := TdKairo.new()
	add_child(actor)
	actor.global_position = Vector2(500, 500)
	var trap := ExploreTrap.new()
	trap.damage_pct = 10.0
	trap.safe_point = Vector2(100, 100)
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(64, 64)
	shape.shape = box
	trap.add_child(shape)
	trap.position = Vector2(500, 500)
	add_child(trap)
	await get_tree().physics_frame
	await get_tree().physics_frame

	var hp_before := GameState.hp_percent()
	var deaths_before := actor.deaths
	trap._spring(actor)
	_check("جان ۱۰٪ کم شد",
		is_equal_approx(GameState.hp_percent(), hp_before - 10.0),
		"= %.0f٪ (پیش از آن %.0f٪)" % [GameState.hp_percent(), hp_before])
	_check("مرگ ثبت **نشد** — اکتشاف مرگ ندارد", actor.deaths == deaths_before,
		"= %d مرگ" % actor.deaths)
	_check("به کاشی امن برگشت", actor.global_position == Vector2(100, 100),
		"= %s" % str(actor.global_position))

	# جان هرگز زیر صفر نمی‌رود
	for i in 20:
		GameState.damage_percent(10.0)
	_check("جان زیر صفر نمی‌رود", GameState.hp_percent() >= 0.0,
		"= %.0f٪" % GameState.hp_percent())
	GameState.restore_full()
	_check("نقطهٔ ذخیره جان را پر می‌کند",
		is_equal_approx(GameState.hp_percent(), 100.0))

	actor.queue_free()
	trap.queue_free()


func _t_challenge_rule() -> void:
	print("— قاعدهٔ مرگ در اتاق چالش: عکس اکتشاف (سند ۰۹ §۲ب) —")
	var d := CameraDirector.new()
	add_child(d)
	d.setup("topdown", [{"id": "challenge_a", "mode": "side",
		"rect": [10, 5, 6, 4]}], 32)
	var room := ChallengeRoom.new()
	room.room_id = "challenge_a"
	room.entry_point = Vector2(320, 288)
	add_child(room)
	room.bind(d)

	var actor := TdKairo.new()
	add_child(actor)
	_check("پیش از ورود، اتاق فعال نیست", not room.is_active)

	d.update(Vector2(12 * 32, 6 * 32))
	_check("ورود خودکار اتاق را فعال کرد", room.is_active)

	actor.global_position = Vector2(9999, 9999)
	room.register_death(actor)
	room.register_death(actor)
	room.register_death(actor)
	_check("مرگ بی‌نهایت است و شمرده می‌شود", room.deaths == 3,
		"= %d" % room.deaths)
	_check("هر مرگ به نقطهٔ ورود برمی‌گرداند",
		actor.global_position == Vector2(320, 288), "= %s" % str(actor.global_position))
	_check("ریستارت زیر ۰٫۳ ثانیه است",
		ChallengeRoom.restart_seconds() < 0.3,
		"= %.2f ثانیه" % ChallengeRoom.restart_seconds())

	# خروج خودکار
	for i in CameraDirector.blend_frames() + 2:
		d.update(Vector2(12 * 32, 6 * 32))
	for i in CameraDirector.blend_frames() + 2:
		d.update(Vector2(2 * 32, 2 * 32))
	_check("خروج خودکار اتاق را غیرفعال کرد", not room.is_active)

	actor.queue_free()
	room.queue_free()
	d.queue_free()


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  ✔ %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  ✘ %s %s" % [label, detail])


func _report() -> void:
	print("")
	if _failures.is_empty():
		print("همهٔ %d سنجه قبول شد." % _checks)
		get_tree().quit(0)
	else:
		print("%d از %d سنجه رد شد." % [_failures.size(), _checks])
		get_tree().quit(1)
