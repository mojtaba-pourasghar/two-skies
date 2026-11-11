## ضبط گشت و مخروط دید — اثبات M5-ت
##
##   godot --path game --fixed-fps 60 --resolution 1280x720 \
##     res://tools/tests/clip_patrol.tscn
##
## چیزی که باید دیده شود: نگهبان روی مسیرش می‌رود و مخروط زردش با او
## می‌چرخد؛ کایرو از بیرون مخروط رد می‌شود و خبری نمی‌شود؛ بعد وارد
## مخروط می‌شود، «!» بالای سر نگهبان روشن می‌شود و مخروط نارنجی/قرمز
## می‌شود؛ کایرو عقب می‌کشد، نگهبان فراموش می‌کند و به گشت برمی‌گردد.
extends Node2D

const OUT := "user://patrol/"
const EVERY: int = 2
@export var room_id: String = "s3a_plaza"
## "spot" = دیده شدن و تعقیب؛ "sneak" = دور زدن و حملهٔ از پشت
@export var mode: String = "spot"

## مسیر از BFS و از سنجش ماسک آمده، نه از حدس.
## نقطهٔ طعمه **روی امتداد مسیر گشت** است، نه زیر آن: مخروط ۷۰ درجه در
## جهت حرکت نگهبان باز می‌شود، پس ایستادن پایینِ مسیر هرگز دیده نمی‌شود.
## بار اول همین را اشتباه گذاشتم و ضبط صفر فریمِ دیده‌شدن داد.
const BAIT := Vector2(545, 735)
const ROUTE_IN := [Vector2(440, 700), Vector2(500, 740), BAIT]
const ROUTE_OUT := [Vector2(420, 770), Vector2(300, 760), Vector2(240, 740)]

var _game: Node2D
var _n: int = 0
var _states: Dictionary = {}
var _seen_frames: int = 0
var _bang_frames: int = 0
var _guard_moved: float = 0.0
var _guard_from: Vector2 = Vector2.ZERO


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_game = load("res://scenes/room_game.tscn").instantiate()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--room="):
			room_id = a.substr(7)
		elif a.begins_with("--mode="):
			mode = a.substr(7)
	_game.set("start_room", room_id)
	add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame
	await _run()


func _guard() -> MapEnemy:
	var rm = _game.get("room")
	if rm == null or not is_instance_valid(rm):
		return null
	for m in rm.enemies:
		if is_instance_valid(m) and m.patrol.size() >= 2:
			return m
	return null


func _run() -> void:
	var kairo = _game.get("kairo")
	var g := _guard()
	if kairo == null or g == null:
		push_error("کایرو یا نگهبان ساخته نشد")
		get_tree().quit(1)
		return
	kairo.set("use_scripted", true)
	kairo.global_position = ROUTE_IN[0]
	_guard_from = g.position
	if mode == "sneak":
		await _sneak(kairo, g)
		return
	await _hold(60)                      # اول فقط گشت دیده شود
	for i in range(1, ROUTE_IN.size()):
		await _goto(kairo, ROUTE_IN[i], 220)
	# ایستادن سر راه تا نگهبان در دور بعدی گشت برسد و ببیند
	await _wait_seen(kairo, 480)
	await _hold(70)                      # «!» و شروع تعقیب دیده شود
	for p in ROUTE_OUT:
		await _goto(kairo, p, 220)
	await _hold(180)                     # فراموشی و برگشت به گشت

	print("")
	print("— گشت و مخروط دید در «%s» —" % room_id)
	print("  فریم ضبط‌شده: %d" % (_n / EVERY))
	print("  فریمی که کایرو در مخروط بود: %d" % _seen_frames)
	print("  فریمی که «!» روشن بود: %d" % _bang_frames)
	print("  جابه‌جایی نگهبان: %.0fpx" % _guard_moved)
	print("  حالت‌های دیده‌شده: %s" % str(_states.keys()))
	# ضبطی که هر چهار حالت را نشان ندهد چیزی را ثابت نمی‌کند
	get_tree().quit(0 if _states.size() >= 3 and _seen_frames > 20
		and _bang_frames > 5 and _guard_moved > 40.0 else 1)


## پنهان‌کاری و حملهٔ از پشت (سند ۰۹ §۲). کایرو پایین مسیر گشت — بیرون
## مخروط ۷۰ درجه — می‌ماند تا نگهبان **از او رد شود**، بعد از پشت
## می‌رسد. نبرد باید با `last_ambush` شروع شود.
func _sneak(kairo, g: MapEnemy) -> void:
	await _hold(90)                      # اول گشت و مخروط دیده شود
	await _goto(kairo, Vector2(470, 780), 260)
	await _goto(kairo, Vector2(600, 790), 260)
	# صبر تا نگهبان پشتش به کایرو باشد و هنوز خبردار نشده باشد
	var ok := false
	for i in 600:
		await get_tree().physics_frame
		await _grab()
		if g.is_behind(kairo.foot_position()) and not g.alerted:
			ok = true
			break
	await _hold(20)
	# حالا از پشت به او می‌خورد
	for i in 260:
		if not is_instance_valid(g) or _game.get("battle") != null:
			break
		var to: Vector2 = g.position - kairo.foot_position()
		kairo.set("scripted_dir", to.normalized())
		await get_tree().physics_frame
		await _grab()
	await _hold(60)
	print("")
	print("— حملهٔ از پشت در «%s» —" % room_id)
	print("  فریم ضبط‌شده: %d" % (_n / EVERY))
	print("  پشت نگهبان رسید: %s" % str(ok))
	print("  نبرد شروع شد: %s" % str(_game.get("battle") != null))
	print("  با امتیاز حملهٔ از پشت: %s" % str(_game.get("last_ambush")))
	print("  فریمی که کایرو در مخروط بود: %d" % _seen_frames)
	get_tree().quit(0 if ok and bool(_game.get("last_ambush")) else 1)


## می‌ایستد تا نگهبان در گشتش برسد و ببیندش. ضبط نباید به شانس زمان‌بندی
## بند باشد.
func _wait_seen(kairo, max_frames: int) -> void:
	kairo.set("scripted_dir", Vector2.ZERO)
	for i in max_frames:
		await get_tree().physics_frame
		await _grab()
		var g := _guard()
		if g != null and g.state != MapEnemy.State.PATROL:
			return


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
		var moved: float = actor.foot_position().distance_to(last)
		last = actor.foot_position()
		stuck = stuck + 1 if moved < 0.4 else 0
		if stuck > 40:
			break
	actor.set("scripted_dir", Vector2.ZERO)


func _hold(frames: int) -> void:
	var kairo = _game.get("kairo")
	if kairo != null:
		kairo.set("scripted_dir", Vector2.ZERO)
	for i in frames:
		await get_tree().physics_frame
		await _grab()


func _grab() -> void:
	_n += 1
	var g := _guard()
	var kairo = _game.get("kairo")
	if g != null and kairo != null and is_instance_valid(kairo):
		_states[g.state] = true
		_guard_moved = maxf(_guard_moved, _guard_from.distance_to(g.position))
		if g.sees(kairo.foot_position(), _game.get("room")):
			_seen_frames += 1
		var bang := g.get_node_or_null("Bang")
		if bang != null and bang.visible:
			_bang_frames += 1
	if _n % EVERY != 0:
		return
	get_viewport().get_texture().get_image().save_png(OUT + "f%05d.png" % _n)
