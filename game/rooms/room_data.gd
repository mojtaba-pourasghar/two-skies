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
	for key in ["walkable", "blocked", "hazard", "doors", "props", "occluders"]:
		if not room.has(key):
			room[key] = []
	if not room.has("light"):
		room["light"] = {}
	# محیط زنده (قاعدهٔ ۹ CLAUDE.md، D-ART-42)
	var amb = room.get("ambient", {})
	room["ambient"] = amb if amb is Dictionary else {}
	for key in ["motion", "particles"]:
		if not (room["ambient"] as Dictionary).has(key):
			(room["ambient"] as Dictionary)[key] = []
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
	elif not ResourceLoader.exists("res://assets/" + String(room["bg"])):
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

	_validate_living(room, rid)

	# نقطهٔ شروع باید **داخل** ناحیهٔ قابل‌راه‌رفتن باشد، وگرنه بازیکن در
	# دیوار ظاهر می‌شود و هیچ خطایی هم نمی‌بیند.
	var spawn := Vector2(float(room["spawn"][0]), float(room["spawn"][1]))
	if not walk.is_empty() and not point_walkable(room, spawn):
		errors.append("اتاق «%s»: نقطهٔ شروع (%d,%d) بیرون ناحیهٔ قابل‌راه‌رفتن است."
			% [rid, int(spawn.x), int(spawn.y)])


## قاعدهٔ ۹: هر اتاق دست‌کم یک حرکت طبیعت + یک جریان ذره + یک نور متغیر
## می‌خواهد. **هشدار است نه خطا**: هنر زندهٔ اتاق‌ها هنوز نرسیده
## (REQ-019) و بازی نباید به‌خاطر نیامدن هنر بوت نشود. ولی هشدار سر جایش
## می‌ماند تا «اتاق تمام شد» بی‌دلیل گفته نشود.
func _validate_living(room: Dictionary, rid: String) -> void:
	var amb: Dictionary = room["ambient"]
	var missing: Array[String] = []
	if (amb["motion"] as Array).is_empty():
		missing.append("حرکت طبیعت")
	if (amb["particles"] as Array).is_empty():
		missing.append("جریان ذره")
	var pulsing := false
	for raw in (room["light"] as Dictionary).get("overlays", []):
		if raw is Dictionary and float((raw as Dictionary).get("flicker", 0.0)) > 0.0:
			pulsing = true
			break
	if not pulsing:
		missing.append("نور متغیر")
	if not missing.is_empty():
		warnings.append("اتاق «%s» طبق قاعدهٔ ۹ تمام نیست: %s ندارد."
			% [rid, ", ".join(missing)])

	for raw in room["zoom_zones"]:
		if not (raw is Dictionary):
			errors.append("اتاق «%s»: ناحیهٔ زوم باید شیء باشد." % rid)
			continue
		var z: Dictionary = raw
		var r: Array = z.get("rect", [])
		if r.size() != 4 or float(r[2]) <= 0.0 or float(r[3]) <= 0.0:
			errors.append("اتاق «%s»: ناحیهٔ زوم rect معتبر ندارد." % rid)
		if String(z.get("level", "")) not in GameCamera.ZOOM_LEVELS:
			errors.append("اتاق «%s»: سطح زوم «%s» وجود ندارد."
				% [rid, z.get("level", "")])

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
