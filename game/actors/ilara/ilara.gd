## ایلارا — همراه کایرو در فصل ۱ (docs/02_godot_spec.md §۵، «قانون همراهی» سند ۰۱)
##
## یک CharacterBody2D مستقل با همان فیزیک کایرو ولی ثابت‌های خودش:
## RUN_SPEED ۱۰۵، JUMP_VELOCITY −۲۹۰، بدون دش و بدون پرش دیواری (در فصل ۱).
##
## دنبال کردن: ورودی‌های ثبت‌شدهٔ کایرو را با تأخیر ۴۸ فریم (۰٫۸ ثانیه) بازپخش می‌کند.
## بازیکن مستقیم او را کنترل نمی‌کند. تأخیر بر حسب **فریم** است نه ثانیه، تا بازپخش
## کاملاً تکرارپذیر باشد (معیار پذیرش سند ۰۵).
##
## ایلارا خودش خطر را تشخیص نمی‌دهد و از لبه نمی‌پرد مگر مسیر کایرو را بازپخش کند (§۵).
class_name Ilara
extends PlatformActor

enum Mode { FOLLOW, STAY }

signal teleported
signal mode_changed(mode: Mode)

## تأخیر دنبال کردن: ۰٫۸ ثانیه = ۴۸ فریم در ۶۰ تیک (§۵)
const FOLLOW_DELAY_FRAMES: int = 48
## اگر فاصلهٔ افقی از این بیشتر شود، کنار کایرو ظاهر می‌شود (§۵)
const MAX_H_DISTANCE_TILES: float = 12.0
## اگر این مدت بدون پیشرفت گیر کند، کنار کایرو ظاهر می‌شود (§۵)
const STUCK_SECONDS: float = 2.0
## جعبهٔ آسیب ایلارا ۱۰×۱۴ و ۱ جان (§۵)
const HURTBOX := Vector2(10, 14)

var mode: Mode = Mode.FOLLOW
var kairo: Kairo = null

var _stay_icon: Label
var _replay := {"x": 0.0, "jump": false, "jump_held": false, "action": false}


func _ready() -> void:
	actor_name = "ilara"
	# فصل ۱: ایلارا نه دش دارد نه پرش دیواری (§۵)
	can_wall_jump = false
	can_dash = false
	super()
	add_to_group("ilara")
	collision_layer = Layers.ILARA
	collision_mask = Layers.GROUND
	_build_stay_icon()


func _sync_constants() -> void:
	run_speed = KairoConst.ILARA_RUN_SPEED
	jump_velocity = KairoConst.ILARA_JUMP_VELOCITY


func _build_stay_icon() -> void:
	_stay_icon = Label.new()
	_stay_icon.text = "⏸"
	_stay_icon.add_theme_font_size_override("font_size", 10)
	_stay_icon.position = Vector2(-5, -24)
	_stay_icon.visible = false
	add_child(_stay_icon)


