## آزمون دوربین و اتاق نقاشی‌شده — T3/T6 بازنویسی‌شده برای M1 (D-ART-32)
##
##   godot --headless res://tools/tests/test_camera.tscn
##
## `side` و `camera_zone` لغو شدند، پس سنجه‌های گذار حالت و هیسترزیس مرز
## بی‌موضوع‌اند. جایشان: گذار **در به در** (۰٫۳ث) و رفتار دوربین هر اتاق.
extends Node2D

const TILE := 32

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	_t_scale()
	_t_door_transition()
	await _t_follow()
	_report()


## اندازهٔ کاشی در چند فایل تکرار شده (ترتیب بارگذاری GDScript اجازهٔ ارجاع
## به ثابت کلاس دیگر در `const` را نمی‌دهد). این سنجه مانع واگرایی‌شان است.
func _t_scale() -> void:
	print("— مقیاس جهان —")
	_check("WorldScale.TILE = 32", WorldScale.TILE == 32, "= %d" % WorldScale.TILE)
	_check("KairoConst.TILE با WorldScale یکی است", KairoConst.TILE == WorldScale.TILE,
		"= %d" % KairoConst.TILE)
	_check("TdConst.TILE با WorldScale یکی است", TdConst.TILE == WorldScale.TILE,
		"= %d" % TdConst.TILE)
	_check("LevelLoader.TILE با WorldScale یکی است", LevelLoader.TILE == WorldScale.TILE,
		"= %d" % LevelLoader.TILE)
	var vp := Vector2i(
		ProjectSettings.get_setting("display/window/size/viewport_width", 0),
		ProjectSettings.get_setting("display/window/size/viewport_height", 0))
	_check("رزولوشن پایه ۱۲۸۰×۷۲۰ است (CLAUDE.md قانون ۳)",
		vp == WorldScale.VIEWPORT, "= %dx%d" % [vp.x, vp.y])


func _t_door_transition() -> void:
	print("— گذار در به در (۰٫۳ث) —")
	_check("گذار ۰٫۳ ثانیه = ۱۸ فریم", CameraDirector.fade_frames() == 18,
		"= %d" % CameraDirector.fade_frames())

	var d := CameraDirector.new()
	add_child(d)
	d.setup(CameraDirector.BEHAVIOR_ROOM, "r1a_living")
	var started: Array = []
	var finished: Array = []
	d.transition_started.connect(func(f, t): started.append([f, t]))
	d.transition_finished.connect(func(r): finished.append(r))

	_check("پیش از گذار، ورودی خوانده می‌شود", not d.should_ignore_input())
	d.go_to_room("r1b_corridor")
	_check("گذار شروع شد", started.size() == 1, "= %d" % started.size())
	_check("شناسهٔ اتاق فوراً عوض شد", d.room_id == "r1b_corridor", "= %s" % d.room_id)
	_check("فریم گذار ورودی نادیده گرفته می‌شود", d.should_ignore_input())
	_check("پردهٔ محو در شروع شفاف است", d.fade_alpha() < 0.2,
		"= %.2f" % d.fade_alpha())

	for i in CameraDirector.fade_frames() / 2:
		d.tick()
	_check("وسط گذار پرده تیره‌ترین است", d.fade_alpha() > 0.8,
		"= %.2f" % d.fade_alpha())
	_check("ورودی دیگر نادیده گرفته نمی‌شود", not d.should_ignore_input())

	for i in CameraDirector.fade_frames():
		d.tick()
	_check("گذار دقیقاً در فریم ۱۸ تمام شد", not d.is_transitioning())
	_check("پایان گذار یک بار اعلام شد", finished.size() == 1, "= %d" % finished.size())
	_check("پایان گذار پرده شفاف است", is_equal_approx(d.fade_alpha(), 0.0))

	# گذار تکراری به همان اتاق شروع نمی‌شود
	d.go_to_room("r1b_corridor")
	_check("گذار به همان اتاق شروع نمی‌شود", started.size() == 1)
	_check("یک پروفایل بیشتر نیست (D-ART-32)",
		d.profile_name() == "topdown", "= %s" % d.profile_name())
	d.queue_free()


