## آزمون ناحیهٔ ۱ — پیوستگی، قفل در، و ذخیره/ادامه (M3)
##
##   godot --headless --fixed-fps 60 res://tools/tests/test_area1.tscn
##
## سه چیز را می‌سنجد که اگر بشکنند بازیکن گیر می‌افتد و هیچ خطایی نمی‌بیند:
##   ۱ گراف در‌ها بسته است: هر در به اتاقی می‌رود که از آن برمی‌گردد
##   ۲ در قفل بدون پرچم باز نمی‌شود، و با پرچم باز می‌شود
##   ۳ ذخیره در گذار در نوشته می‌شود و «ادامه» همان‌جا برمی‌گردد
extends Node2D

## مسیر ناحیهٔ ۱ طبق سند ۱۲ §۶ب.
const AREA1 := ["r1a_living", "r1b_corridor", "r1c_kitchen",
	"r1d_bedroom", "r1e_basement", "c1_balcony"]

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	_t_graph()
	_t_reachable()
	_t_locks()
	await _t_save_resume()
	_report()


## هر در باید رفت‌وبرگشت داشته باشد: اگر از A به B می‌رود، باید دری در B
## باشد که به A برگردد. بدون این، بازیکن در اتاقی می‌افتد که راه بیرون
## ندارد — و چون خطایی نیست، فقط «بازی خراب است» دیده می‌شود.
func _t_graph() -> void:
	print("— گراف در‌های ناحیهٔ ۱ —")
	var doors: Dictionary = {}
	var l := RoomData.new()
	for rid in AREA1:
		var r := l.load_room(rid)
		if r.is_empty():
			_check("«%s» بار شد" % rid, false)
			continue
		var outs: Array[String] = []
		for raw in r["doors"]:
			outs.append(String((raw as Dictionary).get("to", "")))
		doors[rid] = outs

	for rid in AREA1:
		if not doors.has(rid):
			continue
		for dest in doors[rid]:
			if not doors.has(dest):
				# مقصد بیرون ناحیهٔ ۱ (مثلاً S2a) — رفت‌وبرگشتش جای دیگر
				continue
			_check("«%s» → «%s» راه برگشت دارد" % [rid, dest],
				rid in doors[dest], "= %s" % str(doors[dest]))

	# R1b مرکز ناحیه است: باید به هر پنج جا برود
	var hub: Array = doors.get("r1b_corridor", [])
	for want in ["r1a_living", "r1c_kitchen", "r1d_bedroom", "r1e_basement",
			"c1_balcony"]:
		_check("راهرو دری به «%s» دارد" % want, want in hub)


## **هر در باید از نقطهٔ شروع اتاق واقعاً قابل‌رسیدن باشد.**
##
## تا اینجا فقط می‌سنجیدیم که نقطهٔ ورودِ مقصد روی زمین است. ولی خود
## مستطیل در هم باید از جایی که بازیکن می‌ایستد راه داشته باشد. این
## سنجه دو نقص واقعی بیرون کشید که هیچ تصویری نشانشان نمی‌داد:
## در زیرزمینِ راهرو **بیرون ماسک** افتاده بود (صفر خانه)، و در طاقی C1
## فقط **یک** خانهٔ ۸ پیکسلی داشت — سوراخ سوزن.
const GRID: int = 8
const MIN_CELLS: int = 6


func _t_reachable() -> void:
	print("— هر در از نقطهٔ شروع قابل‌رسیدن است —")
	var l := RoomData.new()
	for rid in AREA1:
		var room := l.load_room(rid)
		if room.is_empty():
			continue
		var seen := _flood(room)
		_check("«%s» کف قابل‌رسیدن دارد" % rid, seen.size() > 50,
			"= %d خانه" % seen.size())
		for raw in room["doors"]:
			var d: Dictionary = raw
			var r: Array = d.get("rect", [])
			if r.size() != 4:
				continue
			var hit := 0
			for key in seen:
				var pt: Vector2i = key
				if pt.x >= int(r[0]) and pt.x <= int(r[0]) + int(r[2]) \
						and pt.y >= int(r[1]) and pt.y <= int(r[1]) + int(r[3]):
					hit += 1
			_check("  در «%s» از شروع قابل‌رسیدن است" % d.get("id", "?"),
				hit >= MIN_CELLS, "= %d خانه" % hit)


