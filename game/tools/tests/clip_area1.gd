## ضبط مسیر ناحیهٔ ۱ — پذیرش M3
##
##   godot --fixed-fps 60 --resolution 1280x720 res://tools/tests/clip_area1.tscn
##
## بازی را **واقعاً** اجرا می‌کند و کایرو را با ورودی اسکریپتی از R1a تا
## C1 و برگشت به R1b می‌برد، بی هیچ بارگذاری میانی. هر گذار در، یک ذخیره
## می‌نویسد، پس در پایان باید ذخیره‌ای از R1b باشد.
extends Node2D

const OUT := "user://area1/"
const EVERY: int = 3

var _game: Node2D
var _n: int = 0
var _visited: Array[String] = []
var _log: Array[String] = []


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	GameState.data = GameState.default_save()
	# کلید و فلش‌بک را باز می‌کنیم تا مسیر کامل ضبط شود
	GameState.set_flag("flashback_seen", true)
	GameState.set_flag("basement_key", true)
	_game = load("res://scenes/room_game.tscn").instantiate()
	_game.set("start_room", "r1a_living")
	add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame
	await _run()


func _run() -> void:
	var kairo = _game.get("kairo")
	if kairo == null:
		push_error("کایرو ساخته نشد")
		get_tree().quit(1)
		return
	kairo.set("use_scripted", true)

	# **به سمت در برو، نه به سمت یک جهت.** تلاش اول با جهت‌های ثابت فقط
	# تا R1b رسید و همان‌جا ماند: راه رفتن کور در اتاقی با مبل و ستون،
	# به در نمی‌رسد.
	await _goto_door("to_corridor", 420)     # R1a → راهرو
	# راهرو دراز است و میز شمعدان جلوی در ایوان ایستاده: بدون نقطهٔ
	# میانی، هدایت مستقیم به میز می‌چسبد و ۴۸۰ فریم آنجا می‌ماند.
	await _goto_point(Vector2(820, 470), 300)
	await _goto_point(Vector2(1060, 450), 260)
	await _goto_door("to_balcony", 420)      # R1b → ایوان
	# در ایوان، در طاقی بالا-راست است و مسیر از کنار گودال‌ها می‌گذرد
	# در ایوان مسیر یک حلقه است دور حیاط‌های فرورفته: از گوشهٔ چپ-پایین
	# بالا، روی نوار سنگ روشن، و بعد به در طاقی بالا-راست. خط مستقیم به
	# لبهٔ گودال می‌خورد.
	await _goto_point(Vector2(300, 430), 260)
	await _goto_point(Vector2(430, 300), 260)
	await _goto_point(Vector2(600, 190), 260)
	await _goto_point(Vector2(800, 150), 260)
	await _goto_door("to_corridor", 360)     # C1 → برگشت به راهرو
	await _settle()

	print("")
	print("— مسیر ناحیهٔ ۱ —")
	print("  اتاق‌های دیده‌شده: %s" % str(_visited))
	print("  فریم ضبط‌شده: %d" % (_n / EVERY))
	print("  ذخیرهٔ پایانی: %s در %s"
		% [GameState.explore_room(), str(GameState.explore_at())])
	for line in _log:
		print("  %s" % line)
	get_tree().quit(0 if _visited.size() >= 4 else 1)


## به یک نقطهٔ دلخواه در همین اتاق می‌رود (نقطهٔ میانی مسیر).
func _goto_point(target: Vector2, max_frames: int) -> void:
	await _steer(target, max_frames, "")


## به مرکز دری با این شناسه می‌رود و همان‌جا می‌ایستد تا اتاق عوض شود.
## هدایت ساده است: جهت را به سمت هدف می‌گیرد و اگر گیر کرد، محورها را
## یکی‌یکی امتحان می‌کند — همان کاری که بازیکن می‌کند.
func _goto_door(door_id: String, max_frames: int) -> void:
	var rm = _game.get("room")
	if rm == null or not is_instance_valid(rm):
		return
	var from_room := String(rm.data.get("id", "?"))
	var target := Vector2.ZERO
	var found := false
	for raw in rm.data.get("doors", []):
		var d: Dictionary = raw
		if String(d.get("id", "")) == door_id:
			var r: Array = d.get("rect", [0, 0, 0, 0])
			target = Vector2(float(r[0]) + float(r[2]) * 0.5,
				float(r[1]) + float(r[3]) * 0.5)
			found = true
	if not found:
		_log.append("✘ در «%s» در اتاق «%s» نیست" % [door_id, from_room])
		return
	await _steer(target, max_frames, door_id)


