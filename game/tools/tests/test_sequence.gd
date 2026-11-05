## آزمون GameMode و ScriptedSequence — T5
##
##   godot --headless res://tools/tests/test_sequence.tscn
##
## چیزی که می‌سنجد همان‌هایی است که اگر بشکنند بازیکن گیر می‌کند یا کنترل را
## از دست می‌دهد: قطع ورودی در غیر PLAY، پس دادن کنترل در پایان، شمارش فریم،
## و اینکه گام خراب بی‌صدا رد نشود.
extends Node2D

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	await _t_game_mode()
	await _t_sequence_runs()
	await _t_control_handback()
	await _t_skip_policy()
	_t_validation()
	_t_triggers()
	_report()


func _t_game_mode() -> void:
	print("— GameMode: دو محور جدا —")
	GameMode.set_control(GameMode.ControlMode.PLAY)
	GameMode.set_context(GameMode.Context.EXPLORE)
	_check("پیش‌فرض PLAY است", GameMode.wants_input())
	_check("بافت EXPLORE است", GameMode.context_name() == "EXPLORE",
		"= %s" % GameMode.context_name())

	GameMode.set_control(GameMode.ControlMode.SCRIPTED)
	_check("در SCRIPTED ورودی خوانده نمی‌شود", not GameMode.wants_input())
	_check("در SCRIPTED بردار حرکت صفر است", GameMode.move_vector() == Vector2.ZERO)
	_check("در SCRIPTED مرگ شمرده نمی‌شود", not GameMode.death_counts())
	_check("HUD در SCRIPTED کم‌رنگ است", GameMode.hud_alpha() < 1.0,
		"= %.2f" % GameMode.hud_alpha())

	GameMode.set_control(GameMode.ControlMode.CUTSCENE)
	_check("HUD در CUTSCENE پنهان است", is_equal_approx(GameMode.hud_alpha(), 0.0))

	# بافت می‌تواند BATTLE باشد در حالی که کنترل SCRIPTED است —
	# همان چیزی که با یک فهرست واحد بیان‌شدنی نبود
	GameMode.set_context(GameMode.Context.BATTLE)
	_check("توالی اسکریپتی وسط نبرد بیان‌شدنی است",
		GameMode.context == GameMode.Context.BATTLE
		and GameMode.control == GameMode.ControlMode.CUTSCENE)

	GameMode.set_control(GameMode.ControlMode.PLAY)
	_check("برگشت به PLAY یک فریم مهلت دارد", not GameMode.wants_input())
	GameMode.tick()
	_check("فریم بعد ورودی دوباره خوانده می‌شود", GameMode.wants_input())
	GameMode.set_context(GameMode.Context.EXPLORE)


func _make_scene() -> Dictionary:
	var kairo := Node2D.new()
	kairo.name = "Kairo"
	kairo.global_position = Vector2(0, 0)
	add_child(kairo)
	var marker := Node2D.new()
	marker.name = "MarkerHall"
	marker.global_position = Vector2(320, 0)
	add_child(marker)
	var cam := Camera2D.new()
	cam.name = "Cam"
	add_child(cam)
	return {"kairo": kairo, "marker_hall": marker, "camera": cam}


func _t_sequence_runs() -> void:
	print("— اجرای توالی: حرکت قطعی و شمارش فریم —")
	var scene := _make_scene()
	var seq := ScriptedSequence.new()
	add_child(seq)
	var problems := seq.setup("t_move", {"steps": [
		{"step": "move_to", "actor": "kairo", "marker": "marker_hall", "seconds": 0.5},
		{"step": "wait", "seconds": 0.2},
	]}, scene)
	_check("توالی سالم ایرادی ندارد", problems.is_empty(), "= %s" % str(problems))

	var started: Array = []
	seq.step_started.connect(func(i, s): started.append(i))
	await seq.run()
	_check("هر دو گام اجرا شد", started.size() == 2, "= %d" % started.size())
	_check("بازیگر دقیقاً روی نشانه نشست",
		(scene["kairo"] as Node2D).global_position.is_equal_approx(Vector2(320, 0)),
		"= %s" % str((scene["kairo"] as Node2D).global_position))
	# ۰٫۵ + ۰٫۲ ثانیه = ۴۲ فریم فیزیک. **فریم** می‌سنجیم نه زمان دیواری:
	# با `--fixed-fps 60` موتور فریم‌ها را هر چه سریع‌تر می‌راند، پس زمان
	# دیواری نزدیک صفر است و چیزی را ثابت نمی‌کند.
	_check("توالی دقیقاً ۴۲ فریم فیزیک برد", seq.frames_elapsed == 42,
		"= %d فریم" % seq.frames_elapsed)
	seq.queue_free()


