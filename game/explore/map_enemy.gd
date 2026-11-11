## دشمن دیدنی روی نقشه — M4-پ (سند ۰۹ §۲: «نبرد تصادفی نیست. دشمن روی
## نقشه … برخورد = نبرد»)
##
## ظاهر، برد برخورد، **گشت و مخروط دید** (M5-ت، سند ۰۹ §۲ و بند ۶ §۱۱).
## خود نبرد در `BattleScene` است و تصمیم شروعش با `RoomGame`.
##
## چهار حالت دارد:
##
##   PATROL  روی نقطه‌های `patrol` می‌رود و سر هر کدام `pause` می‌ایستد
##   ALERT   تازه دیده — علامت «!» بالای سرش، ۰٫۴ ثانیه بی‌حرکت
##   CHASE   مستقیم دنبال بازیکن
##   RETURN  بازیکن را `forget` ثانیه ندیده؛ به نقطهٔ گشتش برمی‌گردد
##
## دیدن سه شرط دارد — فاصله، زاویه، و **خط دید**. خط دید دو چیز را
## می‌شکند: چندضلعی `blocked` اتاق، و پنهان شدن پشت occluder (همان
## سنجهٔ پوشش گام ۵۵). پس «پنهان‌کاری پشت اشیا» که سند خواسته، واقعاً
## همان occluderهای گام ۵۵ است، نه یک سازوکار دوم.
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

enum State { PATROL, ALERT, CHASE, RETURN }

## زاویهٔ مخروط **کل** است، نه نیم‌زاویه؛ برد از پای خود دشمن.
const DEF_RANGE: float = 220.0
const DEF_ANGLE: float = 70.0
const DEF_FORGET: float = 2.0
const DEF_SPEED: float = 56.0
const DEF_PAUSE: float = 1.0
## «!» چند ثانیه سر جایش می‌ماند پیش از دویدن — بازیکن باید فرصت
## واکنش داشته باشد، وگرنه دیدن یعنی نبرد و پنهان‌کاری بی‌معنی است.
const ALERT_S: float = 0.45
const CHASE_MULT: float = 1.45
## نمای سه‌چهارم عمق را فشرده می‌کند؛ همان ۲ به ۱ برد برخورد.
const DEPTH: float = 2.0

var state: State = State.PATROL
var facing: Vector2 = Vector2.RIGHT
var patrol: Array[Vector2] = []
var speed: float = DEF_SPEED
var pause_s: float = DEF_PAUSE
var see_range: float = DEF_RANGE
var see_angle: float = DEF_ANGLE
var forget_s: float = DEF_FORGET
## از وقتی ساخته شد تا حالا بازیکن را دیده؟ حملهٔ از پشت فقط وقتی
## امتیاز دارد که دشمن هنوز خبر ندارد.
var alerted: bool = false

var _home: Vector2 = Vector2.ZERO
var _leg: int = 0
var _wait: float = 0.0
var _unseen: float = 0.0
var _state_t: float = 0.0
var _cone: Node2D = null
var _cone_poly: Polygon2D = null
var _cone_edge: Line2D = null
var _bang: Node2D = null


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
	_setup_patrol(e)


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


## ------------------------------------------------------------------
## گشت و مخروط دید (M5-ت)
## ------------------------------------------------------------------

func _setup_patrol(e: Dictionary) -> void:
	_home = position
	for raw in e.get("patrol", []):
		var p: Array = raw
		if p.size() == 2:
			patrol.append(Vector2(float(p[0]), float(p[1])))
	speed = float(e.get("speed", DEF_SPEED))
	pause_s = float(e.get("pause", DEF_PAUSE))
	var v: Dictionary = e.get("vision", {})
	see_range = float(v.get("range", DEF_RANGE))
	see_angle = float(v.get("angle", DEF_ANGLE))
	forget_s = float(v.get("forget", DEF_FORGET))
	if patrol.size() >= 2:
		facing = (patrol[1] - patrol[0]).normalized()
		position = patrol[0]
		_home = patrol[0]
		_leg = 1
	_build_cone()
	_build_bang()
	_paint_cone()


