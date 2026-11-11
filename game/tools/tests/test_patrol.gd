## گشت دشمن و مخروط دید — M5-ت (سند ۰۹ §۲ و بند ۶ §۱۱)
##
##   godot --headless --fixed-fps 60 res://tools/tests/test_patrol.tscn
##
## پنج ادعا سنجیده می‌شود، چون هر پنج‌تا در بازی **دیده** می‌شوند و اگر
## بشکنند بی‌صدا می‌شکنند:
##
##   ۱ گشت واقعاً راه می‌رود، روی ماسک می‌ماند، و حلقه می‌زند
##   ۲ مخروط: داخلش دیده می‌شود، بیرونش نه، پشت سر هرگز
##   ۳ دیوار و occluder دید را می‌شکنند (پنهان‌کاری)
##   ۴ دیدن → «!» → تعقیب → فراموشی → برگشت
##   ۵ حملهٔ از پشت نبرد را با دشمنِ شکننده شروع می‌کند
extends Node2D

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	await _t_patrol_walk()
	await _t_cone()
	await _t_blocked_sight()
	await _t_states()
	_t_ambush()
	_t_data()
	_report()


func _room(rid: String) -> PaintedRoom:
	var l := RoomData.new()
	var room := l.load_room(rid)
	if room.is_empty():
		_check("اتاق «%s» بار شد" % rid, false, "= %s" % str(l.errors))
		return null
	var node := PaintedRoom.new()
	add_child(node)
	node.build(room)
	return node


func _enemy(node: PaintedRoom, eid: String) -> MapEnemy:
	for m in node.enemies:
		if m.enemy_id == eid:
			return m
	return null


## ۱ — گشت راه می‌رود، روی ماسک می‌ماند، و به نقطهٔ بعدی می‌رسد
func _t_patrol_walk() -> void:
	print("— گشت —")
	var node := _room("s3a_plaza")
	if node == null:
		return
	var g := _enemy(node, "guard_patrol")
	_check("نگهبان ساخته شد", g != null)
	if g == null:
		return
	_check("روی نقطهٔ اول گشت ایستاده", g.position == g.patrol[0],
		"= %s" % str(g.position))
	var start := g.position
	var off_mask := 0
	var moved_max := 0.0
	# ۱۲ ثانیه با گام ثابت ۱/۶۰ — بدون وابستگی به ساعت دیوار
	var far := Vector2(-9999, -9999)
	for i in 720:
		g.tick(1.0 / 60.0, far, node)
		if not RoomData.point_walkable(node.data, g.position):
			off_mask += 1
		moved_max = maxf(moved_max, start.distance_to(g.position))
	_check("از ماسک بیرون نزد", off_mask == 0, "= %d فریم بیرون" % off_mask)
	_check("واقعاً جابه‌جا شد", moved_max > 60.0, "= %.0fpx" % moved_max)
	_check("در حالت گشت ماند (بازیکن دور بود)", g.state == MapEnemy.State.PATROL)
	_check("خبردار نشد", not g.alerted)
	node.queue_free()
	await get_tree().process_frame


## ۲ — هندسهٔ مخروط
func _t_cone() -> void:
	print("— مخروط دید —")
	var node := _room("s3a_plaza")
	if node == null:
		return
	var d := _enemy(node, "patrol_drone")
	if d == null:
		_check("پهپاد ساخته شد", false)
		return
	d.facing = Vector2.RIGHT
	var p: Vector2 = d.position
	_check("جلو و نزدیک: دیده می‌شود",
		d.sees(p + Vector2(120, 0), node))
	_check("پشت سر: دیده نمی‌شود",
		not d.sees(p + Vector2(-120, 0), node))
	_check("دورتر از برد: دیده نمی‌شود",
		not d.sees(p + Vector2(d.see_range + 60.0, 0), node))
	# بیرون نیم‌زاویه: زاویهٔ ۵۵ درجه یعنی نیم‌زاویهٔ ۲۷٫۵
	var out := Vector2(cos(deg_to_rad(50.0)), sin(deg_to_rad(50.0)) / MapEnemy.DEPTH) * 120.0
	_check("بیرون زاویه: دیده نمی‌شود", not d.sees(p + out, node),
		"= زاویهٔ مخروط %d" % int(d.see_angle))
	_check("پشت بودن تشخیص داده شد", d.is_behind(p + Vector2(-80, 0)))
	_check("جلو بودن هم", not d.is_behind(p + Vector2(80, 0)))
	node.queue_free()
	await get_tree().process_frame


