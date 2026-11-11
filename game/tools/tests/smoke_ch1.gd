## اجرای سرتاسری فصل ۱ — گام ۵۷ بند ۵
##
##   godot --path game --fixed-fps 60 res://tools/tests/smoke_ch1.tscn
##
## از منوی اصلی شروع می‌کند، کل فصل را می‌رود — خانه، ایوان، خیابان،
## کوچهٔ لیزری (با سه هک)، میدان گشت و تالار برق — وسط راه ذخیره و
## بارگذاری می‌کند، نبردها را خودکار می‌برد، و باید به پرچم `ch1_done`
## برسد.
##
## **مسیرها از BFS روی ماسک همین اجرا می‌آیند، نه از عدد ثابت.** هر بار
## که ماسک اتاقی عوض شود، این آزمون خودش مسیر تازه را پیدا می‌کند — و
## اگر راهی نباشد، همان‌جا رد می‌شود.
extends Node2D

const GRID := 10
const STEP_CAP := 2600

## هر گام: از کدام اتاق، از کدام در.
const ROUTE := [
	["r1a_living", "to_corridor"],
	["r1b_corridor", "to_kitchen"],
	["r1c_kitchen", "to_corridor"],
	["r1b_corridor", "to_balcony"],
	["c1_balcony", "to_corridor"],
	["r1b_corridor", "to_living"],
	["r1a_living", "to_street"],
	["s2a_street", "to_alley"],
	["s2b_street", "to_laser"],
	["c2_laser_alley", "to_street"],
	["s2b_street", "to_plaza"],
	["s3a_plaza", "to_hall"],
	["c3_electric_hall", "to_plaza"],
]
## وسط راه ذخیره و بارگذاری می‌شود — پس از رسیدن به این اتاق.
const SAVE_AT := "s2b_street"

var _game: RoomGame
var _failures: Array[String] = []
var _checks: int = 0
var _saved_once: bool = false
var _battles: int = 0
var _in_battle: bool = false