## مخروط دید **دیده می‌شود**: بدون آن بازیکن نمی‌فهمد چرا گرفتار شد.
## چندضلعی بادبزنی با ۱۲ پره، نیمه‌شفاف، در عمقِ فشردهٔ همان نما.
func _build_cone() -> void:
	if see_range <= 0.0:
		return
	# **ترتیب مهم است:** مخروط در فضای «تخت» ساخته و چرخانده می‌شود و
	# بعد گرهٔ بیرونی عمق را فشرده می‌کند. اگر اول فشرده و بعد چرخانده
	# شود، بادبزن در جهت‌های مورب کج و باریک درمی‌آید — همان چیزی که
	# در نگاه اول درست به نظر می‌رسد و در بازی غلط دیده می‌شود.
	_cone = Node2D.new()
	_cone.name = "Cone"
	_cone.z_index = -1          # زیر خود دشمن، روی کف
	_cone.scale = Vector2(1.0, 1.0 / DEPTH)
	add_child(_cone)
	_cone_poly = Polygon2D.new()
	var pts := PackedVector2Array()
	pts.append(Vector2.ZERO)
	var half := deg_to_rad(see_angle) * 0.5
	for i in 13:
		var a := -half + deg_to_rad(see_angle) * float(i) / 12.0
		pts.append(Vector2(cos(a), sin(a)) * see_range)
	_cone_poly.polygon = pts
	_cone_poly.color = Color(1.0, 0.86, 0.45, 0.16)
	_cone.add_child(_cone_poly)
	# لبهٔ نازک: روی کف روشنِ میدان، فقط پُرکردنِ نیمه‌شفاف دیده نمی‌شد
	# (در فریم ضبط گم بود). خط لبه مخروط را روی هر زمینه‌ای خوانا می‌کند.
	_cone_edge = Line2D.new()
	_cone_edge.width = 2.0
	_cone_edge.closed = true
	_cone_edge.points = pts
	_cone_edge.default_color = Color(1.0, 0.86, 0.45, 0.30)
	_cone_poly.add_child(_cone_edge)


## علامت «!» — سه خط کوتاه، بدون هنر تازه.
func _build_bang() -> void:
	_bang = Node2D.new()
	_bang.name = "Bang"
	_bang.visible = false
	var bar := Polygon2D.new()
	bar.polygon = PackedVector2Array([
		Vector2(-3, -34), Vector2(3, -34), Vector2(2, -14), Vector2(-2, -14)])
	bar.color = Color(1.0, 0.86, 0.3, 0.95)
	var dot := Polygon2D.new()
	dot.polygon = PackedVector2Array([
		Vector2(-3, -10), Vector2(3, -10), Vector2(3, -5), Vector2(-3, -5)])
	dot.color = bar.color
	_bang.add_child(bar)
	_bang.add_child(dot)
	_bang.position = Vector2(0, -float(DEFAULT_HEIGHT))
	add_child(_bang)


## آیا این نقطه در مخروط دید است؟ سه شرط، به ترتیب ارزانی:
## فاصله، زاویه، خط دید.
func sees(foot: Vector2, room: Node = null) -> bool:
	if see_range <= 0.0:
		return false
	var d := foot - position
	var flat := Vector2(d.x, d.y * DEPTH)
	if flat.length() > see_range:
		return false
	if flat.length() > 1.0:
		var ang := rad_to_deg(flat.normalized().angle_to(
			Vector2(facing.x, facing.y * DEPTH).normalized()))
		if absf(ang) > see_angle * 0.5:
			return false
	return _line_of_sight(foot, room)


## دیوار و occluder جلوی دید را می‌گیرند. نمونه‌برداری روی پاره‌خط، چون
## چندضلعی‌های اتاق محدب نیستند و راه‌حل تحلیلی ندارند.
func _line_of_sight(foot: Vector2, room: Node) -> bool:
	if room == null or not is_instance_valid(room):
		return true
	var data: Dictionary = room.get("data")
	var steps := int(clampf(position.distance_to(foot) / 12.0, 2.0, 24.0))
	for i in range(1, steps):
		var p := position.lerp(foot, float(i) / float(steps))
		for raw in data.get("blocked", []):
			if Geometry2D.is_point_in_polygon(p, RoomData.to_polygon(raw)):
				return false
	# پنهان پشت occluder: همان سنجهٔ پوشش گام ۵۵، همان آستانهٔ سیلوئت
	if room.has_method("coverage_at") \
			and float(room.coverage_at(foot)) >= ActorVisual.GHOST_ON:
		return false
	return true


