## قالب دادهٔ اتاق نقاشی‌شده (M1، سند ۱۲ §۷)
##
## هر اتاق یک **تصویر کامل** است، نه کاشی تکرارشونده (سند ۱۱، D-ART-30).
## آنچه کد لازم دارد و از تصویر خوانده نمی‌شود، چندضلعی است: کجا می‌شود رفت،
## کجا دیوار، کجا خطر. **تصویر برنده است** — ماسک از روی آن کشیده می‌شود،
## نه برعکس.
##
##   {
##     "id": "r1a_living",
##     "bg": "scenes/ch1/house_1280x720.png",
##     "size": [1280, 720],
##     "camera": "room",                     // یا "follow"
##     "walkable": [[x,y, x,y, ...], ...],   // چندضلعی‌های قابل‌راه‌رفتن
##     "hazard":   [{"id":..., "poly":[...], "kind":"pit"|"laser"|"electric"}],
##     "doors":    [{"id":..., "rect":[x,y,w,h], "to":"r1b", "spawn":[x,y]}],
##     "props":    [{"id":"save_statue", "at":[x,y]}],
##     "enemies":  [{"id":..., "encounter":"ch1_a2_crawlers", "at":[x,y],
##                   "art":"enemies/nexa_topdown/crawler_0.png", "radius":56}],
##     "occluders":[{"img":"occluders/ch1/arch_gothic.png", "at":[x,y]}],
##     "light":    {"overlays":[{"img":..., "at":[x,y], "flicker":2.0}]},
##     "ambient":  {"motion":   [{"img":..., "at":[x,y], "frames":6, "fps":8}],
##                  "particles":[{"kind":"ember", "rect":[x,y,w,h], "count":8}]},
##     "zoom_zones":[{"rect":[x,y,w,h], "level":"close", "seconds":1.0}],
##     "spawn": [x, y]
##   }
##
## همهٔ مختصات **پیکسل روی تصویر**اند، نه کاشی: اتاق نقاشی است و کاشی ندارد.
class_name RoomData
extends RefCounted

const DIR := "res://rooms/"

var errors: Array[String] = []
var warnings: Array[String] = []


func load_room(room_id: String) -> Dictionary:
	errors.clear()
	warnings.clear()
	var path := DIR + room_id + ".json"
	if not FileAccess.file_exists(path):
		errors.append("اتاق «%s» پیدا نشد: %s" % [room_id, path])
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		errors.append("فایل اتاق «%s» خراب است." % room_id)
		return {}
	var room: Dictionary = parsed
	_normalize(room)
	_validate(room)
	return room if errors.is_empty() else {}


func _normalize(room: Dictionary) -> void:
	room["id"] = String(room.get("id", "unknown"))
	room["bg"] = String(room.get("bg", ""))
	room["camera"] = String(room.get("camera", CameraDirector.BEHAVIOR_ROOM))
	var size: Array = room.get("size", [1280, 720])
	room["size"] = [int(size[0]), int(size[1])] if size.size() == 2 else [1280, 720]
	for key in ["walkable", "blocked", "hazard", "doors", "props", "occluders", "enemies",
			"hackables", "checkpoints", "pickups"]:
		if not room.has(key):
			room[key] = []
	if not room.has("light"):
		room["light"] = {}
	if not room.has("zoom_zones"):
		room["zoom_zones"] = []
	var sp: Array = room.get("spawn", [])
	if sp.size() != 2:
		room["spawn"] = [int(room["size"][0]) / 2, int(room["size"][1]) / 2]
		warnings.append("اتاق «%s» نقطهٔ شروع ندارد؛ وسط تصویر گرفته شد." % room["id"])


