## آزمون کارگردان دوربین و فیلدهای دوربین مرحله — T3 (D-ART-09d)
##
##   godot --headless res://tools/tests/test_camera.tscn
##
## زمان‌بندی را **فریم‌به‌فریم** می‌سنجد، نه با انتظار زمانی: عددهای ۰٫۶ و ۰٫۲
## ثانیه از سند می‌آیند و اگر یک فریم جابه‌جا شوند هیچ‌کس در بازی‌تست نمی‌فهمد.
extends Node2D

const TILE := 32

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	_t_timing()
	_t_zone_switch()
	_t_input_skip()
	_t_presentation()
	_t_profile()
	_t_loader()
	_t_scale()
	await _t_follow()
	await _t_no_jitter()
	_report()


func _make() -> CameraDirector:
	var d := CameraDirector.new()
	add_child(d)
	# یک ناحیهٔ چالش از کاشی (۱۰,۵) به اندازهٔ ۶×۴ کاشی
	d.setup("topdown", [{"id": "challenge_a", "mode": "side", "rect": [10, 5, 6, 4]}], TILE)
	return d


func _t_timing() -> void:
	print("— زمان‌بندی از روی عدد سند —")
	_check("گذار ۰٫۶ ثانیه = ۳۶ فریم", CameraDirector.blend_frames() == 36,
		"= %d" % CameraDirector.blend_frames())
	_check("نگاشت کنترل ۰٫۲ ثانیه = ۱۲ فریم", CameraDirector.remap_frames() == 12,
		"= %d" % CameraDirector.remap_frames())


func _t_zone_switch() -> void:
	print("— عوض شدن حالت با ورود به ناحیه —")
	var d := _make()
	var changing: Array = []
	var changed: Array = []
	var remapped: Array = []
	d.mode_changing.connect(func(f, t): changing.append([f, t]))
	d.mode_changed.connect(func(m): changed.append(m))
	d.controls_remapped.connect(func(m): remapped.append(m))

	var outside := Vector2(2 * TILE, 2 * TILE)
	for i in 5:
		d.update(outside)
	_check("بیرون ناحیه حالت پیش‌فرض است", d.mode == "topdown", "= %s" % d.mode)
	_check("بیرون ناحیه گذاری شروع نشد", changing.is_empty())

	# یک فریم داخل ناحیه: گذار همان فریم شروع می‌شود
	var inside := Vector2(12 * TILE, 6 * TILE)
	d.update(inside)
	_check("ورود به ناحیه گذار را شروع کرد", changing.size() == 1,
		"= %d" % changing.size())
	_check("حالت فوراً side شد (نما نرم می‌رود، نه منطق)", d.mode == "side",
		"= %s" % d.mode)
	_check("شناسهٔ ناحیه ثبت شد", d.active_zone() == "challenge_a",
		"= %s" % d.active_zone())

	# ۱۲ فریم تا نگاشت کنترل
	for i in CameraDirector.remap_frames():
		d.update(inside)
	_check("نگاشت کنترل دقیقاً بعد از ۱۲ فریم", remapped.size() == 1,
		"= %d بار" % remapped.size())
	_check("گذار هنوز تمام نشده", d.is_blending())

	# تا فریم ۳۶ ام
	var left := CameraDirector.blend_frames() - CameraDirector.remap_frames()
	for i in left - 1:
		d.update(inside)
	_check("یک فریم مانده، هنوز در گذار است", d.is_blending(), "= %.2f" % d.blend_t())
	d.update(inside)
	_check("گذار دقیقاً در فریم ۳۶ تمام شد", not d.is_blending())
	_check("mode_changed یک بار آمد", changed.size() == 1, "= %d" % changed.size())

	# بازگشت بیرون ناحیه
	d.update(outside)
	_check("خروج از ناحیه به حالت پیش‌فرض برگشت", d.mode == "topdown", "= %s" % d.mode)
	_check("گذار برگشت هم شروع شد", changing.size() == 2, "= %d" % changing.size())
	d.queue_free()


func _t_input_skip() -> void:
	print("— نادیده‌گرفتن یک فریم ورودی —")
	var d := _make()
	var inside := Vector2(12 * TILE, 6 * TILE)
	_check("پیش از گذار ورودی خوانده می‌شود", not d.should_ignore_input())
	d.update(inside)
	_check("فریم گذار ورودی نادیده گرفته می‌شود", d.should_ignore_input())
	d.update(inside)
	_check("فریم بعد ورودی دوباره خوانده می‌شود", not d.should_ignore_input())
	d.queue_free()


