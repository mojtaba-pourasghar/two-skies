## آزمون قاعدهٔ مرگ و تله (M3-د) — سند ۰۹ §۱ «سه قاعده بر حسب نوع بخش»
##
##   godot --headless --fixed-fps 60 res://tools/tests/test_hazards.tscn
##
## دو قاعدهٔ اول را در موتور واقعی می‌سنجد، نه فقط در داده:
##   ۱ اتاق چالش: یک تماس = مرگ، شروع دوباره زیر ۰٫۳ ثانیه، مرگ بی‌نهایت،
##     شمارندهٔ مرگ روی صفحه
##   ۲ اکتشاف: بدون مرگ؛ آسیب جزئی و برگشت به خانهٔ امن
## قاعدهٔ سوم (نبرد) مال M4 است.
##
## چرا لازم بود: `TdActor` سیگنال `hazard_hit` را از M1 می‌فرستاد ولی هیچ
## کس به آن گوش نمی‌داد. ۴۲۹ سنجه سبز بود و پا گذاشتن روی توری داغ C1
## هیچ اثری نداشت — همان کلاس نقص «سنجه سبز، صفحه خراب» (سند ۱۵ §۷).
extends Node2D

## سقف شروع دوباره، سند ۰۹ §۲ب
const RESTART_MAX_S := 0.3

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	_t_data()
	await _t_challenge_death()
	await _t_explore_trap()
	await _t_statue()
	_t_c3_panels()
	_t_challenge_fair()
	_report()


## داده: هر خطر آسیب دارد، خطر اتاق چالش کشنده است، و جای امن هر خطر
## واقعاً امن است — روی کف، و نه داخل خطر دیگری. جای امنی که خودش خطر
## باشد بازیکن را در حلقهٔ آسیب می‌اندازد.
func _t_data() -> void:
	print("— دادهٔ خطرها —")
	_check("زمان شروع دوباره زیر ۰٫۳ ثانیه است",
		TdConst.RESPAWN_TIME < RESTART_MAX_S
			and TdConst.respawn_frames() <= int(RESTART_MAX_S * TdConst.FPS),
		"= %.2f ث (%d فریم)" % [TdConst.RESPAWN_TIME, TdConst.respawn_frames()])

	var l := RoomData.new()
	var dir := DirAccess.open("res://rooms")
	var ids: Array[String] = []
	for f in dir.get_files():
		if f.ends_with(".json"):
			ids.append(f.get_basename())
	ids.sort()
	for rid in ids:
		var room := l.load_room(rid)
		if room.is_empty():
			_check("«%s» بار شد" % rid, false)
			continue
		var challenge := RoomGame.is_challenge(room)
		for raw in room.get("hazard", []):
			var h: Dictionary = raw
			var hid := "%s/%s" % [rid, h.get("id", "?")]
			_check("  «%s» آسیب دارد" % hid, h.has("damage_pct"))
			if challenge:
				_check("  «%s» در اتاق چالش کشنده است" % hid,
					float(h.get("damage_pct", 0)) >= 100.0,
					"= %s" % str(h.get("damage_pct", "—")))
			var safe: Array = h.get("safe", [])
			if safe.size() != 2:
				_check("  «%s» جای امن دارد" % hid, challenge,
					"(بیرون اتاق چالش لازم است)")
				continue
			var p := Vector2(float(safe[0]), float(safe[1]))
			var foot := p + Vector2(0, TdConst.FOOT_OFFSET_Y)
			_check("  جای امن «%s» روی کف است" % hid,
				RoomData.point_walkable(room, foot), "= %s" % str(p))
			_check("  جای امن «%s» داخل خطر نیست" % hid,
				RoomData.hazard_at(room, foot).is_empty())


