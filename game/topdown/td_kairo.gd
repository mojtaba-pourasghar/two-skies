## کایرو در نمای سه‌چهارم — ورودی بازیکن.
##
## ردّ حرکتش را برای ایلارا ضبط می‌کند: هر فریم یک جای‌گاه، و هر جهش یک نشانهٔ
## **مکانی** (نقطهٔ فرود) نه زمانی. همان الگوی D-037 نمای کناری.
class_name TdKairo
extends TdActor

## طول حلقهٔ ضبط: باید از تأخیر همراه بیشتر باشد.
const TRAIL: int = 180

var _trail_pos: PackedVector2Array = PackedVector2Array()
var _trail_hop: PackedVector2Array = PackedVector2Array()
var _trail_has_hop: PackedByteArray = PackedByteArray()
var _head: int = 0
var _filled: int = 0

## روبات این را پر می‌کند تا به‌جای صفحه‌کلید فرمان بدهد.
var scripted_dir := Vector2.ZERO
var use_scripted: bool = false


func _ready() -> void:
	super()
	actor_name = "kairo"
	speed = TdConst.RUN_SPEED
	add_to_group("kairo")
	_trail_pos.resize(TRAIL)
	_trail_hop.resize(TRAIL)
	_trail_has_hop.resize(TRAIL)
	for i in TRAIL:
		_trail_pos[i] = global_position
	hop_started.connect(_on_hop_started)


func _input_dir() -> Vector2:
	if use_scripted:
		return scripted_dir
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func _physics_process(delta: float) -> void:
	if not use_scripted and state == State.MOVE:
		if Input.is_action_just_pressed("jump"):
			start_hop(_input_dir())
		elif Input.is_action_just_pressed("dash"):
			start_dash(_input_dir())
	super(delta)
	_record()


func _on_hop_started(_from: Vector2, to: Vector2) -> void:
	_trail_hop[_head] = to
	_trail_has_hop[_head] = 1


func _record() -> void:
	_head = (_head + 1) % TRAIL
	_trail_pos[_head] = global_position
	_trail_has_hop[_head] = 0
	_filled = mini(_filled + 1, TRAIL)


## جای کایرو در `delay` فریم پیش. تا پر شدن حلقه، قدیمی‌ترین چیزی که هست.
func trail_at(delay: int) -> Vector2:
	var back: int = mini(delay, maxi(0, _filled - 1))
	return _trail_pos[(_head - back + TRAIL) % TRAIL]


## اگر در آن فریم جهشی شروع شده بود، نقطهٔ فرودش؛ وگرنه بردار صفر.
func hop_mark_at(delay: int) -> Vector2:
	var back: int = mini(delay, maxi(0, _filled - 1))
	var i: int = (_head - back + TRAIL) % TRAIL
	return _trail_hop[i] if _trail_has_hop[i] == 1 else Vector2.ZERO
