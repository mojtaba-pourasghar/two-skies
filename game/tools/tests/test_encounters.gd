## آزمون دشمن دیدنی و گراف کل فصل — M4-پ
##
##   godot --headless --fixed-fps 60 res://tools/tests/test_encounters.tscn
##
## دو بخش:
##   ۱ گراف **هر ۱۱ اتاق**، نه فقط ناحیهٔ ۱: از خانه به هر اتاقی می‌شود رسید،
##     هر در برگشت دارد، از نقطهٔ شروع قابل‌رسیدن است، و نقطهٔ ورود داخل درِ
##     دیگری نمی‌افتد. test_area1 همین را فقط برای ناحیهٔ ۱ می‌سنجید؛ برای
##     همین S2a→S2b و S2b→S3a تا M4-پ نبودند و ناحیهٔ ۲ و ۳ از خانه
##     دست‌نیافتنی بود، با همهٔ سنجه‌ها سبز.
##   ۲ چرخهٔ نبرد در موتور: برخورد → نبرد روی اتاق منجمد → برد (دشمن می‌رود،
##     ذخیره می‌شود، برنمی‌گردد) یا فرار (یک قدم عقب، بی نبرد دوباره).
extends Node

const GRID: int = 8
const MIN_CELLS: int = 6

var _failures: Array[String] = []
var _checks: int = 0
var _rooms: Dictionary = {}


func _ready() -> void:
	_load_all()
	_t_chapter_graph()
	_t_enemy_data()
	await _t_win_flow()
	await _t_flee_flow()
	_report()


func _load_all() -> void:
	var l := RoomData.new()
	for f in DirAccess.open("res://rooms").get_files():
		if f.ends_with(".json"):
			var id := f.get_basename()
			var r := l.load_room(id)
			_check("«%s» بی‌خطا بار شد" % id, not r.is_empty(), str(l.errors))
			if not r.is_empty():
				_rooms[id] = r


func _t_chapter_graph() -> void:
	print("— گراف هر ۱۱ اتاق —")
	# از خانه به همه (قفل‌ها نادیده؛ قفل را test_area1 می‌سنجد)
	var seen: Dictionary = {"r1a_living": true}
	var queue: Array[String] = ["r1a_living"]
	while not queue.is_empty():
		var cur: String = queue.pop_front()
		for raw in _rooms[cur]["doors"]:
			var to := String((raw as Dictionary).get("to", ""))
			if _rooms.has(to) and not seen.has(to):
				seen[to] = true
				queue.append(to)
	var missing: Array = _rooms.keys().filter(func(k): return not seen.has(k))
	_check("از خانه به هر ۱۱ اتاق می‌شود رسید", missing.is_empty(),
		"= %d اتاق؛ نرسیده: %s" % [seen.size(), str(missing)])

	for rid in _rooms:
		var room: Dictionary = _rooms[rid]
		var flood := _flood(room)
		for raw in room["doors"]:
			var d: Dictionary = raw
			var to := String(d.get("to", ""))
			if not _rooms.has(to):
				continue
			var back := false
			for r2 in _rooms[to]["doors"]:
				if String((r2 as Dictionary).get("to", "")) == rid:
					back = true
			_check("  «%s» → «%s» برگشت دارد" % [rid, to], back)
			var r: Array = d["rect"]
			var hit := 0
			for key in flood:
				var p: Vector2i = key
				if Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])).has_point(Vector2(p)):
					hit += 1
			_check("  در «%s/%s» قابل‌رسیدن است" % [rid, d["id"]], hit >= MIN_CELLS,
				"= %d خانه" % hit)
			var sp: Array = d["spawn"]
			var arrive := Vector2(float(sp[0]), float(sp[1]))
			_check("  ورود از «%s/%s» روی کف «%s» است" % [rid, d["id"], to],
				RoomData.point_walkable(_rooms[to], arrive), "= %s" % str(arrive))
			_check("  و داخل در دیگری نمی‌افتد", RoomData.door_at(_rooms[to], arrive).is_empty())