func _validate(room: Dictionary) -> void:
	var rid := String(room["id"])
	if room["camera"] not in [CameraDirector.BEHAVIOR_ROOM, CameraDirector.BEHAVIOR_FOLLOW]:
		errors.append("اتاق «%s»: رفتار دوربین نامعتبر «%s»." % [rid, room["camera"]])

	if String(room["bg"]) == "":
		errors.append("اتاق «%s»: تصویر پس‌زمینه ندارد. اتاق نقاشی‌شده بدون تصویر معنا ندارد." % rid)
	elif not AssetPath.exists(String(room["bg"])):
		# هنر نرسیده: هشدار، نه خطا — بازی نباید به‌خاطر هنر نیامده نشکند
		warnings.append("اتاق «%s»: تصویر «%s» هنوز در assets نیست." % [rid, room["bg"]])

	# بدون چندضلعی قابل‌راه‌رفتن، بازیکن هیچ‌جا نمی‌تواند برود
	var walk: Array = room["walkable"]
	if walk.is_empty():
		errors.append("اتاق «%s»: هیچ چندضلعی قابل‌راه‌رفتنی ندارد." % rid)
	for i in walk.size():
		_check_poly(rid, "walkable[%d]" % i, walk[i])
	for i in (room["blocked"] as Array).size():
		_check_poly(rid, "blocked[%d]" % i, room["blocked"][i])

	for raw in room["hazard"]:
		var h: Dictionary = raw
		var hid := String(h.get("id", ""))
		if hid == "":
			errors.append("اتاق «%s»: یک خطر شناسه ندارد." % rid)
			continue
		_check_poly(rid, "خطر «%s»" % hid, h.get("poly", []))
		if String(h.get("kind", "")) == "":
			warnings.append("اتاق «%s»: خطر «%s» نوع ندارد." % [rid, hid])

	var seen: Dictionary = {}
	for raw in room["doors"]:
		var d: Dictionary = raw
		var did := String(d.get("id", ""))
		if did == "" or seen.has(did):
			errors.append("اتاق «%s»: شناسهٔ در خالی یا تکراری «%s»." % [rid, did])
			continue
		seen[did] = true
		var rect: Array = d.get("rect", [])
		if rect.size() != 4 or float(rect[2]) <= 0.0 or float(rect[3]) <= 0.0:
			errors.append("اتاق «%s»: در «%s» rect معتبر ندارد." % [rid, did])
		if String(d.get("to", "")) == "":
			errors.append("اتاق «%s»: در «%s» مقصد ندارد." % [rid, did])
		var sp: Array = d.get("spawn", [])
		if sp.size() != 2:
			errors.append("اتاق «%s»: در «%s» نقطهٔ ورود مقصد را ندارد." % [rid, did])

	# دشمن دیدنی (سند ۰۹ §۲، M4-پ): نبرد تصادفی نیست، برخورد با دشمنِ روی
	# نقشه نبرد را شروع می‌کند. دشمنی که بیرون ماسک بایستد هرگز لمس نمی‌شود.
	var eseen: Dictionary = {}
	for raw in room["enemies"]:
		var e: Dictionary = raw
		var eid := String(e.get("id", ""))
		if eid == "" or eseen.has(eid):
			errors.append("اتاق «%s»: شناسهٔ دشمن خالی یا تکراری «%s»." % [rid, eid])
			continue
		eseen[eid] = true
		if String(e.get("encounter", "")) == "":
			errors.append("اتاق «%s»: دشمن «%s» نبرد ندارد." % [rid, eid])
		var at: Array = e.get("at", [])
		if at.size() != 2:
			errors.append("اتاق «%s»: دشمن «%s» جا ندارد." % [rid, eid])
		elif not walk.is_empty() and not point_walkable(room, Vector2(float(at[0]), float(at[1]))):
			errors.append("اتاق «%s»: دشمن «%s» بیرون ناحیهٔ قابل‌راه‌رفتن است." % [rid, eid])
		# گشت (M5-ت): نقطه‌ای که روی ماسک نباشد یعنی دشمن تا ابد در دیوار
		# فشار می‌دهد و هرگز به نقطهٔ بعدی نمی‌رسد — گشت بی‌صدا می‌ایستد.
		var pat: Array = e.get("patrol", [])
		if not pat.is_empty() and pat.size() < 2:
			errors.append("اتاق «%s»: گشت دشمن «%s» کمتر از دو نقطه دارد." % [rid, eid])
		for i in pat.size():
			var pt: Array = pat[i]
			if pt.size() != 2:
				errors.append("اتاق «%s»: نقطهٔ گشت %d دشمن «%s» دو عدد نیست." % [rid, i, eid])
			elif not walk.is_empty() \
					and not point_walkable(room, Vector2(float(pt[0]), float(pt[1]))):
				errors.append("اتاق «%s»: نقطهٔ گشت %d دشمن «%s» (%d,%d) بیرون ماسک است."
					% [rid, i, eid, int(pt[0]), int(pt[1])])
		if not pat.is_empty() and float(e.get("speed", MapEnemy.DEF_SPEED)) <= 0.0:
			errors.append("اتاق «%s»: دشمن «%s» گشت دارد ولی سرعتش صفر است." % [rid, eid])
		var vis: Dictionary = e.get("vision", {})
		if not vis.is_empty():
			var ang := float(vis.get("angle", MapEnemy.DEF_ANGLE))
			if ang <= 0.0 or ang > 180.0:
				errors.append("اتاق «%s»: زاویهٔ دید دشمن «%s» باید بین ۰ و ۱۸۰ باشد (%d)."
					% [rid, eid, int(ang)])
			if float(vis.get("range", MapEnemy.DEF_RANGE)) < 0.0:
				errors.append("اتاق «%s»: برد دید دشمن «%s» منفی است." % [rid, eid])

	_validate_occluders(room, rid)
	_validate_gear(room, rid)

	_validate_living(room, rid)

	# نقطهٔ شروع باید **داخل** ناحیهٔ قابل‌راه‌رفتن باشد، وگرنه بازیکن در
	# دیوار ظاهر می‌شود و هیچ خطایی هم نمی‌بیند.
	var spawn := Vector2(float(room["spawn"][0]), float(room["spawn"][1]))
	if not walk.is_empty() and not point_walkable(room, spawn):
		errors.append("اتاق «%s»: نقطهٔ شروع (%d,%d) بیرون ناحیهٔ قابل‌راه‌رفتن است."
			% [rid, int(spawn.x), int(spawn.y)])




