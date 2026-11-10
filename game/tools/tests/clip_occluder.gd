## ضبط عبور از پشت مبل — اثبات بسته شدن REQ-010
##
##   godot --path game --fixed-fps 60 --resolution 1280x720 \
##     res://tools/tests/clip_occluder.tscn
##
## کایرو از جلوی مبل، پشتش، و دوباره جلو رد می‌شود. چیزی که باید دیده
## شود: وقتی پشت مبل است پنهان می‌شود و وقتی بیرون می‌آید برمی‌گردد —
## بدون پرش و بدون نصفه ماندن.
extends Node2D

const OUT := "user://occ/"
const EVERY: int = 2

var _game: Node2D
var _n: int = 0
var _hidden_frames: int = 0
var _seen_frames: int = 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
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
	var il = _game.get("ilara")
	if il != null:
		il.set_order(TdIlara.Order.STAY)
		il.global_position = Vector2(140, 660)

	# **مسیر از BFS روی ماسک آمد، نه از حدس.** تلاش اول با جهت‌های ثابت
	# هرگز پشت مبل نرسید (صفر فریم) و ضبط چیزی را ثابت نمی‌کرد: نوار
	# باریک بین مبل و دیوار پشتی فقط از سمت چپ راه دارد.
	kairo.global_position = Vector2(250, 640)
	await _hold(20)
	for wp in [Vector2(272, 560), Vector2(280, 480), Vector2(300, 440),
			Vector2(340, 410), Vector2(390, 376), Vector2(432, 350)]:
		await _goto(kairo, wp, 220)
	await _hold(40)                      # همین‌جا پشت مبل می‌ماند
	for wp in [Vector2(340, 410), Vector2(280, 490), Vector2(300, 600)]:
		await _goto(kairo, wp, 220)
	await _hold(24)

	print("")
	print("— عبور از پشت مبل —")
	print("  فریم ضبط‌شده: %d" % (_n / EVERY))
	print("  فریمی که کایرو پشت خط مبل بود: %d" % _hidden_frames)
	print("  فریمی که جلوتر بود: %d" % _seen_frames)
	# اگر هیچ فریمی پشت مبل نبوده، ضبط چیزی را ثابت نمی‌کند
	get_tree().quit(0 if _hidden_frames > 30 and _seen_frames > 30 else 1)


## به یک نقطه می‌رود؛ اگر گیر کرد محورها را امتحان می‌کند.
func _goto(actor, target: Vector2, max_frames: int) -> void:
	var tries := [Vector2.ZERO, Vector2.UP, Vector2.LEFT, Vector2.DOWN, Vector2.RIGHT]
	var pick := 0
	var stuck := 0
	var last := Vector2.ZERO
	for i in max_frames:
		if not is_instance_valid(actor):
			return
		var to: Vector2 = target - actor.foot_position()
		if to.length() < 10.0:
			actor.set("scripted_dir", Vector2.ZERO)
			return
		var dir: Vector2 = to.normalized()
		if pick > 0:
			dir = tries[pick]
		actor.set("scripted_dir", dir)
		await get_tree().physics_frame
		await _grab(actor)
		var moved: float = actor.foot_position().distance_to(last)
		last = actor.foot_position()
		if moved < 0.4:
			stuck += 1
			if stuck > 12:
				pick = (pick + 1) % tries.size()
				stuck = 0
		else:
			stuck = 0
			if moved > 1.2:
				pick = 0
	actor.set("scripted_dir", Vector2.ZERO)


func _hold(frames: int) -> void:
	var kairo = _game.get("kairo")
	if kairo != null:
		kairo.set("scripted_dir", Vector2.ZERO)
	for i in frames:
		await get_tree().physics_frame
		await _grab(kairo)


## آیا این نقطه داخل شکل مبل است؟ (همان چندضلعی `cut` در دادهٔ اتاق)
func _in_sofa(p: Vector2) -> bool:
	var rm = _game.get("room")
	if rm == null or not is_instance_valid(rm):
		return false
	for raw in rm.data.get("occluders", []):
		var o: Dictionary = raw
		if String(o.get("id", "")) != "sofa":
			continue
		return Geometry2D.is_point_in_polygon(p, RoomData.to_polygon(o["cut"]))
	return false


func _grab(actor) -> void:
	_n += 1
	if actor != null and is_instance_valid(actor):
		# ۵۱۲ همان `base_y` مبل است
		# «پشت مبل» یعنی داخل خود شکل مبل، نه فقط بالای خط
		if _in_sofa(actor.foot_position()):
			_hidden_frames += 1
		else:
			_seen_frames += 1
	if _n % EVERY != 0:
		return
	get_viewport().get_texture().get_image().save_png(OUT + "f%05d.png" % _n)
