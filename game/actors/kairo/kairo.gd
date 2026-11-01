## کایرو — بازیکن (docs/02_godot_spec.md §۴ و §۶)
##
## تنها شخصیتی که بازیکن مستقیم کنترل می‌کند. ایلارا هم‌مسیر او است و ورودی‌هایی که
## اینجا ثبت می‌شوند با تأخیر ۴۸ فریم برای او بازپخش می‌شوند (§۵).
class_name Kairo
extends PlatformActor

## طول صف ثبت ورودی: ۰٫۸ ثانیه تأخیر ایلارا + حاشیه
const HISTORY_FRAMES: int = 120

## هر درایه: {"frame": int, "pos": Vector2, "x": float, "jump": bool, "jump_held": bool, "facing": int}
var history: Array[Dictionary] = []

## ابزار فعال که دکمهٔ عمل را می‌گیرد؛ در نسخهٔ ۱: "" یا "hack" یا "dash"
var active_tool: String = ""

var _hack_hold_frames: int = 0


func _ready() -> void:
	actor_name = "kairo"
	super()
	_refresh_tools()
	GameState.progress_changed.connect(_refresh_tools)


func _sync_constants() -> void:
	run_speed = KairoConst.RUN_SPEED
	jump_velocity = KairoConst.JUMP_VELOCITY


## ابزارها فقط وقتی باز شده باشند کار می‌کنند (§۶ — تا باز نشده در منو خاکستری است)
func _refresh_tools() -> void:
	can_wall_jump = GameState.is_tool_unlocked("wall_jump")
	can_dash = GameState.is_tool_unlocked("dash")
	if active_tool == "dash" and not can_dash:
		active_tool = ""
	if active_tool == "hack" and not GameState.is_tool_unlocked("hack"):
		active_tool = ""


func _gather_input() -> Dictionary:
	var x := 0.0
	if Input.is_action_pressed("move_right"):
		x += 1.0
	if Input.is_action_pressed("move_left"):
		x -= 1.0
	return {
		"x": x,
		"jump": Input.is_action_just_pressed("jump"),
		"jump_held": Input.is_action_pressed("jump"),
		"action": Input.is_action_just_pressed("action"),
	}


func _physics_process(delta: float) -> void:
	super(delta)
	_record()


## صف موقعیت و ورودی برای بازپخش ایلارا (§۵)
func _record() -> void:
	history.append({
		"frame": frame,
		"pos": global_position,
		"x": input.get("x", 0.0),
		"jump": input.get("jump", false),
		"jump_held": input.get("jump_held", false),
		"facing": facing,
		"state": state,
	})
	if history.size() > HISTORY_FRAMES:
		history.remove_at(0)


## ورودی ثبت‌شدهٔ `delay_frames` فریم قبل. اگر صف هنوز پر نشده null برمی‌گردد.
func history_at(delay_frames: int) -> Variant:
	var idx := history.size() - 1 - delay_frames
	if idx < 0:
		return null
	return history[idx]


func reset_to(pos: Vector2) -> void:
	super(pos)
	history.clear()
	_hack_hold_frames = 0
	active_tool = ""
	_refresh_tools()


## دکمهٔ عمل با ابزار فعال معنی عوض می‌کند (§۶).
## دش در PlatformActor دست می‌خورد؛ هک اینجا نگه‌داشتن می‌خواهد.
func is_holding_hack() -> bool:
	return active_tool == "hack" and Input.is_action_pressed("action")


func hack_hold_progress() -> float:
	var need := _f(Settings.param("hack", "hold_time", 0.6))
	if need <= 0:
		return 0.0
	return clampf(float(_hack_hold_frames) / float(need), 0.0, 1.0)


func set_hack_hold(frames: int) -> void:
	_hack_hold_frames = frames
	if frames > 0:
		_set_state(State.HACK)
	elif state == State.HACK:
		_set_state(State.IDLE)