## اتاق چالش در موتور: کایرو را روی توری داغ C1 می‌گذاریم.
func _t_challenge_death() -> void:
	print("— اتاق چالش: مرگ بی‌نهایت —")
	GameState.data = GameState.default_save()
	GameState.run["deaths"] = 0
	GameState.run["hp_pct"] = 100.0
	var game := _start("c1_balcony")
	await _frames(3)
	var k: TdKairo = game.kairo
	var entry: Vector2 = k.global_position
	var on := _point_in_hazard(game.room.data, "heat_grate")
	_check("نقطه‌ای داخل توری داغ پیدا شد", on != Vector2.INF, "= %s" % str(on))
	var label: Label = game.get("_deaths_label")
	_check("شمارندهٔ مرگ در اتاق چالش دیده می‌شود",
		label != null and label.visible)

	for n in range(1, 4):
		k.global_position = on - Vector2(0, TdConst.FOOT_OFFSET_Y)
		await _frames(2)
		_check("مرگ %d: یک تماس کشت" % n, k.state == TdActor.State.DEAD)
		var waited := 0
		while k.state == TdActor.State.DEAD and waited < 120:
			await get_tree().physics_frame
			waited += 1
		_check("مرگ %d: شروع دوباره زیر ۰٫۳ ثانیه" % n,
			waited <= int(RESTART_MAX_S * TdConst.FPS),
			"= %d فریم" % waited)
		_check("مرگ %d: سر نقطهٔ ورود اتاق، نه گوشهٔ (۰،۰)" % n,
			k.global_position.distance_to(entry) < 1.0,
			"= %s" % str(k.global_position))
	_check("مرگ بی‌نهایت: شمارندهٔ اتاق سه را شمرد",
		int(game.get("room_deaths")) == 3, "= %d" % int(game.get("room_deaths")))
	_check("و شمارندهٔ مرحله هم", int(GameState.run.get("deaths", 0)) == 3)
	_check("برچسب شمارنده عدد فارسی را نشان می‌دهد",
		label != null and label.text.contains("۳"), "= «%s»" % label.text)
	_check("اتاق چالش جان کم نمی‌کند (مرگ است، نه آسیب)",
		is_equal_approx(GameState.hp_percent(), 100.0),
		"= %.0f" % GameState.hp_percent())
	game.queue_free()
	await _frames(2)


## اکتشاف در موتور: کف شکستهٔ R1a آسیب ۱۰٪ می‌زند و برمی‌گرداند.
func _t_explore_trap() -> void:
	print("— اکتشاف: آسیب جزئی و بازگشت —")
	GameState.run["deaths"] = 0
	GameState.run["hp_pct"] = 100.0
	var game := _start("r1a_living")
	await _frames(3)
	var k: TdKairo = game.kairo
	var hurt: Array = []
	game.hazard_hurt.connect(func(h, hp): hurt.append([h, hp]))
	var label: Label = game.get("_deaths_label")
	_check("شمارندهٔ مرگ در اکتشاف پنهان است",
		label != null and not label.visible)

	var on := _point_in_hazard(game.room.data, "broken_floor")
	k.global_position = on - Vector2(0, TdConst.FOOT_OFFSET_Y)
	await _frames(2)
	_check("کف شکسته نکشت", k.state != TdActor.State.DEAD)
	_check("جان ۱۰٪ کم شد", is_equal_approx(GameState.hp_percent(), 90.0),
		"= %.0f" % GameState.hp_percent())
	_check("و یک بار، نه هر فریم", hurt.size() == 1, "= %d" % hurt.size())
	_check("کایرو به خانهٔ امن خطر برگشت",
		k.global_position.distance_to(Vector2(470, 600)) < 1.0,
		"= %s" % str(k.global_position))
	_check("شمارندهٔ مرگ دست نخورد", int(GameState.run.get("deaths", 0)) == 0)

	game.queue_free()
	await _frames(2)
	GameState.run["hp_pct"] = 100.0
	GameState.data = GameState.default_save()


