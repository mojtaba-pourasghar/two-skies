## بارگذار ناحیهٔ اکتشافی — قالب تازه، جدا از قالب مرحلهٔ کناری (T15)
##
## چرا قالب تازه (D-ART-29): قالب `levels/data/*.json` اتاق را ۳۰×۱۷ کاشیِ
## **ثابت** می‌گیرد و پر از منطق نمای کناری است (`exits` با سطر، `floor_gaps`،
## مُهر کردن لبه). ناحیهٔ اکتشافی اندازهٔ آزاد می‌خواهد («۲ تا ۴ صفحه»،
## سند ۰۹ §۵) و لایهٔ کف/دیوار و پراپ و تله. قالب کناری برای اتاق چالش
## دست‌نخورده می‌ماند.
##
## نقش و نوع برخورد هر کاشی از `roles.json` کنار خود کاشی می‌آید، نه از
## شمارهٔ دست‌نویس در کد (`art/TILE_ROLES.md`).
class_name AreaLoader
extends RefCounted

const TILE: int = 32

## نویسه‌های لایهٔ کف و دیوار. «.» یعنی خالی.
const EMPTY := "."

var errors: Array[String] = []
var warnings: Array[String] = []


func load_area(path: String) -> Dictionary:
	errors.clear()
	warnings.clear()
	if not FileAccess.file_exists(path):
		errors.append("فایل ناحیه پیدا نشد: %s" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		errors.append("فایل ناحیه خراب است: %s" % path)
		return {}
	var area: Dictionary = parsed
	_normalize(area)
	_validate(area)
	return area if errors.is_empty() else {}


func _normalize(area: Dictionary) -> void:
	area["id"] = String(area.get("id", "unknown"))
	area["camera_mode"] = String(area.get("camera_mode", "topdown"))
	area["camera_follow"] = String(area.get("camera_follow", "follow"))
	area["tileset"] = String(area.get("tileset", ""))
	area["tileset_side"] = String(area.get("tileset_side", ""))

	var size: Array = area.get("size", [])
	if size.size() != 2:
		errors.append("ناحیهٔ «%s»: size باید [پهنا, بلندی] بر حسب کاشی باشد." % area["id"])
		area["size"] = [0, 0]
	area["width"] = int((area.get("size", [0, 0]) as Array)[0])
	area["height"] = int((area.get("size", [0, 0]) as Array)[1])

	for key in ["props", "pickups", "traps", "camera_zones", "triggers", "safe_points"]:
		if not area.has(key):
			area[key] = []

	var spawn: Array = area.get("spawn", [1, 1])
	area["spawn"] = [int(spawn[0]), int(spawn[1])] if spawn.size() == 2 else [1, 1]


func _validate(area: Dictionary) -> void:
	var w: int = area.get("width", 0)
	var h: int = area.get("height", 0)
	if w <= 0 or h <= 0:
		errors.append("ناحیهٔ «%s»: اندازهٔ نامعتبر %dx%d." % [area["id"], w, h])
		return

	# ناحیه باید دست‌کم به اندازهٔ یک صفحه باشد، وگرنه دوربین جایی برای
	# حرکت ندارد و «۲ تا ۴ صفحه»ی سند ۰۹ §۵ برآورده نمی‌شود.
	var screen_w := int(ceil(1280.0 / float(TILE)))
	var screen_h := int(ceil(720.0 / float(TILE)))
	if w < screen_w or h < screen_h:
		warnings.append("ناحیهٔ «%s»: %dx%d کاشی از یک صفحه (%dx%d) کوچک‌تر است."
			% [area["id"], w, h, screen_w, screen_h])

	var layers: Dictionary = area.get("layers", {})
	for name in ["floor", "walls"]:
		if not layers.has(name):
			errors.append("ناحیهٔ «%s»: لایهٔ «%s» ندارد." % [area["id"], name])
			continue
		var rows: Array = layers[name]
		if rows.size() != h:
			errors.append("ناحیهٔ «%s» لایهٔ «%s»: %d سطر دارد، باید %d باشد."
				% [area["id"], name, rows.size(), h])
			continue
		for r in rows.size():
			if String(rows[r]).length() != w:
				errors.append("ناحیهٔ «%s» لایهٔ «%s» سطر %d: %d نویسه، باید %d."
					% [area["id"], name, r, String(rows[r]).length(), w])
				break

	var sp: Array = area["spawn"]
	if not _inside(sp[0], sp[1], w, h):
		errors.append("ناحیهٔ «%s»: نقطهٔ شروع (%d,%d) بیرون نقشه است."
			% [area["id"], sp[0], sp[1]])
	elif _is_wall(area, sp[0], sp[1]):
		errors.append("ناحیهٔ «%s»: نقطهٔ شروع (%d,%d) داخل دیوار است."
			% [area["id"], sp[0], sp[1]])

	_validate_placed(area, "props", w, h)
	_validate_placed(area, "pickups", w, h)
	_validate_rects(area, "traps", w, h)
	_validate_rects(area, "camera_zones", w, h)
	_validate_rects(area, "triggers", w, h)

	# هر تله باید کاشی امنِ بازگشت داشته باشد، وگرنه بازیکن بعد از آسیب
	# توی خود تله ظاهر می‌شود و حلقهٔ بی‌پایان می‌سازد.
	for raw in area["traps"]:
		var t: Dictionary = raw
		var back: Array = t.get("safe", [])
		if back.size() != 2:
			errors.append("ناحیهٔ «%s»: تلهٔ «%s» کاشی امن ندارد (کلید safe)."
				% [area["id"], t.get("id", "?")])
			continue
		if _is_wall(area, int(back[0]), int(back[1])):
			errors.append("ناحیهٔ «%s»: کاشی امن تلهٔ «%s» داخل دیوار است."
				% [area["id"], t.get("id", "?")])
		elif _in_any_trap(area, int(back[0]), int(back[1])):
			errors.append("ناحیهٔ «%s»: کاشی امن تلهٔ «%s» داخل یک تله است."
				% [area["id"], t.get("id", "?")])


func _validate_placed(area: Dictionary, key: String, w: int, h: int) -> void:
	var seen: Dictionary = {}
	for raw in area.get(key, []):
		var o: Dictionary = raw
		var oid := String(o.get("id", ""))
		if oid == "":
			errors.append("ناحیهٔ «%s»: یک مورد در «%s» شناسه ندارد." % [area["id"], key])
			continue
		var at: Array = o.get("at", [])
		if at.size() != 2 or not _inside(int(at[0]), int(at[1]), w, h):
			errors.append("ناحیهٔ «%s»: «%s» در «%s» جای نامعتبر دارد."
				% [area["id"], oid, key])
			continue
		var cell := "%d,%d" % [int(at[0]), int(at[1])]
		if seen.has(cell):
			warnings.append("ناحیهٔ «%s»: دو مورد «%s» روی خانهٔ %s."
				% [area["id"], key, cell])
		seen[cell] = true


func _validate_rects(area: Dictionary, key: String, w: int, h: int) -> void:
	var seen: Dictionary = {}
	for raw in area.get(key, []):
		var o: Dictionary = raw
		var oid := String(o.get("id", ""))
		if oid == "":
			errors.append("ناحیهٔ «%s»: یک مورد در «%s» شناسه ندارد." % [area["id"], key])
			continue
		if seen.has(oid):
			errors.append("ناحیهٔ «%s»: شناسهٔ تکراری «%s» در «%s»."
				% [area["id"], oid, key])
			continue
		seen[oid] = true
		var rect: Array = o.get("rect", [])
		if rect.size() != 4 or float(rect[2]) <= 0.0 or float(rect[3]) <= 0.0:
			errors.append("ناحیهٔ «%s»: «%s» در «%s» rect معتبر ندارد."
				% [area["id"], oid, key])
			continue
		if not _inside(int(rect[0]), int(rect[1]), w, h) \
				or not _inside(int(rect[0]) + int(rect[2]) - 1, int(rect[1]) + int(rect[3]) - 1, w, h):
			errors.append("ناحیهٔ «%s»: «%s» در «%s» از نقشه بیرون می‌زند."
				% [area["id"], oid, key])


func _inside(c: int, r: int, w: int, h: int) -> bool:
	return c >= 0 and r >= 0 and c < w and r < h


func _is_wall(area: Dictionary, c: int, r: int) -> bool:
	var layers: Dictionary = area.get("layers", {})
	var walls: Array = layers.get("walls", [])
	if r < 0 or r >= walls.size():
		return true
	var row := String(walls[r])
	if c < 0 or c >= row.length():
		return true
	return row[c] != EMPTY


func _in_any_trap(area: Dictionary, c: int, r: int) -> bool:
	for raw in area.get("traps", []):
		var rect: Array = (raw as Dictionary).get("rect", [])
		if rect.size() != 4:
			continue
		if c >= int(rect[0]) and c < int(rect[0]) + int(rect[2]) \
				and r >= int(rect[1]) and r < int(rect[1]) + int(rect[3]):
			return true
	return false


## نقش کاشی‌ها را از `roles.json` کنار اطلس می‌خواند.
static func tile_roles(tileset_path: String) -> Dictionary:
	var p := "res://assets/%s/roles.json" % tileset_path
	if not FileAccess.file_exists(p):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
	return parsed if parsed is Dictionary else {}


## آیا این نقش برخورد دارد؟ (`art/TILE_ROLES.md`)
static func blocks(kind: String) -> bool:
	return kind in ["solid", "wall"]
