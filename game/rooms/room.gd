## اتاق نقاشی‌شده — لایه‌های صحنه (M1، سند ۱۱ §۱ و سند ۱۲ §۲)
##
## ترتیب لایه‌ها دقیقاً همان چیزی است که سند می‌گوید و **اهمیت دارد**:
##
##   ۰ نقاشی پس‌زمینه      تمام کف و دیوار و سایه و نور در خود تصویر است
##   ۱ ماسک برخورد/خطر     چندضلعی، نامرئی؛ از روی تصویر کشیده شده
##   ۲ پراپ با Y-sort      صندوق، مجسمه، جمع‌شدنی
##   ۳ بازیگران            کایرو و ایلارا، هم‌سطح پراپ‌ها در همان Y-sort
##   ۴ occluder            طاق، ستون، پرده — شخصیت از پشتشان رد می‌شود
##   ۵ نور و ذره (Add)     هالهٔ پنجره، اخگر، گرد
##   ۶ HUD                 جدا، در CanvasLayer
##
## لایهٔ حرکت طبیعت (برگ، پرده، آب) z خودش را دارد: پیش‌فرض ۱، یعنی روی
## نقاشی و زیر پراپ؛ با `"occluder": true` می‌رود به ۴ تا شخصیت از پشتش رد
## شود. قاعدهٔ ۹ CLAUDE.md: اتاق بی‌حرکت «تمام» نیست.
##
## اگر occluder زیر بازیگر بیاید شخصیت روی ستون کشیده می‌شود، و اگر نور زیر
## occluder بیاید هاله پشت پرده گیر می‌کند. هر دو را دیده‌ایم.
class_name PaintedRoom
extends Node2D

signal built(room_id: String)
signal door_reached(door: Dictionary)
signal hazard_entered(hazard: Dictionary)

const ASSETS := "res://assets/"

var data: Dictionary = {}
var missing_art: Array[String] = []

var world: Node2D          ## لایه‌های ۰ تا ۵ که با دوربین حرکت می‌کنند
var actors: Node2D         ## لایهٔ ۳ — بیرون می‌نشاندش

var _bg: Sprite2D
var _props: Node2D
var _occluders: Node2D
var _light: Node2D
var _mask_debug: Node2D
var _motion: Node2D
var _fx: RoomEffects = null
var _dust_puff: GPUParticles2D = null
var _last_react := Vector2.ZERO
## ضریب نسخهٔ پرجزئیات: ۱ برای ۱۲۸۰×۷۲۰، ۱٫۳۱۲۵ برای hires.
var _bg_scale: float = 1.0
var _cuts: Array[Polygon2D] = []
## پایانه‌های هک‌شدنی و خطرهایی که خاموش شده‌اند (M5-ب)
var hackables: Array[Dictionary] = []
## چک‌پوینت‌های اتاق چالش (M5-ب)
var checkpoints: Array[Dictionary] = []
## اقلام زمینی و صندوق‌ها (M5-ج)
var pickups: Array[Dictionary] = []
var _off_hazards: Dictionary = {}
var _img_occ: Array[Dictionary] = []


func build(room: Dictionary) -> void:
	data = room
	world = Node2D.new()
	world.name = "World"
	# Y-sort روی ریشهٔ دنیا، تا پراپ و بازیگر با هم مرتب شوند
	world.y_sort_enabled = true
	add_child(world)

	_build_background()
	_build_props()
	actors = _layer("Actors", 3)
	actors.y_sort_enabled = true
	_build_enemies()
	_build_hackables()
	_build_checkpoints()
	_build_pickups()
	_build_effects()
	_reapply_offline()
	_build_occluders()
	_build_light()
	_build_dust_puff()
	built.emit(String(room.get("id", "?")))


func _layer(name: String, z: int) -> Node2D:
	var n := Node2D.new()
	n.name = name
	n.z_index = z
	world.add_child(n)
	return n


func _note_missing(path: String) -> void:
	if path not in missing_art:
		missing_art.append(path)


func _load_tex(rel: String) -> Texture2D:
	# از AssetPath می‌گذرد تا پس‌زمینهٔ تبدیل‌شده به WebP هم پیدا شود
	# (D-ART-56): داده `.png` می‌نویسد، دیسک ممکن است `.webp` داشته باشد.
	var tex: Texture2D = AssetPath.texture(rel)
	if tex == null:
		_note_missing(rel)
	return tex


## نسخهٔ پرجزئیات همان اتاق، برای زوم شفاف تا ۱٫۳× (سند ۱۴، D-ART-46).
## مسیرش از `bg` ساخته می‌شود: `rooms/ch1/x_1280x720.png` →
## `rooms/ch1/hires/x_1680x944.png`.
const HIRES_SCALE: float = 1.3125
## بالاتر از این زوم، بدون نسخهٔ پرجزئیات تصویر نرم و تار می‌شود.
const ZOOM_WITHOUT_HIRES: float = 1.12

var _hires: Texture2D = null
var _lowres: Texture2D = null
var _using_hires: bool = false


func has_hires() -> bool:
	return _hires != null


## حد زوم این اتاق: با نسخهٔ پرجزئیات ۱٫۳×، بی آن ۱٫۱۲×.
func max_zoom() -> float:
	return 1.3 if has_hires() else ZOOM_WITHOUT_HIRES