## بازیکن **پشت** دشمن است؟ (حملهٔ از پشت، سند ۰۹ §۲)
func is_behind(foot: Vector2) -> bool:
	var d := foot - position
	var flat := Vector2(d.x, d.y * DEPTH)
	if flat.length() < 1.0:
		return false
	var ang := rad_to_deg(flat.normalized().angle_to(
		Vector2(facing.x, facing.y * DEPTH).normalized()))
	return absf(ang) > 90.0


## یک گام گشت/تعقیب. `RoomGame` هر فریم فیزیک صدایش می‌زند، چون جای
## بازیکن و ماسک اتاق را فقط او دارد.
func tick(delta: float, foot: Vector2, room: Node) -> void:
	_state_t += delta
	var seen := sees(foot, room)
	if seen:
		_unseen = 0.0
		if state == State.PATROL or state == State.RETURN:
			_set_state(State.ALERT)
			alerted = true
	else:
		_unseen += delta
		if state == State.CHASE and _unseen >= forget_s:
			_set_state(State.RETURN)

	match state:
		State.PATROL:
			_walk_patrol(delta, room)
		State.ALERT:
			if _state_t >= ALERT_S:
				_set_state(State.CHASE)
		State.CHASE:
			_move_toward(foot, speed * CHASE_MULT, delta, room)
		State.RETURN:
			var goal: Vector2 = patrol[_leg] if not patrol.is_empty() else _home
			if _move_toward(goal, speed, delta, room):
				_set_state(State.PATROL)
				alerted = false
	_paint_cone()


func _set_state(s: State) -> void:
	state = s
	_state_t = 0.0
	if _bang != null:
		_bang.visible = s == State.ALERT


func _walk_patrol(delta: float, room: Node) -> void:
	if patrol.size() < 2:
		return
	if _wait > 0.0:
		_wait -= delta
		return
	if _move_toward(patrol[_leg], speed, delta, room):
		_leg = (_leg + 1) % patrol.size()
		_wait = pause_s


## به یک نقطه می‌رود و می‌گوید رسید یا نه. از ماسک بیرون نمی‌زند: دشمنی
## که توی دیوار برود، همان باگی است که در اتاق‌ها بارها دیدیم.
func _move_toward(goal: Vector2, sp: float, delta: float, room: Node) -> bool:
	var to := goal - position
	if to.length() <= maxf(2.0, sp * delta):
		position = goal
		return true
	var dir := to.normalized()
	facing = dir
	var step := position + dir * sp * delta
	if room != null and is_instance_valid(room):
		var data: Dictionary = room.get("data")
		if not RoomData.point_walkable(data, step):
			# روی یک محور بلغز، مثل خود بازیکن
			var sx := position + Vector2(dir.x, 0) * sp * delta
			var sy := position + Vector2(0, dir.y) * sp * delta
			if RoomData.point_walkable(data, sx):
				step = sx
			elif RoomData.point_walkable(data, sy):
				step = sy
			else:
				return false
	position = step
	return false


func _paint_cone() -> void:
	if _cone_poly == null:
		return
	_cone_poly.rotation = Vector2(facing.x, facing.y * DEPTH).angle()
	match state:
		State.ALERT:
			_cone_poly.color = Color(1.0, 0.55, 0.25, 0.24)
		State.CHASE:
			_cone_poly.color = Color(1.0, 0.3, 0.25, 0.22)
		_:
			_cone_poly.color = Color(1.0, 0.86, 0.45, 0.16)
	if _cone_edge != null:
		_cone_edge.default_color = Color(_cone_poly.color.r, _cone_poly.color.g,
			_cone_poly.color.b, _cone_poly.color.a + 0.16)