## جان صفر در اکتشاف (D-ART-51 مدیر): پردهٔ ۰٫۶ث، برگشت به آخرین مجسمهٔ
## ذخیره، جان پر، بدون جریمه. و لمس مجسمه جان را پر و جای برگشت را ثبت می‌کند.
func _t_statue() -> void:
	print("— مجسمهٔ ذخیره و جان صفر —")
	GameState.data = GameState.default_save()
	GameState.run["hp_pct"] = 100.0
	GameState.run["deaths"] = 0
	var room := RoomData.new().load_room("r1a_living")
	var st := RoomGame._statue_in(room)
	_check("R1a مجسمهٔ ذخیره دارد", not st.is_empty())
	var stand: Vector2 = st.get("stand", Vector2.ZERO)
	_check("جای ایستادن جلوی مجسمه روی کف است",
		RoomData.point_walkable(room, stand + Vector2(0, TdConst.FOOT_OFFSET_Y)), "= %s" % str(stand))
	_check("و داخل خطر یا در نیست",
		RoomData.hazard_at(room, stand + Vector2(0, TdConst.FOOT_OFFSET_Y)).is_empty()
			and RoomData.door_at(room, stand).is_empty())

	var game := _start("r1a_living")
	await _frames(3)
	var k: TdKairo = game.kairo
	var touched: Array = []
	var back: Array = []
	game.statue_touched.connect(func(r): touched.append(r))
	game.returned_to_statue.connect(func(r): back.append(r))
	# دور از مجسمه، جان کم
	var on := _point_in_hazard(game.room.data, "broken_floor")
	k.global_position = on - Vector2(0, TdConst.FOOT_OFFSET_Y)
	await _frames(2)
	_check("پیش از لمس مجسمه جان ۹۰ است", is_equal_approx(GameState.hp_percent(), 90.0))
	k.global_position = (st["at"] as Vector2) - Vector2(0, TdConst.FOOT_OFFSET_Y)
	await _frames(2)
	_check("لمس مجسمه اعلام شد", touched.size() == 1, "= %d" % touched.size())
	_check("و جان پر شد", is_equal_approx(GameState.hp_percent(), 100.0))
	_check("و جای برگشت ذخیره شد", GameState.statue().get("room", "") == "r1a_living"
		and (GameState.statue().get("at", Vector2.ZERO) as Vector2).distance_to(stand) < 1.0)
	await _frames(3)
	_check("ایستادن کنار مجسمه دوباره ذخیره نمی‌سازد", touched.size() == 1)

	# جان را تا ۱۰ پایین ببر، بعد یک تله: صفر
	GameState.run["hp_pct"] = 10.0
	k.global_position = on - Vector2(0, TdConst.FOOT_OFFSET_Y)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check("جان به صفر رسید", GameState.hp_percent() <= 0.0)
	var frames := 0
	var peak := 0.0
	var fade: ColorRect = game.get("_fade")
	while back.is_empty() and frames < 120:
		await get_tree().physics_frame
		frames += 1
		peak = maxf(peak, fade.color.a)
	_check("پرده به سیاهی کامل رسید", peak > 0.95, "= %.2f" % peak)
	var total := frames
	while int(game.get("_statue_frames")) > 0 and total < 120:
		await get_tree().physics_frame
		total += 1
	_check("کل پرده حدود ۰٫۶ ثانیه", total >= 34 and total <= 38, "= %d فریم" % total)
	_check("به مجسمه برگشت", game.kairo.global_position.distance_to(stand) < 1.0,
		"= %s" % str(game.kairo.global_position))
	_check("با جان پر", is_equal_approx(GameState.hp_percent(), 100.0))
	_check("بدون جریمه: شمارندهٔ مرگ دست نخورد", int(GameState.run.get("deaths", 0)) == 0)
	_check("کنترل به بازیکن برگشت", GameMode.control == GameMode.ControlMode.PLAY)
	_check("پرده شفاف شد", fade.color.a < 0.01)
	game.queue_free()
	await _frames(2)

	# بازیکنی که هنوز به هیچ مجسمه‌ای نرسیده، به مجسمهٔ خانه برمی‌گردد
	GameState.data = GameState.default_save()
	GameState.run["hp_pct"] = 10.0
	var g2 := _start("r1a_living")
	await _frames(3)
	# نقطهٔ شروع R1a کنار مجسمه است و لمسش جان را پر می‌کند؛ پس جان را بعد
	# از شروع کم می‌کنیم و ثبت مجسمه را پاک، تا واقعاً «هنوز به هیچ مجسمه‌ای
	# نرسیده» سنجیده شود.
	GameState.data = GameState.default_save()
	GameState.run["hp_pct"] = 10.0
	g2.kairo.global_position = on - Vector2(0, TdConst.FOOT_OFFSET_Y)
	await _frames(45)
	_check("بی مجسمهٔ ثبت‌شده: برگشت به مجسمهٔ خانه",
		g2.kairo.global_position.distance_to(stand) < 1.0 and GameState.hp_percent() >= 100.0,
		"= %s، جان %.0f" % [str(g2.kairo.global_position), GameState.hp_percent()])
	g2.queue_free()
	await _frames(2)
	GameState.data = GameState.default_save()
	GameState.run["hp_pct"] = 100.0