## پایانهٔ هک و چک‌پوینت (M5-ب). هر سه خطای اینجا یعنی اتاق چالش
## **غیرقابل‌تمام‌کردن** می‌شود، و هیچ‌کدام در بازی صدا نمی‌دهند:
## پایانه‌ای بیرون ماسک هرگز لمس نمی‌شود، نام خطرِ ناموجود یعنی هک
## هیچ‌کاری نمی‌کند، و چک‌پوینت روی کاشی برق‌دار یعنی حلقهٔ مرگ.
func _validate_gear(room: Dictionary, rid: String) -> void:
	var walk: Array = room["walkable"]
	var hz: Dictionary = {}
	for raw in room["hazard"]:
		hz[String((raw as Dictionary).get("id", ""))] = true
	var seen: Dictionary = {}
	for raw in room.get("hackables", []):
		var hk: Dictionary = raw
		var hid := String(hk.get("id", ""))
		if hid == "" or seen.has(hid):
			errors.append("اتاق «%s»: شناسهٔ پایانه خالی یا تکراری «%s»." % [rid, hid])
			continue
		seen[hid] = true
		var at: Array = hk.get("at", [])
		if at.size() != 2:
			errors.append("اتاق «%s»: پایانهٔ «%s» جا ندارد." % [rid, hid])
			continue
		var p := Vector2(float(at[0]), float(at[1]))
		if not walk.is_empty() and not point_walkable(room, p):
			errors.append("اتاق «%s»: پایانهٔ «%s» (%d,%d) بیرون ماسک است؛ هرگز لمس نمی‌شود."
				% [rid, hid, int(p.x), int(p.y)])
		var dis: Array = hk.get("disables", [])
		if dis.is_empty():
			warnings.append("اتاق «%s»: پایانهٔ «%s» هیچ خطری را خاموش نمی‌کند." % [rid, hid])
		for d in dis:
			if not hz.has(String(d)):
				errors.append("اتاق «%s»: پایانهٔ «%s» خطر ناموجود «%s» را صدا می‌زند."
					% [rid, hid, String(d)])

	var pseen: Dictionary = {}
	for raw in room.get("pickups", []):
		var pk: Dictionary = raw
		var pid := String(pk.get("id", ""))
		if pid == "" or pseen.has(pid):
			errors.append("اتاق «%s»: شناسهٔ قلم خالی یا تکراری «%s»." % [rid, pid])
			continue
		pseen[pid] = true
		var pat: Array = pk.get("at", [])
		if pat.size() != 2:
			errors.append("اتاق «%s»: قلم «%s» جا ندارد." % [rid, pid])
			continue
		var pp := Vector2(float(pat[0]), float(pat[1]))
		# قلمی بیرون ماسک هرگز برداشته نمی‌شود و بازیکن فکر می‌کند باگ است
		if not walk.is_empty() and not point_walkable(room, pp):
			errors.append("اتاق «%s»: قلم «%s» (%d,%d) بیرون ماسک است."
				% [rid, pid, int(pp.x), int(pp.y)])
		if bool(pk.get("needs_action", false)) \
				and (pk.get("contains", {}) as Dictionary).is_empty():
			warnings.append("اتاق «%s»: صندوق «%s» خالی است." % [rid, pid])

	var cseen: Dictionary = {}
	for raw in room.get("checkpoints", []):
		var cp: Dictionary = raw
		var cid := String(cp.get("id", ""))
		if cid == "" or cseen.has(cid):
			errors.append("اتاق «%s»: شناسهٔ چک‌پوینت خالی یا تکراری «%s»." % [rid, cid])
			continue
		cseen[cid] = true
		var cat: Array = cp.get("at", [])
		if cat.size() != 2:
			errors.append("اتاق «%s»: چک‌پوینت «%s» جا ندارد." % [rid, cid])
			continue
		var q := Vector2(float(cat[0]), float(cat[1]))
		if not walk.is_empty() and not point_walkable(room, q):
			errors.append("اتاق «%s»: چک‌پوینت «%s» بیرون ماسک است." % [rid, cid])
		elif not hazard_at(room, q).is_empty():
			errors.append("اتاق «%s»: چک‌پوینت «%s» روی خطر است؛ حلقهٔ مرگ می‌سازد."
				% [rid, cid])