## زوم از حد بی‌هایرز گذشت: تصویر پرجزئیات را بگذار. زیر آن، برگرد —
## نگه داشتن تصویر بزرگ در زوم عادی فقط حافظه می‌خورد.
func use_hires(on: bool) -> void:
	if _bg == null or _hires == null or on == _using_hires:
		return
	_using_hires = on
	_bg.texture = _hires if on else _lowres
	_bg_scale = HIRES_SCALE if on else 1.0
	_bg.scale = Vector2.ONE / _bg_scale
	if _fx != null:
		_fx.set_background(_bg.texture, _bg_scale)
	for c in _cuts:
		c.texture = _bg.texture
		c.texture_offset = Vector2(0, float(c.get_meta("cut_base_y", 0.0))) * _bg_scale
		c.texture_scale = Vector2.ONE * _bg_scale


func _hires_path(bg_rel: String) -> String:
	var dir := bg_rel.get_base_dir()
	var file := bg_rel.get_file()
	# نام نسخهٔ پرجزئیات: همان نام با اندازهٔ ۱۶۸۰×۹۴۴
	var stem := file.replace("_1280x720.png", "")
	if stem == file:
		return ""
	return "%s/hires/%s_1680x944.png" % [dir, stem]


func _build_background() -> void:
	var holder := _layer("Background", 0)
	var tex := _load_tex(String(data.get("bg", "")))
	if tex == null:
		return
	_bg = Sprite2D.new()
	_bg.texture = tex
	_bg.centered = false
	_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	holder.add_child(_bg)
	_lowres = tex
	# مسیر نسخهٔ پرجزئیات: اول فیلد صریح `hires` اتاق، بعد حدس از روی
	# نام `bg`. اتاق‌هایی که تصویرشان در `scenes/` است (R1d، R1e، S2b)
	# نسخهٔ پرجزئیاتشان در `rooms/ch1/hires/` و با **نام دیگری** است،
	# پس حدس از روی مسیر برایشان کار نمی‌کند و بی‌صدا hires نمی‌گرفتند.
	var hp := String(data.get("hires", ""))
	if hp == "":
		hp = _hires_path(String(data.get("bg", "")))
	if hp != "":
		_hires = AssetPath.texture(hp)


func _build_props() -> void:
	_props = _layer("Props", 2)
	_props.y_sort_enabled = true
	for raw in data.get("props", []):
		var p: Dictionary = raw
		var pid := String(p.get("id", ""))
		var rel := String(p.get("img", "explore/props/%s.png" % pid))
		var tex := _load_tex(rel)
		if tex == null:
			continue
		var at: Array = p.get("at", [0, 0])
		var s := Sprite2D.new()
		s.name = "Prop_%s" % pid
		s.texture = tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.centered = false
		# `height` قد روی صفحه است، نه ضریب: هنر تحویلی بوم‌های متفاوت
		# دارد و ضریب ثابت یکی را غول و دیگری را کوتوله می‌کند (همان درس
		# دشمن‌های روی نقشه). نبودنش یعنی اندازهٔ خود تصویر.
		var ph := float(p.get("height", tex.get_height()))
		var psc := ph / float(tex.get_height())
		s.scale = Vector2(psc, psc)
		# پراپ از **پایش** می‌نشیند تا Y-sort درست کار کند
		s.position = Vector2(float(at[0]) - tex.get_width() * psc * 0.5,
			float(at[1]) - ph)
		_props.add_child(s)


## دشمن‌های دیدنی (M4-پ). هم‌لایهٔ بازیگران، تا Y-sort پشت و جلوی
## یاران را درست بچیند. دشمنی که نبردش برده شده دیگر ساخته نمی‌شود.
var enemies: Array[MapEnemy] = []


func _build_enemies() -> void:
	enemies.clear()
	for raw in data.get("enemies", []):
		var e: Dictionary = raw
		if bool(GameState.get_flag("battle_won_%s" % String(e.get("encounter", "")), false)):
			continue
		var m := MapEnemy.new()
		actors.add_child(m)
		m.setup(e)
		# رنگ مخروط دید از نور همین اتاق می‌آید (گام ۵۷)
		m.set_room_light(light_tint())
		for miss in m.missing:
			_note_missing(miss)
		enemies.append(m)


## دشمنی که پای بازیگر به آن خورده، یا null.
func enemy_touching(foot: Vector2) -> MapEnemy:
	for m in enemies:
		if is_instance_valid(m) and m.touches(foot):
			return m
	return null


## یک گام گشت برای همهٔ دشمن‌های اتاق (M5-ت). اتاق صدایش می‌زند، نه خود
## دشمن، چون جای بازیکن و ماسک را اتاق دارد.
func tick_enemies(delta: float, foot: Vector2) -> void:
	for m in enemies:
		if is_instance_valid(m):
			m.tick(delta, foot, self)


## دشمنی که همین حالا بازیکن را می‌بیند، یا null.
func enemy_seeing(foot: Vector2) -> MapEnemy:
	for m in enemies:
		if is_instance_valid(m) and m.sees(foot, self):
			return m
	return null


