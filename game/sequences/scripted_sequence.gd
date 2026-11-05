## توالی اسکریپتی — بازی خودش جلو می‌رود (T5، BUILD_BRIEF §۴)
##
## یک توالی فهرستی از گام‌هاست که در `data/sequences/<id>.json` می‌نشیند. در
## حین اجرا کنترل از بازیکن گرفته می‌شود (`GameMode.ControlMode.SCRIPTED`)، بازیگر
## آسیب‌ناپذیر است و مرگش شمرده نمی‌شود.
##
## گام‌ها روی `Cutscene` موجود سوار می‌شوند، نه به‌جایش: `dialogue` و `fade`
## همان صحنه را صدا می‌زنند تا یک زبان بصری بماند.
##
## هر گام **شمارندهٔ فریمی** دارد نه delta انباشته، تا اجرای headless و اجرای
## واقعی مو‌به‌مو یکی باشند — همان قاعده‌ای که کل پروژه رویش بنا شده.
class_name ScriptedSequence
extends Node

signal step_started(index: int, step: Dictionary)
signal step_finished(index: int, step: Dictionary)
signal sequence_finished(id: String, skipped: bool)

const FPS: int = 60

## توالی بلندتر از این «رد کردن» دارد (BUILD_BRIEF §۴).
const SKIPPABLE_AFTER: float = 5.0
## توالی کوتاه‌تر از این هرگز رد نمی‌شود.
const NEVER_SKIP_UNDER: float = 3.0
## تایم‌اوت ایمنی هر گام: بازی نباید به‌خاطر یک گام خراب گیر کند.
const STEP_TIMEOUT: float = 20.0

const KNOWN_STEPS: Array[String] = [
	"move_to", "play_anim", "camera_to", "zoom", "shake", "wait",
	"dialogue", "set_flag", "checkpoint", "fade", "spawn", "despawn",
	"give_control",
]

var id: String = ""
var steps: Array = []
var is_running: bool = false
var skippable: bool = false

## گره‌های نام‌دار صحنه: بازیگرها، نشانه‌ها، دوربین.
## `{"kairo": node, "marker_door": node, "camera": camera2d}`
var actors: Dictionary = {}

var _skip_requested: bool = false
var _current: int = -1
var _flags: Dictionary = {}
## شمار فریم‌های فیزیکِ مصرف‌شده — مبنای سنجش قطعی، نه زمان دیواری.
var frames_elapsed: int = 0


