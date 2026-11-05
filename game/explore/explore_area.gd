## سازندهٔ ناحیهٔ اکتشافی (T15)
##
## ناحیه را از `levels/data/areas/<id>.json` می‌سازد: دو لایهٔ کاشی، پراپ‌ها،
## جمع‌شدنی‌ها، تله‌ها، نقطهٔ ذخیره، ناحیه‌های دوربین و ماشه‌های توالی.
##
## نقش و برخورد هر کاشی از `roles.json` می‌آید، نه از شمارهٔ دست‌نویس
## (`art/TILE_ROLES.md`: «کاشی را از کد نساز»). اگر هنری نبود، ناحیه ساخته
## می‌شود ولی هشدار می‌دهد — بازی به‌خاطر هنر ناقص نمی‌شکند.
class_name ExploreArea
extends Node2D

signal built(area_id: String)
signal pickup_taken(kind: String, total: int)

const TILE: int = 32
const PROPS_DIR := "res://assets/explore/props/"
const PICKUPS_DIR := "res://assets/explore/pickups/"

## نماد لایهٔ کف → نقش در `roles.json`.
const FLOOR_ROLE := {
	"a": "floor_plank_a", "b": "floor_plank_b", "c": "floor_plank_c",
	"g": "rug_center", "h": "rug_edge_top", "i": "floor_plank_accent_a",
}
## نماد لایهٔ دیوار → نقش.
const WALL_ROLE := {
	"W": "wall_wainscot_front", "S": "cabinet_corner_a", "C": "cabinet_corner_b",
	"N": "wall_post_edge", "P": "wall_post_door", "F": "wall_corner_inner_a",
	"T": "wall_corner_inner_b",
}

var area: Dictionary = {}
var missing_art: Array[String] = []

var director: CameraDirector = null
var traps: Array[ExploreTrap] = []
var save_points: Array[SavePoint] = []
var challenge: ChallengeRoom = null

var _floor_layer: Node2D
var _wall_layer: Node2D
var _object_layer: Node2D
var _roles: Dictionary = {}
var _role_to_index: Dictionary = {}
var _tiles_path: String = ""


func build(data: Dictionary) -> void:
	area = data
	_roles = AreaLoader.tile_roles(String(data.get("tileset", "")))
	_tiles_path = "res://assets/%s/" % String(data.get("tileset", ""))
	_index_roles()

	_floor_layer = _add_layer("Floor", 0)
	_wall_layer = _add_layer("Walls", 1)
	_object_layer = _add_layer("Objects", 2)
	# Y-sort بر پایهٔ y پا؛ بدون آن شخصیت پشت دیوارِ جلویش کشیده می‌شود
	y_sort_enabled = true
	_object_layer.y_sort_enabled = true
	_wall_layer.y_sort_enabled = true

	_build_backdrop()
	_build_tiles()
	_build_props()
	_build_pickups()
	_build_traps()
	_build_challenge()
	built.emit(String(data.get("id", "?")))


## پس‌زمینهٔ لایه‌ای ناحیه (`parallax/ch1/<صحنه>_{far,mid,fore}`).
##
## بدون آن، بیرون کاشی‌ها خالیِ خاکستری دیده می‌شود — چیزی که فقط در
## اسکرین‌شات معلوم می‌شود، نه در سنجه‌های عددی.
func _build_backdrop() -> void:
	var base := String(area.get("parallax_side", ""))
	if base == "":
		return
	var layer := CanvasLayer.new()
	layer.name = "Backdrop"
	layer.layer = -1
	add_child(layer)
	for part in ["far", "mid"]:
		var p := "res://assets/%s_%s_1280x720.png" % [base, part]
		if not ResourceLoader.exists(p):
			_note_missing(p)
			continue
		var tex := TextureRect.new()
		tex.texture = load(p)
		tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(tex)


func _add_layer(name: String, z: int) -> Node2D:
	var n := Node2D.new()
	n.name = name
	n.z_index = z
	add_child(n)
	return n


func _index_roles() -> void:
	_role_to_index.clear()
	var tiles: Dictionary = _roles.get("tiles", {})
	for file in tiles:
		var entry: Dictionary = tiles[file]
		_role_to_index[String(entry.get("role", ""))] = {
			"file": file, "kind": String(entry.get("kind", "background")),
		}


func _tile_texture(role: String) -> Texture2D:
	if not _role_to_index.has(role):
		_note_missing("نقش کاشی «%s»" % role)
		return null
	var file := String((_role_to_index[role] as Dictionary)["file"])
	# نسخهٔ ۳۲ پیکسلی، مطابق مقیاس جهان (CLAUDE.md قانون ۳)
	var p := _tiles_path + file.replace(".png", "_32.png")
	if not ResourceLoader.exists(p):
		p = _tiles_path + file
	if not ResourceLoader.exists(p):
		_note_missing(p)
		return null
	return load(p)


func _role_kind(role: String) -> String:
	if not _role_to_index.has(role):
		return "background"
	return String((_role_to_index[role] as Dictionary)["kind"])


func _note_missing(what: String) -> void:
	if what not in missing_art:
		missing_art.append(what)


func _build_tiles() -> void:
	var layers: Dictionary = area.get("layers", {})
	_paint(_floor_layer, layers.get("floor", []), FLOOR_ROLE, false)
	_paint(_wall_layer, layers.get("walls", []), WALL_ROLE, true)


