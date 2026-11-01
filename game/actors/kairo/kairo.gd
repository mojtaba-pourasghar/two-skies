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

var hack: HackModule = null
var dash_tool: DashTool = null


func _ready() -> void:
	actor_name = "kairo"
	super()
	hack = HackModule.new()
	hack.owner_actor = self
	add_child(hack)
	dash_tool = DashTool.new()
	dash_tool.owner_actor = self
	add_child(dash_tool)
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


func _physics_process(delta: float) -> void:
	_update_hack(delta)
	super(delta)
	_record()


## هک دکمهٔ عمل را می‌گیرد و کایرو را در مدت نگه‌داشتن ثابت می‌کند (§۶).
## وقتی ابزار فعال هک است، دش با همان دکمه فعال نمی‌شود.
func _update_hack(delta: float) -> void:
	if hack == null:
		return
	if not GameState.is_tool_unlocked("hack") or state == State.DEAD or state == State.CUTSCENE:
		return
	var holding := active_tool == "hack" and Input.is_action_pressed("action")
	hack.update_hold(delta, holding)
	if hack.is_charging():
		_set_state(State.HACK)
	elif state == State.HACK:
		_set_state(State.IDLE)


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
	_refresh_tools()
	# ابزار فعال پیش‌فرض: اگر هک باز است، هک؛ وگرنه دش اگر باز است.
	if GameState.is_tool_unlocked("hack"):
		active_tool = "hack"
	elif GameState.is_tool_unlocked("dash"):
		active_tool = "dash"
	else:
		active_tool = ""


## دکمهٔ عمل با ابزار فعال معنی عوض می‌کند (§۶).
func is_holding_hack() -> bool:
	return active_tool == "hack" and Input.is_action_pressed("action")


func hack_hold_progress() -> float:
	return hack.hold_progress() if hack != null else 0.0


## ابزار فعال را عوض می‌کند. در نسخهٔ ۱ فقط "hack" و "dash" و "" هستند.
func set_active_tool(id: String) -> void:
	if id != "" and not GameState.is_tool_unlocked(id):
		return
	active_tool = id


## اگر ابزار فعال هک باشد، دکمهٔ عمل مال هک است و دش نباید شلیک شود.
func _gather_input() -> Dictionary:
	var x := 0.0
	if Input.is_action_pressed("move_right"):
		x += 1.0
	if Input.is_action_pressed("move_left"):
		x -= 1.0
	var action := Input.is_action_just_pressed("action") and active_tool != "hack"
	return {
		"x": x,
		"jump": Input.is_action_just_pressed("jump"),
		"jump_held": Input.is_action_pressed("jump"),
		"action": action,
	}
