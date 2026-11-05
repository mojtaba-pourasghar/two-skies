## بازیگر نمای سه‌چهارم — game/TOPDOWN_SPEC.md
##
## بدون گرانش. حرکت ۸ جهته، جهش با کمان ثابت، دش، و مرگ فوری.
## برخورد فقط با **پا** است (۱۰×۸ در نیمهٔ پایین بدن)، چون در نمای سه‌چهارم سر
## جلوی دیوارِ پشت کشیده می‌شود.
class_name TdActor
extends CharacterBody2D

signal died
signal respawned
signal hop_started(from: Vector2, to: Vector2)
signal landed(at: Vector2)

enum State { MOVE, HOP, DASH, DEAD }

## مدل حرکت. با حالت دوربین عوض می‌شود، **وسط ناحیه و بدون بارگذاری**
## (D-ART-09d): اکتشاف بدون گرانش، اتاق چالش با گرانش و پرش.
enum Movement { TOPDOWN, SIDE }

@export var actor_name: String = "actor"
@export var speed: float = 96.0

var state: State = State.MOVE
var movement: Movement = Movement.TOPDOWN
var facing := Vector2.DOWN
var deaths: int = 0
var spawn_point := Vector2.ZERO

## خانه‌هایی که مرگ‌آورند و خانه‌هایی که دیوارند — اتاق پُرشان می‌کند.
var room: Node = null

var _hop_from := Vector2.ZERO
var _hop_to := Vector2.ZERO
var _hop_frame: int = 0
var _dash_frames_left: int = 0
var _dash_dir := Vector2.ZERO
var _dash_cooldown: int = 0
var _dead_frames: int = 0
var _coyote: float = 0.0
var _jump_buffer: int = 0
var _visual: Node2D = null
var _shadow: Node2D = null


## مدل حرکت را عوض می‌کند. `motion_mode` هم با آن عوض می‌شود، وگرنه در
## حالت کناری بازیگر روی زمین «سُر» می‌خورد و هرگز `is_on_floor` نمی‌شود.
func set_movement(to: Movement) -> void:
	if to == movement:
		return
	movement = to
	motion_mode = (CharacterBody2D.MOTION_MODE_FLOATING if to == Movement.TOPDOWN
		else CharacterBody2D.MOTION_MODE_GROUNDED)
	velocity = Vector2.ZERO
	if state == State.HOP or state == State.DASH:
		state = State.MOVE


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = TdConst.FOOT
	shape.shape = r
	shape.position = Vector2(0, TdConst.FOOT_OFFSET_Y)
	shape.name = "Foot"
	add_child(shape)
	spawn_point = global_position


## اسپرایت و سایه را بازیگر بیرونی می‌نشاند؛ بازیگر فقط جابه‌جایشان می‌کند.
func attach_visual(visual: Node2D, shadow: Node2D) -> void:
	_visual = visual
	_shadow = shadow


## ارتفاع دیداری جهش: فقط جابه‌جایی اسپرایت است، نه فیزیک. سایه روی زمین
## می‌ماند، پس بازیکن نقطهٔ فرود را می‌بیند — همین «دقت پرش» را در نمای بالا
## ممکن می‌کند (TOPDOWN_SPEC §۳).
func _visual_lift() -> float:
	if state != State.HOP:
		return 0.0
	var t: float = float(_hop_frame) / float(maxi(1, TdConst.hop_frames()))
	return -TdConst.HOP_ARC_PX * sin(t * PI)


func _physics_process(_delta: float) -> void:
	match state:
		State.DEAD:
			_tick_dead()
		State.HOP:
			_tick_hop()
		State.DASH:
			_tick_dash()
		State.MOVE:
			_tick_move()
	if _dash_cooldown > 0:
		_dash_cooldown -= 1
	if _visual:
		_visual.position.y = _visual_lift()


func _tick_move() -> void:
	if movement == Movement.SIDE:
		_tick_move_side()
		return
	var wish := TdConst.snap8(_input_dir())
	if wish != Vector2.ZERO:
		facing = wish
	var target := wish * speed
	var accel: float = TdConst.GROUND_ACCEL if wish != Vector2.ZERO else TdConst.GROUND_DECEL
	velocity = velocity.move_toward(target, accel / float(TdConst.FPS))
	move_and_slide()
	_check_ground()