## ورودی ایلارا از رکورد ۴۸ فریم قبلِ کایرو ساخته می‌شود.
##
## §۵ می‌گوید «موقعیت کایرو در هر فریم در یک صف ذخیره می‌شود؛ ایلارا با تأخیر
## ۰٫۸ ثانیه همان **مسیر** و همان **ورودی‌های پرش** را بازپخش می‌کند».
## پس جهت افقی از اختلاف با موقعیت ثبت‌شده می‌آید، نه از ورودی خام کایرو
## (DECISIONS.md: D-013). دلیلش این است که سرعت ایلارا ۱۰۵ است و کایرو ۱۲۰:
## با بازپخش خام ورودی، او هر فریم کمی عقب می‌افتد، انحراف جمع می‌شود و در
## پرش‌های تنگ به چاله می‌افتد — که طبق قانون همراهی یعنی شکست مرحله.
## با بسته شدن به موقعیت، روی رد پای کایرو می‌ماند و انحراف خودش را جبران می‌کند.
func _gather_input() -> Dictionary:
	var idle := {"x": 0.0, "jump": false, "jump_held": false, "action": false}
	if mode == Mode.STAY or kairo == null:
		return idle
	var rec = kairo.history_at(FOLLOW_DELAY_FRAMES)
	if rec == null:
		# صف هنوز پر نشده (ابتدای اتاق): ایلارا می‌ایستد
		return idle

	var target: Vector2 = rec["pos"]
	var dx: float = target.x - global_position.x
	# ناحیهٔ بی‌اثر نیم کاشی، تا کنار کایرو نلرزد
	var x_in := 0.0
	if absf(dx) > float(KairoConst.TILE) * 0.5:
		x_in = clampf(dx / float(KairoConst.TILE), -1.0, 1.0)
		x_in = signf(x_in)

	var jump: bool = bool(rec["jump"])
	var jump_held: bool = bool(rec["jump_held"])

	# اگر از عقب‌افتادن، پرشِ ثبت‌شده را از دست داده باشد: وقتی روی زمین است و
	# هدف بیش از سه‌چهارم کاشی بالاتر و افقاً نزدیک است، خودش می‌پرد.
	# این «تشخیص خطر» نیست (که §۵ منع می‌کند)، فقط جبران تأخیر روی همان مسیر است.
	if not jump and is_on_floor():
		if target.y < global_position.y - float(KairoConst.TILE) * 0.75 				and absf(dx) < float(KairoConst.TILE) * 2.0:
			jump = true
			jump_held = true

	return {"x": x_in, "jump": jump, "jump_held": jump_held, "action": false}


func _physics_process(delta: float) -> void:
	super(delta)
	if mode == Mode.FOLLOW and kairo != null and state != State.DEAD:
		_check_rescue()


## دو شرط §۵ برای ظاهر شدن کنار کایرو: فاصلهٔ افقی بیش از ۱۲ کاشی، یا گیر کردن ۲ ثانیه‌ای.
func _check_rescue() -> void:
	var dx := absf(global_position.x - kairo.global_position.x)
	if dx > MAX_H_DISTANCE_TILES * float(KairoConst.TILE):
		teleport_to_kairo()
		return
	# «بدون پیشرفت» فقط وقتی معنی دارد که کایرو در حرکت باشد؛ وگرنه ایستادن
	# هر دو نفر به‌غلط گیر کردن شمرده می‌شود.
	if stuck_seconds() >= STUCK_SECONDS and absf(kairo.velocity.x) > 5.0:
		teleport_to_kairo()


## ظاهر شدن کنار کایرو با افکت ذره (§۵)
func teleport_to_kairo() -> void:
	if kairo == null:
		return
	global_position = kairo.global_position + Vector2(-float(KairoConst.TILE), 0.0)
	velocity = Vector2.ZERO
	_reset_stuck()
	teleported.emit()
	Audio.play_sfx("ilara_teleport")


func _reset_stuck() -> void:
	_stuck_frames = 0
	_last_x = global_position.x


## دستور «بمان» — نگه‌داشتن دکمهٔ همراه ۰٫۳ ثانیه (§۵).
## در حالت بمان سپر محافظ ندارد، و فقط در جای امن معنی دارد (سند ۰۱).
func command_stay() -> void:
	if mode == Mode.STAY:
		return
	mode = Mode.STAY
	_stay_icon.visible = true
	velocity.x = 0.0
	mode_changed.emit(mode)
	EventBus.companion_command.emit("stay")


## دستور «بیا» — یک ضربه (§۵)
func command_come() -> void:
	if mode == Mode.FOLLOW:
		return
	mode = Mode.FOLLOW
	_stay_icon.visible = false
	_reset_stuck()
	mode_changed.emit(mode)
	EventBus.companion_command.emit("come")


func reset_to(pos: Vector2) -> void:
	super(pos)
	mode = Mode.FOLLOW
	if _stay_icon != null:
		_stay_icon.visible = false