func _t_enemy_data() -> void:
	print("— دادهٔ دشمن‌های دیدنی —")
	var core := BattleCore.new()
	core.load_data()
	var used: Dictionary = {}
	for rid in _rooms:
		var room: Dictionary = _rooms[rid]
		var flood := _flood(room)
		var sp: Array = room["spawn"]
		for raw in room["enemies"]:
			var e: Dictionary = raw
			var tag := "%s/%s" % [rid, e["id"]]
			var enc := String(e["encounter"])
			used[enc] = true
			_check("  «%s» نبردش تعریف شده (%s)" % [tag, enc],
				core.data["encounters"].has(enc))
			_check("  «%s» تصویر دارد" % tag,
				ResourceLoader.exists("res://assets/" + String(e.get("art", ""))))
			var m := MapEnemy.new()
			m.setup(e)
			var near := 0
			for key in flood:
				if m.touches(Vector2(key) + Vector2(0, TdConst.FOOT_OFFSET_Y)):
					near += 1
			_check("  «%s» از نقطهٔ شروع قابل‌رسیدن است" % tag, near >= MIN_CELLS,
				"= %d خانه در برد" % near)
			_check("  «%s» روی نقطهٔ شروع اتاق نیست" % tag,
				not m.touches(Vector2(float(sp[0]), float(sp[1])) + Vector2(0, TdConst.FOOT_OFFSET_Y)))
			# بازیکنی که از در وارد می‌شود نباید وسط نبرد فرود بیاید
			for arrive in _arrivals_into(rid):
				_check("  ورود به «%s» داخل برد «%s» نیست" % [rid, e["id"]],
					not m.touches(arrive + Vector2(0, TdConst.FOOT_OFFSET_Y)), "= %s" % str(arrive))
			m.free()
	for enc in ["ch1_a2_crawlers", "ch1_a3_guard_crawler", "ch1_a3_patrol_drone",
			"ch1_a3_commander"]:
		_check("نبرد v1 «%s» روی نقشه دشمن دارد" % enc, used.has(enc))


func _arrivals_into(rid: String) -> Array[Vector2]:
	var out: Array[Vector2] = []
	for other in _rooms:
		for raw in _rooms[other]["doors"]:
			var d: Dictionary = raw
			if String(d.get("to", "")) == rid:
				var sp: Array = d["spawn"]
				out.append(Vector2(float(sp[0]), float(sp[1])))
	return out


## برخورد → نبرد → برد: دشمن می‌رود و برنمی‌گردد.
func _t_win_flow() -> void:
	print("— برخورد، نبرد، برد —")
	GameState.data = GameState.default_save()
	(GameState.run["flags"] as Dictionary).clear()
	var game: RoomGame = _start("s2a_street")
	await _frames(4)
	var started: Array = []
	game.battle_started.connect(func(e): started.append(e))
	var m: MapEnemy = game.room.enemies[0]
	game.kairo.global_position = m.position - Vector2(0, TdConst.FOOT_OFFSET_Y)
	await _frames(2)
	_check("برخورد نبرد را شروع کرد", started == ["ch1_a2_crawlers"], str(started))
	_check("صحنهٔ نبرد روی اتاق باز شد", game.battle != null and is_instance_valid(game.battle))
	_check("اتاق منجمد شد", game.room.process_mode == Node.PROCESS_MODE_DISABLED)
	_check("بافت بازی «نبرد» است", GameMode.context == GameMode.Context.BATTLE)
	var kpos: Vector2 = game.kairo.global_position
	game.battle.autoplay = "skilled"
	var ended: Array = []
	game.battle_ended.connect(func(e, o): ended.append(o))
	var f := 0
	while ended.is_empty() and f < 60 * 90:
		await get_tree().physics_frame
		f += 1
	_check("نبرد برده شد و به اتاق برگشت", ended == [BattleCore.Outcome.WIN], str(ended))
	_check("صحنهٔ نبرد بسته شد", game.battle == null)
	_check("اتاق دوباره زنده است", game.room.process_mode == Node.PROCESS_MODE_INHERIT)
	_check("بافت بازی دوباره «اکتشاف»", GameMode.context == GameMode.Context.EXPLORE)
	_check("کایرو همان‌جاست (بی بارگذاری)", game.kairo.global_position.distance_to(kpos) < 1.0)
	await _frames(2)
	_check("دشمن از نقشه رفت", game.room.enemies.is_empty())
	_check("برد در ذخیره است", bool((GameState.data.get("explore", {}) as Dictionary)
		.get("flags", {}).get("battle_won_ch1_a2_crawlers", false)))
	# دوباره وارد همان اتاق شدن: دشمن نباید برگردد
	game._enter_room("s2a_street", Vector2.ZERO)
	await _frames(2)
	_check("ورود دوباره: دشمن برنگشت", game.room.enemies.is_empty())
	game.queue_free()
	await _frames(2)