func _make_camera(bounds: Rect2, mode: String) -> Array:
	var d := CameraDirector.new()
	add_child(d)
	d.setup(mode, "t")
	var body := CharacterBody2D.new()
	add_child(body)
	var cam := GameCamera.new()
	cam.follow_mode = mode
	cam.director = d
	cam.target = body
	add_child(cam)
	cam.set_bounds(bounds)
	return [d, body, cam]


func _t_follow() -> void:
	print("— دنبال کردن نرم و حد لبهٔ اتاق —")
	# پانورامای بیرونی: باید از صفحه به‌قدر کافی بزرگ‌تر باشد وگرنه دوربین
	# هیچ آزادی حرکتی ندارد و آزمون چیزی را نمی‌سنجد.
	var pano := Rect2(0, 0, 60 * TILE, 40 * TILE)
	var made := _make_camera(pano, GameCamera.FOLLOW)
	var body: CharacterBody2D = made[1]
	var cam: GameCamera = made[2]

	body.global_position = pano.get_center()
	cam.snap_to_target()
	var prev := cam.global_position
	body.global_position = pano.get_center() + Vector2(400, 0)

	var max_step := 0.0
	var moved := 0.0
	for i in 30:
		await get_tree().physics_frame
		var step := cam.global_position.distance_to(prev)
		max_step = maxf(max_step, step)
		moved += step
		prev = cam.global_position
	_check("هیچ فریمی پرش بزرگ ندارد", max_step < 60.0,
		"= بیشینهٔ %.1f px در یک فریم" % max_step)
	_check("ولی در مجموع حرکت کرد", moved > 1.0, "= %.0f px در ۳۰ فریم" % moved)

	await _frames(90)
	_check("پس از ۹۰ فریم به هدف رسید",
		cam.global_position.distance_to(body.global_position) < 160.0,
		"= %.0f px فاصله" % cam.global_position.distance_to(body.global_position))

	body.global_position = Vector2(0, 0)
	await _frames(240)
	var half := cam.get_viewport_rect().size * 0.5 / cam.zoom.x
	_check("دوربین از لبهٔ چپ بیرون نمی‌زند",
		cam.global_position.x >= half.x - 1.0,
		"= %.0f (حد %.0f)" % [cam.global_position.x, half.x])

	# اتاق داخلی ۱۲۸۰×۷۲۰ دقیقاً هم‌اندازهٔ صفحه است: دوربین باید وسطش
	# بنشیند، نه به لبه بچسبد (D-ART-25).
	var one_screen := Rect2(0, 0, 1280, 720)
	cam.set_bounds(one_screen)
	body.global_position = Vector2(0, 0)
	await _frames(120)
	_check("اتاق هم‌اندازهٔ صفحه وسط‌چین می‌شود",
		cam.global_position.is_equal_approx(one_screen.get_center().round()),
		"= %s" % str(cam.global_position))
	_check("موقعیت دوربین عدد صحیح است (نیم‌پیکسل ممنوع)",
		is_equal_approx(cam.global_position.x, roundf(cam.global_position.x)),
		"= %s" % str(cam.global_position))

	# حالت room: قفل روی مرکز اتاق، بی‌اعتنا به هدف
	var made2 := _make_camera(pano, GameCamera.ROOM)
	var body2: CharacterBody2D = made2[1]
	var cam2: GameCamera = made2[2]
	var room_rect := Rect2(0, 0, 1280, 720)
	cam2.set_room(room_rect)
	body2.global_position = room_rect.get_center() + Vector2(300, 200)
	await _frames(30)
	_check("حالت room روی مرکز اتاق قفل است",
		cam2.global_position.is_equal_approx(_clamp_center(room_rect, pano, cam2)),
		"= %s" % str(cam2.global_position))

	for n in [made[0], body, cam, made2[0], body2, cam2]:
		n.queue_free()


func _clamp_center(room_rect: Rect2, map: Rect2, cam: GameCamera) -> Vector2:
	var half := cam.get_viewport_rect().size * 0.5 / cam.zoom.x
	var c := room_rect.get_center()
	c.x = clampf(c.x, map.position.x + half.x, map.position.x + map.size.x - half.x)
	c.y = clampf(c.y, map.position.y + half.y, map.position.y + map.size.y - half.y)
	return c.round()


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


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
