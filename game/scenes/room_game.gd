## صحنهٔ اتاق نقاشی‌شده — M1
##
## اتاق را می‌سازد، بازیگران را در لایهٔ درست می‌نشاند، دوربین را طبق رفتار
## اتاق می‌چیند، و در را با گذار ۰٫۳ ثانیه‌ای به اتاق بعد وصل می‌کند.
##
## حرکت در این بازی **ماسک‌محور** است نه برخورد فیزیکی: بازیگر هر فریم
## می‌سنجد که قدم بعدی‌اش روی چندضلعی قابل‌راه‌رفتن می‌افتد یا نه. دلیلش
## سند ۱۱ است — دیوار در خود **تصویر** نقاشی شده و جسم فیزیکی ندارد.
extends Node2D

@export var start_room: String = "r1a_living"
@export var debug_mask: bool = false

var room: PaintedRoom
var director: CameraDirector
var camera: GameCamera
var kairo: TdKairo
var ilara: TdIlara

var _loader := RoomData.new()
var _visuals: Array[ActorVisual] = []
var _fade: ColorRect
var _hud: CanvasLayer
var _pending_spawn := Vector2.ZERO


func _ready() -> void:
	director = CameraDirector.new()
	director.name = "Director"
	add_child(director)
	director.transition_finished.connect(_on_transition_finished)

	_build_hud()
	_build_camera()
	if not _enter_room(start_room, Vector2.ZERO):
		return

	GameMode.set_context(GameMode.Context.EXPLORE)
	GameMode.set_control(GameMode.ControlMode.PLAY)
	EventBus.level_started.emit(start_room)


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "HUD"
	_hud.layer = 10
	add_child(_hud)
	# پردهٔ محو گذار در به در
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_fade)


func _build_camera() -> void:
	camera = GameCamera.new()
	camera.name = "Camera"
	camera.director = director
	add_child(camera)
	camera.make_current()


func _enter_room(room_id: String, spawn_override: Vector2) -> bool:
	var data := _loader.load_room(room_id)
	if data.is_empty():
		for e in _loader.errors:
			push_error("RoomGame: %s" % e)
		return false
	for w in _loader.warnings:
		push_warning("RoomGame: %s" % w)

	if room != null:
		room.queue_free()
		room = null
	room = PaintedRoom.new()
	room.name = "Room_%s" % room_id
	add_child(room)
	move_child(room, 0)
	room.build(data)
	if debug_mask:
		room.show_mask(true)
	if not room.missing_art.is_empty():
		push_warning("RoomGame: %d دارایی پیدا نشد: %s"
			% [room.missing_art.size(), ", ".join(room.missing_art.slice(0, 4))])

	director.setup(String(data.get("camera", "room")), room_id)
	_spawn_actors(spawn_override if spawn_override != Vector2.ZERO
		else room.spawn_position())

	camera.follow_mode = String(data.get("camera", "room"))
	camera.set_bounds(room.bounds())
	camera.set_room(room.bounds())
	camera.target = kairo
	camera.snap_to_target()
	return true


func _spawn_actors(at: Vector2) -> void:
	_visuals.clear()
	kairo = TdKairo.new()
	kairo.name = "Kairo"
	room.actors.add_child(kairo)
	kairo.global_position = at
	kairo.room = room
	_dress(kairo, "kairo")

	ilara = TdIlara.new()
	ilara.name = "Ilara"
	room.actors.add_child(ilara)
	ilara.leader = kairo
	ilara.global_position = at - Vector2(40, 0)
	ilara.room = room
	_dress(ilara, "ilara")


func _dress(actor: TdActor, who: String) -> void:
	var vis := ActorVisual.new()
	vis.name = "Visual"
	actor.add_child(vis)
	vis.setup(who)
	actor.attach_visual(vis, vis.shadow())
	_visuals.append(vis)


func _physics_process(_delta: float) -> void:
	GameMode.tick()
	director.tick()
	_fade.color.a = director.fade_alpha()
	if kairo == null or director.is_transitioning():
		return
	for i in _visuals.size():
		var a: TdActor = kairo if i == 0 else ilara
		if a != null:
			_visuals[i].update_from(a)
	_check_door()


func _check_door() -> void:
	var door := room.door_at(kairo.foot_position())
	if door.is_empty():
		return
	var sp: Array = door.get("spawn", [0, 0])
	_pending_spawn = Vector2(float(sp[0]), float(sp[1]))
	director.go_to_room(String(door.get("to", "")), "")


func _on_transition_finished(room_id: String) -> void:
	_enter_room(room_id, _pending_spawn)
	_pending_spawn = Vector2.ZERO