## فرار: یک قدم عقب، دشمن می‌ماند، و تا بیرون رفتن نبرد دوباره نمی‌سازد.
func _t_flee_flow() -> void:
	print("— فرار —")
	GameState.data = GameState.default_save()
	(GameState.run["flags"] as Dictionary).clear()
	var game: RoomGame = _start("s3a_plaza")
	await _frames(4)
	var m: MapEnemy = null
	for e in game.room.enemies:
		if e.enemy_id == "guard_patrol":
			m = e
	var before: Vector2 = m.position + Vector2(-120, 0) - Vector2(0, TdConst.FOOT_OFFSET_Y)
	game.kairo.global_position = before
	await _frames(2)
	game.kairo.global_position = m.position - Vector2(0, TdConst.FOOT_OFFSET_Y)
	await _frames(2)
	_check("نگهبان نبرد را شروع کرد", game.battle != null)
	var b := game.battle
	var f := 0
	while b.phase != BattleScene.Phase.MENU and f < 600:
		await get_tree().physics_frame
		f += 1
	b._on_cmd("flee", "")
	f = 0
	while game.battle != null and f < 600:
		await get_tree().physics_frame
		f += 1
	_check("فرار به اتاق برگرداند", game.battle == null)
	_check("کایرو بیرون برد دشمن ایستاد",
		not m.touches(game.kairo.foot_position()), "= %s" % str(game.kairo.global_position))
	_check("دشمن سر جایش ماند", is_instance_valid(m) and m in game.room.enemies)
	# برگشتن به برد بلافاصله نبرد نمی‌سازد…
	game.kairo.global_position = m.position - Vector2(0, TdConst.FOOT_OFFSET_Y)
	await _frames(3)
	_check("بلافاصله نبرد دوباره نمی‌سازد", game.battle == null)
	# …ولی بعد از بیرون رفتن، چرا
	game.kairo.global_position = before
	await _frames(2)
	game.kairo.global_position = m.position - Vector2(0, TdConst.FOOT_OFFSET_Y)
	await _frames(2)
	_check("بعد از بیرون رفتن، برخورد دوباره نبرد می‌سازد", game.battle != null)
	game.queue_free()
	await _frames(2)
	GameState.data = GameState.default_save()
	(GameState.run["flags"] as Dictionary).clear()


func _start(room_id: String) -> RoomGame:
	var game: RoomGame = load("res://scenes/room_game.tscn").instantiate()
	game.start_room = room_id
	game.resume = false
	add_child(game)
	return game


func _flood(room: Dictionary) -> Dictionary:
	var sp: Array = room["spawn"]
	var start := Vector2i(int(round(float(sp[0]) / GRID)) * GRID,
		int(round(float(sp[1]) / GRID)) * GRID)
	var size: Array = room["size"]
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var steps := [Vector2i(GRID, 0), Vector2i(-GRID, 0), Vector2i(0, GRID), Vector2i(0, -GRID)]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for st in steps:
			var nx: Vector2i = cur + st
			if seen.has(nx) or nx.x < 0 or nx.y < 0 or nx.x >= int(size[0]) or nx.y >= int(size[1]):
				continue
			if RoomData.point_walkable(room, Vector2(nx)):
				seen[nx] = true
				queue.append(nx)
	return seen


func _frames(n: int) -> void:
	for i in n:
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
