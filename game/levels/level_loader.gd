## لودر مرحله — docs/02_godot_spec.md §۱۰ و §۱۱
##
## یک فایل JSON را به اتاق‌های قابل بازی تبدیل می‌کند: TileMapLayer برای کاشی‌های
## جامد و یک صحنهٔ مستقل برای هر شیء.
##
## دو قالب اتاق پشتیبانی می‌شود:
##   * کامل: ۱۷ سطر × ۳۰ ستون (قالب §۱۰ و فصل‌های ۲ تا ۸)
##   * فشرده: ۱۲ سطر (فقط سطر ۲ تا ۱۳) — قالب نقشه‌های فصل ۱ در §۱۱.
##     سطرهای ۰ و ۱ سقف و ۱۴ تا ۱۶ کف جامد می‌شوند، مگر جایی که فیلد `floor_gaps`
##     یا `floor_crumble` اتاق خلافش را بگوید.
##
## اتصال اتاق‌ها (DECISIONS.md: D-005): فیلد `exits` سطرهای دقیق هر درگاه را می‌دهد،
## پس هم درگاه پایین (۱۲ و ۱۳ قالب §۱۰) و هم درگاه بالا (۲ و ۳ مثل L2R1) کار می‌کند.
class_name LevelLoader
extends RefCounted

const TILE: int = 16
const ROOM_W: int = 30
const ROOM_H: int = 17

## سطرهای درگاه پیش‌فرض §۱۰
const LOW_ROWS := [12, 13]
const HIGH_ROWS := [2, 3]

## قالب فشردهٔ §۱۱ از سطر ۲ شروع می‌شود
const COMPACT_OFFSET: int = 2
const COMPACT_ROWS: int = 12

const SOLID := "#"
const EMPTY := "."

## نمادهایی که معنای پایه دارند و لازم نیست در objects تعریف شوند (§۱۰ و §۲۶)
const BASE_SYMBOLS := {
	"#": "solid",
	".": "empty",
	"o": "coin",
	"^": "spike",
	"~": "crumble",
	"P": "ilara_start",
	"I": "kairo_start",
	"X": "exit",
}

## خطاهای اعتبارسنجی آخرین بارگذاری
var errors: Array[String] = []
var warnings: Array[String] = []