func _t_control_handback() -> void:
	print("— کنترل در شروع گرفته و در پایان پس داده می‌شود —")
	var scene := _make_scene()
	var seq := ScriptedSequence.new()
	add_child(seq)
	seq.setup("t_ctrl", {"steps": [{"step": "wait", "seconds": 0.1}]}, scene)

	GameMode.set_control(GameMode.ControlMode.PLAY)
	GameMode.tick()
	var during := [true]
	seq.step_started.connect(func(_i, _s): during[0] = GameMode.wants_input())
	await seq.run()
	_check("در حین توالی ورودی قطع بود", not during[0])
	_check("پس از توالی کنترل برگشت",
		GameMode.control == GameMode.ControlMode.PLAY,
		"= %s" % GameMode.control_name())
	seq.queue_free()


func _t_skip_policy() -> void:
	print("— سیاست رد کردن —")
	var short_steps := [{"step": "wait", "seconds": 1.0}]
	var mid_steps := [{"step": "wait", "seconds": 4.0}]
	var long_steps := [{"step": "wait", "seconds": 8.0}]
	_check("زمان توالی درست برآورد می‌شود",
		is_equal_approx(ScriptedSequence.estimate_seconds(long_steps), 8.0),
		"= %.1f" % ScriptedSequence.estimate_seconds(long_steps))

	var a := ScriptedSequence.new()
	add_child(a)
	a.setup("short", {"steps": short_steps}, {})
	_check("توالی زیر ۳ ثانیه رد نمی‌شود", not a.skippable)

	var b := ScriptedSequence.new()
	add_child(b)
	b.setup("mid", {"steps": mid_steps}, {})
	_check("توالی ۳ تا ۵ ثانیه رد نمی‌شود", not b.skippable)

	var c := ScriptedSequence.new()
	add_child(c)
	c.setup("long", {"steps": long_steps}, {})
	_check("توالی بالای ۵ ثانیه رد می‌شود", c.skippable)

	# رد کردن واقعاً توالی را کوتاه می‌کند
	var scene := _make_scene()
	var d := ScriptedSequence.new()
	add_child(d)
	d.setup("skipme", {"steps": [
		{"step": "wait", "seconds": 4.0},
		{"step": "wait", "seconds": 4.0},
	]}, scene)
	var done := [false]
	var was_skipped := [false]
	d.sequence_finished.connect(func(_id, sk):
		done[0] = true
		was_skipped[0] = sk)
	d.step_started.connect(func(i, _s):
		if i == 0:
			d.request_skip())
	await d.run()
	_check("رد کردن توالی را تمام کرد", done[0] and was_skipped[0],
		"(done=%s skipped=%s)" % [done[0], was_skipped[0]])
	_check("پس از رد کردن هم کنترل برگشت",
		GameMode.control == GameMode.ControlMode.PLAY)
	for n in [a, b, c, d]:
		n.queue_free()


func _t_validation() -> void:
	print("— گام خراب بی‌صدا رد نمی‌شود —")
	var seq := ScriptedSequence.new()
	add_child(seq)
	var problems := seq.setup("bad", {"steps": [
		{"step": "wait", "seconds": 0.1},
		{"step": "teleport_everyone"},
		{"seconds": 1.0},
		"not a dictionary",
	]}, {})
	_check("سه ایراد پیدا شد", problems.size() == 3, "= %d: %s" % [problems.size(), str(problems)])
	seq.queue_free()

	print("— فایل‌های توالی روی دیسک سالم‌اند —")
	for sid in ["ch1_a1_intro", "ch1_a1_trap"]:
		var data := ScriptedSequence.load_from("res://data/sequences/%s.json" % sid)
		_check("%s بار شد" % sid, not data.is_empty())
		var s2 := ScriptedSequence.new()
		add_child(s2)
		var probs := s2.setup(sid, data, {})
		_check("%s گام ناشناخته ندارد" % sid, probs.is_empty(), "= %s" % str(probs))
		s2.queue_free()


func _t_triggers() -> void:
	print("— ماشه‌های مرحله در JSON —")
	var loader := LevelLoader.new()
	loader.errors.clear()
	var fake := {
		"id": "t", "camera_mode": "topdown", "start_room": "r1",
		"triggers": [
			{"id": "ok", "sequence": "ch1_a1_intro", "rect": [1, 1, 3, 3]},
			{"id": "ok", "sequence": "x", "rect": [1, 1, 3, 3]},
			{"id": "", "sequence": "x", "rect": [1, 1, 3, 3]},
			{"id": "noseq", "rect": [1, 1, 3, 3]},
			{"id": "badrect", "sequence": "x", "rect": [1, 1, 0, 3]},
		],
		"rooms": [{"id": "r1", "tiles": []}],
	}
	loader._normalize_triggers(fake)
	_check("چهار ماشهٔ خراب خطا دادند", loader.errors.size() == 4,
		"= %d" % loader.errors.size())
	var kept: Array = fake["triggers"]
	_check("فقط ماشهٔ سالم ماند", kept.size() == 1, "= %d" % kept.size())
	_check("once پیش‌فرض true است", bool((kept[0] as Dictionary).get("once", false)))


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