## occluder — قاعده‌های کاربر در گام ۵۵ (REQ-032).
##
## هر شکایت اینجا یک نقصی است که **فقط در ضبط** دیده می‌شد:
## تکه‌ای که روی در افتاده، تکه‌ای که پای ایستادنش را ننوشته‌ایم و
## بازیکنِ جلویش را هم می‌پوشاند، و تکه‌ای که هنرش اصلاً نیامده.
func _validate_occluders(room: Dictionary, rid: String) -> void:
	var oseen: Dictionary = {}
	for raw in room["occluders"]:
		var o: Dictionary = raw
		var oid := String(o.get("id", ""))
		if oid != "":
			if oseen.has(oid):
				errors.append("اتاق «%s»: شناسهٔ occluder تکراری «%s»." % [rid, oid])
			oseen[oid] = true
		if (o.get("cut", []) as Array).size() >= 6:
			if float(o.get("base_y", 0.0)) <= 0.0:
				errors.append("اتاق «%s»: بریدهٔ «%s» base_y ندارد؛ بی آن هرگز کسی را نمی‌پوشاند."
					% [rid, oid])
			continue
		var img := String(o.get("img", ""))
		if img == "":
			errors.append("اتاق «%s»: occluder «%s» نه بریده است نه تصویر." % [rid, oid])
			continue
		if not AssetPath.exists(img):
			warnings.append("اتاق «%s»: تصویر occluder «%s» هنوز در assets نیست." % [rid, img])
		var at: Array = o.get("at", [])
		if at.size() != 2:
			errors.append("اتاق «%s»: occluder «%s» جا ندارد." % [rid, oid])
			continue
		var pos := Vector2(float(at[0]), float(at[1]))
		var base_y := float(o.get("base_y", 0.0))
		if base_y > 0.0 and base_y < pos.y:
			errors.append("اتاق «%s»: occluder «%s» base_y (%d) بالاتر از خود تصویر (%d) است."
				% [rid, oid, int(base_y), int(pos.y)])
		# روی در نیفتد: دری که پشت یک ستون پنهان شود، راه بسته است.
		for raw_d in room["doors"]:
			var d: Dictionary = raw_d
			var r: Array = d.get("rect", [])
			if r.size() != 4:
				continue
			var dr := Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
			var orect := Rect2(pos, Vector2(float(o.get("w", 0.0)), float(o.get("h", 0.0))))
			if orect.size.x <= 0.0 or orect.size.y <= 0.0:
				continue
			if orect.intersects(dr):
				errors.append("اتاق «%s»: occluder «%s» روی در «%s» افتاده است."
					% [rid, oid, String(d.get("id", "?"))])

