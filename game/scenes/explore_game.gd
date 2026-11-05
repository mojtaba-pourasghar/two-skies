## صحنهٔ اکتشاف — MVP قابل‌بازی ناحیهٔ ۱ (T15)
##
## همهٔ تکه‌های T3 تا T6 را به هم وصل می‌کند: ناحیه، کایرو، ایلارا در صف،
## دوربین نرم، کارگردان دوربین با `camera_zone`، و ماشه‌های توالی.
extends Node2D

const AREA_DIR := "res://levels/data/areas/"

@export var area_id: String = "ch1_a1"

var area_node: ExploreArea
var director: CameraDirector
var camera: GameCamera
var kairo: TdKairo
var ilara: TdIlara

var _visuals: Array[ActorVisual] = []
var _fired: Dictionary = {}
var _sequences: Dictionary = {}
var _running: ScriptedSequence = null


func _ready() -> void:
	var loader := AreaLoader.new()
	var data := loader.load_area(AREA_DIR + area_id + ".json")
	if data.is_empty():
		for e in loader.errors:
			push_error("ExploreGame: %s" % e)
		return
	for w in loader.warnings:
		push_warning("ExploreGame: %s" % w)

	director = CameraDirector.new()
	director.name = "Director"
	add_child(director)
	director.setup(String(data.get("camera_mode", "topdown")),
		data.get("camera_zones", []), ExploreArea.TILE)

	area_node = ExploreArea.new()
	area_node.name = "Area"
	area_node.director = director
	add_child(area_node)
	area_node.build(data)
	if not area_node.missing_art.is_empty():
		# هنر ناقص بازی را نمی‌شکند، فقط گزارش می‌شود (CLAUDE.md)
		push_warning("ExploreGame: %d دارایی هنری پیدا نشد: %s"
			% [area_node.missing_art.size(), ", ".join(area_node.missing_art.slice(0, 5))])

	_spawn_actors(data)
	_build_camera(data)
	_bind_traps()

	GameMode.set_context(GameMode.Context.EXPLORE)
	GameMode.set_control(GameMode.ControlMode.PLAY)
	GameState.set_respawn_point(area_node.spawn_position())
	EventBus.level_started.emit(area_id)


func _spawn_actors(_data: Dictionary) -> void:
	kairo = TdKairo.new()
	kairo.name = "Kairo"
	add_child(kairo)
	kairo.global_position = area_node.spawn_position()
	kairo.room = area_node
	_dress(kairo, "kairo")

	ilara = TdIlara.new()
	ilara.name = "Ilara"
	add_child(ilara)
	ilara.leader = kairo
	ilara.global_position = area_node.spawn_position() - Vector2(ExploreArea.TILE, 0)
	ilara.room = area_node
	_dress(ilara, "ilara")

	if area_node.challenge != null:
		kairo.died.connect(func(): area_node.challenge.register_death(kairo))


## اسپرایت و سایه را به بازیگر می‌چسباند. بدون این، بازیگر نامرئی است —
## چیزی که فقط در اسکرین‌شات دیده می‌شود، نه در هیچ سنجهٔ عددی.
func _dress(actor: TdActor, who: String) -> void:
	var vis := ActorVisual.new()
	vis.name = "Visual"
	actor.add_child(vis)
	vis.setup(who)
	actor.attach_visual(vis, vis.shadow())
	_visuals.append(vis)
	if not vis.missing.is_empty():
		push_warning("ExploreGame: اسپرایت «%s» ناقص: %s"
			% [who, ", ".join(vis.missing.slice(0, 3))])


func _build_camera(data: Dictionary) -> void:
	camera = GameCamera.new()
	camera.name = "Camera"
	camera.follow_mode = String(data.get("camera_follow", GameCamera.FOLLOW))
	camera.director = director
	camera.target = kairo
	add_child(camera)
	camera.set_bounds(area_node.bounds())
	camera.make_current()
	camera.snap_to_target()


func _bind_traps() -> void:
	for t in area_node.traps:
		t.sprung.connect(_on_trap_sprung.bind(t))


func _on_trap_sprung(_pct: float, _safe: Vector2, trap: ExploreTrap) -> void:
	if trap.sequence_id != "":
		_start_sequence(trap.sequence_id)


func _physics_process(_delta: float) -> void:
	GameMode.tick()
	if kairo == null:
		return
	director.update(kairo.foot_position())
	if _visuals.size() >= 1:
		_visuals[0].update_from(kairo)
	if _visuals.size() >= 2 and ilara != null:
		_visuals[1].update_from(ilara)
	_check_triggers()


func _check_triggers() -> void:
	if _running != null and _running.is_running:
		return
	var foot := kairo.foot_position()
	for raw in area_node.area.get("triggers", []):
		var t: Dictionary = raw
		var tid := String(t.get("id", ""))
		if bool(t.get("once", true)) and _fired.has(tid):
			continue
		var rect: Array = t.get("rect", [0, 0, 1, 1])
		var r := Rect2(
			int(rect[0]) * ExploreArea.TILE, int(rect[1]) * ExploreArea.TILE,
			int(rect[2]) * ExploreArea.TILE, int(rect[3]) * ExploreArea.TILE)
		if r.has_point(foot):
			_fired[tid] = true
			_start_sequence(String(t.get("sequence", "")))
			return


func _start_sequence(sequence_id: String) -> void:
	if sequence_id == "" or (_running != null and _running.is_running):
		return
	var data := ScriptedSequence.load_from("res://data/sequences/%s.json" % sequence_id)
	if data.is_empty():
		push_warning("ExploreGame: توالی «%s» پیدا نشد." % sequence_id)
		return
	var seq := ScriptedSequence.new()
	seq.name = "Seq_%s" % sequence_id
	add_child(seq)
	var problems := seq.setup(sequence_id, data, _actor_map())
	for p in problems:
		push_warning("ExploreGame: توالی «%s»: %s" % [sequence_id, p])
	_running = seq
	EventBus.emit_signal("sequence_triggered", sequence_id)
	seq.run()


func _actor_map() -> Dictionary:
	return {"kairo": kairo, "ilara": ilara, "camera": camera}
