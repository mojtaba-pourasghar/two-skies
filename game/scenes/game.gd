## اجراکنندهٔ مرحله — docs/02_godot_spec.md §۹، §۱۰، §۱۳
##
## یک مرحله را بار می‌کند، اتاق فعال را می‌سازد، دوربین را به اتاق قفل می‌کند،
## گذار بین اتاق‌ها را انجام می‌دهد و مرگ و شروع دوباره را اداره می‌کند.
extends Node2D

signal level_finished(result: Dictionary)

const TILE := LevelLoader.TILE

@export var level_path: String = "res://levels/data/test_room.json"

var level: Dictionary = {}
var room: Room = null
var kairo: Kairo = null
var ilara: Node2D = null

var current_room_id: String = ""
var checkpoint_room: String = ""
var checkpoint_pos := Vector2.ZERO

## آمار اجرای فعلی
var coins_banked: int = 0
var gems_banked: Array[String] = []
var pages_banked: Array[String] = []
var deaths: int = 0
var ilara_falls: int = 0
var elapsed: float = 0.0
var finished: bool = false

var _tileset: TileSet
var _camera: Camera2D
var _rooms_root: Node2D
var _hud: CanvasLayer
var _hud_label: Label
var _loader := LevelLoader.new()
var _entry_side: String = ""
var _entry_row: int = -1


func _ready() -> void:
	if SceneRouter.pending_level != "":
		level_path = SceneRouter.pending_level
	_tileset = LevelLoader.make_placeholder_tileset()
	_rooms_root = Node2D.new()
	_rooms_root.name = "Rooms"
	add_child(_rooms_root)
	_build_camera()
	_build_hud()
	if not _load(level_path):
		return
	_spawn_actors()
	_enter_room(String(level.get("start_room", "r1")), "", -1)
	EventBus.level_started.emit(String(level.get("id", "?")))


func _load(path: String) -> bool:
	level = _loader.load_level(path)
	for w in _loader.warnings:
		push_warning("LevelLoader: %s" % w)
	if level.is_empty():
		for e in _loader.errors:
			push_error("LevelLoader: %s" % e)
		if _hud_label != null:
			_hud_label.text = "خطا در بارگذاری مرحله:\n" + "\n".join(_loader.errors)
		return false
	return true


func _room_data(id: String) -> Dictionary:
	for r in level.get("rooms", []):
		if String(r.get("id", "")) == id:
			return r
	return {}


func _spawn_actors() -> void:
	kairo = load("res://actors/kairo/kairo.tscn").instantiate()
	add_child(kairo)
	kairo.respawn_ready.connect(_on_respawn)
	kairo.died.connect(_on_death)


## ----- گذار اتاق -----

func _enter_room(room_id: String, from_side: String, row: int) -> void:
	var rd := _room_data(room_id)
	if rd.is_empty():
		push_error("Game: اتاق «%s» در مرحله نیست." % room_id)
		return

	# اقلام اتاق قبلی فقط هنگام ترک اتاق قطعی می‌شوند (§۸)
	if room != null:
		_bank_room()
		room.queue_free()
		room = null

	current_room_id = room_id
	_entry_side = from_side
	_entry_row = row

	room = Room.new()
	room.name = "Room_%s" % room_id
	_rooms_root.add_child(room)
	room.build(level, rd, _tileset)
	room.door_crossed.connect(_on_door_crossed)
	room.exit_reached.connect(_on_exit_reached)
	room.checkpoint_reached.connect(_on_checkpoint)

	_place_actors_on_entry()
	_lock_camera()
	EventBus.room_entered.emit(String(level.get("id", "?")), room_id)


func _place_actors_on_entry() -> void:
	var pos: Vector2
	if _entry_side == "":
		pos = room.kairo_start
	else:
		pos = _entry_position(_entry_side, _entry_row)
	kairo.reset_to(pos)
	if ilara != null and ilara.has_method("reset_to"):
		var ipos: Vector2 = room.ilara_start if _entry_side == "" and room.ilara_start != Vector2.ZERO else pos
		ilara.call("reset_to", ipos)


## `exit_side` سمتی است که بازیکن از اتاق قبلی **بیرون** رفته؛ پس در اتاق تازه
## از سمت مقابل ظاهر می‌شود. برای left/right پارامتر دوم سطر است و برای up/down ستون.
func _entry_position(exit_side: String, index: int) -> Vector2:
	var r := index if index >= 0 else LevelLoader.LOW_ROWS[0]
	match exit_side:
		"right":
			return Vector2(1.5 * TILE, (r + 1) * TILE - KairoConst.HITBOX.y * 0.5)
		"left":
			return Vector2((LevelLoader.ROOM_W - 1.5) * TILE, (r + 1) * TILE - KairoConst.HITBOX.y * 0.5)
		"down":
			return Vector2((r + 0.5) * TILE, 2.5 * TILE)
		"up":
			return Vector2((r + 0.5) * TILE, (LevelLoader.ROOM_H - 2.5) * TILE)
	return room.kairo_start


func _on_door_crossed(side: String, to_room: String, row: int) -> void:
	if finished:
		return
	_enter_room(to_room, side, row)