## بودجهٔ زندگی (سند ۱۳). **هشدار است نه خطا**: هنر زندهٔ اتاق‌ها هنوز نرسیده
## (REQ-019) و بازی نباید به‌خاطر نیامدن هنر بوت نشود. ولی هشدار سر جایش
## می‌ماند تا «اتاق تمام شد» بی‌دلیل گفته نشود.
func _validate_living(room: Dictionary, rid: String) -> void:
	# افکت‌ها دیگر در خود اتاق نیستند؛ در نقشهٔ تصویر اتاق‌اند (سند ۱۴).
	# پس اعتبارسنجی هم باید **همان نقشه** را بخواند، نه بلوکی که برداشته
	# شده — وگرنه هر اتاقی بی‌دلیل هشدار می‌گیرد.
	var map_name := String(room.get("fx_map", rid))
	var path := RoomEffects.map_path(map_name)
	if not FileAccess.file_exists(path):
		warnings.append("اتاق «%s»: نقشهٔ افکت «%s» نیست؛ صحنه ساکن می‌ماند."
			% [rid, map_name])
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		errors.append("اتاق «%s»: نقشهٔ افکت «%s» خراب است." % [rid, map_name])
		return

	var kinds: Dictionary = {}
	for raw in (parsed as Dictionary).get("effects", []):
		if raw is Dictionary:
			var t := String((raw as Dictionary).get("type", ""))
			kinds[t] = int(kinds.get(t, 0)) + 1

	# سه سطل، با انواع تازهٔ گام ۵۲ (arc_pop، neon_buzz، laser_hum،
	# led_blink) در جای درستشان.
	var moving: int = int(kinds.get("sway", 0)) + int(kinds.get("anim", 0)) \
		+ int(kinds.get("fog_patch", 0))
	var parts: int = int(kinds.get("embers", 0)) + int(kinds.get("dust_in_beam", 0)) \
		+ int(kinds.get("arc_pop", 0))
	var lights: int = int(kinds.get("flicker_light", 0)) \
		+ int(kinds.get("glow_pulse", 0)) + int(kinds.get("neon_buzz", 0)) \
		+ int(kinds.get("laser_hum", 0)) + int(kinds.get("led_blink", 0))

	var missing: Array[String] = []
	if moving + parts + lights < 3:
		missing.append("کمتر از ۳ منبع")
	if lights == 0:
		missing.append("هیچ نور زنده‌ای ندارد")
	if moving == 0 and parts == 0:
		missing.append("نه حرکتی دارد نه ذره‌ای")
	# **شرط «هر اتاق باید ذره داشته باشد» برداشته شد.** سند ۱۴ می‌گوید
	# ذره فقط **از منبع** باشد، نه اینکه هر اتاقی منبعی داشته باشد. با
	# شرط قبلی، سه اتاقی که مدیر هنر عمداً بی‌ذره طراحی کرده بود
	# (R1e، C2، S3a) بی‌دلیل هشدار می‌گرفتند.
	if not missing.is_empty():
		warnings.append("اتاق «%s» بودجهٔ زندگی را ندارد: %s."
			% [rid, ", ".join(missing)])

	for raw in room["zoom_zones"]:
		if not (raw is Dictionary):
			errors.append("اتاق «%s»: ناحیهٔ زوم باید شیء باشد." % rid)
			continue
		var z: Dictionary = raw
		var r: Array = z.get("rect", [])
		if r.size() != 4 or float(r[2]) <= 0.0 or float(r[3]) <= 0.0:
			errors.append("اتاق «%s»: ناحیهٔ زوم rect معتبر ندارد." % rid)
		var lvl := String(z.get("level", ""))
		if lvl not in GameCamera.ZOOM_LEVELS:
			errors.append("اتاق «%s»: سطح زوم «%s» وجود ندارد." % [rid, lvl])
			continue
		# **زوم بالای ۱٫۱۲ بدون نسخهٔ پرجزئیات ممنوع است** (تصمیم کاربر،
		# D-ART-58). بدون این قاعده، اتاقی می‌توانست ناحیهٔ زوم `close`
		# بگذارد و دوربین بی‌صدا روی ۱٫۱۲ قفل شود — یعنی ناحیهٔ زوم
		# نوشته شده و کار نمی‌کند، و هیچ‌کس نمی‌فهمد.
		if float(GameCamera.ZOOM_LEVELS[lvl]) > PaintedRoom.ZOOM_WITHOUT_HIRES \
				and not AssetPath.exists(String(room.get("hires", ""))):
			errors.append(("اتاق «%s»: ناحیهٔ زوم «%s» (%.2f×) نسخهٔ پرجزئیات "
				+ "لازم دارد. یا `hires` اتاق را بده، یا سطح زوم را به "
				+ "`normal` یا `wide` ببر.")
				% [rid, lvl, float(GameCamera.ZOOM_LEVELS[lvl])])

	# اتاقی هم‌اندازهٔ صفحه جا برای حرکت دوربین ندارد و زوم روی آن یعنی
	# بریدن لبه. REQ-018 اتاق تازه را ۱٫۵ تا ۲ برابر صفحه می‌خواهد.
	var w := float(room["size"][0])
	var h := float(room["size"][1])
	if not (room["zoom_zones"] as Array).is_empty() and w <= 1280.0 and h <= 720.0:
		warnings.append(("اتاق «%s» %d×%d است (هم‌اندازهٔ صفحه) ولی ناحیهٔ زوم "
			+ "دارد؛ زوم باز لبه را می‌برد. REQ-018.") % [rid, int(w), int(h)])