func remove_enemy(m: MapEnemy) -> void:
	enemies.erase(m)
	if is_instance_valid(m):
		m.queue_free()





## ------------------------------------------------------------------
## اقلام و صندوق (M5-ج، سند ۰۹ §۱۱ بند ۳)
## ------------------------------------------------------------------
##
## دو جور: `kind` معمولی که با رد شدن برداشته می‌شود، و صندوق که
## `needs_action` دارد و باید دکمه زد. هر دو با پرچم در `GameState`
## می‌مانند، پس برگشت به اتاق سکه را دوباره نمی‌رویاند.
func _build_pickups() -> void:
	pickups.clear()
	for raw in data.get("pickups", []):
		var pk: Dictionary = raw
		var pid := String(pk.get("id", ""))
		if bool(GameState.get_flag(pickup_flag(String(data.get("id", "")), pid), false)):
			continue
		var at: Array = pk.get("at", [0, 0])
		var pos := Vector2(float(at[0]), float(at[1]))
		var rel := String(pk.get("img", "icons/%s.png" % String(pk.get("kind", "coin"))))
		var tex := _load_tex(rel)
		var node: Sprite2D = null
		if tex != null:
			node = Sprite2D.new()
			node.name = "Pick_%s" % pid
			node.texture = tex
			node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			node.centered = false
			var h := float(pk.get("height", 30.0))
			var sc := h / float(tex.get_height())
			node.scale = Vector2(sc, sc)
			node.position = pos - Vector2(float(tex.get_width()) * sc * 0.5, h)
			_props.add_child(node)
		pickups.append({
			"id": pid, "at": pos, "node": node,
			"kind": String(pk.get("kind", "coin")),
			"amount": int(pk.get("amount", 1)),
			"radius": float(pk.get("radius", 34.0)),
			"needs_action": bool(pk.get("needs_action", false)),
			"contains": pk.get("contains", {}),
		})


static func pickup_flag(room_id: String, pid: String) -> String:
	return "got_%s_%s" % [room_id, pid]


## قلمی که پا رویش است. `want_action` تعیین می‌کند کدام دسته.
func pickup_at(foot: Vector2, want_action: bool) -> Dictionary:
	for pk in pickups:
		if bool(pk["needs_action"]) != want_action:
			continue
		if foot.distance_to(pk["at"] as Vector2) <= float(pk["radius"]):
			return pk
	return {}


## برداشتن: گره حذف، پرچم ثبت. **چه چیزی اضافه شد** را برمی‌گرداند تا
## رابط بتواند نشانش بدهد.
func take_pickup(pid: String) -> Dictionary:
	for i in pickups.size():
		var pk: Dictionary = pickups[i]
		if String(pk["id"]) != pid:
			continue
		var node = pk["node"]
		if node != null and is_instance_valid(node):
			node.queue_free()
		pickups.remove_at(i)
		GameState.set_flag(pickup_flag(String(data.get("id", "")), pid), true)
		var gained: Dictionary = {}
		if bool(pk["needs_action"]):
			gained = (pk["contains"] as Dictionary).duplicate()
		else:
			gained[String(pk["kind"])] = int(pk["amount"])
		return gained
	return {}

## ------------------------------------------------------------------
## چک‌پوینت اتاق چالش (M5-ب)
## ------------------------------------------------------------------
##
## در اتاق چالش یک تماس = مرگ و شروع دوباره (سند ۰۹ §۱ قاعدهٔ ۱). بی
## چک‌پوینت، هر مرگ در C3 یعنی از اول تالار؛ با ۲۴ خطر، این یعنی رها
## کردن بازی. چک‌پوینت فقط **جای شروع دوباره** را جابه‌جا می‌کند، نه
## چیز دیگری: نه جان پر می‌کند (اتاق چالش جان ندارد) و نه ذخیره است.
func _build_checkpoints() -> void:
	checkpoints.clear()
	for raw in data.get("checkpoints", []):
		var cp: Dictionary = raw
		var at: Array = cp.get("at", [0, 0])
		var pos := Vector2(float(at[0]), float(at[1]))
		var off := _load_tex(String(cp.get("img", "checkpoint_exit/checkpoint_off.png")))
		var on := _load_tex(String(cp.get("img_on", "checkpoint_exit/checkpoint_on.png")))
		var node: Sprite2D = null
		if off != null:
			node = Sprite2D.new()
			node.name = "Cp_%s" % String(cp.get("id", "x"))
			node.texture = off
			node.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			node.centered = false
			var h := float(cp.get("height", 52.0))
			var sc := h / float(off.get_height())
			node.scale = Vector2(sc, sc)
			node.position = pos - Vector2(float(off.get_width()) * sc * 0.5, h)
			var m: Array = cp.get("mod", [])
			if m.size() >= 3:
				node.modulate = Color(float(m[0]), float(m[1]), float(m[2]))
			_props.add_child(node)
		checkpoints.append({
			"id": String(cp.get("id", "")), "at": pos, "node": node,
			"radius": float(cp.get("radius", 52.0)),
			"off": off, "on": on, "lit": false,
		})


## چک‌پوینتی که پا رویش است و هنوز روشن نشده، یا تهی.
func checkpoint_at(foot: Vector2) -> Dictionary:
	for cp in checkpoints:
		if bool(cp["lit"]):
			continue
		if foot.distance_to(cp["at"] as Vector2) <= float(cp["radius"]):
			return cp
	return {}


