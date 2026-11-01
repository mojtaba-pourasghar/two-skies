## یک اتاق ۳۰×۱۷ — docs/02_godot_spec.md §۹ و §۱۰
##
## کاشی‌های جامد در یک TileMapLayer و هر شیء یک صحنهٔ مستقل.
class_name Room
extends Node2D

signal exit_reached
signal checkpoint_reached(pos: Vector2)
signal door_crossed(side: String, to_room: String, row: int)

const TILE := LevelLoader.TILE
const ROOM_W := LevelLoader.ROOM_W
const ROOM_H := LevelLoader.ROOM_H

var data: Dictionary = {}
var level_id: String = ""
var kairo_start := Vector2.ZERO
var ilara_start := Vector2.ZERO
var pickups: Array[Pickup] = []
var gates: Array[Gate] = []
var hazards: Array[Node] = []
var exit_point: ExitPoint = null

var _tiles: TileMapLayer
var _objects_root: Node2D


func build(level: Dictionary, room: Dictionary, tileset: TileSet) -> void:
	data = room
	level_id = String(level.get("id", "?"))

	_tiles = TileMapLayer.new()
	_tiles.name = "Tiles"
	_tiles.tile_set = tileset
	add_child(_tiles)

	_objects_root = Node2D.new()
	_objects_root.name = "Objects"
	add_child(_objects_root)

	var rows: Array = room.get("tiles", [])
	var objects: Dictionary = room.get("objects", {})
	var doors: Array = room.get("exits", [])
	var open_cells := _door_cells(doors)

	for r in rows.size():
		var line := String(rows[r])
		for c in line.length():
			var sym := line[c]
			# درگاه: دیوار در این خانه باز می‌شود تا گذار اتاق ممکن باشد
			if open_cells.has(Vector2i(c, r)):
				continue
			# سوراخ اعلام‌نشده در دیوار کناری یا سقف مُهر می‌شود. نقشه‌های §۱۱ در
			# بعضی اتاق‌ها هر دو لبه را باز کشیده‌اند ولی فقط یک سمتش درگاه واقعی
			# است؛ بدون این کار بازیکن از لبهٔ بی‌مقصد بیرون می‌افتد.
			# کف (سطر ۱۴ تا ۱۶) مُهر نمی‌شود: چاه طراحی‌شده و مرگ از پایین (§۷).
			if _is_sealable_border(c, r) and sym != LevelLoader.SOLID:
				_tiles.set_cell(Vector2i(c, r), 0, Vector2i.ZERO)
				continue
			if sym == LevelLoader.SOLID:
				_tiles.set_cell(Vector2i(c, r), 0, Vector2i.ZERO)
				continue
			if sym == LevelLoader.EMPTY:
				continue
			_spawn(sym, c, r, objects)

	_spawn_door_triggers(doors)


## لبه‌هایی که اگر درگاه نباشند باید جامد شوند: ستون ۰ و ۲۹ در سطرهای ۰ تا ۱۳،
## و سقف (سطر ۰ و ۱). کف و سطرهای ۱۴ به بعد کاری‌شان نداریم.
func _is_sealable_border(c: int, r: int) -> bool:
	if r >= 14:
		return false
	if r <= 1:
		return true
	return c == 0 or c == ROOM_W - 1


## خانه‌هایی که به‌خاطر درگاه باید خالی بمانند.
func _door_cells(doors: Array) -> Dictionary:
	var cells := {}
	for door in doors:
		var side := String(door.get("side", ""))
		for v in (door.get("rows", []) as Array):
			var i := int(v)
			match side:
				"left":
					cells[Vector2i(0, i)] = true
				"right":
					cells[Vector2i(ROOM_W - 1, i)] = true
				"up":
					cells[Vector2i(i, 0)] = true
					cells[Vector2i(i, 1)] = true
				"down":
					cells[Vector2i(i, ROOM_H - 1)] = true
	return cells


## ماشهٔ عبور از درگاه: کمی بیرون از لبه، تا عبور قطعی باشد.
func _spawn_door_triggers(doors: Array) -> void:
	for door in doors:
		var side := String(door.get("side", ""))
		var to := String(door.get("to", ""))
		if to == "":
			continue
		var rows: Array = door.get("rows", [])
		if rows.is_empty():
			continue
		var area := Area2D.new()
		area.collision_layer = Layers.TRIGGER
		area.collision_mask = Layers.KAIRO
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		var first := int(rows[0])
		var last := int(rows[rows.size() - 1])
		match side:
			"left":
				rect.size = Vector2(6, (last - first + 1) * TILE)
				shape.position = Vector2(1, (first + (last - first + 1) * 0.5) * TILE)
			"right":
				rect.size = Vector2(6, (last - first + 1) * TILE)
				shape.position = Vector2(ROOM_W * TILE - 1, (first + (last - first + 1) * 0.5) * TILE)
			"up":
				rect.size = Vector2((last - first + 1) * TILE, 6)
				shape.position = Vector2((first + (last - first + 1) * 0.5) * TILE, 1)
			"down":
				rect.size = Vector2((last - first + 1) * TILE, 6)
				shape.position = Vector2((first + (last - first + 1) * 0.5) * TILE, ROOM_H * TILE - 1)
		shape.shape = rect
		area.add_child(shape)
		add_child(area)
		area.body_entered.connect(func(body):
			if body is Kairo:
				door_crossed.emit(side, to, first))


