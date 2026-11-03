## نقطهٔ خروج و چک‌پوینت — docs/02_godot_spec.md §۸ (نماد X)
##
## ماشهٔ Area2D. در مرحله‌های دونفره با رسیدن **هر دو** شخصیت فعال می‌شود (§۸ و
## «پایان مرحله: هر دو باید به خروجی برسند» سند ۰۱).
class_name ExitPoint
extends Area2D

signal reached
signal occupancy_changed(kairo_in: bool, ilara_in: bool)

## اگر true، این نقطه چک‌پوینت است نه خروج (مرحلهٔ ۷ فصل‌ها)
@export var is_checkpoint: bool = false
## اگر false، فقط رسیدن کایرو کافی است (مرحله‌های بدون همراه)
@export var needs_both: bool = true

## پنجرهٔ «هر دو رسیدند». §۸ می‌گوید «با رسیدن هر دو شخصیت فعال می‌شود» و سند ۰۱
## «هر دو باید به خروجی برسند» — هیچ‌کدام نمی‌گوید **هم‌زمان**.
##
## و هم‌زمانی با طراحی ناسازگار است: §۵ ایلارا را به‌عمد ۰٫۸ ثانیه عقب‌تر نگه
## می‌دارد، و نقطهٔ خروج در L1R4 و L2R4 سه کاشی بالای کف کشیده شده، پس فقط در
## اوج پرش قابل لمس است. با شرط حضور هم‌زمان، مرحله تنها وقتی تمام می‌شد که
## پرش هر دو تصادفاً در یک فریم بیفتد (DECISIONS.md: D-054).
const BOTH_WINDOW: float = 2.0

var _kairo_in: bool = false
var _ilara_in: bool = false
var _kairo_seen: float = -1.0
var _ilara_seen: float = -1.0
var _fired: bool = false


func _ready() -> void:
	collision_layer = Layers.TRIGGER
	collision_mask = Layers.ACTORS
	var shape := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(16, 24)
	shape.shape = r
	add_child(shape)

	# فریم ۰ خروج (سبز موفقیت)، فریم ۱ نقطهٔ ذخیره (فیروزهٔ نکسا)
	add_child(Art.sprite(Art.EXIT, 2, 1 if is_checkpoint else 0))

	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(body: Node2D) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if body is Kairo:
		_kairo_in = true
		_kairo_seen = now
	elif body.is_in_group("ilara"):
		_ilara_in = true
		_ilara_seen = now
	else:
		return
	occupancy_changed.emit(_kairo_in, _ilara_in)
	_try_fire()


func _on_exit(body: Node2D) -> void:
	if body is Kairo:
		_kairo_in = false
	elif body.is_in_group("ilara"):
		_ilara_in = false
	else:
		return
	occupancy_changed.emit(_kairo_in, _ilara_in)


func _try_fire() -> void:
	if _fired:
		return
	if needs_both:
		if not _both_arrived():
			return
	elif not _kairo_in:
		return
	_fired = true
	reached.emit()


## هر دو شخصیت در پنجرهٔ BOTH_WINDOW ثانیه‌ای رسیده‌اند؟
## یکی از دو نفر باید همین حالا داخل باشد، تا رسیدنِ کهنه مرحله را تمام نکند.
func _both_arrived() -> bool:
	if _kairo_seen < 0.0 or _ilara_seen < 0.0:
		return false
	if not (_kairo_in or _ilara_in):
		return false
	return absf(_kairo_seen - _ilara_seen) <= BOTH_WINDOW


func reset() -> void:
	_fired = false
	_kairo_in = false
	_ilara_in = false
	_kairo_seen = -1.0
	_ilara_seen = -1.0


func both_present() -> bool:
	return _kairo_in and _ilara_in