func _t_presentation() -> void:
	print("— نمای دوربین نرم درون‌یابی می‌شود —")
	var d := _make()
	var inside := Vector2(12 * TILE, 6 * TILE)
	var start: Dictionary = d.presentation()
	_check("پیش از گذار نمای topdown است",
		is_equal_approx(float(start["zoom"]), 1.0), "= %.2f" % start["zoom"])
	d.update(inside)
	var mid_zoom := 0.0
	for i in CameraDirector.blend_frames() / 2:
		d.update(inside)
	mid_zoom = float(d.presentation()["zoom"])
	_check("وسط گذار زوم بین دو حالت است", mid_zoom > 1.0 and mid_zoom < 1.15,
		"= %.3f" % mid_zoom)
	for i in CameraDirector.blend_frames():
		d.update(inside)
	_check("پایان گذار نمای side است",
		is_equal_approx(float(d.presentation()["zoom"]), 1.15),
		"= %.2f" % d.presentation()["zoom"])
	d.queue_free()


func _t_profile() -> void:
	print("— پروفایل tuning از حالت می‌آید، نه دستی —")
	var d := _make()
	_check("topdown → پروفایل topdown", d.profile_name() == "topdown",
		"= %s" % d.profile_name())
	d.force_mode("side")
	_check("side → پروفایل challenge_side", d.profile_name() == "challenge_side",
		"= %s" % d.profile_name())
	var tuning := _load_tuning()
	_check("هر دو پروفایل در tuning.json هستند",
		tuning.has("topdown") and tuning.has("challenge_side"),
		"= %s" % str(tuning.keys()))
	d.queue_free()


