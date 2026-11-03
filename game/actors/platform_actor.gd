## PlatformActor — فیزیک و ماشین حالت مشترک (docs/02_godot_spec.md §۳ و §۴)
##
## ایلارا «همان فیزیک کایرو با ثابت‌های خودش» است (§۵)، پس هر دو از این کلاس می‌آیند
## و فقط ثابت‌ها و منبع ورودی‌شان تفاوت دارد.
##
## تکرارپذیری: همهٔ تایمرها شمارندهٔ فریم فیزیک (int) هستند، نه ثانیهٔ انباشته.
## معیار پذیرش سند ۰۵ می‌خواهد ده بار اجرای یکسان ورودی‌ها نتیجهٔ یکسان بدهد و
## بازپخش ایلارا هم روی همین تضمین سوار است.
class_name PlatformActor
extends CharacterBody2D

enum State { IDLE, RUN, JUMP, FALL, WALL_SLIDE, DASH, HACK, GRAPPLE, DEAD, CUTSCENE }

signal state_changed(from: State, to: State)
signal died
signal respawn_ready
signal landed(hard: bool)
signal turned(facing: int)

## سرعت عمودی که فرود را «سخت» می‌کند (لرزش و گرد و غبار)
const HARD_LAND_VY: float = 260.0

@export var actor_name: String = "actor"
@export var can_wall_jump: bool = false
@export var can_dash: bool = false

## مرز پایین اتاق بر حسب پیکسل. پایین‌تر از این = مرگ (§۴ و §۷:
## «خروج از پایین اتاق مرگ است»). مرحله هنگام ساخت اتاق مقدارش را می‌نشاند؛
## مقدار منفی یعنی بی‌مرز (مثلاً در اتاق آزمایش).
var fall_limit_y: float = -1.0

var state: State = State.IDLE
var facing: int = 1
var frame: int = 0

## ثابت‌های این بازیگر — زیرکلاس پر می‌کند تا ایلارا اعداد خودش را داشته باشد
var run_speed: float = 120.0
var jump_velocity: float = -306.0

var _coyote_frames: int = 0
var _jump_buffer_frames: int = 0
var _wall_lock_frames: int = 0
var _dash_frames: int = 0
var _dash_cd_frames: int = 0
var _dash_charges: int = 0
var _respawn_frames: int = 0
var _jump_held: bool = false
var _was_on_floor: bool = false
var _stuck_frames: int = 0
var _last_x: float = 0.0

## ورودی این فریم: {"x": float, "jump": bool, "jump_held": bool, "action": bool}
var input := {"x": 0.0, "jump": false, "jump_held": false, "action": false}


func _ready() -> void:
	_sync_constants()
	_dash_charges = KairoConst.DASH_CHARGES
	_last_x = global_position.x


## زیرکلاس ثابت‌های خودش را اینجا می‌نشاند.
func _sync_constants() -> void:
	run_speed = KairoConst.RUN_SPEED
	jump_velocity = KairoConst.JUMP_VELOCITY


## زیرکلاس ورودی این فریم را برمی‌گرداند (زنده یا بازپخش‌شده).
func _gather_input() -> Dictionary:
	return {"x": 0.0, "jump": false, "jump_held": false, "action": false}


func _physics_process(delta: float) -> void:
	frame += 1

	if state == State.DEAD:
		_respawn_frames -= 1
		if _respawn_frames <= 0:
			# پس از RESPAWN_TIME بازیگر دوباره قابل کنترل می‌شود؛ جای شروع دوباره را
			# مرحله تعیین می‌کند و با گوش دادن به respawn_ready موقعیت را می‌نشاند.
			_set_state(State.IDLE)
			respawn_ready.emit()
		return

	if state == State.CUTSCENE:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# خروج از پایین اتاق مرگ است (§۴ جدول گذارها، §۷). بدون این سنجه بازیگر
	# در چاه‌های طراحی‌شده تا بی‌نهایت سقوط می‌کند.
	if fall_limit_y > 0.0 and global_position.y > fall_limit_y:
		die()
		return

	input = _gather_input()

	_tick_timers()
	_update_facing()

	match state:
		State.DASH:
			_process_dash(delta)
		State.HACK:
			_process_hack(delta)
		_:
			_process_normal(delta)

	_detect_stuck()


