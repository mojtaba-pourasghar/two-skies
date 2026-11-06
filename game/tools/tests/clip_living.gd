## ضبط ۱۰ ثانیه از یک اتاق و سنجش «زنده بودن» — سند ۱۳، بخش پذیرش
##
##   godot --path game --fixed-fps 60 res://tools/tests/clip_living.tscn -- --room=r1a_living
##
## دو چیز را می‌سنجد، و هر دو لازم‌اند:
##   ۱ **عدد:** دست‌کم ۳ گره در گروه `LivingLayer`
##   ۲ **تصویر:** میانگین اختلاف فریم‌به‌فریم پس‌زمینه بیشتر از ε
##
## چرا هر دو: گره‌ها می‌توانند باشند و هیچ‌کدام تکان نخورند (شیدر خراب،
## ذرهٔ خاموش، انیمیشن بی‌فریم). آن‌وقت شمارش سبز است و صفحه مرده. این
## دقیقاً همان کلاس نقصی است که چهار بار در این پروژه پیش آمد.
extends Node2D

const OUT := "user://living/"
## بازیکن **حرکت نمی‌کند**: هر چه تکان می‌خورد از خود محیط است.
const SECONDS: float = 10.0
const EVERY: int = 2
## آستانهٔ اختلاف: میانگین قدر مطلق تفاوت کانال، بر حسب ۰..۱.
##
## **اندازه‌گیری شد، حدس نیست.** `r1a_static_probe` همان R1a است با همهٔ
## لایه‌های زنده برداشته‌شده؛ ضبط ۱۰ ثانیه‌اش ۰٫۰۰۰۰۲ داد. R1a زنده
## ۰٫۰۰۱۳۵ می‌دهد، یعنی ۶۷ برابر. آستانه ۰٫۰۰۰۳ است: ۱۵ برابر کفِ ساکن،
## و با فاصلهٔ ۴ برابری زیر اتاق زنده. اولین عددی که نوشتم (۰٫۰۰۱۵) از
## هوا آمده بود و R1a را به‌غلط رد می‌کرد.
const EPSILON: float = 0.0003
## کف اندازه‌گیری‌شدهٔ اتاق ساکن، برای مقایسه در گزارش.
const STATIC_FLOOR: float = 0.00002

var _game: Node2D
var _room_id: String = "r1a_living"
var _n: int = 0
var _prev: Image = null
var _diffs: Array[float] = []


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--room="):
			_room_id = a.substr(7)
	DirAccess.make_dir_recursive_absolute(OUT)
	_game = load("res://scenes/room_game.tscn").instantiate()
	_game.set("start_room", _room_id)
	add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame
	await _run()


func _run() -> void:
	var room = _game.get("room")
	if room == null:
		push_error("اتاق «%s» ساخته نشد" % _room_id)
		get_tree().quit(1)
		return
	var kairo = _game.get("kairo")
	if kairo != null:
		kairo.set("use_scripted", true)
		kairo.set("scripted_dir", Vector2.ZERO)

	var frames := int(SECONDS * 60.0)
	for i in frames:
		await get_tree().physics_frame
		await _grab()

	var living: Dictionary = room.living_layers()
	var sources := int(living["sources"])
	var avg := 0.0
	for d in _diffs:
		avg += d
	avg = avg / float(maxi(1, _diffs.size()))

	print("")
	print("— پذیرش زنده بودن: %s —" % _room_id)
	print("  گره‌های متحرک در LivingLayer: %d (حرکت %d، ذره %d، نور %d)"
		% [sources, int(living["motion"]), int(living["particles"]),
			int(living["lights"])])
	print("  میانگین اختلاف فریم‌به‌فریم: %.5f (آستانه %.5f، کفِ اتاق ساکن %.5f)"
		% [avg, EPSILON, STATIC_FLOOR])
	print("  یعنی %.0f برابر اتاق ساکن" % (avg / maxf(STATIC_FLOOR, 0.000001)))
	print("  فریم ذخیره‌شده: %d در %s" % [_diffs.size(), OUT])

	var ok_nodes := sources >= 3
	var ok_motion := avg > EPSILON
	if not ok_nodes:
		print("  ✘ کمتر از ۳ گرهٔ متحرک")
	if not ok_motion:
		print("  ✘ تصویر عملاً ثابت است — گره هست ولی چیزی تکان نمی‌خورد")
	if ok_nodes and ok_motion:
		print("  ✔ اتاق زنده است")
		get_tree().quit(0)
	else:
		get_tree().quit(1)


func _grab() -> void:
	_n += 1
	if _n % EVERY != 0:
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + "f%05d.png" % _n)
	if _prev != null:
		_diffs.append(_mean_diff(_prev, img))
	_prev = img


## میانگین اختلاف دو فریم. نمونه‌برداری شبکه‌ای است نه کامل: ۱۲۸۰×۷۲۰ در
## ۳۰۰ فریم یعنی ۲۷۶ میلیون پیکسل، و آزمون نباید دقیقه‌ها طول بکشد.
static func _mean_diff(a: Image, b: Image) -> float:
	var step := 8
	var total := 0.0
	var count := 0
	var w: int = mini(a.get_width(), b.get_width())
	var h: int = mini(a.get_height(), b.get_height())
	var y := 0
	while y < h:
		var x := 0
		while x < w:
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			total += absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)
			count += 3
			x += step
		y += step
	return total / float(maxi(1, count))