## پنل‌های C3 از خود تصویر (REQ-027 بند ۲، tools/panel_extract.py).
func _t_c3_panels() -> void:
	print("— پنل‌های C3 از روی تصویر —")
	var room := RoomData.new().load_room("c3_electric_hall")
	# از AssetPath می‌گذرد: `bg` در داده `.png` است ولی روی دیسک ممکن
	# است WebP باشد (D-ART-56).
	var bg_tex := AssetPath.texture(String(room["bg"]))
	_check("تصویر C3 پیدا شد", bg_tex != null, String(room["bg"]))
	if bg_tex == null:
		return
	var img: Image = bg_tex.get_image()
	var panels := 0
	var off_cyan: Array[String] = []
	for raw in room["hazard"]:
		var h: Dictionary = raw
		if String(h.get("kind", "")) != "electric":
			continue
		panels += 1
		var poly := RoomData.to_polygon(h["poly"])
		if poly.size() != 4:
			off_cyan.append("%s: %d رأس" % [h["id"], poly.size()])
			continue
		# سهم پیکسل‌های فیروزه‌ای داخل چهارضلعی، نه یک پیکسل مرکز: روی یکی از
		# پنل‌ها کابل قرمز رد می‌شود و مرکزش تیره است
		var box := Rect2(poly[0], Vector2.ZERO)
		for v in poly:
			box = box.expand(v)
		var inside := 0
		var cyan := 0
		for y in range(int(box.position.y), int(box.end.y), 3):
			for x in range(int(box.position.x), int(box.end.x), 3):
				if not Geometry2D.is_point_in_polygon(Vector2(x, y), poly):
					continue
				inside += 1
				var px := img.get_pixel(x, y)
				if px.g > px.r + 0.15 and px.b > px.r + 0.15:
					cyan += 1
		if inside == 0 or float(cyan) / float(inside) < 0.5:
			off_cyan.append("%s: %d/%d" % [h["id"], cyan, inside])
	_check("دست‌کم ۲۰ پنل استخراج شد", panels >= 20, "= %d" % panels)
	_check("هر پنل چهارضلعی است و بیشترش در تصویر فیروزه‌ای", off_cyan.is_empty(),
		str(off_cyan.slice(0, 3)))
	var mp := RoomEffects.clip_mask_path("c3_electric_hall", "panel_cyan_components")
	_check("ماسک نور پنل‌ها هست", ResourceLoader.exists(mp))
	var pr := PaintedRoom.new()
	add_child(pr)
	pr.build(room)
	var clipped := 0
	for n in pr.find_children("*", "Sprite2D", true, false):
		var m := (n as Sprite2D).material as ShaderMaterial
		if m != null and m.get_shader_parameter("use_clip_tex") == true:
			clipped += 1
	_check("نور «clip_mask» نقشهٔ C3 با ماسک بریده شد", clipped >= 1, "= %d نور" % clipped)
	_check("هیچ ماسکی گم نشد", pr.missing_art.filter(
		func(m): return String(m).contains("masks/")).is_empty(), str(pr.missing_art))
	pr.free()


