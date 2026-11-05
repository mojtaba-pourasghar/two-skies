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