func light_checkpoint(cid: String) -> void:
	for cp in checkpoints:
		if String(cp["id"]) != cid:
			continue
		cp["lit"] = true
		var node = cp["node"]
		if node != null and is_instance_valid(node) and cp["on"] != null:
			node.texture = cp["on"]

## ------------------------------------------------------------------
## پایانهٔ هک‌شدنی (M5-ب)
## ------------------------------------------------------------------
##
## چرا لازم شد: کوچهٔ لیزری C2 در نقاشی یک **دیوار کامل** از هفت پرتو
## است؛ اندازه‌گیری روی ماسک نشان داد هیچ راه بی‌خطری از شروع به در
## بالا نیست و شکاف‌های بین پرتوها فقط سایهٔ پایه‌هایند (۱۰ تا ۵۰
## پیکسل). پس راه باید از یک **سازوکار** بیاید، نه از دور زدن.
## قاعدهٔ ۸ CLAUDE.md می‌گوید تناقض را به نفع تصویر حل کن: پرتو
## **کشیده می‌ماند** (نقشهٔ افکت هم همین را می‌خواهد: «خطر بصری ثابت
## می‌ماند»)، ولی پس از هک کم‌رنگ و فیروزه‌ای می‌شود و دیگر نمی‌زند.
## تأیید مدیر هنر با REQ-033 خواسته شد.
func _build_hackables() -> void:
	hackables.clear()
	_off_hazards.clear()
	for raw in data.get("hackables", []):
		var hk: Dictionary = raw
		var hid := String(hk.get("id", ""))
		var at: Array = hk.get("at", [0, 0])
		var pos := Vector2(float(at[0]), float(at[1]))
		var done := bool(GameState.get_flag(_hack_flag(hid), false))
		var tex := _load_tex(String(hk.get("img", "hackables/terminal.png")))
		var node: Node2D = null
		if tex != null:
			var s := Sprite2D.new()
			s.name = "Hack_%s" % hid
			s.texture = tex
			s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			s.centered = false
			var h := float(hk.get("height", 64.0))
			var sc := h / float(tex.get_height())
			s.scale = Vector2(sc, sc)
			# `at` پای پایانه است، نه گوشه‌اش
			s.position = pos - Vector2(float(tex.get_width()) * sc * 0.5, h)
			var m: Array = hk.get("mod", [])
			if m.size() >= 3:
				s.modulate = Color(float(m[0]), float(m[1]), float(m[2]))
			_props.add_child(s)
			node = s
		var rec := {
			"id": hid, "at": pos, "node": node,
			"radius": float(hk.get("radius", 64.0)),
			"disables": hk.get("disables", []),
			"done": done,
		}
		hackables.append(rec)
		if done:
			_apply_hack(rec)


static func _hack_flag(hid: String) -> String:
	return "hacked_%s" % hid


## نزدیک‌ترین پایانهٔ هک‌نشده در برد، یا تهی.
func hackable_at(foot: Vector2) -> Dictionary:
	var best: Dictionary = {}
	var bd := INF
	for hk in hackables:
		if bool(hk["done"]):
			continue
		var d: float = foot.distance_to(hk["at"] as Vector2)
		if d <= float(hk["radius"]) and d < bd:
			bd = d
			best = hk
	return best


func hack(hid: String) -> bool:
	for hk in hackables:
		if String(hk["id"]) != hid or bool(hk["done"]):
			continue
		hk["done"] = true
		GameState.set_flag(_hack_flag(hid), true)
		_apply_hack(hk)
		return true
	return false


## پایانه‌هایی که از ذخیره «هک‌شده» آمده‌اند، هنگام ساخت اتاق پیش از
## لایهٔ افکت پردازش می‌شوند و آن موقع `_fx` هنوز نیست. اگر اینجا دوباره
## اعمال نشود، خطر خاموش است ولی **پرتو همچنان قرمز کشیده می‌شود** —
## بازیکن جلوی پرتوی قرمزی می‌ایستد که نمی‌زند. در عکس گام ۵۷ دیده شد.
func _reapply_offline() -> void:
	if _fx == null:
		return
	var ids: Array = []
	for hk in hackables:
		if bool(hk["done"]):
			ids.append_array(hk["disables"])
	if not ids.is_empty():
		_fx.set_offline(ids)


func _apply_hack(hk: Dictionary) -> void:
	for raw in hk["disables"]:
		_off_hazards[String(raw)] = true
	var node = hk["node"]
	if node != null and is_instance_valid(node):
		node.modulate = Color(0.45, 1.0, 0.9)
	if _fx != null:
		_fx.set_offline(hk["disables"])

