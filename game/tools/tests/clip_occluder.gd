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
@export var room_id: String = "r1c_kitchen"
@export var occ_id: String = "table"
const EVERY: int = 2

## مسیر هر اتاق: از جلو، به پشت شیء، و برگشت.
## مسیر هر اتاق: از جلوی شیء، به پشتش، و برگشت. **همه از BFS روی ماسک
## آمده‌اند، نه از حدس** — و نقطهٔ «پشت» همان نقطه‌ای است که آزمون
## ثابت کرده هم رفتنی است و هم پوششش از ۶۰٪ می‌گذرد. کلید یا نام اتاق
## است یا «اتاق#شناسهٔ occluder» وقتی اتاق بیش از یکی دارد.
const ROUTES := {
	# R1c: میز با صندلی وارونه (REQ-010، گام ۵۴)
	"r1c_kitchen#table": [
		Vector2(560, 620), Vector2(700, 560), Vector2(860, 430),
		Vector2(1000, 330), Vector2(1120, 320), Vector2(1000, 330),
		Vector2(820, 440), Vector2(620, 600),
	],
	"r1a_living": [
		Vector2(248, 640), Vector2(284, 640), Vector2(320, 640), Vector2(356, 640),
		Vector2(392, 640), Vector2(428, 640), Vector2(464, 640), Vector2(500, 640),
		Vector2(536, 640), Vector2(572, 640), Vector2(608, 640), Vector2(644, 640),
		Vector2(680, 640), Vector2(716, 640), Vector2(752, 664), Vector2(768, 680),
		Vector2(732, 652), Vector2(720, 616), Vector2(744, 600), Vector2(768, 600),
		Vector2(744, 600), Vector2(720, 616), Vector2(732, 652), Vector2(768, 680),
		Vector2(752, 664), Vector2(716, 640), Vector2(680, 640), Vector2(644, 640),
		Vector2(608, 640), Vector2(572, 640), Vector2(536, 640), Vector2(500, 640),
		Vector2(464, 640), Vector2(428, 640), Vector2(392, 640), Vector2(356, 640),
		Vector2(320, 640), Vector2(284, 640), Vector2(248, 640),
	],
	"r1b_corridor": [
		Vector2(600, 640), Vector2(564, 640), Vector2(528, 640), Vector2(492, 640),
		Vector2(456, 640), Vector2(420, 640), Vector2(384, 640), Vector2(348, 640),
		Vector2(312, 664), Vector2(296, 680), Vector2(332, 656), Vector2(348, 620),
		Vector2(332, 596), Vector2(296, 596), Vector2(332, 596), Vector2(348, 620),
		Vector2(332, 656), Vector2(296, 680), Vector2(312, 664), Vector2(348, 640),
		Vector2(384, 640), Vector2(420, 640), Vector2(456, 640), Vector2(492, 640),
		Vector2(528, 640), Vector2(564, 640), Vector2(600, 640),
	],
	"r1c_kitchen": [
		Vector2(560, 560), Vector2(560, 524), Vector2(560, 488), Vector2(576, 452),
		Vector2(612, 416), Vector2(648, 380), Vector2(684, 356), Vector2(700, 320),
		Vector2(680, 300), Vector2(648, 300), Vector2(680, 300), Vector2(700, 320),
		Vector2(684, 356), Vector2(648, 380), Vector2(612, 416), Vector2(576, 452),
		Vector2(560, 488), Vector2(560, 524), Vector2(560, 560),
	],
	"c1_balcony#pillar_west": [
		Vector2(260, 580), Vector2(296, 600), Vector2(332, 636), Vector2(304, 600),
		Vector2(300, 564), Vector2(332, 556), Vector2(300, 564), Vector2(304, 600),
		Vector2(332, 636), Vector2(296, 600), Vector2(260, 580),
	],
	"c1_balcony#pillar_east": [
		Vector2(1016, 328), Vector2(1052, 324), Vector2(1088, 316),
		Vector2(1104, 300), Vector2(1076, 264), Vector2(1080, 228),
		Vector2(1108, 228),
		Vector2(1080, 228), Vector2(1076, 264), Vector2(1104, 300),
		Vector2(1088, 316), Vector2(1052, 324), Vector2(1016, 328),
	],
}

