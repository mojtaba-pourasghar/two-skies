## ضبط تمام کردن کوچهٔ لیزری — اثبات M5-ب
##
##   godot --path game --fixed-fps 60 --resolution 1280x720 \
##     res://tools/tests/clip_challenge.tscn
##
## کایرو سه پایانه را هک می‌کند و از دری که اولش بسته بود بیرون می‌رود.
## دکمهٔ هک با `Input.action_press` فشرده می‌شود، نه با صدا زدن مستقیم
## `room.hack()`: وگرنه ضبط فقط موتور را نشان می‌دهد، نه بازی را.
extends Node2D

const OUT := "user://chal/"
const EVERY: int = 2

## مسیرها از BFS روی ماسک، با خطرهای خاموش‌شدهٔ هر مرحله.
const LEGS := [
	["c2_relay_a", [
		Vector2(640, 648), Vector2(616, 648), Vector2(592, 648), Vector2(568, 648),
		Vector2(544, 648), Vector2(520, 648), Vector2(496, 648), Vector2(472, 648),
		Vector2(448, 636), Vector2(424, 612), Vector2(400, 588), Vector2(376, 564),
		Vector2(372, 560),
	]],
	["c2_relay_b", [
		Vector2(372, 560), Vector2(396, 560), Vector2(420, 560), Vector2(444, 560),
		Vector2(468, 560), Vector2(492, 560), Vector2(516, 560), Vector2(540, 560),
		Vector2(564, 560), Vector2(588, 560), Vector2(612, 560), Vector2(636, 560),
		Vector2(660, 560), Vector2(684, 560), Vector2(708, 552), Vector2(732, 528),
		Vector2(756, 504), Vector2(780, 480), Vector2(804, 456), Vector2(828, 432),
		Vector2(852, 408), Vector2(876, 384), Vector2(900, 360), Vector2(920, 340),
	]],
	["c2_relay_c", [
		Vector2(920, 340), Vector2(896, 344), Vector2(872, 368), Vector2(848, 392),
		Vector2(824, 416), Vector2(800, 440), Vector2(776, 464), Vector2(752, 484),
		Vector2(728, 484), Vector2(704, 484), Vector2(680, 484), Vector2(656, 484),
		Vector2(632, 484), Vector2(608, 484), Vector2(584, 484), Vector2(560, 484),
		Vector2(536, 484), Vector2(532, 460), Vector2(532, 436), Vector2(532, 412),
		Vector2(532, 388), Vector2(524, 364), Vector2(500, 340), Vector2(476, 316),
		Vector2(452, 292), Vector2(428, 268), Vector2(404, 244), Vector2(380, 220),
		Vector2(372, 212),
	]],
	["", [
		Vector2(372, 212), Vector2(396, 212), Vector2(420, 200), Vector2(444, 176),
		Vector2(468, 152), Vector2(492, 128), Vector2(516, 104), Vector2(540, 84),
		Vector2(564, 84), Vector2(588, 84), Vector2(612, 92), Vector2(636, 116),
		Vector2(640, 120),
	]],
]

var _game: Node2D
var _n: int = 0
var _hacked: Array[String] = []
var _deaths_before: int = 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	# هر اجرای ضبط از نو: پرچم‌های هک قبلی پاک شوند
	for k in GameState.run.get("flags", {}).keys():
		if String(k).begins_with("hacked_"):
			GameState.set_flag(String(k), false)
	_game = load("res://scenes/room_game.tscn").instantiate()
	_game.set("start_room", "c2_laser_alley")
	add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame
	_game.connect("hack_done", func(id): _hacked.append(id))
	await _run()


func _run() -> void:
	var kairo = _game.get("kairo")
	if kairo == null:
		push_error("کایرو ساخته نشد")
		get_tree().quit(1)
		return
	kairo.set("use_scripted", true)
	_deaths_before = int(GameState.run.get("deaths", 0))
	await _hold(40)
	for leg in LEGS:
		print("  مرحله: %s (%d نقطه)" % [str(leg[0]), (leg[1] as Array).size()])
		for p in leg[1]:
			await _goto(kairo, p, 200)
		print("    رسید؛ پا در %s" % str(_game.get("kairo").foot_position().round()))
		if String(leg[0]) != "":
			await _do_hack(String(leg[0]))
			print("    هک: %s" % str(_hacked))
	await _hold(40)

	var room = _game.get("room")
	var in_room := room != null and is_instance_valid(room) \
		and String(room.data.get("id", "")) == "c2_laser_alley"
	print("")
	print("— تمام کردن کوچهٔ لیزری —")
	print("  فریم ضبط‌شده: %d" % (_n / EVERY))
	print("  پایانه‌های هک‌شده: %s" % str(_hacked))
	print("  مرگ در این اجرا: %d" % (int(GameState.run.get("deaths", 0)) - _deaths_before))
	print("  هنوز در کوچه است: %s" % str(in_room))
	get_tree().quit(0 if _hacked.size() == 3 and not in_room else 1)


## نزدیک پایانه می‌ایستد و دکمه را نگه می‌دارد تا هک تمام شود.
func _do_hack(hid: String) -> void:
	Input.action_press("action")
	for i in 150:
		await get_tree().physics_frame
		await _grab()
		if not is_instance_valid(_game):
			break
		if hid in _hacked:
			break
	Input.action_release("action")
	await _hold(30)


func _goto(actor, target: Vector2, max_frames: int) -> void:
	var last := Vector2.ZERO
	var stuck := 0
	for i in max_frames:
		if not is_instance_valid(actor):
			return
		var to: Vector2 = target - actor.foot_position()
		if to.length() < 12.0:
			actor.set("scripted_dir", Vector2.ZERO)
			return
		actor.set("scripted_dir", to.normalized())
		await get_tree().physics_frame
		await _grab()
		# **بعد از هر await دوباره سنجیده می‌شود:** عبور از در وسط همین
		# دو خط، بازیگر را آزاد می‌کند و صدا زدن متدش روی نمونهٔ آزادشده
		# موتور را می‌خواباند (segfault، نه خطای اسکریپت).
		if not is_instance_valid(actor):
			return
		var moved: float = actor.foot_position().distance_to(last)
		last = actor.foot_position()
		stuck = stuck + 1 if moved < 0.4 else 0
		if stuck > 40:
			break
	actor.set("scripted_dir", Vector2.ZERO)


func _hold(frames: int) -> void:
	var kairo = _game.get("kairo")
	if kairo != null and is_instance_valid(kairo):
		kairo.set("scripted_dir", Vector2.ZERO)
	for i in frames:
		await get_tree().physics_frame
		await _grab()
		kairo = _game.get("kairo")
		if kairo != null and is_instance_valid(kairo):
			kairo.set("scripted_dir", Vector2.ZERO)


func _grab() -> void:
	_n += 1
	if _n % EVERY != 0:
		return
	get_viewport().get_texture().get_image().save_png(OUT + "f%05d.png" % _n)