func _spawn(sym: String, c: int, r: int, objects: Dictionary) -> void:
	var pos := Vector2((c + 0.5) * TILE, (r + 0.5) * TILE)
	var def: Dictionary = objects.get(sym, {})
	var kind := String(def.get("type", LevelLoader.BASE_SYMBOLS.get(sym, "")))

	match kind:
		"kairo_start":
			kairo_start = _feet_pos(c, r)
		"ilara_start":
			ilara_start = _feet_pos(c, r)
		"coin":
			_add_pickup("coin", "%s_%s_c%d_%d" % [level_id, data.get("id", "r"), c, r], pos)
		"gem":
			_add_pickup("gem", String(def.get("id", "%s_g_%d_%d" % [level_id, c, r])), pos)
		"page":
			_add_pickup("page", String(def.get("id", "%s_p_%d_%d" % [level_id, c, r])), pos)
		"note":
			var n := Note.new()
			n.text_key = String(def.get("text_key", ""))
			n.position = pos
			_objects_root.add_child(n)
		"spike":
			var s := Spike.new()
			s.position = pos
			_objects_root.add_child(s)
		"exit", "checkpoint":
			var e := ExitPoint.new()
			e.is_checkpoint = (kind == "checkpoint")
			e.needs_both = bool(def.get("needs_both", true))
			e.position = pos
			_objects_root.add_child(e)
			exit_point = e
			if kind == "checkpoint":
				e.reached.connect(func(): checkpoint_reached.emit(pos))
			else:
				e.reached.connect(func(): exit_reached.emit())
		"gate", "lock":
			var g := Gate.new()
			g.gate_kind = kind
			g.position = pos
			if def.has("open_duration"):
				g.auto_close_after = float(def["open_duration"])
			_objects_root.add_child(g)
			gates.append(g)
		"crumble":
			var cr := Crumble.new()
			cr.position = pos
			_objects_root.add_child(cr)
			hazards.append(cr)
		"laser":
			var la := Laser.new()
			la.dir = String(def.get("dir", "down"))
			la.phase_offset = float(def.get("phase", 0.0))
			la.length_tiles = _beam_length(c, r, String(def.get("dir", "down")))
			la.position = pos
			_objects_root.add_child(la)
			hazards.append(la)
		"drone":
			var dr := Drone.new()
			dr.axis = String(def.get("axis", "h"))
			dr.patrol_tiles = int(def.get("range", 6))
			dr.position = pos
			_objects_root.add_child(dr)
			hazards.append(dr)
		_:
			push_warning("Room %s: نوع شیء «%s» (نماد %s) پیاده‌سازی نشده." % [data.get("id", "?"), kind, sym])


## پرتو تا برخورد با دیوار امتداد می‌یابد (§۷)
func _beam_length(c: int, r: int, d: String) -> int:
	var rows: Array = data.get("tiles", [])
	var step := Vector2i(0, 1)
	match d:
		"up": step = Vector2i(0, -1)
		"left": step = Vector2i(-1, 0)
		"right": step = Vector2i(1, 0)
	var n := 0
	var cc := c + step.x
	var rr := r + step.y
	while cc >= 0 and cc < ROOM_W and rr >= 0 and rr < rows.size():
		if String(rows[rr])[cc] == LevelLoader.SOLID:
			break
		n += 1
		cc += step.x
		rr += step.y
	return maxi(n, 1)


func _placeholder(kind: String, pos: Vector2) -> void:
	var poly := Polygon2D.new()
	poly.position = pos
	poly.color = Color(1, 0, 1, 0.35)
	poly.polygon = PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)])
	poly.name = "TODO_%s" % kind
	_objects_root.add_child(poly)


func _add_pickup(kind: String, id: String, pos: Vector2) -> void:
	var p := Pickup.new()
	p.kind = kind
	p.id = id
	p.position = pos
	_objects_root.add_child(p)
	pickups.append(p)


## پای شخصیت روی کف کاشی می‌نشیند
func _feet_pos(c: int, r: int) -> Vector2:
	return Vector2((c + 0.5) * TILE, (r + 1) * TILE - KairoConst.HITBOX.y * 0.5)


## با مرگ در همان اتاق، سکه‌ها و درها به حالت اول برمی‌گردند (§۸)
func reset_room() -> void:
	for p in pickups:
		p.respawn()
	for g in gates:
		g.reset()
	for h in hazards:
		if h.has_method("reset"):
			h.call("reset")
	if exit_point != null:
		exit_point.reset()


## اقلامی که در این اتاق جمع شده‌اند
func collected() -> Dictionary:
	var out := {"coins": 0, "gems": [], "pages": []}
	for p in pickups:
		if not p.is_taken():
			continue
		match p.kind:
			"coin":
				out["coins"] = int(out["coins"]) + 1
			"gem":
				out["gems"].append(p.id)
			"page":
				out["pages"].append(p.id)
	return out


func size_px() -> Vector2:
	return Vector2(ROOM_W * TILE, ROOM_H * TILE)