func _paint(parent: Node2D, rows: Array, mapping: Dictionary, collide: bool) -> void:
	var cache: Dictionary = {}
	for r in rows.size():
		var line := String(rows[r])
		for c in line.length():
			var ch := line[c]
			if ch == AreaLoader.EMPTY:
				continue
			var role := String(mapping.get(ch, ""))
			if role == "":
				_note_missing("نماد «%s»" % ch)
				continue
			if not cache.has(role):
				cache[role] = _tile_texture(role)
			var tex: Texture2D = cache[role]
			if tex == null:
				continue
			var s := Sprite2D.new()
			s.texture = tex
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.centered = false
			# کاشی دیوار بلندتر از خانه است (نمای جلویش)؛ پایش باید روی
			# خانه بنشیند، نه سرش، وگرنه یک کاشی بالاتر دیده می‌شود.
			s.position = Vector2(c * TILE, r * TILE - (tex.get_height() - TILE))
			parent.add_child(s)
			if collide and AreaLoader.blocks(_role_kind(role)):
				_add_blocker(c, r)


func _add_blocker(c: int, r: int) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Layers.GROUND
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(TILE, TILE)
	shape.shape = box
	shape.position = Vector2(TILE * 0.5, TILE * 0.5)
	body.add_child(shape)
	body.position = Vector2(c * TILE, r * TILE)
	_wall_layer.add_child(body)


func _sprite_at(dir: String, file: String, c: int, r: int) -> Sprite2D:
	var p := dir + file
	if not ResourceLoader.exists(p):
		_note_missing(p)
		return null
	var s := Sprite2D.new()
	s.texture = load(p)
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = false
	var tex: Texture2D = s.texture
	# پراپ بلند از پایش می‌نشیند تا Y-sort درست کار کند
	s.position = Vector2(c * TILE, r * TILE - (tex.get_height() - TILE))
	_object_layer.add_child(s)
	return s


func _build_props() -> void:
	for raw in area.get("props", []):
		var p: Dictionary = raw
		var pid := String(p.get("id", ""))
		var at: Array = p.get("at", [0, 0])
		var spr := _sprite_at(PROPS_DIR, "%s.png" % pid, int(at[0]), int(at[1]))
		if pid == "save_statue":
			var sp := SavePoint.new()
			sp.point_id = "%s_%s" % [area.get("id", "a"), pid]
			var shape := CollisionShape2D.new()
			var box := RectangleShape2D.new()
			box.size = Vector2(TILE * 2, TILE * 2)
			shape.shape = box
			sp.add_child(shape)
			sp.position = Vector2(int(at[0]) * TILE + TILE * 0.5,
				int(at[1]) * TILE + TILE * 0.5)
			_object_layer.add_child(sp)
			save_points.append(sp)


func _build_pickups() -> void:
	for raw in area.get("pickups", []):
		var p: Dictionary = raw
		var pid := String(p.get("id", ""))
		var at: Array = p.get("at", [0, 0])
		# سکه و گوهر چند فریم دارند؛ فریم اول را می‌گذاریم
		var file := "%s_0.png" % pid
		if not ResourceLoader.exists(PICKUPS_DIR + file):
			file = "%s.png" % pid
		_sprite_at(PICKUPS_DIR, file, int(at[0]), int(at[1]))


func _build_traps() -> void:
	for raw in area.get("traps", []):
		var t: Dictionary = raw
		var rect: Array = t.get("rect", [0, 0, 1, 1])
		var safe: Array = t.get("safe", [0, 0])
		var trap := ExploreTrap.new()
		trap.name = "Trap_%s" % String(t.get("id", "t"))
		trap.damage_pct = float(t.get("damage_pct", 10.0))
		trap.sequence_id = String(t.get("sequence", ""))
		trap.safe_point = Vector2(
			int(safe[0]) * TILE + TILE * 0.5, int(safe[1]) * TILE + TILE * 0.5)
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = Vector2(int(rect[2]) * TILE, int(rect[3]) * TILE)
		shape.shape = box
		shape.position = box.size * 0.5
		trap.add_child(shape)
		trap.position = Vector2(int(rect[0]) * TILE, int(rect[1]) * TILE)
		_object_layer.add_child(trap)
		traps.append(trap)


func _build_challenge() -> void:
	for raw in area.get("camera_zones", []):
		var z: Dictionary = raw
		if String(z.get("mode", "")) != CameraDirector.MODE_SIDE:
			continue
		var rect: Array = z.get("rect", [0, 0, 1, 1])
		challenge = ChallengeRoom.new()
		challenge.name = "Challenge_%s" % String(z.get("id", "c"))
		challenge.room_id = String(z.get("id", "challenge"))
		challenge.entry_point = Vector2(
			int(rect[0]) * TILE + TILE * 0.5,
			(int(rect[1]) + int(rect[3]) - 2) * TILE)
		add_child(challenge)
		if director != null:
			challenge.bind(director)
		break


## مرز نقشه بر حسب پیکسل، برای حد دوربین.
func bounds() -> Rect2:
	return Rect2(0, 0, int(area.get("width", 0)) * TILE,
		int(area.get("height", 0)) * TILE)


func spawn_position() -> Vector2:
	var sp: Array = area.get("spawn", [1, 1])
	return Vector2(int(sp[0]) * TILE + TILE * 0.5, int(sp[1]) * TILE + TILE * 0.5)