func _load_tuning() -> Dictionary:
	var f := FileAccess.open("res://data/tuning.json", FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	return (parsed as Dictionary).get("profiles", {})


func _t_loader() -> void:
	print("— خواندن فیلدهای دوربین از JSON مرحله —")
	var loader := LevelLoader.new()
	var level := loader.load_level("res://levels/data/ch1_l1.json")
	_check("مرحله بار شد", not level.is_empty())
	if level.is_empty():
		return
	_check("camera_mode پر شد", level.has("camera_mode"), "= %s" % level.get("camera_mode", "-"))
	_check("camera_follow پیش‌فرض follow است", level.get("camera_follow", "") == "follow",
		"= %s" % level.get("camera_follow", "-"))
	_check("camera_zones آرایه است", typeof(level.get("camera_zones", null)) == TYPE_ARRAY)

	# ناحیهٔ خراب باید خطا بدهد، نه بی‌صدا رد شود
	var bad := LevelLoader.new()
	bad.errors.clear()
	var fake := {
		"id": "t", "camera_mode": "topdown", "start_room": "r1",
		"camera_zones": [
			{"id": "ok", "mode": "side", "rect": [1, 1, 2, 2]},
			{"id": "ok", "mode": "side", "rect": [3, 3, 2, 2]},
			{"id": "no_rect", "mode": "side"},
			{"id": "zero", "mode": "side", "rect": [0, 0, 0, 4]},
			{"id": "badmode", "mode": "diagonal", "rect": [5, 5, 2, 2]},
		],
		"rooms": [{"id": "r1", "tiles": []}],
	}
	bad._normalize_camera(fake)
	_check("شناسهٔ تکراری، rect نبود، اندازهٔ صفر و حالت نامعتبر خطا دادند",
		bad.errors.size() == 4, "= %d خطا" % bad.errors.size())
	_check("فقط ناحیهٔ سالم ماند", (fake["camera_zones"] as Array).size() == 1,
		"= %d" % (fake["camera_zones"] as Array).size())


## اندازهٔ کاشی در چند فایل تکرار شده (ترتیب بارگذاری GDScript اجازهٔ ارجاع
## به ثابت کلاس دیگر در `const` را نمی‌دهد). این سنجه مانع واگرایی‌شان است —
## همان چیزی که یک بار پیش آمد و عددهای «بر حسب کاشی» را دو برابر کرد.
func _t_scale() -> void:
	print("— اندازهٔ کاشی همه‌جا یکی است —")
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


# ----------------------------- T6: دوربین نرم -----------------------------

func _make_camera(bounds: Rect2, mode: String) -> Array:
	var d := CameraDirector.new()
	add_child(d)
	d.setup("topdown", [], TILE)
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
	print("— دنبال کردن نرم و حد لبهٔ مرحله —")
	# نقشه باید از صفحه (۱۲۸۰×۷۲۰) **به‌قدر کافی** بزرگ‌تر باشد، وگرنه
	# دوربین هیچ آزادی حرکتی ندارد و آزمون چیزی را نمی‌سنجد.
	# ۶۰×۴۰ کاشی = ۱۹۲۰×۱۲۸۰، یعنی ۶۴۰ پیکسل آزادی در هر محور.
	var map := Rect2(0, 0, 60 * TILE, 40 * TILE)
	var made := _make_camera(map, GameCamera.FOLLOW)
	var body: CharacterBody2D = made[1]
	var cam: GameCamera = made[2]

	body.global_position = map.get_center()
	cam.snap_to_target()
	var start := cam.global_position

	# هدف را دور می‌بریم ولی **درون مرز**، تا دوربین واقعاً بتواند برسد
	body.global_position = map.get_center() + Vector2(400, 0)
	# به‌جای «یک فریم» پرش هر فریم را در ۳۰ فریم نمونه می‌گیریم: قرارداد
	# واقعی این است که دوربین **نرم** برود، یعنی هیچ فریمی پرش بزرگ نداشته
	# باشد و مجموع حرکت صفر نماند. سنجهٔ تک‌فریمی به ترتیب اجرای فریم اول
	# حساس بود، که چیزی دربارهٔ نرمی نمی‌گوید.
	var prev := start
	var max_step := 0.0
	var moved := 0.0
	for i in 30:
		await _frames(1)
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

	# حد لبه: هدف را به گوشه ببر
	body.global_position = Vector2(0, 0)
	await _frames(240)
	var half := cam.get_viewport_rect().size * 0.5 / cam.zoom.x
	_check("دوربین از لبهٔ چپ نقشه بیرون نمی‌زند",
		cam.global_position.x >= half.x - 1.0,
		"= %.0f (حد %.0f)" % [cam.global_position.x, half.x])
	_check("دوربین از لبهٔ بالای نقشه بیرون نمی‌زند",
		cam.global_position.y >= half.y - 1.0,
		"= %.0f (حد %.0f)" % [cam.global_position.y, half.y])

	# نقشهٔ کوچک‌تر از صفحه: وسطش را نشان بده نه لبه‌اش
	var small := Rect2(0, 0, 10 * TILE, 6 * TILE)
	cam.set_bounds(small)
	body.global_position = Vector2(0, 0)
	await _frames(120)
	_check("نقشهٔ کوچک‌تر از صفحه وسط‌چین می‌شود",
		cam.global_position.is_equal_approx(small.get_center().round()),
		"= %s (مرکز %s)" % [str(cam.global_position), str(small.get_center())])

	_check("موقعیت دوربین عدد صحیح است (نیم‌پیکسل ممنوع)",
		is_equal_approx(cam.global_position.x, roundf(cam.global_position.x))
		and is_equal_approx(cam.global_position.y, roundf(cam.global_position.y)),
		"= %s" % str(cam.global_position))

	# حالت room: قفل روی مرکز اتاق، بی‌اعتنا به هدف
	var made2 := _make_camera(map, GameCamera.ROOM)
	var body2: CharacterBody2D = made2[1]
	var cam2: GameCamera = made2[2]
	var room := Rect2(0, 0, 30 * TILE, 17 * TILE)
	cam2.set_room(room)
	body2.global_position = room.get_center() + Vector2(300, 200)
	await _frames(30)
	_check("حالت room روی مرکز اتاق قفل است",
		cam2.global_position.is_equal_approx(_clamp_center(room, map, cam2)),
		"= %s" % str(cam2.global_position))

	for n in [made[0], body, cam, made2[0], body2, cam2]:
		n.queue_free()


func _clamp_center(room: Rect2, map: Rect2, cam: GameCamera) -> Vector2:
	var half := cam.get_viewport_rect().size * 0.5 / cam.zoom.x
	var c := room.get_center()
	c.x = clampf(c.x, map.position.x + half.x, map.position.x + map.size.x - half.x)
	c.y = clampf(c.y, map.position.y + half.y, map.position.y + map.size.y - half.y)
	return c.round()


func _t_no_jitter() -> void:
	print("— مرز camera_zone نمی‌لرزد (هیسترزیس) —")
	var d := CameraDirector.new()
	add_child(d)
	d.setup("topdown", [{"id": "z", "mode": "side", "rect": [10, 5, 6, 4]}], TILE)

	# دقیقاً روی لبهٔ چپ ناحیه، با نوسان یک‌پیکسلی — بدترین حالت
	var edge := float(10 * TILE)
	var changes := [0]
	d.mode_changing.connect(func(_f, _t): changes[0] += 1)

	# اول وارد ناحیه شو و بگذار گذار تمام شود
	for i in CameraDirector.blend_frames() + 2:
		d.update(Vector2(edge + 20.0, 6 * TILE))
	_check("ورود به ناحیه یک گذار داشت", changes[0] == 1, "= %d" % changes[0])

	# حالا روی لبه بلرز: یک پیکسل داخل، یک پیکسل بیرون، ۶۰ بار
	for i in 60:
		var x := edge + (1.0 if i % 2 == 0 else -1.0)
		d.update(Vector2(x, 6 * TILE))
	_check("نوسان یک‌پیکسلی روی لبه گذار تازه نساخت", changes[0] == 1,
		"= %d گذار (باید ۱ بماند)" % changes[0])
	_check("حالت همچنان side است", d.mode == "side", "= %s" % d.mode)

	# دور شدن واقعی باید حالت را برگرداند
	for i in CameraDirector.blend_frames() + 2:
		d.update(Vector2(edge - CameraDirector.ZONE_HYSTERESIS - 8.0, 6 * TILE))
	_check("دور شدن واقعی حالت را برگرداند", d.mode == "topdown", "= %s" % d.mode)
	_check("و گذار دوم ثبت شد", changes[0] == 2, "= %d" % changes[0])
	d.queue_free()


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