## پخش‌شدن روی شبکهٔ ۸ پیکسلی از نقطهٔ شروع اتاق.
func _flood(room: Dictionary) -> Dictionary:
	var sp: Array = room["spawn"]
	var start := Vector2i(int(round(float(sp[0]) / GRID)) * GRID,
		int(round(float(sp[1]) / GRID)) * GRID)
	var size: Array = room["size"]
	var w := int(size[0])
	var h := int(size[1])
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var steps := [Vector2i(GRID, 0), Vector2i(-GRID, 0),
		Vector2i(0, GRID), Vector2i(0, -GRID)]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for st in steps:
			var nx: Vector2i = cur + st
			if seen.has(nx) or nx.x < 0 or nx.y < 0 or nx.x >= w or nx.y >= h:
				continue
			if RoomData.point_walkable(room, Vector2(nx)):
				seen[nx] = true
				queue.append(nx)
	return seen


func _t_locks() -> void:
	print("— در قفل —")
	var l := RoomData.new()
	var r := l.load_room("r1b_corridor")
	var locked: Dictionary = {}
	for raw in r["doors"]:
		var d: Dictionary = raw
		var f := String(d.get("needs_flag", ""))
		if f != "":
			locked[String(d.get("to", ""))] = f
	_check("اتاق ایلارا تا فلش‌بک قفل است",
		String(locked.get("r1d_bedroom", "")) == "flashback_seen",
		"= %s" % str(locked.get("r1d_bedroom", "—")))
	_check("زیرزمین تا کلید قفل است",
		String(locked.get("r1e_basement", "")) == "basement_key",
		"= %s" % str(locked.get("r1e_basement", "—")))
	_check("اتاق چالش قفل نیست", not locked.has("c1_balcony"))


func _t_save_resume() -> void:
	print("— ذخیره و ادامه —")
	GameState.data = GameState.default_save()
	(GameState.run["flags"] as Dictionary).clear()

	GameState.save_explore("r1c_kitchen", Vector2(560, 560))
	_check("اتاق ذخیره شد", GameState.explore_room() == "r1c_kitchen",
		"= %s" % GameState.explore_room())
	_check("و جای دقیقش هم", GameState.explore_at() == Vector2(560, 560),
		"= %s" % str(GameState.explore_at()))

	# پرچم‌ها هم باید با ذخیره بروند و برگردند، وگرنه بازیکن بعد از
	# «ادامه» دوباره پشت در قفل می‌ماند با اینکه بازش کرده بود
	GameState.set_flag("basement_key", true)
	GameState.save_explore("r1b_corridor", Vector2(600, 640))
	(GameState.run["flags"] as Dictionary).clear()
	_check("پرچم‌ها پاک شدند (شبیه‌سازی بستن بازی)",
		not bool(GameState.get_flag("basement_key", false)))
	GameState.restore_explore_flags()
	_check("و با «ادامه» برگشتند",
		bool(GameState.get_flag("basement_key", false)))

	# اجرای واقعی: صحنه با resume باید همان اتاق را باز کند
	var game: Node2D = load("res://scenes/room_game.tscn").instantiate()
	game.set("play_story", false)
	game.set("resume", true)
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var rm = game.get("room")
	_check("«ادامه» همان اتاق ذخیره‌شده را باز کرد",
		rm != null and String(rm.data.get("id", "")) == "r1b_corridor",
		"= %s" % (String(rm.data.get("id", "")) if rm != null else "—"))
	var k = game.get("kairo")
	_check("و کایرو همان‌جا ایستاد، نه سر نقطهٔ شروع اتاق",
		k != null and k.global_position.distance_to(Vector2(600, 640)) < 2.0,
		"= %s" % (str(k.global_position) if k != null else "—"))
	game.queue_free()
	await get_tree().process_frame

	GameState.data = GameState.default_save()


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