## هدایت ساده به سمت یک نقطه. اگر گیر کرد، محورها را یکی‌یکی امتحان
## می‌کند — همان کاری که بازیکن پشت مبل می‌کند.
##
## با `door_id` غیرخالی، به‌محض عوض شدن اتاق تمام می‌شود و گزارش می‌دهد.
func _steer(target: Vector2, max_frames: int, door_id: String) -> void:
	var rm = _game.get("room")
	if rm == null or not is_instance_valid(rm):
		return
	var from_room := String(rm.data.get("id", "?"))
	var stuck := 0
	var last := Vector2.ZERO
	var tries := [Vector2.ZERO, Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]
	var pick := 0
	for i in max_frames:
		var kairo = _game.get("kairo")
		# **گره آزادشده هنوز نول نیست.** در لحظهٔ گذار اتاق، اتاق قبلی
		# `queue_free` می‌شود و کایروی قدیمی با آن می‌رود، ولی ارجاع
		# `_game.kairo` تا ساخته شدن کایروی تازه همان را نگه می‌دارد.
		# صدا زدن متدی روی آن، بازی را با segfault می‌خواباند — همین
		# اتفاق در اولین اجرای این ضبط افتاد.
		if kairo == null or not is_instance_valid(kairo):
			await get_tree().physics_frame
			continue
		# **کایروی هر اتاق تازه است.** `use_scripted` روی نمونهٔ قبلی
		# تنظیم شده بود، پس بعد از اولین گذار در، ورودی اسکریپتی خوانده
		# نمی‌شد و بازیکن همان‌جا خشک می‌ماند. هر فریم تنظیمش می‌کنیم.
		kairo.set("use_scripted", true)
		var here: Vector2 = kairo.foot_position()
		var to := target - here
		if door_id == "" and to.length() < 14.0:
			kairo.set("scripted_dir", Vector2.ZERO)
			_log.append("· نقطهٔ میانی %s رسید" % str(target.round()))
			return
		var dir := to.normalized() if to.length() > 6.0 else Vector2.ZERO
		if pick > 0:
			dir = tries[pick]
		kairo.set("scripted_dir", dir)
		await get_tree().physics_frame
		await _grab()
		await _note()

		if not is_instance_valid(kairo):
			continue
		var moved: float = kairo.foot_position().distance_to(last)
		last = kairo.foot_position()
		if moved < 0.4 and dir != Vector2.ZERO:
			stuck += 1
			if stuck > 14:
				pick = (pick + 1) % tries.size()
				stuck = 0
		else:
			stuck = 0
			if moved > 1.0 and pick > 0 and randf() < 0.08:
				pick = 0

		var now = _game.get("room")
		if door_id != "" and now != null and is_instance_valid(now) \
				and String(now.data.get("id", "?")) != from_room:
			var to_id := String(now.data.get("id", "?"))
			_log.append("✔ «%s» → «%s» از در «%s» در فریم %d"
				% [from_room, to_id, door_id, i])
			var il = _game.get("ilara")
			if il != null and not is_instance_valid(il):
				il = null
			if RoomGame.is_challenge(now.data):
				_log.append("   اتاق چالش است؛ ایلارا %s"
					% ("وارد شد ✘" if il != null else "بیرون ماند ✔"))
			else:
				_log.append("   اتاق عادی است؛ ایلارا %s"
					% ("همراه است ✔" if il != null else "گم شد ✘"))
			var k2 = _game.get("kairo")
			if k2 != null and is_instance_valid(k2):
				k2.set("scripted_dir", Vector2.ZERO)
			await _settle()
			return
	if door_id != "":
		var k3 = _game.get("kairo")
		var where := "؟"
		if k3 != null and is_instance_valid(k3):
			where = str(k3.foot_position().round())
		_log.append("✘ از «%s» از در «%s» رد نشد (%d فریم)؛ آخرین جا %s، هدف %s"
			% [from_room, door_id, max_frames, where, str(target.round())])


func _note() -> void:
	var rm = _game.get("room")
	if rm != null and is_instance_valid(rm):
		var id := String(rm.data.get("id", "?"))
		if _visited.is_empty() or _visited[-1] != id:
			_visited.append(id)
	await get_tree().physics_frame


func _walk(dir: Vector2, frames: int) -> void:
	var kairo = _game.get("kairo")
	for i in frames:
		# در گذار در، ورودی باید خاموش بماند وگرنه بازیکن در پرده حرکت
		# می‌کند و سر از جای غلط درمی‌آورد
		kairo = _game.get("kairo")
		if kairo != null:
			kairo.set("scripted_dir", dir)
		await get_tree().physics_frame
		await _grab()
		await _note()
	if kairo != null:
		kairo.set("scripted_dir", Vector2.ZERO)


func _settle() -> void:
	var kairo = _game.get("kairo")
	if kairo != null and is_instance_valid(kairo):
		kairo.set("scripted_dir", Vector2.ZERO)
	for i in 36:
		await get_tree().physics_frame
		await _grab()
		await _note()


func _grab() -> void:
	_n += 1
	if _n % EVERY != 0:
		return
	get_viewport().get_texture().get_image().save_png(OUT + "f%05d.png" % _n)
