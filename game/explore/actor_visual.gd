## ظاهر شخصیت در نمای سه‌چهارم (T15)
##
## اسپرایت را از `assets/<who>/home/` می‌گیرد: فریم‌های انیمیشن از
## `anims.json` و حالت‌های ایستا از فایل‌های `idle_*`.
##
## بوم ۱۲۸×۱۲۸ است و خط پا روی y=124 (BUILD_BRIEF §۶)، پس اسپرایت طوری
## نشانده می‌شود که **پا** روی جای بازیگر بیفتد، نه مرکز بوم. بدون این،
## شخصیت یک‌ونیم کاشی بالاتر از جایی که واقعاً ایستاده دیده می‌شود.
class_name ActorVisual
extends Node2D

const CANVAS: int = 128
const FOOT_Y: int = 124
## سند ۰۴: فریم‌ریت انیمیشن شخصیت ۱۲ فریم بر ثانیه.
const ANIM_FPS: float = 12.0

## تنفس ایستاده (سند ۱۳ بند ۵). شخصیتی که ایستاده و **هیچ** حرکتی ندارد
## مجسمه دیده می‌شود، حتی اگر همهٔ پس‌زمینه زنده باشد.
## آهسته و ریز: ۰٫۴ هرتز، یک پیکسل. بیشتر از این «تکان» می‌شود نه نفس.
const BREATH_HZ: float = 0.4
const BREATH_PX: float = 1.0
## سایه زیر پا با جهش کوچک و کم‌رنگ می‌شود — بازیکن ارتفاع را می‌بیند.
const SHADOW_MIN_SCALE: float = 0.62

var who: String = "kairo"
var missing: Array[String] = []

var _sprite: Sprite2D
var _shadow: Node2D
var _frames: Dictionary = {}
var _current: String = ""
var _frame: int = 0
var _timer: float = 0.0
var _breath_t: float = 0.0
var _sprite_base_y: float = 0.0
var _base := "res://assets/%s/home/"


func setup(actor_name: String) -> void:
	who = actor_name
	_base = "res://assets/%s/home/" % who

	# سایهٔ بیضی زیر پا (سند ۰۴)
	_shadow = Node2D.new()
	_shadow.name = "Shadow"
	add_child(_shadow)
	var ellipse := Polygon2D.new()
	ellipse.color = Color(0, 0, 0, 0.35)
	var pts := PackedVector2Array()
	for i in 12:
		var a := TAU * float(i) / 12.0
		pts.append(Vector2(cos(a) * 14.0, sin(a) * 6.0))
	ellipse.polygon = pts
	_shadow.add_child(ellipse)

	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.centered = false
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# پا روی مبدأ: بوم را بالا و چپ می‌بریم
	_sprite.position = Vector2(-CANVAS * 0.5, -FOOT_Y)
	_sprite_base_y = _sprite.position.y
	add_child(_sprite)
	# فاز تصادفی: کایرو و ایلارا نباید مثل دو ساعت با هم نفس بکشند
	_breath_t = randf() * 10.0

	_load_anims()
	play("idle_down")


func _load_anims() -> void:
	var p := _base + "anims.json"
	if not FileAccess.file_exists(p):
		missing.append(p)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(p))
	if parsed is Dictionary:
		_frames = parsed


func _texture(path: String) -> Texture2D:
	# شخصیت‌ها بی‌اتلاف و PNG می‌مانند، ولی از AssetPath می‌گذرند تا اگر
	# روزی سیاست فشرده‌سازی عوض شد اینجا نشکند (D-ART-56).
	var found := AssetPath.find(path)
	if found != "":
		return load(found)
	if not ResourceLoader.exists(path):
		if path not in missing:
			missing.append(path)
		return null
	return load(path)


## یک انیمیشن یا حالت ایستا را می‌گذارد.
func play(anim: String) -> void:
	if anim == _current:
		return
	_current = anim
	_frame = 0
	_timer = 0.0
	_apply()


func _apply() -> void:
	var tex: Texture2D = null
	if _frames.has(_current):
		var list: Array = _frames[_current]
		if not list.is_empty():
			var rel := String(list[_frame % list.size()])
			tex = _texture(_base + rel)
	if tex == null:
		tex = _texture(_base + _current + ".png")
	if tex == null:
		# بازگشت امن: ایستادهٔ رو به پایین؛ هنر ناقص بازی را نمی‌شکند
		tex = _texture(_base + "idle_down.png")
	if tex != null:
		_sprite.texture = tex


func _process(delta: float) -> void:
	_tick_breath(delta)
	if not _frames.has(_current):
		return
	_timer += delta
	var step := 1.0 / ANIM_FPS
	while _timer >= step:
		_timer -= step
		_frame += 1
		_apply()


## نفس فقط وقتی می‌آید که شخصیت **واقعاً ایستاده** است. روی راه رفتن
## سوار نمی‌شود، وگرنه با فریم‌های راه رفتن می‌جنگد و لرزش می‌دهد.
func _tick_breath(delta: float) -> void:
	_breath_t += delta
	if _sprite == null:
		return
	if not _current.begins_with("idle"):
		_sprite.position.y = _sprite_base_y
		return
	var rise: float = BREATH_PX * 0.5 * (1.0 + sin(_breath_t * TAU * BREATH_HZ))
	# به **بالا** گرد می‌شود: نیم‌پیکسل روی پیکسل‌آرت لبه را تار می‌کند
	_sprite.position.y = _sprite_base_y + round(-rise)


## سایهٔ پویا: با جهش کوچک و کم‌رنگ می‌شود و با دش کمی کشیده. ثابت ماندنش
## در جهش باعث می‌شد ارتفاع پرش روی صفحه خوانده نشود.
func _tick_shadow(actor: TdActor) -> void:
	if _shadow == null:
		return
	var lift: float = absf(actor.visual_lift())
	var k: float = clampf(lift / maxf(1.0, TdConst.HOP_ARC_PX), 0.0, 1.0)
	var sc: float = lerpf(1.0, SHADOW_MIN_SCALE, k)
	_shadow.scale = Vector2(sc, sc)
	_shadow.modulate.a = lerpf(1.0, 0.55, k)


## از روی جهت و حالت بازیگر، انیمیشن درست را می‌چیند.
func update_from(actor: TdActor) -> void:
	_tick_shadow(actor)
	var moving := actor.velocity.length() > 8.0
	var row := TdConst.facing_row(actor.facing)
	var dir: String = ["down", "up", "left"][row]
	# «راست = آینه» (BUILD_BRIEF §۶): فریم چپ را برمی‌گردانیم
	_sprite.flip_h = row == 2 and actor.facing.x > 0.0
	if _sprite.flip_h:
		_sprite.position.x = CANVAS * 0.5
	else:
		_sprite.position.x = -CANVAS * 0.5

	match actor.state:
		TdActor.State.HOP:
			play("hop")
		TdActor.State.DASH:
			play("dash_%s" % dir)
		TdActor.State.DEAD:
			play("death")
		_:
			play(("walk_%s" % dir) if moving else ("idle_%s" % _idle_dir(row)))


func _idle_dir(row: int) -> String:
	var names: Array[String] = ["down", "up", "side"]
	return names[row]


func shadow() -> Node2D:
	return _shadow
