## حالت بازی — چه کسی کنترل دارد و کجاییم (T5، BUILD_BRIEF §۴)
##
## دو محور جدا، نه یک فهرست:
##
##   `control` — **چه کسی فرمان می‌دهد**: PLAY (بازیکن)، SCRIPTED (توالی
##               سناریو)، CUTSCENE (صحنهٔ سینمایی)، MENU.
##   `context` — **کجاییم**: OVERWORLD، EXPLORE، BATTLE.
##
## `BUILD_BRIEF §۴` سه‌تای اول را می‌خواهد و `docs/02 §۰` هر شش‌تا را «حالت
## بازی» می‌نامد. اگر همه را در یک فهرست بگذاریم، «توالی اسکریپتی وسط نبرد»
## بیان‌شدنی نیست — در حالی که سند ۰۹ §۵ دقیقاً همین را دارد (لحظهٔ افتادن
## ایلارا، باز شدن پنل باس). دو محور هر دو سند را برآورده می‌کند.
## (DECISIONS.md: D-ART-19)
extends Node

signal control_changed(from: ControlMode, to: ControlMode)
signal context_changed(from: Context, to: Context)

enum ControlMode { PLAY, SCRIPTED, CUTSCENE, MENU }
enum Context { OVERWORLD, EXPLORE, BATTLE }

const CONTROL_NAME := {
	ControlMode.PLAY: "PLAY", ControlMode.SCRIPTED: "SCRIPTED",
	ControlMode.CUTSCENE: "CUTSCENE", ControlMode.MENU: "MENU",
}
const CONTEXT_NAME := {
	Context.OVERWORLD: "OVERWORLD", Context.EXPLORE: "EXPLORE",
	Context.BATTLE: "BATTLE",
}

## همهٔ کنش‌های بازیکن. در غیر PLAY هیچ‌کدام خوانده نمی‌شوند.
const PLAYER_ACTIONS: Array[String] = [
	"move_left", "move_right", "move_up", "move_down",
	"jump", "action", "companion", "ability",
]

var control: ControlMode = ControlMode.PLAY
var context: Context = Context.EXPLORE

## وقتی بازیگر در توالی اسکریپتی است، آسیب نمی‌بیند و مرگش شمرده نمی‌شود
## (BUILD_BRIEF §۴)، مگر گامی صریح خلافش را بگوید.
var scripted_invulnerable: bool = true

var _ignore_frames: int = 0


func set_control(to: ControlMode) -> void:
	if to == control:
		return
	var from := control
	control = to
	if to != ControlMode.PLAY:
		# بافر ورودی پاک می‌شود، وگرنه دکمه‌ای که پیش از توالی فشرده شده بود
		# لحظهٔ برگشت کنترل شلیک می‌کند (BUILD_BRIEF §۴).
		flush_input()
	else:
		# یک فریم مهلت، تا همان دکمه‌ای که توالی را رد کرد بلافاصله در بازی
		# خوانده نشود.
		_ignore_frames = 1
	control_changed.emit(from, to)


func set_context(to: Context) -> void:
	if to == context:
		return
	var from := context
	context = to
	context_changed.emit(from, to)


## آیا ورودی بازیکن این فریم خوانده می‌شود؟
func wants_input() -> bool:
	return control == ControlMode.PLAY and _ignore_frames <= 0


## هر فریم فیزیک صدا زده می‌شود تا مهلت یک‌فریمی بگذرد.
func tick() -> void:
	if _ignore_frames > 0:
		_ignore_frames -= 1


## بافر ورودی را پاک می‌کند.
func flush_input() -> void:
	for a in PLAYER_ACTIONS:
		if InputMap.has_action(a):
			Input.action_release(a)


## جای `Input.get_vector` برای بازیگرها: در غیر PLAY صفر می‌دهد.
func move_vector() -> Vector2:
	if not wants_input():
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


## جای `Input.is_action_just_pressed` برای بازیگرها.
func just_pressed(action: String) -> bool:
	return wants_input() and Input.is_action_just_pressed(action)


func is_pressed(action: String) -> bool:
	return wants_input() and Input.is_action_pressed(action)


## HUD در غیر PLAY پنهان یا کم‌رنگ می‌شود (BUILD_BRIEF §۴).
func hud_alpha() -> float:
	match control:
		ControlMode.CUTSCENE:
			return 0.0
		ControlMode.SCRIPTED:
			return 0.35
		ControlMode.MENU:
			return 0.0
		_:
			return 1.0


func control_name() -> String:
	return String(CONTROL_NAME.get(control, "?"))


func context_name() -> String:
	return String(CONTEXT_NAME.get(context, "?"))


## آیا مرگ این لحظه شمرده می‌شود؟
func death_counts() -> bool:
	if control == ControlMode.SCRIPTED and scripted_invulnerable:
		return false
	return control == ControlMode.PLAY