## یک مرحله را از JSON می‌خواند و دادهٔ اعتبارسنجی‌شده برمی‌گرداند.
## در صورت خطا، یک دیکشنری خالی و پر بودن `errors`.
func load_level(path: String) -> Dictionary:
	errors.clear()
	warnings.clear()
	if not FileAccess.file_exists(path):
		errors.append("فایل مرحله پیدا نشد: %s" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("JSON مرحله خراب است: %s" % path)
		return {}
	var level: Dictionary = parsed
	_normalize(level)
	_validate(level)
	return level if errors.is_empty() else {}


## قالب فشرده را به ۱۷ سطر کامل باز می‌کند و فیلدهای نبود را پر می‌کند.
func _normalize(level: Dictionary) -> void:
	level["id"] = String(level.get("id", "unknown"))
	level["view"] = String(level.get("view", "side"))
	level["companion"] = bool(level.get("companion", true))
	level["par_time"] = float(level.get("par_time", 0.0))
	var rooms: Array = level.get("rooms", [])
	if rooms.is_empty():
		errors.append("مرحلهٔ «%s» هیچ اتاقی ندارد." % level["id"])
		return
	level["start_room"] = String(level.get("start_room", String(rooms[0].get("id", "r1"))))
	for room in rooms:
		_normalize_room(level, room)


func _normalize_room(level: Dictionary, room: Dictionary) -> void:
	var rid := String(room.get("id", "?"))
	var tiles: Array = room.get("tiles", [])
	if tiles.size() == COMPACT_ROWS:
		room["tiles"] = _expand_compact(level, room, tiles)
		room["compact_source"] = true
	elif tiles.size() != ROOM_H:
		errors.append("اتاق %s/%s: %d سطر دارد؛ باید %d (کامل) یا %d (فشردهٔ §۱۱) باشد."
			% [level.get("id", "?"), rid, tiles.size(), ROOM_H, COMPACT_ROWS])
	if not room.has("objects"):
		room["objects"] = {}
	# خروج‌ها به یک آرایه از {side, to, rows} یکدست می‌شوند. سه قالب پذیرفته است:
	#   §۱۰ کوتاه:  "exits": {"right": "r2"}
	#   دیکشنری:    "exits": {"right": {"to": "r2", "rows": [2, 3]}}
	#   آرایه:      "exits": [{"side": "right", "to": "r2", "rows": [2, 3]}, ...]
	# قالب آرایه لازم است چون یک اتاق می‌تواند در یک سمت دو درگاه داشته باشد
	# (مثل L2R1 که خروجش بالا راست است) — DECISIONS.md: D-005.
	var doors: Array = []
	var raw_exits = room.get("exits", {})
	if raw_exits is Array:
		for d in raw_exits:
			if d is Dictionary:
				doors.append({
					"side": String(d.get("side", "right")),
					"to": String(d.get("to", "")),
					"rows": (d.get("rows", _default_rows(String(d.get("side", "right"))))) as Array,
				})
	elif raw_exits is Dictionary:
		for side in raw_exits.keys():
			var raw = raw_exits[side]
			if raw is String:
				doors.append({"side": String(side), "to": raw, "rows": _default_rows(String(side))})
			elif raw is Dictionary:
				doors.append({
					"side": String(side),
					"to": String(raw.get("to", "")),
					"rows": (raw.get("rows", _default_rows(String(side)))) as Array,
				})
	room["exits"] = doors


func _default_rows(side: String) -> Array:
	# درگاه چپ/راست پیش‌فرض سطر ۱۲ و ۱۳ (§۱۰)؛ بالا/پایین ستون‌محورند و
	# اگر ستون داده نشود میانهٔ اتاق فرض می‌شود.
	match side:
		"left", "right":
			return LOW_ROWS.duplicate()
		"up", "down":
			return [14, 15]
		_:
			return LOW_ROWS.duplicate()


## نقشهٔ ۱۲ سطری §۱۱ → ۱۷ سطر کامل.
func _expand_compact(level: Dictionary, room: Dictionary, tiles: Array) -> Array:
	var out: Array = []
	var ceiling := SOLID.repeat(ROOM_W)
	out.append(ceiling)
	out.append(ceiling)
	for row in tiles:
		out.append(String(row))

	# سه سطر کف: جامد، مگر ستون‌هایی که اتاق «گودال» یا «کف شکننده» اعلام کرده.
	# یادداشت‌های §۱۱ این‌ها را به متن گفته‌اند، نه در خود نقشه، پس در JSON صریح می‌آیند.
	var gaps: Array = room.get("floor_gaps", [])
	var crumble: Array = room.get("floor_crumble", [])
	for r in range(14, ROOM_H):
		var line := ""
		for c in ROOM_W:
			if _in_ranges(c, gaps):
				line += EMPTY
			elif r == 14 and _in_ranges(c, crumble):
				line += "~"
			elif _in_ranges(c, crumble) and r > 14:
				line += EMPTY
			else:
				line += SOLID
		out.append(line)
	return out


## بازه‌ها به شکل [[c0, c1], ...] با هر دو سر شامل
func _in_ranges(c: int, ranges: Array) -> bool:
	for rng in ranges:
		if rng is Array and rng.size() >= 2:
			if c >= int(rng[0]) and c <= int(rng[1]):
				return true
	return false


## اعتبارسنجی §۱۰: هر سطر دقیقاً ۳۰ کاراکتر، هر نماد تعریف‌شده، اتصال‌ها درست.
func _validate(level: Dictionary) -> void:
	var rooms: Array = level.get("rooms", [])
	var ids := {}
	for room in rooms:
		ids[String(room.get("id", "?"))] = true

	var seen_kairo := false
	var seen_exit := false

	for room in rooms:
		var rid := String(room.get("id", "?"))
		var tiles: Array = room.get("tiles", [])
		for r in tiles.size():
			var line := String(tiles[r])
			if line.length() != ROOM_W:
				errors.append("اتاق %s سطر %d: %d کاراکتر دارد، باید %d باشد."
					% [rid, r, line.length(), ROOM_W])
		# نمادها
		var objects: Dictionary = room.get("objects", {})
		for r in tiles.size():
			var line := String(tiles[r])
			for c in line.length():
				var sym := line[c]
				if BASE_SYMBOLS.has(sym):
					if sym == "I":
						seen_kairo = true
					elif sym == "X":
						seen_exit = true
					continue
				if not objects.has(sym):
					errors.append("اتاق %s (%d,%d): نماد «%s» نه پایه است و نه در objects تعریف شده."
						% [rid, c, r, sym])
		# نمادهای تعریف‌شده‌ای که در نقشه نیستند فقط هشدارند
		for sym in objects.keys():
			var found := false
			for line in tiles:
				if String(line).contains(String(sym)):
					found = true
					break
			if not found:
				warnings.append("اتاق %s: نماد «%s» در objects تعریف شده ولی در نقشه نیست." % [rid, sym])
		# اتصال‌ها
		for door in room.get("exits", []):
			var to := String(door.get("to", ""))
			var side := String(door.get("side", "?"))
			if not ids.has(to):
				errors.append("اتاق %s: خروج «%s» به اتاق ناموجود «%s» اشاره می‌کند." % [rid, side, to])
			if (door.get("rows", []) as Array).is_empty():
				errors.append("اتاق %s: خروج «%s» هیچ سطری ندارد." % [rid, side])

	if not seen_kairo:
		errors.append("مرحلهٔ %s: نماد شروع کایرو (I) در هیچ اتاقی نیست." % level.get("id", "?"))
	if not seen_exit:
		errors.append("مرحلهٔ %s: نقطهٔ خروج (X) در هیچ اتاقی نیست." % level.get("id", "?"))


## ----- ساخت صحنه -----

## یک TileSet با یک کاشی جامد ۱۶×۱۶ می‌سازد.
## مکان‌نگهدار است: وقتی کاشی واقعی رسید، فقط این تابع به بارگذاری یک .tres عوض می‌شود
## و هیچ جای دیگری از کد تغییر نمی‌کند (گام ۶ سند ۰۵).
static func make_placeholder_tileset(color: Color = Color(0.18, 0.19, 0.24)) -> TileSet:
	var img := Image.create(TILE, TILE, false, Image.FORMAT_RGBA8)
	img.fill(color)
	# یک خط روشن‌تر بالای کاشی تا لبه‌ها در بازی‌تست دیده شوند
	for x in TILE:
		img.set_pixel(x, 0, color.lightened(0.25))
	var tex := ImageTexture.create_from_image(img)

	var source := TileSetAtlasSource.new()
	source.texture = tex
	source.texture_region_size = Vector2i(TILE, TILE)
	source.create_tile(Vector2i.ZERO)

	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, Layers.GROUND)
	ts.set_physics_layer_collision_mask(0, 0)
	ts.add_source(source, 0)

	var data := source.get_tile_data(Vector2i.ZERO, 0)
	data.add_collision_polygon(0)
	data.set_collision_polygon_points(0, 0, PackedVector2Array([
		Vector2(-TILE * 0.5, -TILE * 0.5),
		Vector2(TILE * 0.5, -TILE * 0.5),
		Vector2(TILE * 0.5, TILE * 0.5),
		Vector2(-TILE * 0.5, TILE * 0.5),
	]))
	return ts