## عدالت اتاق چالش: از نقطهٔ شروع به هر در راهی هست که **روی هیچ خطری**
## فرود نمی‌آید — با راه رفتن، یا جهش از روی خطر (TOPDOWN_SPEC §۳: در
## میانهٔ جهش پا با خطر برخورد نمی‌کند ولی با دیوار بله). برد جهش با ۱۵٪
## حاشیه، همان قاعدهٔ عدالت پروژه. بی این، ماسک خودکار پنل‌ها می‌توانست
## اتاق را حل‌نشدنی کند.
func _t_challenge_fair() -> void:
	print("— اتاق چالش حل‌شدنی است —")
	var l := RoomData.new()
	for rid in ["c1_balcony", "c2_laser_alley", "c3_electric_hall"]:
		var room := l.load_room(rid)
		var sp: Array = room["spawn"]
		var g := 8
		var start := Vector2i(int(float(sp[0]) / g) * g, int(float(sp[1]) / g) * g)
		var seen := {start: true}
		var q: Array[Vector2i] = [start]
		var foot := Vector2(0, TdConst.FOOT_OFFSET_Y)
		var hop := TdConst.HOP_DISTANCE * 0.85
		var dirs: Array[Vector2] = []
		for k in 8:
			dirs.append(Vector2.RIGHT.rotated(TAU * float(k) / 8.0))
		while not q.is_empty():
			var cur: Vector2i = q.pop_front()
			var nexts: Array[Vector2i] = [cur + Vector2i(g, 0), cur + Vector2i(-g, 0),
				cur + Vector2i(0, g), cur + Vector2i(0, -g)]
			for dv in dirs:
				var land := Vector2(cur) + dv * hop
				var clear := true
				var t := 8.0
				while t < hop:
					if not RoomData.point_walkable(room, Vector2(cur) + dv * t):
						clear = false
						break
					t += 8.0
				if clear:
					nexts.append(Vector2i(int(land.x / g) * g, int(land.y / g) * g))
			for nx in nexts:
				if seen.has(nx):
					continue
				var p := Vector2(nx)
				if RoomData.point_walkable(room, p) and RoomData.hazard_at(room, p + foot).is_empty():
					seen[nx] = true
					q.append(nx)
		for raw in room["doors"]:
			var d: Dictionary = raw
			var r: Array = d["rect"]
			var hit := 0
			for key in seen:
				if Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])).has_point(Vector2(key)):
					hit += 1
			_check("  «%s»: راه بی‌خطر تا در «%s»" % [rid, d["id"]], hit >= 4, "= %d خانه" % hit)


func _start(room_id: String) -> RoomGame:
	var game: RoomGame = load("res://scenes/room_game.tscn").instantiate()
	game.set("play_story", false)
	game.start_room = room_id
	game.resume = false
	add_child(game)
	return game


## نخستین خانهٔ ۴ پیکسلی داخل چندضلعی خطر. مرکز هندسی چندضلعی مقعر
## ممکن است بیرونش بیفتد، پس شبکه را می‌گردیم.
func _point_in_hazard(room: Dictionary, hid: String) -> Vector2:
	for raw in room.get("hazard", []):
		var h: Dictionary = raw
		if String(h.get("id", "")) != hid:
			continue
		var poly := RoomData.to_polygon(h.get("poly", []))
		var box := Rect2(poly[0], Vector2.ZERO)
		for v in poly:
			box = box.expand(v)
		var best := Vector2.INF
		var c := box.get_center()
		var y := box.position.y
		while y <= box.end.y:
			var x := box.position.x
			while x <= box.end.x:
				var p := Vector2(x, y)
				if Geometry2D.is_point_in_polygon(p, poly) \
						and RoomData.hazard_at(room, p).get("id", "") == hid \
						and (best == Vector2.INF or p.distance_to(c) < best.distance_to(c)):
					best = p
				x += 4.0
			y += 4.0
		return best
	return Vector2.INF


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