## ----- دوربین -----

func _build_camera() -> void:
	_camera = Camera2D.new()
	_camera.position_smoothing_enabled = false
	_camera.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	_camera.ignore_rotation = true
	add_child(_camera)
	_camera.make_current()


## اتاق ۳۰×۱۷ کاشی = دقیقاً ۴۸۰×۲۷۰، پس دوربین ثابت و بدون نرمی است (§۹)
func _lock_camera() -> void:
	_camera.position = Vector2.ZERO
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = int(room.size_px().x)
	_camera.limit_bottom = int(room.size_px().y)


## لرزش دوربین در مرگ: ۲ پیکسل، قابل خاموش شدن در تنظیمات (§۹)
func _shake_death() -> void:
	if not Settings.camera_shake_enabled:
		return
	var amp: float = Settings.param("camera", "death_shake_px", 2.0)
	var dur: float = Settings.param("camera", "death_shake_time", 0.2)
	var tw := create_tween()
	for i in 4:
		var off := Vector2(randf_range(-amp, amp), randf_range(-amp, amp)).round()
		tw.tween_property(_camera, "offset", off, dur / 4.0)
	tw.tween_property(_camera, "offset", Vector2.ZERO, 0.05)


## ----- مرگ و شروع دوباره -----

func _on_death() -> void:
	deaths += 1
	_shake_death()


func _on_respawn() -> void:
	# مرگ کایرو: شروع دوباره در همان اتاق، سکه‌های اتاق برمی‌گردند (§۸)
	room.reset_room()
	_place_actors_on_entry()


## مرگ ایلارا = شکست مرحله: مرحله از ابتدا شروع می‌شود (§۵ و «قانون همراهی» سند ۰۱).
## استثنا: اگر چک‌پوینت گرفته شده باشد، از آخرین چک‌پوینت.
func restart_level_from_companion_death() -> void:
	ilara_falls += 1
	coins_banked = 0
	gems_banked.clear()
	pages_banked.clear()
	var target := checkpoint_room if checkpoint_room != "" else String(level.get("start_room", "r1"))
	_enter_room(target, "", -1)


func _on_checkpoint(pos: Vector2) -> void:
	checkpoint_room = current_room_id
	checkpoint_pos = pos
	_bank_room()


## ----- اقلام و پایان -----

func _bank_room() -> void:
	if room == null:
		return
	var c := room.collected()
	coins_banked += int(c["coins"])
	for g in c["gems"]:
		if g not in gems_banked:
			gems_banked.append(g)
			EventBus.gem_collected.emit(g)
	for p in c["pages"]:
		if p not in pages_banked:
			pages_banked.append(p)
			EventBus.page_collected.emit(p)


func _on_exit_reached() -> void:
	if finished:
		return
	finished = true
	_bank_room()
	var result := {
		"level_id": String(level.get("id", "?")),
		"coins": coins_banked,
		"gems": gems_banked.duplicate(),
		"pages": pages_banked.duplicate(),
		"deaths": deaths,
		"ilara_falls": ilara_falls,
		"time": elapsed,
		"par_time": float(level.get("par_time", 0.0)),
	}
	result["stars"] = _stars(result)
	EventBus.level_completed.emit(result["level_id"], result)
	level_finished.emit(result)


## رتبه‌بندی: (۱) رسیدن، (۲) جمع هر سه گوهر، (۳) زمان کمتر از زمان هدف (§۸).
## مرگ در رتبه شمرده نمی‌شود، ولی نمایش داده می‌شود.
func _stars(result: Dictionary) -> int:
	var stars := 1
	var total_gems := _total_gems()
	if total_gems > 0 and result["gems"].size() >= total_gems:
		stars += 1
	var par: float = result["par_time"]
	if par > 0.0 and result["time"] <= par:
		stars += 1
	return stars


func _total_gems() -> int:
	var n := 0
	for rd in level.get("rooms", []):
		var objects: Dictionary = rd.get("objects", {})
		for sym in objects.keys():
			if String(objects[sym].get("type", "")) == "gem":
				for line in rd.get("tiles", []):
					n += String(line).count(String(sym))
	return n


func _process(delta: float) -> void:
	if not finished and not level.is_empty():
		elapsed += delta
	_update_hud()


## ----- HUD (§۱۳) -----

func _build_hud() -> void:
	_hud = CanvasLayer.new()
	add_child(_hud)
	_hud.add_child(load("res://ui/touch_controls/touch_controls.tscn").instantiate())
	_hud_label = Label.new()
	_hud_label.position = Vector2(4, 2)
	_hud_label.add_theme_font_size_override("font_size", 8)
	_hud.add_child(_hud_label)


func _update_hud() -> void:
	if _hud_label == null or level.is_empty():
		return
	# چیدمان نهایی HUD (سکه بالا چپ، شمارندهٔ مرگ بالا وسط، توقف بالا راست) در گام ۵
	_hud_label.text = "سکه %d   مرگ %d   اتاق %s   %0.1fs" % [
		coins_banked + (int(room.collected()["coins"]) if room != null else 0),
		deaths, current_room_id, elapsed,
	]
