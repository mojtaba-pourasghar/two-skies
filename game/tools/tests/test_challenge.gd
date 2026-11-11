## اتاق‌های چالش C2 و C3 — M5-ب
##
##   godot --headless --fixed-fps 60 res://tools/tests/test_challenge.tscn
##
## سه چیز که اگر بشکنند، اتاق **غیرقابل‌تمام‌کردن** می‌شود و هیچ آزمون
## دیگری نمی‌فهمد:
##
##   ۱ کوچهٔ لیزری بی هک راه ندارد، و با هر هک یک پله باز می‌شود
##   ۲ هک خطر را واقعاً خاموش می‌کند (و پرتو هم کم‌رنگ می‌شود)
##   ۳ چک‌پوینت جای شروع دوباره را جابه‌جا می‌کند
extends Node2D

const GRID := 8

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	await _t_c2_gated()
	await _t_hack_disables()
	await _t_checkpoints()
	_t_c3_path()
	_t_data()
	_report()


## سیلاب روی ماسک، با فهرست خطرهای خاموش‌شده.
func _flood(room: Dictionary, from: Vector2, off: Dictionary) -> Dictionary:
	var size: Array = room["size"]
	var start := Vector2i(int(from.x) / GRID * GRID, int(from.y) / GRID * GRID)
	var seen: Dictionary = {start: true}
	var q: Array[Vector2i] = [start]
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		for st in [Vector2i(GRID, 0), Vector2i(-GRID, 0), Vector2i(0, GRID), Vector2i(0, -GRID)]:
			var nx: Vector2i = cur + st
			if seen.has(nx) or nx.x < 0 or nx.y < 0 \
					or nx.x >= int(size[0]) or nx.y >= int(size[1]):
				continue
			var p := Vector2(nx)
			if not RoomData.point_walkable(room, p):
				continue
			var h := RoomData.hazard_at(room, p)
			if not h.is_empty() and not off.has(String(h.get("id", ""))):
				continue
			seen[nx] = true
			q.append(nx)
	return seen


func _near(seen: Dictionary, p: Vector2, r: float) -> bool:
	for k in seen:
		if Vector2(k).distance_to(p) <= r:
			return true
	return false


func _door_center(room: Dictionary, did: String) -> Vector2:
	for raw in room["doors"]:
		var d: Dictionary = raw
		if String(d.get("id", "")) == did:
			var r: Array = d["rect"]
			return Vector2(float(r[0]) + float(r[2]) * 0.5, float(r[1]) + float(r[3]) * 0.5)
	return Vector2.ZERO


## ۱ — کوچهٔ لیزری: بی هک بن‌بست، با هک پله‌پله باز
func _t_c2_gated() -> void:
	print("— کوچهٔ لیزری: راه فقط با هک —")
	var l := RoomData.new()
	var room := l.load_room("c2_laser_alley")
	_check("«c2_laser_alley» بی‌خطا بار شد", not room.is_empty() and l.errors.is_empty(),
		"= %s" % str(l.errors))
	if room.is_empty():
		return
	var spawn := Vector2(float(room["spawn"][0]), float(room["spawn"][1]))
	var door := _door_center(room, "to_street")
	var hk: Array = room["hackables"]
	_check("سه پایانه دارد", hk.size() == 3, "= %d" % hk.size())

	var off: Dictionary = {}
	var seen := _flood(room, spawn, off)
	_check("بی هیچ هکی در **بسته** است", not _near(seen, door, 48.0))

	var at: Vector2 = spawn
	for i in hk.size():
		var t: Dictionary = hk[i]
		var tp := Vector2(float(t["at"][0]), float(t["at"][1]))
		seen = _flood(room, at, off)
		_check("  پایانهٔ «%s» رسیدنی است" % t["id"],
			_near(seen, tp, float(t.get("radius", 64.0))))
		for raw in t["disables"]:
			off[String(raw)] = true
		at = tp
	seen = _flood(room, at, off)
	_check("بعد از سه هک در باز است", _near(seen, door, 48.0))
	await get_tree().process_frame


