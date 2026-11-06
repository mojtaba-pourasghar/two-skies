## آزمون موتور اتاق نقاشی‌شده — M1
##
##   godot --headless res://tools/tests/test_rooms.tscn
##
## سه چیز را می‌سنجد که اگر بشکنند بازیکن در دیوار گیر می‌کند یا بازی
## بی‌صدا خالی می‌شود: اعتبارسنجی ماسک، خواندن ماسک از تصویر، و ترتیب
## لایه‌ها (occluder باید **روی** بازیگر باشد).
extends Node2D

const ROOM := "r1a_living"

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	_t_validation()
	_t_real_room()
	_t_mask_queries()
	_t_layers()
	_t_living()
	_report()


func _t_validation() -> void:
	print("— اعتبارسنجی دادهٔ اتاق —")
	var l := RoomData.new()
	var room := l.load_room(ROOM)
	_check("اتاق %s بار شد" % ROOM, not room.is_empty(),
		"" if room.is_empty() else "= %dx%d" % [room["size"][0], room["size"][1]])
	if room.is_empty():
		for e in l.errors:
			print("      %s" % e)
		return
	_check("هیچ خطایی ندارد", l.errors.is_empty(), "= %s" % str(l.errors))
	_check("تصویر پس‌زمینه دارد", String(room["bg"]) != "", "= %s" % room["bg"])
	_check("رفتار دوربین room است", String(room["camera"]) == "room")

	# دادهٔ خراب باید خطا بدهد، نه بی‌صدا رد شود
	var bad := RoomData.new()
	var fake := {
		"id": "bad", "bg": "", "size": [1280, 720], "camera": "isometric",
		"walkable": [[0, 0, 10, 0]],
		"doors": [
			{"id": "d", "rect": [0, 0, 10, 10], "to": "", "spawn": [1, 1]},
			{"id": "d", "rect": [0, 0, 10, 10], "to": "x", "spawn": [1, 1]},
		],
		"spawn": [5000, 5000],
	}
	bad._normalize(fake)
	bad._validate(fake)
	var msgs := " | ".join(bad.errors)
	_check("رفتار دوربین نامعتبر خطا داد", msgs.contains("دوربین"), "")
	_check("نبودن تصویر خطا داد", msgs.contains("پس‌زمینه"), "")
	_check("چندضلعی ۲ نقطه‌ای خطا داد", msgs.contains("walkable[0]"), "")
	_check("در بی‌مقصد و شناسهٔ تکراری خطا دادند",
		msgs.contains("مقصد") and msgs.contains("تکراری"), "")
	_check("نقطهٔ شروع بیرون ماسک خطا داد", msgs.contains("شروع"), "")


func _t_real_room() -> void:
	print("— ساخت اتاق با هنر واقعی —")
	var l := RoomData.new()
	var room := l.load_room(ROOM)
	if room.is_empty():
		return
	var node := PaintedRoom.new()
	add_child(node)
	node.build(room)
	_check("هیچ دارایی هنری گم نشد", node.missing_art.is_empty(),
		"= %s" % str(node.missing_art))
	_check("مرز اتاق از اندازهٔ تصویر می‌آید",
		node.bounds().size == Vector2(1280, 720), "= %s" % str(node.bounds().size))
	_check("پس‌زمینه کشیده شد",
		node.get_node("World/Background").get_child_count() == 1)
	_check("پراپ‌ها کشیده شدند",
		node.get_node("World/Props").get_child_count() >= 1,
		"= %d" % node.get_node("World/Props").get_child_count())
	_check("occluderها کشیده شدند",
		node.get_node("World/Occluders").get_child_count() >= 2,
		"= %d" % node.get_node("World/Occluders").get_child_count())
	_check("لایهٔ نور کشیده شد",
		node.get_node("World/Light").get_child_count() >= 1,
		"= %d" % node.get_node("World/Light").get_child_count())
	node.queue_free()


func _t_mask_queries() -> void:
	print("— ماسک از روی تصویر خوانده می‌شود —")
	var l := RoomData.new()
	var room := l.load_room(ROOM)
	if room.is_empty():
		return
	var spawn := Vector2(float(room["spawn"][0]), float(room["spawn"][1]))
	_check("نقطهٔ شروع روی زمین است", RoomData.point_walkable(room, spawn),
		"= %s" % str(spawn))
	_check("بیرون قاب روی زمین نیست",
		not RoomData.point_walkable(room, Vector2(-50, -50)))
	_check("دیوار پنجره (بالا-چپ) روی زمین نیست",
		not RoomData.point_walkable(room, Vector2(300, 150)))

	# سوراخ‌ها: مبل جایی است که ماسک **دارد** ولی نباید رفت
	var sofa := Vector2(380, 430)
	var inside_walk := false
	for flat in room["walkable"]:
		if Geometry2D.is_point_in_polygon(sofa, RoomData.to_polygon(flat)):
			inside_walk = true
	_check("مبل داخل چندضلعی قابل‌راه‌رفتن است", inside_walk)
	_check("ولی سوراخ `blocked` جلویش را می‌گیرد",
		not RoomData.point_walkable(room, sofa), "= %s" % str(sofa))

	var hz := RoomData.hazard_at(room, Vector2(640, 515))
	_check("ماسک خطر کف شکسته خوانده می‌شود", not hz.is_empty(),
		"= %s" % String(hz.get("id", "-")))
	_check("خطر آسیب ۱۰٪ دارد، نه مرگ",
		is_equal_approx(float(hz.get("damage_pct", 0.0)), 10.0),
		"= %.0f٪" % float(hz.get("damage_pct", 0.0)))
	_check("جای امن خطر بیرون خودش است",
		not RoomData.hazard_at(room,
			Vector2(float(hz["safe"][0]), float(hz["safe"][1]))).has("id"))

	# مرکز در را از خود داده می‌گیریم، نه عدد دست‌نویس: ماسک از روی تصویر
	# کشیده می‌شود و با هر اصلاح جابه‌جا می‌شود (درس D-ART-17).
	var door_rect: Array = ((room["doors"] as Array)[0] as Dictionary)["rect"]
	var door_mid := Vector2(
		float(door_rect[0]) + float(door_rect[2]) * 0.5,
		float(door_rect[1]) + float(door_rect[3]) * 0.5)
	var dr := RoomData.door_at(room, door_mid)
	_check("در طاق از مرکز خودش خوانده می‌شود", not dr.is_empty(),
		"= %s → %s در %s" % [dr.get("id", "-"), dr.get("to", "-"), str(door_mid)])
	_check("نقطه‌ای دور از هر در، در نیست",
		RoomData.door_at(room, Vector2(200, 650)).is_empty())