## افکت‌های اتاق از نقشهٔ تصویر (سند ۱۴، D-ART-46).
##
## جای سیستم قبلی `ambient` را گرفت. آن سیستم لایه‌های سراسری می‌ساخت که
## به هیچ چیزِ تصویر وصل نبودند — همان چیزی که کاربر در ضبط دید و گفت
## «افکت‌ها غیرطبیعی‌اند». حالا افکتی ساخته می‌شود که در نقشه باشد و به
## منبع دیدنی‌اش وصل باشد.
func _build_effects() -> void:
	_motion = _layer("Motion", 1)
	var map_name := String(data.get("fx_map", String(data.get("id", ""))))
	_fx = RoomEffects.new()
	_fx.name = "Effects"
	_fx.room_id = String(data.get("id", ""))
	if not _fx.load_map(map_name):
		_fx.free()
		_fx = null
		warnings_note("نقشهٔ افکت «%s» نیست؛ اتاق ساکن می‌ماند." % map_name)
		return
	_motion.add_child(_fx)
	_fx.build(_bg.texture if _bg != null else null, _bg_scale)
	for rel in _fx.missing:
		_note_missing(rel)


func _rect_of(d: Dictionary) -> Rect2:
	var r: Array = d.get("rect", [])
	if r.size() != 4:
		return Rect2()
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


## occluder دو شکل دارد:
##
##   `img`  — تصویر جدا (طاق، ستون، پرده). همیشه **روی** بازیگران است،
##            چون چیزهایی‌اند که بازیکن هرگز جلوشان نمی‌ایستد.
##   `cut`  — چندضلعی روی **خود نقاشی** (مبل، بوفه، میز). اینجا بازیکن
##            هم می‌تواند جلو باشد هم پشت، پس Y-sort تصمیم می‌گیرد.
##
## مدیر هنر گفت هنر occluder جدا نمی‌آید (گام ۵۴، REQ-010)، پس شکل دوم
## راهی است که مبلمان بتواند شخصیت را بپوشاند بدون یک تکه هنر تازه:
## همان پیکسل‌های نقاشی دوباره، ولی بریده و در Y-sort.
func _build_occluders() -> void:
	_occluders = _layer("Occluders", 4)
	for raw in data.get("occluders", []):
		var o: Dictionary = raw
		if (o.get("cut", []) as Array).size() >= 6:
			_add_cut_occluder(o)
			continue
		_add_img_occluder(o)


## occluder تصویری — یک تکه هنر مستقل روی اتاق.
##
## دو حالت دارد و تفاوتشان **کجا کشیده می‌شود** است:
##
##   بی `base_y` → لایهٔ ۴. همیشه روی بازیگر. برای چیزی که بازیکن هرگز
##                  جلویش نمی‌ایستد: لبهٔ قاب، شاخهٔ آویزان، کابل.
##   با `base_y` → لایهٔ بازیگران با Y-sort. برای چیزی که **روی کف
##                  می‌ایستد** (قفسه، ستون): اگر بازیکن جلوتر از پای آن
##                  باشد باید جلویش دیده شود، نه پشتش. بدون این، ستون
##                  وسط اتاق بازیکنِ جلویش را هم می‌پوشاند و غلط است.
##
## `mod` رنگ را با نقاشی هماهنگ می‌کند (دستهٔ ۱۶ سردتر و پرکنتراست‌تر از
## اتاق‌های ناحیهٔ ۱ است) و `shadow` سایهٔ تماس با کف می‌دهد؛ بی سایه،
## هر تکه روی کف **شناور** دیده می‌شود. هر دو تصمیم کاربر در گام ۵۵‌اند.
func _add_img_occluder(o: Dictionary) -> void:
	var tex := _load_tex(String(o.get("img", "")))
	if tex == null:
		return
	var at: Array = o.get("at", [0, 0])
	var pos := Vector2(float(at[0]), float(at[1]))
	var base_y := float(o.get("base_y", 0.0))
	var s := Sprite2D.new()
	s.name = "Occ_%s" % String(o.get("id", "x"))
	s.texture = tex
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = false
	s.flip_h = bool(o.get("flip", false))
	var m: Array = o.get("mod", [])
	if m.size() >= 3:
		s.modulate = Color(float(m[0]), float(m[1]), float(m[2]),
				float(m[3]) if m.size() > 3 else 1.0)

	var shadow: Node2D = null
	var sh: Array = o.get("shadow", [])
	if sh.size() >= 3:
		shadow = _contact_shadow(Vector2(float(sh[0]), float(sh[1])),
				float(sh[2]), float(sh[3]) if sh.size() > 3 else 0.35)

	if base_y > 0.0:
		# گره روی `base_y` می‌نشیند و تصویر به همان اندازه بالا می‌رود —
		# همان ترفند بریده‌ها، چون Y-sort گودو از موقعیت گره می‌چیند.
		var holder := Node2D.new()
		holder.name = "OccStand_%s" % String(o.get("id", "x"))
		holder.position = Vector2(0, base_y)
		s.position = pos - Vector2(0, base_y)
		if shadow != null:
			shadow.position -= Vector2(0, base_y)
			holder.add_child(shadow)
		holder.add_child(s)
		s.set_meta("occ_base_y", base_y)
		actors.add_child(holder)
	else:
		s.position = pos
		if shadow != null:
			_occluders.add_child(shadow)
		_occluders.add_child(s)

	# برای سنجش پوشش، آلفای خود تصویر لازم است. یک بار خوانده و
	# نگه داشته می‌شود؛ `get_image` هر فریم گران است.
	_img_occ.append({
		"rect": Rect2(pos, tex.get_size()),
		"img": tex.get_image(),
		"flip": s.flip_h,
		"base_y": base_y,
	})


