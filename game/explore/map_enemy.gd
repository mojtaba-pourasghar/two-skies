## دشمن دیدنی روی نقشه — M4-پ (سند ۰۹ §۲: «نبرد تصادفی نیست. دشمن روی
## نقشه … برخورد = نبرد»)
##
## فقط ظاهر و برد برخورد است؛ خود نبرد در `BattleScene` است و تصمیم شروعش
## با `RoomGame`. گشت‌زنی و مخروط دید (حمله از پشت، پنهان‌کاری) کار M5 است.
##
## ایستاده ولی نه مجسمه (سند ۱۳ بند ۵): دو فریم به تناوب و یک نوسان ریز.
class_name MapEnemy
extends Node2D

const ASSETS := "res://assets/"
const FRAME_S: float = 0.35
const BOB_PX: float = 2.0
const DEFAULT_HEIGHT: float = 72.0

var enemy_id: String = ""
var encounter: String = ""
var radius: float = 56.0
var missing: Array[String] = []

var _sprites: Array[Sprite2D] = []
var _frames: Array[Texture2D] = []
var _t: float = 0.0


func setup(e: Dictionary) -> void:
	enemy_id = String(e.get("id", ""))
	encounter = String(e.get("encounter", ""))
	radius = float(e.get("radius", 56.0))
	name = "Enemy_%s" % enemy_id
	var at: Array = e.get("at", [0, 0])
	position = Vector2(float(at[0]), float(at[1]))
	for key in ["art", "art_alt"]:
		var rel := String(e.get(key, ""))
		if rel == "":
			continue
		# AssetPath، نه مسیر خام: دشمن روی نقشه هم ممکن است WebP باشد
		var t: Texture2D = AssetPath.texture(rel)
		if t != null:
			_frames.append(t)
		else:
			missing.append(rel)
	var count := maxi(1, int(e.get("count", 1)))
	# اندازه بر حسب **قد روی صفحه**، نه ضریب: تصویرهای تحویلی بوم‌های
	# متفاوت دارند (پهپاد ۳۱۳ پیکسل، نگهبان ۸۲) و ضریب ثابت یکی را غول و
	# دیگری را کوتوله می‌کرد. قد شخصیت‌ها ~۸۸ است (CLAUDE.md قانون ۳).
	var sc := 1.0
	if not _frames.is_empty():
		sc = float(e.get("height", DEFAULT_HEIGHT)) / float(_frames[0].get_height())
	# سایه زیر پا، مثل یاران (سند ۰۴)
	for i in count:
		var off := Vector2((float(i) - float(count - 1) * 0.5) * 54.0, float(i % 2) * 10.0)
		var shadow := Polygon2D.new()
		shadow.color = Color(0, 0, 0, 0.33)
		var pts := PackedVector2Array()
		for k in 12:
			var a := TAU * float(k) / 12.0
			pts.append(off + Vector2(cos(a) * 26.0, sin(a) * 9.0))
		shadow.polygon = pts
		add_child(shadow)
		var s := Sprite2D.new()
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.centered = true
		s.scale = Vector2(sc, sc)
		if not _frames.is_empty():
			s.texture = _frames[0]
			s.position = off - Vector2(0, float(s.texture.get_height()) * sc * 0.5 - 4.0)
		s.flip_h = i % 2 == 1
		add_child(s)
		_sprites.append(s)
	# فاز تصادفی: دو دشمن کنار هم نباید هم‌گام نفس بکشند
	_t = randf() * 3.0


func _process(delta: float) -> void:
	_t += delta
	for i in _sprites.size():
		var s := _sprites[i]
		if _frames.size() > 1:
			s.texture = _frames[(int(_t / FRAME_S) + i) % _frames.size()]
		s.offset.y = sin(_t * 2.2 + float(i)) * BOB_PX


## پای بازیگر در برد برخورد است؟ برد بیضی است (عرض ۲ به ۱)، چون در نمای
## سه‌چهارم عمق صفحه فشرده‌تر از پهنا دیده می‌شود.
func touches(foot: Vector2) -> bool:
	var d := foot - position
	return Vector2(d.x, d.y * 2.0).length() <= radius
