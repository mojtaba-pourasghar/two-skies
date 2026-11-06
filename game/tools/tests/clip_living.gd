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
## ضبط دوم: همان اتاق با افکت‌ها خاموش. کاربر خواست هر دو را ببیند تا
## بتواند قضاوت کند افکت چه اضافه کرده — نه فقط عددش را بخواند.
const OUT_OFF := "user://living_off/"
## بازیکن **حرکت نمی‌کند**: هر چه تکان می‌خورد از خود محیط است.
const SECONDS: float = 10.0
const EVERY: int = 2
## **آستانهٔ مطلق جواب نمی‌دهد.** اختلاف پیکسلی با روشنایی اتاق بالا و
## پایین می‌رود: R1a روشن ۰٫۰۰۰۵۲ داد و R1b تاریک با همان مقدار حرکت
## ۰٫۰۰۰۲۳ — یعنی عدد ثابت، اتاق تاریک را به‌خاطر تاریک بودنش رد می‌کند،
## نه به‌خاطر مرده بودنش.
##
## پس هر اتاق با **خودش** سنجیده می‌شود: همان ده ثانیه دو بار ضبط
## می‌شود، بار دوم با همهٔ گره‌های `LivingLayer` پنهان. نسبت این دو
## مستقل از روشنایی است.
const LIVE_RATIO: float = 8.0
## و یک کف مطلق **خیلی** کوچک، فقط برای وقتی اتاق ساکن هم صفر است و
## نسبت از تقسیم بر نویز درمی‌آید.
##
## اولین عددی که گذاشتم (۰٫۰۰۰۰۸) دوباره همان دام بود: R1b و R1c با
## نسبت ۱۲ و ۱۵ رد شدند، چون تاریک‌اند و اختلاف مطلقشان کوچک است. کف
## باید در حد **کف اندازه‌گیری** باشد، نه در حد «چقدر حرکت می‌خواهم».
const ABS_FLOOR: float = 0.00002

var _game: Node2D
var _room_id: String = "r1a_living"
var _n: int = 0
var _prev: Image = null
var _diffs: Array[float] = []
var _dir: String = OUT


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--room="):
			_room_id = a.substr(7)
	DirAccess.make_dir_recursive_absolute(OUT)
	DirAccess.make_dir_recursive_absolute(OUT_OFF)
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
	var live_avg := _avg()

	# پاس دوم: همان اتاق، با لایه‌های زنده پنهان. شیدرها از TIME
	# می‌خوانند پس «مکث» نمی‌شوند؛ پنهان کردن تنها راه درستِ گرفتن
	# تصویر ساکنِ همین اتاق است.
	for n in get_tree().get_nodes_in_group(RoomEffects.GROUP):
		if n is CanvasItem:
			(n as CanvasItem).visible = false
	_prev = null
	_diffs.clear()
	_n = 0
	_dir = OUT_OFF
	DirAccess.make_dir_recursive_absolute(_dir)
	for i in frames:
		await get_tree().physics_frame
		await _grab()
	var static_avg := _avg()

	var living: Dictionary = room.living_layers()
	var sources := int(living["sources"])
	var ratio: float = live_avg / maxf(static_avg, 0.0000005)

	print("")
	print("— پذیرش زنده بودن: %s —" % _room_id)
	print("  گره‌های متحرک در LivingLayer: %d (حرکت %d، ذره %d، نور %d)"
		% [sources, int(living["motion"]), int(living["particles"]),
			int(living["lights"])])
	print("  اختلاف فریم‌به‌فریم زنده: %.5f" % live_avg)
	print("  همان اتاق با لایه‌های پنهان: %.5f" % static_avg)
	print("  نسبت: %.0f برابر (لازم %.0f)؛ کف مطلق %.5f" % [ratio, LIVE_RATIO, ABS_FLOOR])

	var ok_nodes := sources >= 3
	var ok_motion := ratio >= LIVE_RATIO and live_avg >= ABS_FLOOR
	if not ok_nodes:
		print("  ✘ کمتر از ۳ گرهٔ متحرک")
	if not ok_motion:
		print("  ✘ تصویر عملاً همان اتاق ساکن است — گره هست ولی اثری ندارد")
	if ok_nodes and ok_motion:
		print("  ✔ اتاق زنده است")
		get_tree().quit(0)
	else:
		get_tree().quit(1)


func _avg() -> float:
	var t := 0.0
	for d in _diffs:
		t += d
	return t / float(maxi(1, _diffs.size()))


func _grab() -> void:
	_n += 1
	if _n % EVERY != 0:
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png(_dir + "f%05d.png" % _n)
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