func _tick_timers() -> void:
	if _wall_lock_frames > 0:
		_wall_lock_frames -= 1
	if _dash_cd_frames > 0:
		_dash_cd_frames -= 1

	# بافر پرش: ورودی پرش ۰٫۱۲ ثانیه جلوتر ثبت می‌شود (§۲)
	if input["jump"]:
		_jump_buffer_frames = _f(KairoConst.JUMP_BUFFER)
	elif _jump_buffer_frames > 0:
		_jump_buffer_frames -= 1

	# رها کردن پرش در هوا ارتفاع را کم می‌کند — پرش متغیر (§۲)
	if _jump_held and not input["jump_held"] and velocity.y < 0.0:
		velocity.y *= KairoConst.JUMP_CUT
	_jump_held = input["jump_held"]


func _process_normal(delta: float) -> void:
	var on_floor := is_on_floor()

	if on_floor:
		_coyote_frames = _f(KairoConst.COYOTE_TIME)
		_dash_charges = KairoConst.DASH_CHARGES

	if on_floor and not _was_on_floor:
		var hard := velocity.y >= HARD_LAND_VY
		landed.emit(hard)
	_was_on_floor = on_floor

	_apply_horizontal(delta, on_floor)
	_apply_gravity(delta)

	var wall_dir := _wall_direction()
	var sliding := (
		not on_floor
		and wall_dir != 0
		and signf(input["x"]) == float(wall_dir)
		and velocity.y > 0.0
	)

	if sliding:
		velocity.y = minf(velocity.y, KairoConst.WALL_SLIDE_MAX)
		_set_state(State.WALL_SLIDE)
		# دیوار هم دش را شارژ می‌کند (§۳)
		_dash_charges = KairoConst.DASH_CHARGES

	# پرش: روی زمین یا در پنجرهٔ coyote
	if _jump_buffer_frames > 0:
		if on_floor or _coyote_frames > 0:
			_do_jump()
		elif sliding and can_wall_jump:
			_do_wall_jump(wall_dir)

	# دش: از هر حالت هوایی، اگر ابزار باز است و شارژ دارد (§۴)
	if input["action"] and can_dash and _dash_cd_frames <= 0 and _dash_charges > 0:
		_start_dash()
		return

	move_and_slide()
	_update_normal_state(on_floor, sliding)

	# پنجرهٔ coyote در پایان فریم کم می‌شود تا پرش در آخرین فریم پنجره هم بگیرد.
	if not on_floor and _coyote_frames > 0:
		_coyote_frames -= 1


func _apply_horizontal(delta: float, on_floor: bool) -> void:
	if _wall_lock_frames > 0:
		# قفل کنترل افقی پس از پرش دیواری (§۳)
		return
	var target: float = float(input["x"]) * run_speed
	var accel: float
	if on_floor:
		accel = KairoConst.GROUND_ACCEL if absf(target) > 0.01 else KairoConst.GROUND_DECEL
		if is_on_slippery_floor():
			accel *= KairoConst.SLIPPERY_ACCEL_MULT
	else:
		accel = KairoConst.AIR_ACCEL if absf(target) > 0.01 else KairoConst.AIR_DECEL
	velocity.x = move_toward(velocity.x, target, accel * delta)


func _apply_gravity(delta: float) -> void:
	var g: float = KairoConst.GRAVITY
	if velocity.y > 0.0:
		g *= KairoConst.FALL_GRAVITY_MULT
	velocity.y = minf(velocity.y + g * delta, KairoConst.MAX_FALL)


func _do_jump() -> void:
	velocity.y = jump_velocity
	_jump_buffer_frames = 0
	_coyote_frames = 0
	_set_state(State.JUMP)
	Audio.play_sfx("%s_jump" % actor_name)


func _do_wall_jump(wall_dir: int) -> void:
	velocity = Vector2(-wall_dir * KairoConst.WALL_JUMP_VEL.x, KairoConst.WALL_JUMP_VEL.y)
	_wall_lock_frames = _f(KairoConst.WALL_JUMP_LOCK)
	_jump_buffer_frames = 0
	facing = -wall_dir
	turned.emit(facing)
	_set_state(State.JUMP)
	Audio.play_sfx("%s_wall_jump" % actor_name)