var _game: Node2D
var _n: int = 0
var _hidden_frames: int = 0
var _seen_frames: int = 0
var _max_cover: float = 0.0
var _max_cover_il: float = 0.0
var _ghost_frames: int = 0
var _max_ghost: float = 0.0
var _no_visuals: int = 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_game = load("res://scenes/room_game.tscn").instantiate()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--room="):
			room_id = a.substr(7)
		elif a.begins_with("--occ="):
			occ_id = a.substr(6)
	_game.set("start_room", room_id)
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
	# ایلارا این بار **دنبال می‌کند**: او هم باید پشت شیء برود

	# مسیر: از جلوی شیء، دور می‌زند به پشتش، می‌ماند، و برمی‌گردد.
	# نقاط از BFS روی ماسک آمدند، نه از حدس (همان درس D-ART-48).
	var route: Array = ROUTES.get("%s#%s" % [room_id, occ_id], ROUTES.get(room_id, []))
	if route.is_empty():
		push_error("مسیری برای «%s» نیست" % room_id)
		get_tree().quit(1)
		return
	kairo.global_position = route[0]
	await _hold(24)
	for i in range(1, route.size()):
		await _goto(kairo, route[i], 260)
		if i == route.size() / 2:
			var fp: Vector2 = kairo.foot_position()
			var rm0 = _game.get("room")
			print("  ایستگاه: پا در %s، پوشش %.0f٪"
				% [str(fp.round()), rm0.coverage_at(fp) * 100.0])
			await _hold(72)          # پشت شیء می‌ماند تا سیلوئت دیده شود
	await _hold(30)

	print("")
	print("— عبور از پشت «%s» در «%s» —" % [occ_id, room_id])
	print("  فریم ضبط‌شده: %d" % (_n / EVERY))
	print("  فریمی که کایرو پشت شیء بود: %d" % _hidden_frames)
	print("  فریمی که جلوتر بود: %d" % _seen_frames)
	print("  بیشینهٔ پوشش کایرو: %.0f٪" % (_max_cover * 100.0))
	print("  فریمی که سیلوئت روشن بود: %d" % _ghost_frames)
	print("  بیشینهٔ شدت سیلوئت: %.2f" % _max_ghost)
	print("  فریم بدون ظاهر بازیگر: %d" % _no_visuals)
	print("  بیشینهٔ پوشش ایلارا: %.0f٪" % (_max_cover_il * 100.0))
	# اگر هیچ فریمی پشت مبل نبوده، ضبط چیزی را ثابت نمی‌کند
	get_tree().quit(0 if _hidden_frames > 30 and _seen_frames > 30
		and _ghost_frames > 20 else 1)


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


## «پشت شیء» یعنی چه؟ تا گام ۵۴ یعنی «داخل چندضلعی بریده»، که برای
## occluder تصویری اصلاً چندضلعی ندارد. تعریف تازه همان چیزی است که
## بازیکن می‌بیند: پوشش بدن از آستانهٔ سیلوئت گذشته باشد.
func _in_occ(p: Vector2) -> bool:
	var rm = _game.get("room")
	if rm == null or not is_instance_valid(rm):
		return false
	return rm.coverage_at(p) >= ActorVisual.GHOST_ON


func _grab(actor) -> void:
	_n += 1
	if actor != null and is_instance_valid(actor):
		if _in_occ(actor.foot_position()):
			_hidden_frames += 1
		else:
			_seen_frames += 1
	var rm = _game.get("room")
	if rm != null and is_instance_valid(rm) and actor != null \
			and is_instance_valid(actor):
		_max_cover = maxf(_max_cover, rm.coverage_at(actor.foot_position()))
	var il = _game.get("ilara")
	if rm != null and is_instance_valid(rm) and il != null and is_instance_valid(il):
		_max_cover_il = maxf(_max_cover_il, rm.coverage_at(il.foot_position()))
	var vis: Array = _game.get("_visuals") if _game != null else []
	if vis.is_empty():
		_no_visuals += 1
	for v in vis:
		if v != null and is_instance_valid(v):
			_max_ghost = maxf(_max_ghost, v.ghost_amount())
			if v.ghost_amount() > 0.5:
				_ghost_frames += 1
				break
	if _n % EVERY != 0:
		return
	get_viewport().get_texture().get_image().save_png(OUT + "f%05d.png" % _n)