## نواحی زوم را به شکلی می‌دهد که دوربین می‌خواهد (Rect2 نه آرایه).
static func zoom_zones(room: Dictionary) -> Array:
	var out: Array = []
	for raw in room.get("zoom_zones", []):
		if not (raw is Dictionary):
			continue
		var z: Dictionary = raw
		var r: Array = z.get("rect", [])
		if r.size() != 4:
			continue
		out.append({
			"rect": Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])),
			"level": String(z.get("level", GameCamera.ZOOM_NORMAL)),
			"seconds": float(z.get("seconds", GameCamera.ZOOM_SECONDS)),
		})
	return out


func _check_poly(rid: String, what: String, poly) -> void:
	if typeof(poly) != TYPE_ARRAY:
		errors.append("اتاق «%s»: %s چندضلعی نیست." % [rid, what])
		return
	var pts: Array = poly
	if pts.size() < 6 or pts.size() % 2 != 0:
		errors.append("اتاق «%s»: %s باید دست‌کم ۳ نقطه (۶ عدد) و زوج باشد؛ %d عدد دارد."
			% [rid, what, pts.size()])


## آرایهٔ مسطح [x,y,x,y,...] را به چندضلعی Godot می‌برد.
static func to_polygon(flat: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	var i := 0
	while i + 1 < flat.size():
		out.append(Vector2(float(flat[i]), float(flat[i + 1])))
		i += 2
	return out


## آیا این نقطه روی زمین قابل‌راه‌رفتن است؟
##
## `blocked` سوراخ‌های داخل ناحیهٔ قابل‌راه‌رفتن است (مبل، میز، بوفه).
## `Geometry2D.is_point_in_polygon` سوراخ نمی‌شناسد، پس جدا سنجیده می‌شود —
## وگرنه هر چندضلعی با سوراخ باید به چند تکهٔ بی‌قواره بریده شود.
static func point_walkable(room: Dictionary, p: Vector2) -> bool:
	var inside := false
	for flat in room.get("walkable", []):
		if Geometry2D.is_point_in_polygon(p, to_polygon(flat)):
			inside = true
			break
	if not inside:
		return false
	for flat in room.get("blocked", []):
		if Geometry2D.is_point_in_polygon(p, to_polygon(flat)):
			return false
	return true


## اگر روی خطری ایستاده، شناسه و نوعش را می‌دهد؛ وگرنه خالی.
static func hazard_at(room: Dictionary, p: Vector2) -> Dictionary:
	for raw in room.get("hazard", []):
		var h: Dictionary = raw
		if Geometry2D.is_point_in_polygon(p, to_polygon(h.get("poly", []))):
			return h
	return {}


## اگر داخل دری ایستاده، آن در را می‌دهد.
static func door_at(room: Dictionary, p: Vector2) -> Dictionary:
	for raw in room.get("doors", []):
		var d: Dictionary = raw
		var r: Array = d.get("rect", [])
		if r.size() != 4:
			continue
		if Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])).has_point(p):
			return d
	return {}