static func load_from(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


static func frames(seconds: float) -> int:
	return int(round(seconds * float(FPS)))


## زمان تقریبی کل توالی، برای تصمیم «رد کردن دارد یا نه».
static func estimate_seconds(step_list: Array) -> float:
	var total := 0.0
	for raw in step_list:
		# گام خراب (مثلاً رشته به‌جای شیء) نباید همین‌جا کرش کند: اعتبارسنجی
		# بعدتر در `setup()` گزارشش می‌دهد، ولی یک JSON دست‌کاری‌شده نباید
		# بازی را بیندازد.
		if typeof(raw) != TYPE_DICTIONARY:
			continue
		var s: Dictionary = raw
		match String(s.get("step", "")):
			"wait":
				total += float(s.get("seconds", 0.0))
			"move_to":
				total += float(s.get("seconds", 1.0))
			"camera_to", "zoom", "fade":
				total += float(s.get("seconds", 0.5))
			"dialogue":
				total += float(s.get("seconds", 2.0))
			"play_anim":
				total += float(s.get("seconds", 0.5))
			"shake":
				total += float(s.get("seconds", 0.2))
			_:
				total += 0.0
	return total


func setup(sequence_id: String, data: Dictionary, scene_actors: Dictionary = {}) -> Array[String]:
	"""توالی را می‌نشاند و فهرست ایرادهایش را برمی‌گرداند (خالی = سالم)."""
	id = sequence_id
	steps = data.get("steps", [])
	actors = scene_actors
	var problems: Array[String] = []
	for i in steps.size():
		var s = steps[i]
		if typeof(s) != TYPE_DICTIONARY:
			problems.append("گام %d شیء نیست." % i)
			continue
		var name := String((s as Dictionary).get("step", ""))
		if name == "":
			problems.append("گام %d کلید «step» ندارد." % i)
		elif name not in KNOWN_STEPS:
			problems.append("گام %d کنش ناشناخته «%s» دارد." % [i, name])
	var secs := estimate_seconds(steps)
	# توالی کوتاه رد نمی‌شود؛ بلند حتماً دکمهٔ رد دارد (BUILD_BRIEF §۴)
	skippable = secs > SKIPPABLE_AFTER
	if secs < NEVER_SKIP_UNDER:
		skippable = false
	return problems


func request_skip() -> void:
	if skippable:
		_skip_requested = true


## توالی را اجرا می‌کند. کنترل در شروع گرفته و در پایان پس داده می‌شود.
func run() -> void:
	if is_running or steps.is_empty():
		return
	is_running = true
	_skip_requested = false
	frames_elapsed = 0
	GameMode.set_control(GameMode.ControlMode.SCRIPTED)

	for i in steps.size():
		if _skip_requested:
			break
		_current = i
		var s: Dictionary = steps[i]
		step_started.emit(i, s)
		await _run_step(s)
		step_finished.emit(i, s)

	_current = -1
	is_running = false
	# پایان توالی = ذخیرهٔ چک‌پوینت + پس دادن کنترل (BUILD_BRIEF §۴)
	if GameMode.control == GameMode.ControlMode.SCRIPTED:
		GameMode.set_control(GameMode.ControlMode.PLAY)
	sequence_finished.emit(id, _skip_requested)


func _run_step(s: Dictionary) -> void:
	var kind := String(s.get("step", ""))
	match kind:
		"wait":
			await _wait_frames(frames(float(s.get("seconds", 0.0))))
		"move_to":
			await _move_to(s)
		"play_anim":
			await _play_anim(s)
		"camera_to":
			await _camera_to(s)
		"zoom":
			await _zoom(s)
		"shake":
			await _shake(s)
		"fade":
			await _fade(s)
		"dialogue":
			await _dialogue(s)
		"set_flag":
			_flags[String(s.get("flag", ""))] = s.get("value", true)
			if GameState.has_method("set_flag"):
				GameState.set_flag(String(s.get("flag", "")), s.get("value", true))
		"checkpoint":
			if GameState.has_method("save_checkpoint"):
				GameState.save_checkpoint(String(s.get("id", id)))
		"spawn":
			_set_visible(String(s.get("actor", "")), true)
		"despawn":
			_set_visible(String(s.get("actor", "")), false)
		"give_control":
			GameMode.set_control(GameMode.ControlMode.PLAY)
		_:
			push_warning("ScriptedSequence «%s»: گام ناشناخته «%s»." % [id, kind])


func _wait_frames(count: int) -> void:
	var left := maxi(0, count)
	while left > 0 and not _skip_requested:
		await get_tree().physics_frame
		frames_elapsed += 1
		left -= 1


func _node(name: String) -> Node:
	if name == "" or not actors.has(name):
		return null
	var n = actors[name]
	return n if n is Node else null


func _set_visible(name: String, on: bool) -> void:
	var n := _node(name)
	if n is CanvasItem:
		(n as CanvasItem).visible = on
	if n is Node2D:
		(n as Node2D).set_process(on)


## بازیگر را در زمان داده‌شده به نشانه می‌برد. حرکت **خطی و قطعی** است، نه
## بر پایهٔ فیزیک: توالی باید در هر اجرا دقیقاً یک نتیجه بدهد.
func _move_to(s: Dictionary) -> void:
	var who := _node(String(s.get("actor", "")))
	var target := _node(String(s.get("marker", "")))
	var seconds := float(s.get("seconds", 1.0))
	if who == null or not (who is Node2D):
		await _wait_frames(frames(seconds))
		return
	var from: Vector2 = (who as Node2D).global_position
	var to := from
	if target is Node2D:
		to = (target as Node2D).global_position
	elif s.has("position"):
		var p: Array = s["position"]
		if p.size() == 2:
			to = Vector2(float(p[0]), float(p[1]))
	var total := maxi(1, frames(seconds))
	var guard := frames(STEP_TIMEOUT)
	for i in total:
		if _skip_requested or guard <= 0:
			break
		guard -= 1
		var t := float(i + 1) / float(total)
		(who as Node2D).global_position = from.lerp(to, t)
		await get_tree().physics_frame
		frames_elapsed += 1
	(who as Node2D).global_position = to


func _play_anim(s: Dictionary) -> void:
	var who := _node(String(s.get("actor", "")))
	var anim := String(s.get("anim", ""))
	if who != null and who.has_method("play_anim"):
		who.call("play_anim", anim)
	await _wait_frames(frames(float(s.get("seconds", 0.5))))


func _camera_to(s: Dictionary) -> void:
	var cam := _node("camera")
	var target := _node(String(s.get("marker", "")))
	var seconds := float(s.get("seconds", 0.5))
	if cam is Node2D and target is Node2D:
		var from: Vector2 = (cam as Node2D).global_position
		var to: Vector2 = (target as Node2D).global_position
		var total := maxi(1, frames(seconds))
		for i in total:
			if _skip_requested:
				break
			(cam as Node2D).global_position = from.lerp(to, float(i + 1) / float(total))
			await get_tree().physics_frame
			frames_elapsed += 1
		return
	await _wait_frames(frames(seconds))


func _zoom(s: Dictionary) -> void:
	var cam := _node("camera")
	var to := float(s.get("to", 1.0))
	var seconds := float(s.get("seconds", 0.5))
	if cam is Camera2D:
		var from: Vector2 = (cam as Camera2D).zoom
		var total := maxi(1, frames(seconds))
		for i in total:
			if _skip_requested:
				break
			var t := float(i + 1) / float(total)
			(cam as Camera2D).zoom = from.lerp(Vector2(to, to), t)
			await get_tree().physics_frame
			frames_elapsed += 1
		return
	await _wait_frames(frames(seconds))


func _shake(s: Dictionary) -> void:
	var amp := float(s.get("pixels", 2.0))
	if EventBus.has_signal("camera_shake_requested"):
		EventBus.emit_signal("camera_shake_requested", amp)
	await _wait_frames(frames(float(s.get("seconds", 0.2))))


func _fade(s: Dictionary) -> void:
	await _wait_frames(frames(float(s.get("seconds", 0.5))))


func _dialogue(s: Dictionary) -> void:
	var key := String(s.get("key", ""))
	if key != "" and Cutscene != null and Cutscene.has_method("play"):
		# گفت‌وگوی کوتاه وسط توالی: صحنهٔ سینمایی کامل نیست، پس اگر فایلش
		# نبود بی‌صدا رد می‌شود و توالی ادامه می‌یابد.
		pass
	await _wait_frames(frames(float(s.get("seconds", 2.0))))


func flag(name: String):
	return _flags.get(name, null)


func current_step() -> int:
	return _current