## حرکت کناری: گرانش، پرش، و فقط محور افقی از ورودی.
##
## اعداد از پروفایل `challenge_side` می‌آیند (همان نگاشت `CameraDirector`)،
## پس حالت دوربین و اعداد فیزیک هرگز واگرا نمی‌شوند (D-ART-14).
func _tick_move_side() -> void:
	var raw := _input_dir()
	var dir := signf(raw.x) if absf(raw.x) > 0.2 else 0.0
	if dir != 0.0:
		facing = Vector2(dir, 0.0)

	var target_x := dir * KairoConst.RUN_SPEED
	var accel := KairoConst.GROUND_ACCEL if dir != 0.0 else KairoConst.GROUND_DECEL
	if not is_on_floor():
		accel = KairoConst.AIR_ACCEL if dir != 0.0 else KairoConst.AIR_DECEL
	velocity.x = move_toward(velocity.x, target_x, accel / float(TdConst.FPS))

	if is_on_floor():
		_coyote = KairoConst.COYOTE_TIME
	else:
		_coyote = maxf(0.0, _coyote - 1.0 / float(TdConst.FPS))
		var g := KairoConst.GRAVITY
		if velocity.y > 0.0:
			g *= KairoConst.FALL_GRAVITY_MULT
		velocity.y = minf(velocity.y + g / float(TdConst.FPS), KairoConst.MAX_FALL)

	if _jump_buffer > 0:
		_jump_buffer -= 1
	if _wants_jump():
		_jump_buffer = TdConst.frames(KairoConst.JUMP_BUFFER)
	if _jump_buffer > 0 and _coyote > 0.0:
		velocity.y = KairoConst.JUMP_VELOCITY
		_jump_buffer = 0
		_coyote = 0.0
	# پرش متغیر: رها کردن دکمه اوج را کوتاه می‌کند (§۳)
	if velocity.y < 0.0 and not _holds_jump():
		velocity.y *= KairoConst.JUMP_CUT

	move_and_slide()
	_check_ground()


## زیرکلاس‌ها بازنویسی می‌کنند (بازیکن، همراه، روبات).
func _wants_jump() -> bool:
	return false


func _holds_jump() -> bool:
	return true


func _tick_hop() -> void:
	var total: int = TdConst.hop_frames()
	_hop_frame += 1
	var t: float = clampf(float(_hop_frame) / float(total), 0.0, 1.0)
	var want := _hop_from.lerp(_hop_to, t)
	var before := global_position
	velocity = (want - global_position) * float(TdConst.FPS)
	move_and_slide()
	# برخورد با دیوار جهش را همان‌جا متوقف می‌کند (TOPDOWN_SPEC §۳)
	if get_slide_collision_count() > 0 and global_position.distance_to(before) < 0.2:
		_land()
		return
	if _hop_frame >= total:
		_land()


func _land() -> void:
	state = State.MOVE
	velocity = Vector2.ZERO
	_hop_frame = 0
	landed.emit(global_position)
	_check_ground()


func _tick_dash() -> void:
	_dash_frames_left -= 1
	velocity = _dash_dir * TdConst.DASH_SPEED
	move_and_slide()
	if _dash_frames_left <= 0:
		state = State.MOVE
		velocity = Vector2.ZERO
	_check_ground()


func _tick_dead() -> void:
	velocity = Vector2.ZERO
	_dead_frames -= 1
	if _dead_frames <= 0:
		_respawn()


## ورودی خام. زیرکلاس‌ها بازنویسی‌اش می‌کنند (بازیکن، همراه، روبات).
func _input_dir() -> Vector2:
	return Vector2.ZERO


func start_hop(dir: Vector2) -> bool:
	if state != State.MOVE:
		return false
	var d := TdConst.snap8(dir)
	if d == Vector2.ZERO:
		d = facing
	facing = d
	_hop_from = global_position
	_hop_to = global_position + d * TdConst.HOP_DISTANCE
	_hop_frame = 0
	state = State.HOP
	hop_started.emit(_hop_from, _hop_to)
	return true


func start_dash(dir: Vector2) -> bool:
	if state != State.MOVE or _dash_cooldown > 0:
		return false
	var d := TdConst.snap8(dir)
	if d == Vector2.ZERO:
		d = facing
	_dash_dir = d
	facing = d
	_dash_frames_left = TdConst.dash_frames()
	_dash_cooldown = TdConst.frames(TdConst.DASH_COOLDOWN)
	state = State.DASH
	return true


func foot_position() -> Vector2:
	return global_position + Vector2(0, TdConst.FOOT_OFFSET_Y)


## در میانهٔ جهش پا با چاله و خار برخورد نمی‌کند (از رویشان رد می‌شود).
func _check_ground() -> void:
	if state == State.HOP or state == State.DEAD or room == null:
		return
	if room.has_method("is_deadly_at") and room.is_deadly_at(foot_position()):
		die()
	# در اتاق چالش، افتادن بیرون از مرز هم مرگ است (سند ۰۹ §۲ب)
	elif movement == Movement.SIDE and room.has_method("below_bounds") \
			and room.below_bounds(foot_position()):
		die()


func die() -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	deaths += 1
	velocity = Vector2.ZERO
	_dead_frames = TdConst.respawn_frames()
	if _visual:
		_visual.visible = false
	if _shadow:
		_shadow.visible = false
	died.emit()


func _respawn() -> void:
	global_position = spawn_point
	velocity = Vector2.ZERO
	state = State.MOVE
	_hop_frame = 0
	if _visual:
		_visual.visible = true
		_visual.position.y = 0.0
	if _shadow:
		_shadow.visible = true
	respawned.emit()