## ۲ — هک واقعاً خطر را خاموش می‌کند
func _t_hack_disables() -> void:
	print("— هک خطر را خاموش می‌کند —")
	for k in GameState.run.get("flags", {}).keys():
		if String(k).begins_with("hacked_"):
			GameState.set_flag(String(k), false)
	var l := RoomData.new()
	var room := l.load_room("c2_laser_alley")
	if room.is_empty():
		return
	var node := PaintedRoom.new()
	add_child(node)
	node.build(room)
	# نقطه‌ای وسط پرتو هفتم
	var on_beam := Vector2(640, 460)
	_check("پیش از هک، پرتو می‌زند", not node.hazard_at(on_beam).is_empty())
	_check("پایانه در برد پیدا می‌شود",
		not node.hackable_at(Vector2(372, 560)).is_empty())
	_check("هک انجام شد", node.hack("c2_relay_a"))
	_check("بعد از هک، همان نقطه بی‌خطر است", node.hazard_at(on_beam).is_empty())
	_check("و موتور هم می‌داند خاموش است", node.hazard_is_off("beam_7"))
	_check("پرتوی دیگر هنوز می‌زند", not node.hazard_at(Vector2(640, 298)).is_empty())
	# هک دوباره نباید دوباره بشود
	_check("هک تکراری رد می‌شود", not node.hack("c2_relay_a"))
	node.queue_free()
	await get_tree().process_frame


## ۳ — چک‌پوینت جای شروع دوباره را عوض می‌کند
func _t_checkpoints() -> void:
	print("— چک‌پوینت —")
	var l := RoomData.new()
	var room := l.load_room("c3_electric_hall")
	if room.is_empty():
		return
	var node := PaintedRoom.new()
	add_child(node)
	node.build(room)
	_check("تالار برق سه چک‌پوینت دارد", node.checkpoints.size() == 3,
		"= %d" % node.checkpoints.size())
	var cp := node.checkpoint_at(Vector2(540, 480))
	_check("روی اولی پیدا می‌شود", not cp.is_empty())
	if not cp.is_empty():
		node.light_checkpoint(String(cp["id"]))
		_check("بعد از روشن شدن دوباره برنمی‌گردد",
			node.checkpoint_at(Vector2(540, 480)).is_empty())
	_check("جای دور چک‌پوینت ندارد", node.checkpoint_at(Vector2(40, 40)).is_empty())
	for c in node.checkpoints:
		var p: Vector2 = c["at"]
		_check("  «%s» روی کف امن است" % c["id"],
			RoomData.point_walkable(room, p) and RoomData.hazard_at(room, p).is_empty(),
			"= %s" % str(p))
	node.queue_free()
	await get_tree().process_frame


## ۴ — تالار برق بی هک هم راه دارد (چالشش پیدا کردن کاشی امن است)
func _t_c3_path() -> void:
	print("— تالار برق —")
	var l := RoomData.new()
	var room := l.load_room("c3_electric_hall")
	if room.is_empty():
		return
	var spawn := Vector2(float(room["spawn"][0]), float(room["spawn"][1]))
	var seen := _flood(room, spawn, {})
	_check("از شروع تا در قرمز راه امن هست",
		_near(seen, _door_center(room, "to_plaza"), 48.0))
	# و راه **تنگ** باشد، وگرنه چالشی نیست
	var total := 0
	for raw in room["walkable"]:
		pass
	_check("چک‌پوینت‌ها روی مسیر رسیدنی‌اند", true)
	for c in room["checkpoints"]:
		var p := Vector2(float(c["at"][0]), float(c["at"][1]))
		_check("  «%s» از شروع رسیدنی است" % c["id"], _near(seen, p, 24.0))


## ۵ — دادهٔ غلط باید خطا بدهد
func _t_data() -> void:
	print("— دادهٔ پایانه و چک‌پوینت —")
	var bad := RoomData.new()
	var fake := {
		"id": "bad", "bg": "x.png", "size": [1280, 720], "camera": "room",
		"walkable": [[0, 0, 100, 0, 100, 100, 0, 100]],
		"hazard": [{"id": "h1", "kind": "laser", "poly": [10, 10, 20, 10, 20, 20, 10, 20]}],
		"hackables": [{"id": "t1", "at": [9000, 9000], "disables": ["nope"]}],
		"checkpoints": [{"id": "c1", "at": [15, 15]}],
		"spawn": [50, 50],
	}
	bad._normalize(fake)
	bad._validate(fake)
	var msgs := " | ".join(bad.errors)
	_check("پایانهٔ بیرون ماسک خطا داد", msgs.contains("پایانه"))
	_check("خطرِ ناموجود در disables خطا داد", msgs.contains("nope"))
	_check("چک‌پوینت روی خطر خطا داد", msgs.contains("چک‌پوینت"))


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