func _start_dash() -> void:
	_dash_frames = _f(KairoConst.DASH_TIME)
	_dash_cd_frames = _f(KairoConst.DASH_COOLDOWN)
	_dash_charges -= 1
	velocity = Vector2(facing * KairoConst.DASH_SPEED, 0.0)
	_set_state(State.DASH)
	Audio.play_sfx("%s_dash" % actor_name)
	EventBus.tool_used.emit("dash")


func _process_dash(_delta: float) -> void:
	# گرانش در دش صفر است (§۴)
	velocity = Vector2(facing * KairoConst.DASH_SPEED, 0.0)
	move_and_slide()
	_dash_frames -= 1
	if _dash_frames <= 0:
		_set_state(State.FALL)


## نگه‌داشتن action برای هک: کایرو در این مدت ثابت است (§۶).
## خود منطق هک در tools/hack_module.gd است؛ اینجا فقط بی‌حرکتی تضمین می‌شود.
func _process_hack(_delta: float) -> void:
	velocity = Vector2.ZERO
	move_and_slide()


func _update_normal_state(on_floor: bool, sliding: bool) -> void:
	if sliding:
		return
	if not on_floor:
		_set_state(State.FALL if velocity.y >= 0.0 else State.JUMP)
	elif absf(velocity.x) < 5.0 and absf(input["x"]) < 0.01:
		_set_state(State.IDLE)
	else:
		_set_state(State.RUN)


func _update_facing() -> void:
	if _wall_lock_frames > 0:
		return
	var x: float = float(input["x"])
	if absf(x) > 0.01:
		var f := 1 if x > 0.0 else -1
		if f != facing:
			facing = f
			turned.emit(facing)


func _wall_direction() -> int:
	if not is_on_wall():
		return 0
	var n := get_wall_normal()
	if absf(n.x) < 0.5:
		return 0
	return -1 if n.x > 0.0 else 1


## زمین‌های لغزنده با ضریب ۰٫۳ برای شتاب (§۳) — کاشی لغزنده در فصل ۱ نداریم،
## ولی قرارداد از اول هست تا فصل‌های بعد کد عوض نشود.
func is_on_slippery_floor() -> bool:
	return false


## گیر کردن: برای teleport ایلارا لازم است (§۵)
func _detect_stuck() -> void:
	if absf(global_position.x - _last_x) < 0.5:
		_stuck_frames += 1
	else:
		_stuck_frames = 0
		_last_x = global_position.x


func stuck_seconds() -> float:
	return float(_stuck_frames) / 60.0


## مرگ فوری است و بدون انیمیشن طولانی (§۳)
func die() -> void:
	if state == State.DEAD:
		return
	velocity = Vector2.ZERO
	_set_state(State.DEAD)
	_respawn_frames = _f(KairoConst.RESPAWN_TIME)
	# ورودی بافرشده پس از شروع دوباره پاک می‌شود (§۴)
	_jump_buffer_frames = 0
	_coyote_frames = 0
	_jump_held = false
	Audio.play_sfx("%s_death" % actor_name)
	if Settings.haptics_enabled:
		Input.vibrate_handheld(40)
	died.emit()
	EventBus.player_died.emit(actor_name)


func enter_cutscene() -> void:
	_set_state(State.CUTSCENE)


func exit_cutscene() -> void:
	_set_state(State.IDLE)


func reset_to(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	frame = 0
	_coyote_frames = 0
	_jump_buffer_frames = 0
	_wall_lock_frames = 0
	_dash_frames = 0
	_dash_cd_frames = 0
	_dash_charges = KairoConst.DASH_CHARGES
	_respawn_frames = 0
	_jump_held = false
	_stuck_frames = 0
	_last_x = pos.x
	_was_on_floor = false
	facing = 1
	_set_state(State.IDLE)


func _set_state(to: State) -> void:
	if to == state:
		return
	var from := state
	state = to
	state_changed.emit(from, to)


## ثانیه → تعداد فریم فیزیک
func _f(seconds: float) -> int:
	return int(round(seconds * float(Engine.physics_ticks_per_second)))
