## کنترل لمسی نمای کناری — docs/02_godot_spec.md §۲
##
## چیدمان: چپ پایین دو دکمهٔ دایره‌ای چپ/راست (قطر ۴۸، فاصله ۸)، راست پایین پرش (۵۶)
## و عمل (۴۸) و بالای آن همراه (۳۶)، بالا راست توقف (۲۴).
##
## چندلمسی: هر دکمه شناسهٔ انگشت (index) خودش را دنبال می‌کند تا کشیدن انگشت از دکمه‌ای
## به دکمهٔ دیگر خطا ندهد. حداقل ۴ لمس هم‌زمان پشتیبانی می‌شود.
##
## این گره رویدادهای InputMap را می‌سازد، پس کایرو فرقی بین لمس و صفحه‌کلید نمی‌بیند.
extends Control

## قطر هر دکمه بر حسب پیکسل مجازی (§۲)
const SIZES := {
	"move_left": 48.0,
	"move_right": 48.0,
	"jump": 56.0,
	"action": 48.0,
	"companion": 36.0,
	"pause": 24.0,
}

const MARGIN: float = 10.0
const GAP: float = 8.0

## حداقل اندازهٔ لمس ۴۸×۴۸ پیکسل مجازی (§۱۳) — ناحیهٔ لمس هر دکمه از ظاهرش بزرگ‌تر است
const MIN_TOUCH: float = 48.0

## action → مرکز دایره بر حسب پیکسل مجازی
var _centers: Dictionary = {}
## شناسهٔ انگشتی که هر دکمه را گرفته: action → index
var _owner_index: Dictionary = {}
## index انگشت → action
var _index_action: Dictionary = {}

var _vp := Vector2(480, 270)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_vp = Vector2(get_viewport_rect().size)
	Settings.changed.connect(_layout)
	get_viewport().size_changed.connect(_on_viewport_resized)
	_layout()


func _on_viewport_resized() -> void:
	_vp = Vector2(get_viewport_rect().size)
	_layout()
	queue_redraw()


func _layout() -> void:
	var s: float = Settings.touch_scale
	var w: float = _vp.x
	var h: float = _vp.y
	var m: float = MARGIN * s
	var g: float = GAP * s

	var r_left: float = SIZES["move_left"] * s * 0.5
	var r_right: float = SIZES["move_right"] * s * 0.5
	var r_jump: float = SIZES["jump"] * s * 0.5
	var r_action: float = SIZES["action"] * s * 0.5
	var r_comp: float = SIZES["companion"] * s * 0.5
	var r_pause: float = SIZES["pause"] * s * 0.5

	_centers = {
		"move_left": Vector2(m + r_left, h - m - r_left),
		"move_right": Vector2(m + r_left * 2.0 + g + r_right, h - m - r_right),
		"jump": Vector2(w - m - r_jump, h - m - r_jump),
		"action": Vector2(w - m - r_jump * 2.0 - g - r_action, h - m - r_action),
		"companion": Vector2(w - m - r_jump * 2.0 - g - r_action, h - m - r_action * 2.0 - g - r_comp),
		"pause": Vector2(w - m - r_pause, m + r_pause),
	}
	queue_redraw()


func _radius(action: String) -> float:
	return SIZES[action] * Settings.touch_scale * 0.5


## ناحیهٔ لمس هیچ‌وقت کمتر از ۴۸×۴۸ نمی‌شود، حتی اگر ظاهر دکمه کوچک‌تر باشد.
func _touch_radius(action: String) -> float:
	return maxf(_radius(action), MIN_TOUCH * Settings.touch_scale * 0.5)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		_handle_touch(event)
	elif event is InputEventScreenDrag:
		_handle_drag(event)


func _handle_touch(e: InputEventScreenTouch) -> void:
	if e.pressed:
		var action := _action_at(e.position)
		if action == "":
			return
		# اگر دکمه دست انگشت دیگری است، انگشت تازه آن را نمی‌قاپد.
		if _owner_index.has(action):
			return
		_owner_index[action] = e.index
		_index_action[e.index] = action
		_press(action, true)
		get_viewport().set_input_as_handled()
	else:
		if not _index_action.has(e.index):
			return
		var action: String = _index_action[e.index]
		_release_index(e.index, action)
		get_viewport().set_input_as_handled()


## کشیدن انگشت: دکمهٔ گرفته‌شده را رها نمی‌کند تا انگشت از ناحیهٔ لمس بیرون برود.
## این همان چیزی است که §۲ می‌خواهد: کشیدن انگشت از دکمه‌ای به دکمهٔ دیگر خطا ندهد.
func _handle_drag(e: InputEventScreenDrag) -> void:
	if not _index_action.has(e.index):
		return
	var action: String = _index_action[e.index]
	if e.position.distance_to(_centers.get(action, Vector2.ZERO)) > _touch_radius(action) * 1.6:
		_release_index(e.index, action)


func _release_index(index: int, action: String) -> void:
	_press(action, false)
	_index_action.erase(index)
	if _owner_index.get(action, -1) == index:
		_owner_index.erase(action)


func _action_at(pos: Vector2) -> String:
	var best := ""
	var best_d := INF
	for action in _centers.keys():
		var d: float = pos.distance_to(_centers[action])
		if d <= _touch_radius(action) and d < best_d:
			best = action
			best_d = d
	return best


func _press(action: String, pressed: bool) -> void:
	if pressed:
		Input.action_press(action, 1.0)
	else:
		Input.action_release(action)


## همهٔ دکمه‌ها رها شوند — هنگام مکث یا شروع دوباره لازم است
func release_all() -> void:
	for index in _index_action.keys():
		Input.action_release(_index_action[index])
	_index_action.clear()
	_owner_index.clear()


## مکان‌نگهدار بصری: دایره‌های نیمه‌شفاف. در گام ۶ با آیکون واقعی عوض می‌شود.
func _draw() -> void:
	for action in _centers.keys():
		var c: Vector2 = _centers[action]
		var r: float = _radius(action)
		var held: bool = _owner_index.has(action)
		var col := Color(Palette.WHITE, 0.30 if held else 0.16)
		draw_circle(c, r, col)
		draw_arc(c, r, 0.0, TAU, 24, Color(Palette.WHITE, 0.45), 1.0, false)