## ترتیب لایه‌ها اهمیت دارد: اگر occluder زیر بازیگر بیاید، شخصیت روی ستون
## کشیده می‌شود؛ اگر نور زیر occluder بیاید، هاله پشت پرده گیر می‌کند.
func _t_layers() -> void:
	print("— ترتیب لایه‌ها —")
	var l := RoomData.new()
	var room := l.load_room(ROOM)
	if room.is_empty():
		return
	var node := PaintedRoom.new()
	add_child(node)
	node.build(room)
	var bg: Node2D = node.get_node("World/Background")
	var props: Node2D = node.get_node("World/Props")
	var actors: Node2D = node.actors
	var occ: Node2D = node.get_node("World/Occluders")
	var light: Node2D = node.get_node("World/Light")
	_check("نقاشی زیر همه است", bg.z_index < props.z_index)
	_check("پراپ زیر بازیگر است", props.z_index < actors.z_index)
	_check("occluder روی بازیگر است", occ.z_index > actors.z_index)
	_check("نور روی occluder است", light.z_index > occ.z_index)
	_check("Y-sort روی دنیا و بازیگران روشن است",
		node.world.y_sort_enabled and actors.y_sort_enabled)
	node.queue_free()


## محیط زنده (قاعدهٔ ۹ CLAUDE.md، D-ART-42). اتاق ساکن «تمام» نیست، و
## کد باید **بگوید** کدام سه چیز را ندارد، نه اینکه بی‌صدا ساکن بماند.
func _t_living() -> void:
	print("— محیط زنده —")
	var l := RoomData.new()
	var room := l.load_room(ROOM)
	if room.is_empty():
		return
	var node := PaintedRoom.new()
	add_child(node)
	node.build(room)

	var motion: Node2D = node.get_node("World/Motion")
	var parts: Node2D = node.get_node("World/Particles")
	_check("لایهٔ حرکت روی نقاشی و زیر پراپ است",
		motion.z_index > 0 and motion.z_index < node.get_node("World/Props").z_index,
		"= z %d" % motion.z_index)
	_check("لایهٔ ذره هم‌سطح نور است (روی occluder)",
		parts.z_index > node.get_node("World/Occluders").z_index,
		"= z %d" % parts.z_index)

	var made := parts.get_child_count()
	_check("جریان ذرهٔ اتاق ساخته شد", made >= 1, "= %d جریان" % made)
	var pre_spread := true
	for c in parts.get_children():
		var ps := c as CPUParticles2D
		if ps == null or ps.amount < 1 or ps.preprocess <= 0.0:
			pre_spread = false
	# بدون preprocess همهٔ ذره‌ها با هم از صفر می‌زنند و ورود به اتاق
	# یک موج ناگهانی گرد می‌شود
	_check("ذره‌ها از لحظهٔ ورود پخش‌شده‌اند", pre_spread)

	var living: Dictionary = node.living_layers()
	_check("نور متغیر دارد (سوسوی هاله)", bool(living["variable_light"]))
	_check("شمارش جریان ذره با لایهٔ ساخته‌شده می‌خواند",
		int(living["particles"]) == made, "= %d" % int(living["particles"]))
	# این اتاق هنوز حرکت طبیعت ندارد (REQ-019). آزمون **همین** را ثبت
	# می‌کند تا روزی که هنر رسید، سنجه خودش عوض شود و یادمان بیاید.
	_check("اتاق بی‌حرکتِ طبیعت «تمام» شمرده نمی‌شود",
		node.is_living() == (int(living["motion"]) > 0),
		"= حرکت %d، زنده %s" % [int(living["motion"]), str(node.is_living())])
	var warned := false
	for w in l.warnings:
		if w.contains("قاعدهٔ ۹"):
			warned = true
	_check("نبودِ لایهٔ زنده هشدار می‌دهد نه سکوت",
		warned if not node.is_living() else true)

	# ناحیهٔ زوم: اتاق هم‌اندازهٔ صفحه نباید ناحیهٔ زوم داشته باشد (REQ-018)
	_check("ناحیهٔ زوم اتاق به شکل Rect2 درمی‌آید",
		node.zoom_zones().size() == (room["zoom_zones"] as Array).size())
	node.queue_free()

	# دادهٔ غلط باید خطا بدهد، نه بی‌صدا رد شود
	var bad := {"id": "z", "bg": "x.png", "size": [2560, 1080],
		"walkable": [[0, 0, 100, 0, 100, 100]], "spawn": [10, 10],
		"zoom_zones": [{"rect": [0, 0, 100, 100], "level": "telescope"}]}
	var v := RoomData.new()
	v._normalize(bad)
	v._validate(bad)
	var caught := false
	for e in v.errors:
		if e.contains("سطح زوم"):
			caught = true
	_check("سطح زوم ناموجود خطای اعتبارسنجی است", caught)


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