## ۳ — دیوار و occluder دید را می‌شکنند
func _t_blocked_sight() -> void:
	print("— پنهان‌کاری —")
	var node := _room("s3a_plaza")
	if node == null:
		return
	var g := _enemy(node, "guard_patrol")
	if g == null:
		return
	# فواره: چندضلعی blocked شمارهٔ صفر، x از ۱۹۷ تا ۵۲۷ و y از ۴۶۴ تا ۶۶۰.
	# نگهبان روی y=۵۴۰ گذاشته می‌شود تا **تنها** چیزِ بین او و هدف،
	# خود فواره باشد؛ وگرنه آزمون چیزی را ثابت می‌کند که نخواسته‌ایم
	# (اولین‌بار از میان یک چندضلعی دیگر رد می‌شد و «بی‌مانع» هم رد شد).
	g.position = Vector2(620, 540)
	g.facing = Vector2.LEFT
	var hidden := Vector2(420, 540)        # داخل خود فواره
	_check("پشت فواره دیده نمی‌شود", not g.sees(hidden, node))
	g.facing = Vector2.RIGHT
	var open_spot := Vector2(780, 545)
	_check("همان فاصله در جهت باز دیده می‌شود", g.sees(open_spot, node),
		"= %s" % str(open_spot.round()))
	node.queue_free()
	await get_tree().process_frame

	# occluder ایستاده هم باید دید را بشکند — همان پوشش گام ۵۵
	var r1a := _room("r1a_living")
	if r1a == null:
		return
	var m := MapEnemy.new()
	r1a.actors.add_child(m)
	m.setup({"id": "probe", "encounter": "x", "at": [769, 480],
		"vision": {"range": 300, "angle": 120}})
	m.facing = Vector2.DOWN
	var behind_shelf := Vector2(769, 600)
	_check("پشت قفسه از دید دشمن هم پنهان است",
		not m.sees(behind_shelf, r1a),
		"= پوشش %.0f٪" % (r1a.coverage_at(behind_shelf) * 100.0))
	# یک قدم کنارِ قفسه، همان فاصله: دیده می‌شود. بی این سنجه، «پنهان»
	# می‌توانست از کوتاه بودن برد بیاید نه از خود قفسه.
	var beside := Vector2(690, 600)
	_check("یک قدم کنارتر دیده می‌شود", m.sees(beside, r1a),
		"= پوشش %.0f٪" % (r1a.coverage_at(beside) * 100.0))
	r1a.queue_free()
	await get_tree().process_frame


## ۴ — زنجیرهٔ حالت‌ها
func _t_states() -> void:
	print("— دیدن، تعقیب، فراموشی —")
	var node := _room("s3a_plaza")
	if node == null:
		return
	var g := _enemy(node, "guard_patrol")
	if g == null:
		return
	g.position = Vector2(760, 650)
	g.facing = Vector2.RIGHT
	var seen := g.position + Vector2(120, 0)
	g.tick(1.0 / 60.0, seen, node)
	_check("دیدن → ALERT", g.state == MapEnemy.State.ALERT)
	_check("علامت «!» روشن شد", g.get_node("Bang").visible)
	_check("خبردار شد", g.alerted)
	for i in 40:
		g.tick(1.0 / 60.0, seen, node)
	_check("بعد از ~۰٫۵ ثانیه → CHASE", g.state == MapEnemy.State.CHASE)
	_check("«!» خاموش شد", not g.get_node("Bang").visible)
	var d0: float = g.position.distance_to(seen)
	for i in 30:
		g.tick(1.0 / 60.0, seen, node)
	_check("به بازیکن نزدیک شد", g.position.distance_to(seen) < d0,
		"= %.0f → %.0f" % [d0, g.position.distance_to(seen)])
	# بازیکن غیب شد: بعد از forget باید برگردد
	var far := Vector2(-9999, -9999)
	for i in int(g.forget_s * 60.0) + 4:
		g.tick(1.0 / 60.0, far, node)
	_check("فراموشی → RETURN", g.state == MapEnemy.State.RETURN,
		"= %d" % g.state)
	for i in 900:
		g.tick(1.0 / 60.0, far, node)
		if g.state == MapEnemy.State.PATROL:
			break
	_check("به گشت برگشت", g.state == MapEnemy.State.PATROL)
	_check("و دوباره بی‌خبر شد", not g.alerted)
	node.queue_free()
	await get_tree().process_frame