## بیضی تیرهٔ نرم زیر پای یک شیء ایستاده.
func _contact_shadow(center: Vector2, rx: float, alpha: float) -> Node2D:
	var n := Polygon2D.new()
	n.name = "Shadow"
	var pts := PackedVector2Array()
	var ry := rx * 0.36
	for i in range(20):
		var a := TAU * float(i) / 20.0
		pts.append(center + Vector2(cos(a) * rx, sin(a) * ry))
	n.polygon = pts
	n.color = Color(0.0, 0.0, 0.0, alpha)
	return n


## بریده‌ای از نقاشی که در Y-sort با بازیگران می‌نشیند.
##
## گره روی `base_y` نشانده می‌شود و نقاط چندضلعی به همان اندازه بالا
## می‌روند: Y-sort گودو از **موقعیت گره** می‌چیند، نه از شکلش. پس اگر
## گره روی (۰,۰) بماند، مبل همیشه ته صف می‌رود و هیچ‌وقت کسی را
## نمی‌پوشاند.
func _add_cut_occluder(o: Dictionary) -> void:
	if _bg == null or _bg.texture == null:
		return
	var flat: Array = o["cut"]
	var base_y := float(o.get("base_y", 0.0))
	if base_y <= 0.0:
		# نبودش یعنی پایین‌ترین نقطهٔ خود بریده
		var i := 1
		while i < flat.size():
			base_y = maxf(base_y, float(flat[i]))
			i += 2

	var poly := PackedVector2Array()
	var j := 0
	while j + 1 < flat.size():
		poly.append(Vector2(float(flat[j]), float(flat[j + 1]) - base_y))
		j += 2

	var n := Polygon2D.new()
	n.name = "Cut_%s" % String(o.get("id", "x"))
	n.polygon = poly
	n.position = Vector2(0, base_y)
	n.texture = _bg.texture
	# بافت باید یک‌به‌یک روی مختصات اتاق بیفتد: جابه‌جایی به اندازهٔ
	# همان `base_y` که از نقاط کم شد، و مقیاس به اندازهٔ نسخهٔ تصویر.
	n.texture_offset = Vector2(0, base_y) * _bg_scale
	n.texture_scale = Vector2.ONE * _bg_scale
	n.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	n.set_meta("cut_base_y", base_y)
	# **در لایهٔ بازیگران**، نه لایهٔ occluder: آنجا z بالاتر است و همیشه
	# می‌پوشاند. اینجا Y-sort تصمیم می‌گیرد.
	actors.add_child(n)
	_cuts.append(n)


## لایهٔ نور ثابت. **سوسو اینجا نیست**: نور زنده از نقشهٔ افکت می‌آید
## (`flicker_light` و `glow_pulse`)، چون آنجا به منبع دیدنی‌اش وصل است.
## اینجا فقط overlay ثابتی می‌ماند که اتاق بخواهد.
func _build_light() -> void:
	_light = _layer("Light", 5)
	for raw in (data.get("light", {}) as Dictionary).get("overlays", []):
		var o: Dictionary = raw
		var tex := _load_tex(String(o.get("img", "")))
		if tex == null:
			continue
		var at: Array = o.get("at", [0, 0])
		var s := Sprite2D.new()
		s.texture = tex
		s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		s.centered = false
		s.position = Vector2(float(at[0]), float(at[1]))
		s.modulate = Color(1, 1, 1, float(o.get("alpha", 1.0)))
		s.material = _additive()
		_light.add_child(s)


func warnings_note(msg: String) -> void:
	push_warning("اتاق «%s»: %s" % [String(data.get("id", "?")), msg])


## گردی که از پای بازیکن بلند می‌شود. یک گره است که دنبال پا می‌رود، نه
## یکی به‌ازای هر قدم: ساختن و دور انداختن گره در حلقهٔ فیزیک گران است.
##
## در نقشهٔ افکت نیست چون افکت صحنه نیست، **واکنش** است (سند ۱۳ بند ۷).
func _build_dust_puff() -> void:
	var tex := _load_tex("overlays/particles/dust_1.png")
	if tex == null:
		return
	var ps := GPUParticles2D.new()
	ps.name = "DustPuff"
	ps.amount = 6
	ps.lifetime = 0.7
	ps.texture = tex
	ps.local_coords = false
	ps.emitting = false
	ps.z_index = 3
	var m := ParticleProcessMaterial.new()
	m.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	m.emission_sphere_radius = 6.0
	m.direction = Vector3(0, -1, 0)
	m.spread = 55.0
	m.gravity = Vector3(0, 26, 0)
	m.initial_velocity_min = 6.0
	m.initial_velocity_max = 18.0
	m.scale_min = 0.05
	m.scale_max = 0.11
	m.color = Color(0.86, 0.82, 0.72, 0.30)
	ps.process_material = m
	ps.material = _additive()
	ps.add_to_group(RoomEffects.GROUP)
	_light.add_child(ps)
	_dust_puff = ps


func _additive() -> CanvasItemMaterial:
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	return m


## شعاعی که عبور بازیکن در آن حس می‌شود، و چقدر طول می‌کشد تا بخوابد.
const REACT_PX: float = 86.0
const REACT_PUSH: float = 5.0
const REACT_DECAY: float = 0.90
## زیر این سرعت، رد شدن «عبور» نیست و گرد بلند نمی‌کند.
const REACT_SPEED: float = 40.0


