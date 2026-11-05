## تلهٔ اکتشاف — آسیب جزئی، نه مرگ (T15)
##
## سند ۰۹ §۱ قاعدهٔ ۲: «اکتشاف سه‌چهارمی: بدون مرگ؛ تله = آسیب جزئی (−۱۰٪) +
## بازگشت به کاشی امن». این صریحاً **خلاف** قاعدهٔ قدیمی «تیغه کشنده» است
## (سند ۰۹ §۱۰: «تیغه‌های کشنده → آسیب جزئی + بازگشت»).
##
## بازگشت باید **زیر یک ثانیه** حس شود، وگرنه بازیکن فکر می‌کند بازی گیر کرده.
class_name ExploreTrap
extends Area2D

signal sprung(damage_pct: float, safe_point: Vector2)

const RETURN_TIME: float = 0.35
const FPS: float = 60.0
## پس از بازگشت، چند فریم تله خاموش می‌ماند تا دوباره شلیک نکند.
const COOLDOWN_FRAMES: int = 30

@export var damage_pct: float = 10.0
@export var sequence_id: String = ""

var safe_point := Vector2.ZERO
var _cooldown: int = 0


func _ready() -> void:
	collision_layer = Layers.HAZARD
	collision_mask = Layers.ACTORS
	add_to_group("explore_trap")
	body_entered.connect(_on_body_entered)


func _physics_process(_delta: float) -> void:
	if _cooldown > 0:
		_cooldown -= 1


func _on_body_entered(body: Node2D) -> void:
	if _cooldown > 0:
		return
	if not (body is TdActor):
		return
	# در توالی اسکریپتی بازیگر آسیب‌ناپذیر است (BUILD_BRIEF §۴)
	if not GameMode.death_counts():
		return
	_cooldown = COOLDOWN_FRAMES
	_spring(body as TdActor)


func _spring(actor: TdActor) -> void:
	GameState.damage_percent(damage_pct)
	# بازگشت **فوری** است و انیمیشنش دیداری: جای بازیگر همان فریم عوض
	# می‌شود، وگرنه ممکن است در فریم بعد باز هم داخل تله باشد و حلقه بسازد.
	actor.global_position = safe_point
	actor.velocity = Vector2.ZERO
	sprung.emit(damage_pct, safe_point)
	EventBus.emit_signal("camera_shake_requested", 4.0)
	Audio.play_sfx("trap_hit")