func _ready() -> void:
	_fresh_run()
	# منوی اصلی: فقط باید بی‌خطا بار شود (شروع «از منو»)
	var menu: Node = load("res://ui/main_menu/main_menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	_check("منوی اصلی بار شد", menu.get_child_count() > 0)
	menu.queue_free()
	await get_tree().process_frame

	_start_game("r1a_living")
	for leg in ROUTE:
		var ok := await _leg(String(leg[0]), String(leg[1]))
		if not ok:
			break
	await _finish()
	_report()


func _fresh_run() -> void:
	GameState.run["flags"] = {}
	GameState.data["flags"] = {}
	GameState.data["upgrades"] = []
	GameState.restore_full()


func _start_game(room_id: String, resume: bool = false) -> void:
	if _game != null and is_instance_valid(_game):
		_game.queue_free()
	_game = load("res://scenes/room_game.tscn").instantiate()
	_game.start_room = room_id
	_game.resume = resume
	_game.battle_autoplay = "skilled"
	add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame


func _room_id() -> String:
	if _game == null or _game.room == null or not is_instance_valid(_game.room):
		return ""
	return String(_game.room.data.get("id", ""))


## یک پا از مسیر: صبر برای داستان، کار ویژهٔ اتاق، و رفتن به در.
func _leg(room_id: String, door_id: String) -> bool:
	await _settle()
	_check("در «%s» هستیم" % room_id, _room_id() == room_id, "= %s" % _room_id())
	if _room_id() != room_id:
		return false
	if room_id == "c2_laser_alley":
		if not await _hack_alley():
			return false
	if room_id == SAVE_AT and not _saved_once:
		await _save_and_reload(room_id)
	var target := _door_point(door_id)
	if target == Vector2.ZERO:
		_check("در «%s» پیدا شد" % door_id, false)
		return false
	var went := await _walk_to(target, door_id)
	_check("از «%s» رد شد" % door_id, went, "= %s" % _room_id())
	return went


## کوچهٔ لیزری: سه پایانه را به ترتیب هک می‌کند.
func _hack_alley() -> bool:
	for hk in _game.room.data.get("hackables", []):
		var h: Dictionary = hk
		var at: Array = h["at"]
		var p := Vector2(float(at[0]), float(at[1]))
		if not await _walk_to(p, ""):
			_check("به پایانهٔ «%s» رسید" % h["id"], false)
			return false
		Input.action_press("action")
		var done := false
		for i in 200:
			await get_tree().physics_frame
			if _game.room.hackable_at(_game.kairo.foot_position()).is_empty():
				done = true
				break
		Input.action_release("action")
		_check("پایانهٔ «%s» هک شد" % h["id"], done)
		if not done:
			return false
	return true


## ذخیره و بارگذاری وسط راه: همان اتاق، همان جا.
func _save_and_reload(room_id: String) -> void:
	_saved_once = true
	GameState.save_explore(room_id, _game.kairo.global_position)
	var ok := GameState.save_game()
	_check("ذخیره روی دیسک نوشته شد", ok)
	var coins := int(GameState.data.get("coins", 0))
	_check("بارگذاری از دیسک", GameState.load_game())
	await _start_game("", true)
	await _settle()
	_check("بعد از بارگذاری در همان اتاق است", _room_id() == room_id,
		"= %s" % _room_id())
	_check("و دارایی‌اش سر جایش است", int(GameState.data.get("coins", 0)) == coins,
		"= %d" % int(GameState.data.get("coins", 0)))


## صبر تا صحنه/گفت‌وگو/نبرد تمام شود و کنترل برگردد.
func _settle(cap: int = 2400) -> void:
	for i in cap:
		if Cutscene.is_playing:
			Cutscene.skip_now()
		elif _game != null and _game.battle != null:
			# **شروع** نبرد شمرده می‌شود، نه فریم‌های آن: بار اول عدد
			# ۴۶۶۶ درآمد که تعداد فریم بود، نه تعداد نبرد.
			if not _in_battle:
				_in_battle = true
				_battles += 1
				print("  — نبرد %d شروع شد —" % _battles)
		elif GameMode.control == GameMode.ControlMode.PLAY:
			_in_battle = false
			return
		await get_tree().physics_frame


## رفتن به یک نقطه با BFS روی ماسک همین اتاق.
##
## **درس عبور از در:** وقتی بازیکن از در رد می‌شود، اتاق و خود بازیگر
## دوباره ساخته می‌شوند. پس بعد از هر فریم، هم اتاق سنجیده می‌شود هم
## بازیگر دوباره گرفته می‌شود و `use_scripted` روی تازه‌اش ست می‌شود —
## وگرنه بازیکن تازه همان‌جا می‌ایستد.
func _walk_to(target: Vector2, door_id: String) -> bool:
	var start_room := _room_id()
	# اول مسیری که از هیچ در دیگری رد نمی‌شود؛ اگر نبود، مسیر مستقیم.
	var path := _path_to(target, door_id, true)
	if path.is_empty():
		path = _path_to(target, door_id, false)
	if path.is_empty():
		print("    مسیر پیدا نشد: از %s به %s"
			% [str(_game.kairo.foot_position().round()), str(target.round())])
		return false
	var frames := 0
	var stuck := 0
	var last := Vector2.ZERO
	var deaths := int(GameState.run.get("deaths", 0))
	for p in path:
		stuck = 0
		for i in 300:
			frames += 1
			if frames > STEP_CAP:
				break
			if _room_id() != start_room:
				return door_id != ""
			var kairo = _game.kairo
			if kairo == null or not is_instance_valid(kairo):
				await get_tree().physics_frame
				continue
			kairo.set("use_scripted", true)
			var to: Vector2 = p - kairo.foot_position()
			if to.length() < 10.0:
				break
			kairo.set("scripted_dir", to.normalized())
			await get_tree().physics_frame
			if Cutscene.is_playing:
				Cutscene.skip_now()
			# **گیر کردن را باید دید.** نقطه‌های راه روی شبکه‌اند و خط
			# مستقیم بینشان می‌تواند گوشهٔ یک چندضلعی مانع را ببرد؛
			# آن‌وقت بازیگر به دیوار فشار می‌دهد و تا ابد همان‌جاست.
			# در ایوان C1 دقیقاً همین شد و ۲۶۰۰ فریم روی یک نقطه ماند.
			var now := _game.kairo.foot_position() if is_instance_valid(_game.kairo) \
				else Vector2.ZERO
			# مرگ در اتاق چالش بازیگر را به چک‌پوینت برمی‌گرداند؛ ادامهٔ
			# همان نقطه‌های راه از آنجا بی‌معنی است. مسیر دوباره گرفته
			# می‌شود.
			if int(GameState.run.get("deaths", 0)) != deaths:
				return await _walk_to(target, door_id)
			if now.distance_to(last) < 0.5:
				stuck += 1
				if stuck > 40:
					break
			else:
				stuck = 0
			last = now
		if frames > STEP_CAP:
			break
	# **نزدیک شدن آخر.** نقطهٔ راه روی شبکهٔ ۸ پیکسلی است و بازیکن در
	# ۱۰ پیکسلی آن می‌ایستد؛ یعنی تا ۱۸ پیکسل از مرکز در فاصله می‌ماند و
	# پایش هنوز داخل مستطیل در نیست. بار اول دقیقاً روی لبهٔ پایینی در
	# ایستاد (y=۴۷۲ در برابر مستطیل ۴۲۴..۴۷۲) و هیچ‌وقت رد نشد.
	if door_id != "":
		for i in 180:
			if _room_id() != start_room:
				break
			var kk = _game.kairo
			if kk == null or not is_instance_valid(kk):
				break
			kk.set("use_scripted", true)
			kk.set("scripted_dir", (target - kk.foot_position()).normalized())
			await get_tree().physics_frame
			if Cutscene.is_playing:
				Cutscene.skip_now()
	var k = _game.kairo
	if k != null and is_instance_valid(k):
		k.set("scripted_dir", Vector2.ZERO)
	await _settle()
	if door_id != "":
		if _room_id() == start_room:
			print("    نرسید به در «%s»: پا %s، هدف %s، %d نقطه، %d فریم"
				% [door_id, str(_game.kairo.foot_position().round()),
					str(target.round()), path.size(), frames])
		return _room_id() != start_room
	return _game.kairo.foot_position().distance_to(target) < 56.0


var _leg_room: String = ""


func _path_to(target: Vector2, keep_door: String = "", dodge: bool = true) -> Array:
	var room: Dictionary = _game.room.data
	_leg_room = String(room.get("id", ""))
	var from := _game.kairo.foot_position()
	var start := Vector2i(int(from.x) / GRID * GRID, int(from.y) / GRID * GRID)
	var goal := Vector2i(int(target.x) / GRID * GRID, int(target.y) / GRID * GRID)
	var size: Array = room["size"]
	var prev: Dictionary = {start: start}
	var q: Array[Vector2i] = [start]
	var found := false
	while not q.is_empty():
		var cur: Vector2i = q.pop_front()
		if cur.distance_to(goal) <= GRID * 2:
			goal = cur
			found = true
			break
		for st in [Vector2i(GRID, 0), Vector2i(-GRID, 0), Vector2i(0, GRID),
				Vector2i(0, -GRID)]:
			var nx: Vector2i = cur + st
			if prev.has(nx) or nx.x < 0 or nx.y < 0 \
					or nx.x >= int(size[0]) or nx.y >= int(size[1]):
				continue
			var pt := Vector2(nx)
			# **جعبهٔ پا پهنا دارد.** مسیری که فقط برای یک نقطه باز است،
			# برای بدن باز نیست: در ایوان C1 مسیر از لبهٔ چاله رد می‌شد و
			# بازیگر به دیواره فشار می‌داد و همان‌جا می‌ماند.
			if not _fits(room, pt):
				continue
			# **درِ دیگر مانع است.** مسیر کوتاه از در آشپزخانه به در ایوان
			# از گوشهٔ در نشیمن رد می‌شد و بازیکن بی‌اختیار به R1a
			# می‌رفت. بازیکن واقعی هم همین‌طور: درها را باید دور زد.
			if dodge and _other_door(pt, keep_door):
				continue
			prev[nx] = cur
			q.append(nx)
	if not found:
		return []
	var out: Array = []
	var c: Vector2i = goal
	while c != start:
		out.append(Vector2(c))
		c = prev[c]
	out.reverse()
	# هر ۴ خانه یک نقطهٔ راه؛ ریزتر از این، گام‌ها بی‌فایده کوتاه می‌شوند
	var thin: Array = []
	for i in out.size():
		if i % 2 == 0 or i == out.size() - 1:
			thin.append(out[i])
	return thin


## نقطه داخل مستطیل دری **به‌جز** در هدف است؟
func _other_door(p: Vector2, keep_door: String) -> bool:
	for raw in _game.room.data.get("doors", []):
		var d: Dictionary = raw
		if String(d.get("id", "")) == keep_door:
			continue
		var r: Array = d.get("rect", [])
		if r.size() != 4:
			continue
		# کمی حاشیه، چون جعبهٔ پای بازیگر پهنا دارد
		if Rect2(float(r[0]) - 4.0, float(r[1]) - 4.0,
				float(r[2]) + 8.0, float(r[3]) + 8.0).has_point(p):
			return true
	return false


## نقطه‌ای که **جعبهٔ پای** بازیگر هم در آن جا می‌شود.
func _fits(room: Dictionary, p: Vector2) -> bool:
	# جعبهٔ پا هم پهنا دارد هم عمق. در تالار برق با ۲۴ کاشی برق‌دار،
	# بی سنجیدن عمق، مسیر از لبهٔ کاشی رد می‌شد و بازیگر می‌مرد و
	# دوباره از اول — حلقهٔ بی‌پایان.
	for off in [Vector2.ZERO, Vector2(9, 0), Vector2(-9, 0),
			Vector2(0, 5), Vector2(0, -5)]:
		var q: Vector2 = p + off
		if not RoomData.point_walkable(room, q):
			return false
		if not _game.room.hazard_at(q).is_empty():
			return false
	return true


func _door_point(did: String) -> Vector2:
	for raw in _game.room.data.get("doors", []):
		var d: Dictionary = raw
		if String(d.get("id", "")) != did:
			continue
		var r: Array = d["rect"]
		return Vector2(float(r[0]) + float(r[2]) * 0.5, float(r[1]) + float(r[3]) * 0.5)
	return Vector2.ZERO


## پایان: نبرد فرمانده و پردهٔ پایان فصل.
func _finish() -> void:
	await _settle()
	print("  اتاق پایانی: %s، نبردها: %d" % [_room_id(), _battles])
	# اگر فرمانده هنوز شکست نخورده، به او می‌رویم
	if not bool(GameState.get_flag("battle_won_ch1_a3_commander", false)):
		if _room_id() == "s3a_plaza":
			for raw in _game.room.data.get("enemies", []):
				var e: Dictionary = raw
				if String(e.get("encounter", "")) != "ch1_a3_commander":
					continue
				var at: Array = e["at"]
				await _walk_to(Vector2(float(at[0]), float(at[1])), "")
				await _settle()
	_check("فرماندهٔ گشت شکست خورد",
		bool(GameState.get_flag("battle_won_ch1_a3_commander", false)))
	# بیت‌های پایانی
	for i in 1200:
		if bool(GameState.get_flag("ch1_done", false)):
			break
		if Cutscene.is_playing:
			Cutscene.skip_now()
		var ui := _find_upgrade()
		if ui != null:
			ui.choose("heart")
		await get_tree().physics_frame
	_check("ارتقا انتخاب شد",
		(GameState.data.get("upgrades", []) as Array).size() == 1,
		"= %s" % str(GameState.data.get("upgrades", [])))
	_check("فصل ۱ تمام شد", bool(GameState.get_flag("ch1_done", false)))
	_check("دست‌کم یک نبرد روی نقشه شروع شد", _battles > 0, "= %d" % _battles)


func _find_upgrade() -> UpgradeChoice:
	if _game == null or not is_instance_valid(_game):
		return null
	for c in _game.get_children():
		if c is UpgradeChoice:
			return c
	return null


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