## محیط به عبور بازیکن واکنش نشان می‌دهد (سند ۱۳ بند ۷): برگ و پرده‌ای
## که نزدیکش رد می‌شود تکان بیشتری می‌خورد، و از پا گرد بلند می‌شود.
##
## بدون این، صحنه زنده هست ولی **بی‌اعتنا**؛ بازیکن حس نمی‌کند در آن
## اتاق حضور دارد.
func react_to(foot: Vector2, speed: float) -> void:
	for n in (_fx.sway_nodes() if _fx != null else []):
		var mat := n.material as ShaderMaterial
		if mat == null:
			continue
		var rect: Rect2 = n.get_meta("react_rect", Rect2())
		var raw_push = mat.get_shader_parameter("push")
		var push: float = float(raw_push) if raw_push != null else 0.0
		var near: float = _distance_to_rect(foot, rect)
		if near < REACT_PX and speed > REACT_SPEED:
			# نزدیک‌تر، تکان بیشتر — نه روشن/خاموش
			push = maxf(push, REACT_PUSH * (1.0 - near / REACT_PX))
		push *= REACT_DECAY
		mat.set_shader_parameter("push", push)

	if _dust_puff != null:
		var moved := foot.distance_to(_last_react)
		_dust_puff.position = foot
		# فقط وقتی واقعاً راه می‌رود، نه وقتی ایستاده می‌لرزد
		_dust_puff.emitting = speed > REACT_SPEED and moved > 0.5
	_last_react = foot


static func _distance_to_rect(p: Vector2, r: Rect2) -> float:
	if r.size == Vector2.ZERO:
		return INF
	var dx: float = maxf(maxf(r.position.x - p.x, 0.0), p.x - r.end.x)
	var dy: float = maxf(maxf(r.position.y - p.y, 0.0), p.y - r.end.y)
	return sqrt(dx * dx + dy * dy)


## بدنهٔ دیداری بازیگر، برای سنجیدن پوشش. از پا به بالا.
const BODY_W: float = 36.0
const BODY_H: float = 88.0
## شبکهٔ نمونه‌برداری: ۵×۸ یعنی ۴۰ نقطه — برای آستانهٔ ۶۰٪ بس است و
## محاسبهٔ دقیق مساحت اشتراک چندضلعی‌ها را لازم ندارد.
const COVER_COLS: int = 5
const COVER_ROWS: int = 8


## چه کسری از بدنهٔ بازیگری که پایش اینجاست، زیر یک `cut` می‌افتد؟
##
## فقط بریده‌هایی شمرده می‌شوند که بازیگر **پشتشان** است (`base_y` از
## پای او جلوتر). بریده‌ای که بازیگر جلویش ایستاده او را نمی‌پوشاند،
## پس شمردنش یعنی سیلوئت بی‌جا روشن شود.
func coverage_at(foot: Vector2) -> float:
	if _cuts.is_empty() and _img_occ.is_empty():
		return 0.0
	var hit := 0
	var total := 0
	for cx in COVER_COLS:
		for cy in COVER_ROWS:
			var p := Vector2(
				foot.x - BODY_W * 0.5 + BODY_W * (float(cx) + 0.5) / float(COVER_COLS),
				foot.y - BODY_H * (float(cy) + 0.5) / float(COVER_ROWS))
			total += 1
			if _covered(p, foot):
				hit += 1
	return float(hit) / float(maxi(1, total))


## آیا این نقطه زیر occluderی است که بازیگر **پشتش** است؟
func _covered(p: Vector2, foot: Vector2) -> bool:
	for c in _cuts:
		if float(c.get_meta("cut_base_y", 0.0)) <= foot.y:
			continue
		# نقاط چندضلعی نسبت به `base_y` بالا برده شده‌اند
		if Geometry2D.is_point_in_polygon(p - c.position, c.polygon):
			return true
	# occluder تصویری همیشه روی بازیگر است، پس شرط `base_y` ندارد؛
	# ولی فقط جایی می‌پوشاند که **خود تصویر** آنجا مات باشد.
	for o in _img_occ:
		var r: Rect2 = o["rect"]
		if not r.has_point(p):
			continue
		# ورق ایستاده مثل بریده در Y-sort است: فقط کسی را می‌پوشاند که
		# پایش عقب‌تر از پای خودش باشد.
		var oby := float(o.get("base_y", 0.0))
		if oby > 0.0 and oby <= foot.y:
			continue
		var img: Image = o["img"]
		if img == null:
			continue
		var q := Vector2i(p - r.position)
		if bool(o.get("flip", false)):
			q.x = img.get_width() - 1 - q.x
		if q.x < 0 or q.y < 0 or q.x >= img.get_width() or q.y >= img.get_height():
			continue
		if img.get_pixelv(q).a > 0.5:
			return true
	return false


## رنگ نور اتاق، برای گذار در به در: پردهٔ گذار به‌جای سیاه خالص، به رنگ
## نور اتاق می‌رود، پس عبور از در **تغییر نور** دیده می‌شود نه خاموشی.
func light_tint() -> Color:
	var t: Array = (data.get("light", {}) as Dictionary).get("tint", [])
	if t.size() != 3:
		return Color(0, 0, 0)
	return Color(float(t[0]), float(t[1]), float(t[2]))