## ۵ — حملهٔ از پشت: نبرد با دشمنِ شکننده شروع می‌شود
func _t_ambush() -> void:
	print("— حملهٔ از پشت —")
	var plain := BattleCore.new()
	_check("نبرد عادی بار شد", plain.load_data() and plain.start("ch1_a2_crawlers", 1))
	var any_plain := false
	for u in plain.units:
		if u["side"] == "enemy" and bool(u["fragile"]):
			any_plain = true
	_check("بی حملهٔ از پشت هیچ دشمنی شکننده نیست", not any_plain)

	var amb := BattleCore.new()
	_check("نبرد غافلگیرانه بار شد",
		amb.load_data() and amb.start("ch1_a2_crawlers", 1, {}, true))
	var n := 0
	var frag := 0
	for u in amb.units:
		if u["side"] == "enemy":
			n += 1
			if bool(u["fragile"]):
				frag += 1
	_check("همهٔ دشمن‌ها نوبت اول شکننده‌اند", n > 0 and frag == n,
		"= %d از %d" % [frag, n])
	# و شروع دوباره هم باید همان امتیاز را نگه دارد، نه که پاکش کند
	amb.restart()
	var frag2 := 0
	for u in amb.units:
		if u["side"] == "enemy" and bool(u["fragile"]):
			frag2 += 1
	_check("شروع دوبارهٔ نبرد امتیاز را نگه می‌دارد", frag2 == frag,
		"= %d" % frag2)


## ۶ — دادهٔ گشت در اتاق‌ها
func _t_data() -> void:
	print("— دادهٔ اتاق‌ها —")
	var want := {"s3a_plaza": ["guard_patrol", "patrol_drone"], "s2a_street": ["crawlers"]}
	for rid in want:
		var l := RoomData.new()
		var room := l.load_room(rid)
		_check("«%s» بی‌خطا بار شد" % rid, not room.is_empty() and l.errors.is_empty(),
			"= %s" % str(l.errors))
		if room.is_empty():
			continue
		for eid in want[rid]:
			var found := false
			for raw in room["enemies"]:
				var e: Dictionary = raw
				if String(e.get("id", "")) != eid:
					continue
				found = true
				_check("  «%s» گشت دارد" % eid, (e.get("patrol", []) as Array).size() >= 2,
					"= %d نقطه" % (e.get("patrol", []) as Array).size())
				_check("  «%s» مخروط دید دارد" % eid,
					not (e.get("vision", {}) as Dictionary).is_empty())
			_check("  «%s» در اتاق هست" % eid, found)

	# دادهٔ غلط باید خطا بدهد، نه بی‌صدا رد شود
	var bad := RoomData.new()
	var fake := {
		"id": "bad", "bg": "x.png", "size": [1280, 720], "camera": "room",
		"walkable": [[0, 0, 100, 0, 100, 100, 0, 100]],
		"enemies": [{"id": "e", "encounter": "x", "at": [50, 50],
			"patrol": [[50, 50], [9000, 9000]], "speed": 0,
			"vision": {"angle": 400}}],
		"spawn": [50, 50],
	}
	bad._normalize(fake)
	bad._validate(fake)
	var msgs := " | ".join(bad.errors)
	_check("نقطهٔ گشت بیرون ماسک خطا داد", msgs.contains("نقطهٔ گشت"))
	_check("سرعت صفر خطا داد", msgs.contains("سرعتش صفر"))
	_check("زاویهٔ ۴۰۰ درجه خطا داد", msgs.contains("زاویهٔ دید"))


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