## نواحی زوم اتاق، به شکلی که دوربین می‌خواهد (D-ART-42).
func zoom_zones() -> Array:
	return RoomData.zoom_zones(data)


## بودجهٔ زندگی این اتاق — از **گره‌های ساخته‌شده** شمرده می‌شود، نه از
## روی JSON. اگر هنر یک افکت نرسیده باشد، نقشه می‌گوید سه منبع دارم و
## صحنه ساکن است؛ اینجا همان چیزی شمرده می‌شود که روی صفحه حرکت می‌کند.
func living_layers() -> Dictionary:
	var motion := 0
	var particles := 0
	var lights := 0
	for n in get_tree().get_nodes_in_group(RoomEffects.GROUP) if is_inside_tree() else []:
		if not is_ancestor_of(n):
			continue
		# گردِ پای بازیکن **منبع محیطی نیست**: واکنش است و تا کسی راه
		# نرود چیزی نمی‌بارد. اگر شمرده شود، اتاق ساکن هم شرط «ذره دارد»
		# را برآورده می‌کند و بودجه بی‌معنا می‌شود.
		if n == _dust_puff:
			continue
		if n is GPUParticles2D or n is CPUParticles2D:
			particles += 1
		elif (n is Sprite2D) and (n as Sprite2D).material is ShaderMaterial \
				and ((n as Sprite2D).material as ShaderMaterial).shader != null \
				and String(((n as Sprite2D).material as ShaderMaterial).shader.resource_path)\
					.ends_with("glow.gdshader"):
			lights += 1
		else:
			motion += 1
	return {
		"motion": motion,
		"particles": particles,
		"variable_light": lights > 0,
		"lights": lights,
		"sources": motion + particles + lights,
	}


## «≥۳ منبع حرکت محیطی همزمان» (سند ۱۳ بند ۱) و نور نبض‌دار و ذره.
const LIVING_MIN_SOURCES: int = 3


func is_living() -> bool:
	var l := living_layers()
	return int(l["sources"]) >= LIVING_MIN_SOURCES \
		and int(l["particles"]) > 0 \
		and bool(l["variable_light"]) \
		and int(l["motion"]) > 0


## اندازهٔ اتاق بر حسب پیکسل — حد دوربین از همین می‌آید.
func bounds() -> Rect2:
	var size: Array = data.get("size", [1280, 720])
	return Rect2(0, 0, float(size[0]), float(size[1]))


func spawn_position() -> Vector2:
	var sp: Array = data.get("spawn", [0, 0])
	return Vector2(float(sp[0]), float(sp[1]))


func is_walkable(p: Vector2) -> bool:
	return RoomData.point_walkable(data, p)


## خطری که **خاموش شده** دیگر نمی‌زند. پایانهٔ هک‌شده همین کار را
## می‌کند، و چون از همین‌جا می‌گذرد، هم بازیگر و هم ربات و هم آزمون
## یک حقیقت را می‌بینند.
func hazard_at(p: Vector2) -> Dictionary:
	var h := RoomData.hazard_at(data, p)
	if not h.is_empty() and _off_hazards.has(String(h.get("id", ""))):
		return {}
	return h


func hazard_is_off(hid: String) -> bool:
	return _off_hazards.has(hid)


func door_at(p: Vector2) -> Dictionary:
	return RoomData.door_at(data, p)


## ماسک را برای بازبینی چشمی نشان می‌دهد — فقط در اسکرین‌شات عیب‌یابی.
func show_mask(on: bool) -> void:
	if _mask_debug != null:
		_mask_debug.queue_free()
		_mask_debug = null
	if not on:
		return
	_mask_debug = _layer("MaskDebug", 6)
	for flat in data.get("walkable", []):
		var poly := Polygon2D.new()
		poly.polygon = RoomData.to_polygon(flat)
		poly.color = Color(0.2, 1.0, 0.4, 0.22)
		_mask_debug.add_child(poly)
	for flat in data.get("blocked", []):
		var poly := Polygon2D.new()
		poly.polygon = RoomData.to_polygon(flat)
		poly.color = Color(0.15, 0.15, 0.2, 0.55)
		_mask_debug.add_child(poly)
	for raw in data.get("hazard", []):
		var h: Dictionary = raw
		var poly := Polygon2D.new()
		poly.polygon = RoomData.to_polygon(h.get("poly", []))
		poly.color = Color(1.0, 0.25, 0.2, 0.30)
		_mask_debug.add_child(poly)
	for raw in data.get("doors", []):
		var d: Dictionary = raw
		var r: Array = d.get("rect", [])
		if r.size() != 4:
			continue
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([
			Vector2(float(r[0]), float(r[1])),
			Vector2(float(r[0]) + float(r[2]), float(r[1])),
			Vector2(float(r[0]) + float(r[2]), float(r[1]) + float(r[3])),
			Vector2(float(r[0]), float(r[1]) + float(r[3]))])
		poly.color = Color(0.3, 0.6, 1.0, 0.30)
		_mask_debug.add_child(poly)
