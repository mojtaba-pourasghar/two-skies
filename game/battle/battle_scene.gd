## صحنهٔ نبرد نوبتی — M4-ب (سند ۰۸ §۴ و §۶، سند ۰۹ §۷ «در نبرد: نوار
## ترتیب بالا، منوی پایین-چپ، حلقهٔ زمان‌بندی روی هدف»)
##
## همه‌چیز در یک CanvasLayer است، پس روی هر اتاقی با هر دوربینی و هر زومی
## درست می‌نشیند و به دوربین زنده کاری ندارد. هیچ عدد بازی اینجا حساب
## نمی‌شود: صحنه فقط فرمان و «فاصلهٔ فشار از لحظهٔ درست» را به `BattleCore`
## می‌دهد و رویدادهایش را نشان می‌دهد (D-ART-50).
##
## زمان صحنه فریم‌محور است (D-007): حلقه و مکث‌ها شمارندهٔ فریم فیزیک‌اند،
## تا نتیجهٔ headless و اجرای واقعی یکی باشد.
class_name BattleScene
extends CanvasLayer

signal finished(outcome: int, encounter_id: String)

const FPS: int = 60
const ASSETS := "res://assets/"
const FONT := "res://assets/fonts/Vazirmatn-NL-Bold.ttf"
## سند ۰۸ §۶: «انتقال به نبرد (گردابی ۰٫۵ ثانیه)»
const INTRO_FRAMES: int = 30
const RESOLVE_FRAMES: int = 32
const TELEGRAPH_FRAMES: int = 22
const BANNER_FRAMES: int = 54
## شکست → شروع دوباره. سقف سند ۰۸ §۱ دو ثانیه است؛ بنر + پرده باید زیرش بماند.
const RESTART_FADE_FRAMES: int = 24

## یاران کنار منو (پایین-چپ، سند ۰۹ §۷) ولی نه رویش؛ دشمن‌ها بالای پنل جان.
const PARTY_AT := {"kairo": Vector2(530, 540), "ilara": Vector2(410, 610)}
const ENEMY_SLOTS := [Vector2(900, 500), Vector2(1090, 450), Vector2(760, 420),
	Vector2(1170, 540)]
## پهپاد فرمانده و کوچک هنوز تصویر ندارند (REQ-030)؛ تا آن موقع پهپاد گشتی
## با مقیاس.
const ENEMY_SCALE := {"commander": 1.4, "drone_small": 0.7}
const PARTY_SCALE: float = 1.35

const C_TEXT := Color(0.96, 0.93, 0.86)
const C_NORMAL := Color(1, 1, 1)
const C_GOOD := Color(1.0, 0.86, 0.35)
const C_PERFECT := Color(0.45, 0.95, 1.0)
const C_HURT := Color(1.0, 0.42, 0.38)
const C_HEAL := Color(0.55, 1.0, 0.55)

enum Phase { INTRO, MENU, TARGET, RING, RESOLVE, TELEGRAPH, DEFENSE, BANNER, RESTART, DONE }

@export var encounter_id: String = "ch1_a2_crawlers"
@export var battle_seed: int = 1
## روبات به‌جای بازیکن، برای آزمون و ضبط: "" خاموش، "skilled" همیشه عالی
## و قطع‌کن، "idle" فقط سپر و بی‌دفاع.
@export var autoplay: String = ""

var core: BattleCore
var phase: Phase = Phase.INTRO
## چند بار شکست و شروع دوباره (برای آزمون و آمار؛ جریمه ندارد)
var retries: int = 0
## فریم‌های آخرین شروع دوباره، از لحظهٔ شکست تا نوبت تازه (آزمون: <۲ث)
var last_restart_frames: int = 0

var _ui: Control
var _stage: Node2D
var _bg: TextureRect
var _fade: ColorRect
var _banner: Label
var _menu_box: VBoxContainer
var _menu_frame: TextureRect
var _strip_labels: Array[Label] = []
var _energy_fill: ColorRect
var _energy_label: Label
var _ring: Sprite2D
var _ring_frames: Array[Texture2D] = []
var _party_nodes: Dictionary = {}
var _enemy_nodes: Dictionary = {}
var _floaters: Array[Dictionary] = []
var _fx: Array[Dictionary] = []

var _wait: int = 0
var _ring_total: int = 0
var _ring_t: int = 0
var _ring_window: int = 0
var _pressed_at: int = -1
var _pending: Dictionary = {}
var _target_list: Array[String] = []
var _target_i: int = 0
var _lose_frame: int = 0
var _frame: int = 0


func _ready() -> void:
	layer = 20
	core = BattleCore.new()
	if not core.load_data() or not core.start(encounter_id, battle_seed, _inventory()):
		push_error("BattleScene: %s" % str(core.errors))
		return
	core.flags = GameState.run.get("flags", {})
	core.assist = Settings.assist_timing
	GameMode.set_context(GameMode.Context.BATTLE)
	_build()
	_refresh()
	_set_phase(Phase.INTRO, INTRO_FRAMES)


## کیف نبرد از ذخیره، اگر هست؛ وگرنه کیف شروع داده.
func _inventory() -> Dictionary:
	var inv: Variant = GameState.data.get("battle_items", {})
	return inv if inv is Dictionary else {}


# ---------- ساختن ----------

func _build() -> void:
	# ترتیب کشیدن: پس‌زمینه ← صحنه (یاران، دشمن، افکت، حلقه) ← رابط.
	# بازیگران Node2D اند؛ اگر بعد از رابط اضافه شوند روی منو کشیده می‌شوند.
	_bg = TextureRect.new()
	_bg.name = "Background"
	add_child(_bg)
	# پدرش CanvasLayer است نه Control، پس لنگر به تنهایی اندازه نمی‌دهد
	_bg.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.texture = _tex("battle_bg/%s_1280x720.png" % String(core.encounter.get("bg", "battle_bg_street")))
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage = Node2D.new()
	_stage.name = "Stage"
	add_child(_stage)

	_ui = Control.new()
	_ui.name = "UI"
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# چیدمان صفحه ثابت و دستی است (منو پایین-چپ، نوار بالا، سند ۰۹ §۷)؛
	# ریشهٔ پروژه RTL است و بی این خط هر `position` آینه می‌شد و منو به
	# راست می‌رفت. متن خود برچسب‌ها جدا RTL می‌ماند.
	_ui.layout_direction = Control.LAYOUT_DIRECTION_LTR
	var theme := Theme.new()
	if ResourceLoader.exists(FONT):
		theme.default_font = load(FONT)
	theme.default_font_size = 22
	_ui.theme = theme
	add_child(_ui)

	for pid in ["kairo", "ilara"]:
		_build_party(pid)
	for u in core.units:
		if u["side"] == "enemy":
			_build_enemy(u)
	_build_strip()
	_build_party_panel()
	_build_menu()

	_ring = Sprite2D.new()
	_ring.name = "TimingRing"
	_ring.visible = false
	_ring.z_index = 10
	for i in 4:
		var t := _tex("battle_fx/skills/timing_ring_%d.png" % i)
		if t != null:
			_ring_frames.append(t)
	_stage.add_child(_ring)

	_banner = _label("", 64, C_TEXT)
	_ui.add_child(_banner)
	_banner.set_anchors_preset(Control.PRESET_CENTER)
	_banner.position = Vector2(340, 250)
	_banner.size = Vector2(600, 110)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.add_theme_color_override("font_outline_color", Color(0.05, 0.06, 0.1))
	_banner.visible = false

	_fade = ColorRect.new()
	_fade.name = "Fade"
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.color = Color(0.03, 0.04, 0.08, 1.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(_fade)


func _build_party(pid: String) -> void:
	var vis := ActorVisual.new()
	vis.name = "Party_%s" % pid
	_stage.add_child(vis)
	vis.setup(pid)
	vis.play("idle_side")
	vis.position = PARTY_AT[pid]
	# اسپرایت پهلو رو به چپ کشیده شده؛ یاران رو به دشمن (راست) می‌ایستند
	vis.scale = Vector2(-PARTY_SCALE, PARTY_SCALE)
	var btn := _target_button("party", pid, PARTY_AT[pid] + Vector2(-50, -150), Vector2(100, 150))
	_party_nodes[pid] = {"vis": vis, "button": btn}


func _build_enemy(u: Dictionary) -> void:
	var id := String(u["id"])
	var kind := String(u["kind"])
	var slot: Vector2 = ENEMY_SLOTS[mini(_enemy_nodes.size(), ENEMY_SLOTS.size() - 1)]
	if _enemy_nodes.size() >= ENEMY_SLOTS.size():
		slot += Vector2(-60.0 * float(_enemy_nodes.size() - ENEMY_SLOTS.size() + 1), 0)
	var sc: float = float(ENEMY_SCALE.get(kind, 1.0))
	var art := String(core.data["enemies"][kind].get("art", kind))
	var spr := Sprite2D.new()
	spr.name = "Enemy_%s" % id
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.texture = _tex("enemies/battle_nexa/%s_idle.png" % art)
	spr.centered = true
	# دشمن رو به یاران (چپ)؛ پا روی جای خانه
	spr.flip_h = true
	spr.scale = Vector2(sc, sc)
	var h := 90.0 * sc
	if spr.texture != null:
		h = float(spr.texture.get_height()) * sc
	spr.position = slot - Vector2(0, h * 0.5)
	_stage.add_child(spr)

	var top := slot - Vector2(0, h + 14)
	var icon := TextureRect.new()
	_ui.add_child(icon)
	icon.size = Vector2(46, 46)
	icon.position = top - Vector2(23, 50)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var left := _label("", 22, C_TEXT)
	_ui.add_child(left)
	left.position = top + Vector2(18, -46)
	left.size = Vector2(40, 30)
	left.add_theme_constant_override("outline_size", 6)
	left.add_theme_color_override("font_outline_color", Color(0, 0, 0))

	var bar_bg := ColorRect.new()
	_ui.add_child(bar_bg)
	bar_bg.color = Color(0.05, 0.05, 0.08, 0.85)
	bar_bg.size = Vector2(96, 9)
	bar_bg.position = slot + Vector2(-48, 10)
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := ColorRect.new()
	bar_bg.add_child(fill)
	fill.color = C_HURT
	fill.size = Vector2(94, 7)
	fill.position = Vector2(1, 1)
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var btn := _target_button("enemy", id, slot + Vector2(-60, -h), Vector2(120, h + 10))
	_enemy_nodes[id] = {"sprite": spr, "icon": icon, "left": left, "bar": bar_bg,
		"fill": fill, "button": btn, "art": art, "slot": slot, "height": h,
		"hurt": 0, "dead_fade": 1.0}


func _target_button(side: String, id: String, at: Vector2, sz: Vector2) -> Button:
	var b := Button.new()
	_ui.add_child(b)
	b.flat = true
	b.position = at
	b.size = sz
	b.focus_mode = Control.FOCUS_NONE
	b.visible = false
	b.pressed.connect(_on_target_pressed.bind(side, id))
	return b


func _build_strip() -> void:
	var strip := TextureRect.new()
	_ui.add_child(strip)
	strip.name = "TurnStrip"
	strip.texture = _tex("battle_ui/turn_order_strip.png")
	strip.position = Vector2(378, 10)
	strip.size = Vector2(524, 60)
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# سمت راست = اکنون (فارسی راست‌به‌چپ می‌خواند). نام زیر هر دایرهٔ نوار
	# می‌نشیند؛ دایره‌ها در تصویر نوار هر ۶۸ پیکسل‌اند.
	for i in 6:
		var l := _label("", 16 if i > 0 else 19, C_TEXT)
		_ui.add_child(l)
		l.size = Vector2(72, 30)
		l.position = Vector2(808.0 - 68.0 * float(i) - 36.0, 62)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_constant_override("outline_size", 5)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_strip_labels.append(l)


func _build_party_panel() -> void:
	var y := 584.0
	for pid in ["kairo", "ilara"]:
		var name := _label(Fa.t("name_%s" % pid), 22, C_TEXT)
		_ui.add_child(name)
		name.position = Vector2(1150, y)
		name.size = Vector2(110, 32)
		name.add_theme_constant_override("outline_size", 6)
		name.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		var frame := TextureRect.new()
		_ui.add_child(frame)
		frame.texture = _tex("battle_ui/bar_health.png")
		frame.position = Vector2(850, y - 4)
		frame.size = Vector2(299, 45)
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var fill := ColorRect.new()
		_ui.add_child(fill)
		fill.color = Color(0.86, 0.25, 0.28, 0.9)
		fill.position = Vector2(856, y + 10)
		fill.size = Vector2(286, 16)
		fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var num := _label("", 18, C_TEXT)
		_ui.add_child(num)
		num.position = Vector2(860, y + 4)
		num.size = Vector2(280, 28)
		num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num.add_theme_constant_override("outline_size", 5)
		num.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		_party_nodes[pid]["fill"] = fill
		_party_nodes[pid]["num"] = num
		_party_nodes[pid]["name"] = name
		y += 44.0
	var en := _label(Fa.t("battle_energy"), 20, C_PERFECT)
	_ui.add_child(en)
	en.position = Vector2(1150, y)
	en.size = Vector2(120, 32)
	en.add_theme_constant_override("outline_size", 6)
	en.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_energy_fill = ColorRect.new()
	_ui.add_child(_energy_fill)
	_energy_fill.color = Color(0.35, 0.85, 1.0, 0.9)
	_energy_fill.position = Vector2(856, y + 10)
	_energy_fill.size = Vector2(286, 16)
	_energy_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ef := TextureRect.new()
	_ui.add_child(ef)
	ef.texture = _tex("battle_ui/bar_energy.png")
	ef.position = Vector2(850, y - 4)
	ef.size = Vector2(298, 45)
	ef.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_energy_label = _label("", 18, C_TEXT)
	_ui.add_child(_energy_label)
	_energy_label.position = Vector2(860, y + 4)
	_energy_label.size = Vector2(280, 28)
	_energy_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_energy_label.add_theme_constant_override("outline_size", 5)
	_energy_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))


func _build_menu() -> void:
	_menu_frame = TextureRect.new()
	_ui.add_child(_menu_frame)
	_menu_frame.name = "MenuFrame"
	_menu_frame.texture = _tex("battle_ui/menu_frame.png")
	_menu_frame.position = Vector2(16, 428)
	_menu_frame.size = Vector2(300, 284)
	_menu_frame.stretch_mode = TextureRect.STRETCH_SCALE
	_menu_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_box = VBoxContainer.new()
	_ui.add_child(_menu_box)
	_menu_box.name = "Menu"
	_menu_box.position = Vector2(36, 466)
	_menu_box.size = Vector2(260, 228)
	_menu_box.add_theme_constant_override("separation", 0)


func _label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.text_direction = Control.TEXT_DIRECTION_RTL
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _tex(rel: String) -> Texture2D:
	# از AssetPath می‌گذرد تا پس‌زمینهٔ نبردِ تبدیل‌شده به WebP هم پیدا شود
	# (D-ART-56). بدون این، صحنهٔ نبرد بی‌پس‌زمینه باز می‌شد و فقط آزمون
	# می‌گفت، نه خود بازی.
	return AssetPath.texture(rel)


# ---------- نمایش وضعیت ----------

func _refresh() -> void:
	var pv := core.preview(6)
	for i in _strip_labels.size():
		var l := _strip_labels[i]
		if i < pv.size():
			l.text = _short_name(pv[i])
			var u := core.unit(pv[i])
			l.add_theme_color_override("font_color",
				C_PERFECT if u.get("side", "") == "party" else C_HURT)
			l.modulate.a = 1.0 if i == 0 else 0.78
		else:
			l.text = ""
	for pid in _party_nodes:
		var u := core.unit(pid)
		var n: Dictionary = _party_nodes[pid]
		var r := float(u["hp"]) / float(u["max_hp"])
		(n["fill"] as ColorRect).size.x = 286.0 * r
		(n["num"] as Label).text = "%s / %s" % [Fa.num(int(u["hp"])), Fa.num(int(u["max_hp"]))]
		var vis: ActorVisual = n["vis"]
		vis.modulate = Color(1, 1, 1, 1.0 if u["alive"] else 0.35)
		var cur := core.current()
		(n["name"] as Label).add_theme_color_override("font_color",
			C_PERFECT if cur.get("id", "") == pid and phase == Phase.MENU else C_TEXT)
	var cap := int(core.data["energy"]["max"])
	_energy_fill.size.x = 286.0 * float(core.energy) / float(cap)
	_energy_label.text = "%s / %s" % [Fa.num(core.energy), Fa.num(cap)]
	for u in core.units:
		if u["side"] != "enemy":
			continue
		if not _enemy_nodes.has(u["id"]):
			_build_enemy(u)
		var n: Dictionary = _enemy_nodes[u["id"]]
		var alive: bool = u["alive"]
		(n["fill"] as ColorRect).size.x = 94.0 * float(u["hp"]) / float(u["max_hp"])
		(n["bar"] as ColorRect).visible = alive
		var it := core.intent_of(String(u["id"]))
		var icon: TextureRect = n["icon"]
		var left: Label = n["left"]
		if it.is_empty():
			icon.visible = false
			left.text = ""
		else:
			icon.visible = true
			icon.texture = _tex("battle_ui/intent_%s.png" % String(it["icon"]))
			left.text = Fa.num(int(it["left"])) if int(it["left"]) > 0 else ""
		var spr: Sprite2D = n["sprite"]
		spr.modulate = Color(1, 0.75, 0.75) if u["fragile"] else Color(1, 1, 1)


func _short_name(id: String) -> String:
	var u := core.unit(id)
	if u.is_empty():
		return ""
	if u["side"] == "party":
		return Fa.t("name_%s" % id)
	var key := String(core.data["enemies"][u["kind"]].get("name_key", u["kind"]))
	var full := Fa.t(key)
	# «ربات خزنده» → «خزنده»: نوار ترتیب جا ندارد
	var parts := full.split(" ")
	return parts[parts.size() - 1] if parts.size() > 1 else full


# ---------- چرخهٔ فاز ----------

func _set_phase(p: Phase, wait: int = 0) -> void:
	phase = p
	_wait = wait
	if p == Phase.MENU:
		_show_menu()
	elif p != Phase.TARGET:
		_clear_menu()
	_show_targets(p == Phase.TARGET)
	_refresh()


func _physics_process(_delta: float) -> void:
	if core == null:
		return
	_frame += 1
	_tick_visuals()
	if _wait > 0:
		_wait -= 1
		if phase == Phase.INTRO:
			_fade.color.a = float(_wait) / float(INTRO_FRAMES)
		elif phase == Phase.RESTART:
			_fade.color.a = 1.0 - absf(float(_wait) / float(RESTART_FADE_FRAMES) * 2.0 - 1.0)
			if _wait == RESTART_FADE_FRAMES / 2:
				_do_restart()
		return
	match phase:
		Phase.INTRO:
			_fade.color.a = 0.0
			_next_turn()
		Phase.MENU:
			if autoplay != "":
				_auto_menu()
		Phase.TARGET:
			if autoplay != "":
				_choose_target(_target_list[0] if not _target_list.is_empty() else "")
		Phase.RING, Phase.DEFENSE:
			_tick_ring()
		Phase.RESOLVE:
			_next_turn()
		Phase.TELEGRAPH:
			if core.pending_attack():
				_start_ring(Phase.DEFENSE, _party_center())
			else:
				core.run_enemy()
				_after_action()
		Phase.BANNER:
			_end_banner()
		Phase.RESTART:
			_set_phase(Phase.INTRO, 1)


func _next_turn() -> void:
	if core.outcome != BattleCore.Outcome.ONGOING:
		_show_outcome()
		return
	if core.is_party_turn():
		_set_phase(Phase.MENU)
	else:
		_set_phase(Phase.TELEGRAPH, TELEGRAPH_FRAMES)
		# قصد روی دشمن نبض می‌زند: بازیکن می‌بیند چه کسی و چه چیزی می‌آید
		var n: Dictionary = _enemy_nodes.get(core.current()["id"], {})
		if not n.is_empty():
			_pulse(n["icon"])


func _after_action() -> void:
	_show_events()
	_set_phase(Phase.RESOLVE, RESOLVE_FRAMES)


func _show_outcome() -> void:
	_banner.visible = true
	match core.outcome:
		BattleCore.Outcome.WIN:
			_banner.text = Fa.t("battle_win")
			_banner.add_theme_color_override("font_color", C_GOOD)
			_apply_reward()
		BattleCore.Outcome.LOSE:
			_banner.text = Fa.t("battle_lose")
			_banner.add_theme_color_override("font_color", C_HURT)
			_lose_frame = _frame
		BattleCore.Outcome.FLED:
			_banner.text = Fa.t("battle_fled")
			_banner.add_theme_color_override("font_color", C_TEXT)
	# شکست کوتاه‌تر: «دوباره!» فقط یک نگاه است، نه مکث جریمه‌مانند
	_set_phase(Phase.BANNER, BANNER_FRAMES / 2 if core.outcome == BattleCore.Outcome.LOSE
		else BANNER_FRAMES)


func _end_banner() -> void:
	if core.outcome == BattleCore.Outcome.LOSE:
		_set_phase(Phase.RESTART, RESTART_FADE_FRAMES)
		return
	_set_phase(Phase.DONE)
	finished.emit(core.outcome, encounter_id)


## شکست = همان نبرد از اول، بدون جریمه (سند ۰۸ §۱). وسط پرده انجام می‌شود
## تا بازیکن پرش وضعیت را نبیند.
func _do_restart() -> void:
	core.restart()
	retries += 1
	_banner.visible = false
	for id in _enemy_nodes.keys():
		if core.unit(String(id)).is_empty():
			var n: Dictionary = _enemy_nodes[id]
			for k in ["sprite", "icon", "left", "bar", "button"]:
				(n[k] as Node).queue_free()
			_enemy_nodes.erase(id)
		else:
			var n: Dictionary = _enemy_nodes[id]
			(n["sprite"] as Sprite2D).visible = true
			(n["sprite"] as Sprite2D).modulate.a = 1.0
			n["dead_fade"] = 1.0
	last_restart_frames = _frame - _lose_frame + RESTART_FADE_FRAMES / 2 + 1
	_refresh()


func _apply_reward() -> void:
	var r := core.reward()
	if r.has("coins"):
		GameState.add_coins(int(r["coins"]))
	GameState.set_flag("battle_won_%s" % encounter_id, true)


# ---------- منو ----------

func _clear_menu() -> void:
	for c in _menu_box.get_children():
		c.queue_free()
	_menu_frame.visible = false


func _show_menu(sub: String = "") -> void:
	_clear_menu()
	_menu_frame.visible = true
	var me := core.current()
	var cmds := core.commands(String(me["id"]))
	if sub == "":
		_menu_button(Fa.t("battle_strike"), true, _on_cmd.bind("strike", ""))
		var any_skill := cmds.any(func(c): return c["cmd"] == "skill")
		_menu_button(Fa.t("battle_skill"), any_skill, _show_menu.bind("skill"))
		var link: Array = cmds.filter(func(c): return c["cmd"] == "link")
		_menu_button(Fa.t("battle_link"), not link.is_empty() and bool(link[0]["ok"]),
			_on_cmd.bind("link", ""))
		_menu_button(Fa.t("battle_guard"), true, _on_cmd.bind("guard", ""))
		var any_item := cmds.any(func(c): return c["cmd"] == "item")
		_menu_button(Fa.t("battle_item"), any_item, _show_menu.bind("item"))
		_menu_button(Fa.t("battle_flee"), core.can_flee(), _on_cmd.bind("flee", ""))
	else:
		for c in cmds:
			if c["cmd"] != sub:
				continue
			if sub == "skill":
				_menu_button("%s  (%s)" % [Fa.t("skill_%s" % c["skill"]), Fa.num(int(c["cost"]))],
					bool(c["ok"]), _on_cmd.bind("skill", String(c["skill"])))
			else:
				var key := String(core.data["items"][c["item"]].get("name_key", c["item"]))
				_menu_button("%s ×%s" % [Fa.t(key), Fa.num(int(c["count"]))], bool(c["ok"]),
					_on_cmd.bind("item", String(c["item"])))
		_menu_button(Fa.t("battle_back"), true, _show_menu.bind(""))
	var first := _menu_box.get_child(0) as Button if _menu_box.get_child_count() > 0 else null
	if first != null and autoplay == "":
		first.grab_focus.call_deferred()


func _menu_button(text: String, ok: bool, cb: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.text_direction = Control.TEXT_DIRECTION_RTL
	b.disabled = not ok
	b.custom_minimum_size = Vector2(240, 37)
	b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
	b.add_theme_font_size_override("font_size", 19)
	b.pressed.connect(cb)
	_menu_box.add_child(b)


func _on_cmd(cmd: String, arg: String) -> void:
	_pending = {"cmd": cmd, "arg": arg}
	match cmd:
		"strike":
			_ask_target("enemy")
		"skill":
			var t := String(core.data["skills"][arg]["target"])
			if t == "enemy":
				_ask_target("enemy")
			elif t == "ally":
				_ask_target("ally")
			else:
				_commit("")
		"item":
			if core.data["items"][arg].has("heal"):
				_ask_target("ally")
			else:
				_commit("")
		_:
			_commit("")


func _ask_target(side: String) -> void:
	_target_list.clear()
	for u in core.units:
		if side == "enemy" and u["side"] == "enemy" and u["alive"]:
			_target_list.append(String(u["id"]))
		elif side == "ally" and u["side"] == "party":
			_target_list.append(String(u["id"]))
	_target_i = 0
	_set_phase(Phase.TARGET)


func _show_targets(on: bool) -> void:
	for id in _enemy_nodes:
		(_enemy_nodes[id]["button"] as Button).visible = on and id in _target_list
	for id in _party_nodes:
		(_party_nodes[id]["button"] as Button).visible = on and id in _target_list


func _on_target_pressed(_side: String, id: String) -> void:
	if phase == Phase.TARGET:
		_choose_target(id)


func _choose_target(id: String) -> void:
	_pending["target"] = id
	var cmd := String(_pending["cmd"])
	var arg := String(_pending.get("arg", ""))
	# ضربه، دش، و پیوند حلقهٔ زمان‌بندی روی هدف دارند (سند ۰۹ §۷)
	var timed: bool = cmd == "strike" or (cmd == "skill" and core.data["skills"][arg].has("hits"))
	if timed:
		var n: Dictionary = _enemy_nodes.get(id, {})
		var at: Vector2 = n.get("slot", Vector2(1000, 560)) - Vector2(0, float(n.get("height", 90.0)) * 0.5)
		_start_ring(Phase.RING, at)
	else:
		_commit(id)


func _commit(target: String, timing: float = BattleCore.NO_PRESS) -> void:
	var ok := core.act(String(_pending["cmd"]), String(_pending.get("arg", "")), target, timing)
	if not ok:
		# بازیکن انسانی به منو برمی‌گردد و چیز دیگری می‌زند. ولی ربات
		# همان انتخاب را دوباره می‌کند و نبرد قفل می‌شود، پس برایش
		# کنشی می‌زنیم که **همیشه** ممکن است.
		if autoplay != "":
			core.act("guard")
			_after_action()
			return
		_set_phase(Phase.MENU)
		return
	_after_action()


# ---------- حلقهٔ زمان‌بندی ----------

## حلقه از بزرگ به کوچک جمع می‌شود؛ لحظهٔ درست وقتی است که به اندازهٔ
## هدف رسید. پنجره بعد از آن هم باز می‌ماند (فشار دیر هم «خوب» است).
func _start_ring(p: Phase, at: Vector2) -> void:
	var t: Dictionary = core.data["timing"]
	_ring_total = int(round(float(t["ring_time_s"]) * FPS))
	var w := float(t["assist_window_mult"]) if core.assist else 1.0
	_ring_window = int(ceil(float(t["good_s"]) * w * FPS))
	_ring_t = 0
	_pressed_at = -1
	_ring.position = at
	_ring.visible = true
	phase = p
	_clear_menu()
	_show_targets(false)


func _tick_ring() -> void:
	_ring_t += 1
	var k := clampf(float(_ring_t) / float(_ring_total), 0.0, 1.0)
	if not _ring_frames.is_empty():
		_ring.texture = _ring_frames[mini(_ring_frames.size() - 1,
			int(k * float(_ring_frames.size())))]
	_ring.scale = Vector2.ONE * lerpf(2.2, 0.9, k)
	_ring.modulate = Color(1, 1, 1, 0.55 + 0.45 * k)
	if autoplay == "skilled" and _ring_t == _ring_total:
		_press()
	if _pressed_at >= 0 or _ring_t > _ring_total + _ring_window:
		var timing := BattleCore.NO_PRESS
		if _pressed_at >= 0:
			timing = float(_pressed_at - _ring_total) / float(FPS)
		_ring.visible = false
		if phase == Phase.RING:
			_commit(String(_pending.get("target", "")), timing)
		else:
			core.run_enemy(timing)
			_after_action()


func _press() -> void:
	if (phase == Phase.RING or phase == Phase.DEFENSE) and _pressed_at < 0:
		_pressed_at = _ring_t


func _unhandled_input(event: InputEvent) -> void:
	var tap: bool = (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventMouseButton and event.pressed)
	if event.is_action_pressed("action") or event.is_action_pressed("jump") or tap:
		if phase == Phase.RING or phase == Phase.DEFENSE:
			_press()
			get_viewport().set_input_as_handled()
		elif phase == Phase.TARGET and not tap and not _target_list.is_empty():
			_choose_target(_target_list[_target_i])
			get_viewport().set_input_as_handled()
	elif phase == Phase.TARGET and not _target_list.is_empty():
		if event.is_action_pressed("move_left") or event.is_action_pressed("move_up"):
			_target_i = (_target_i + 1) % _target_list.size()
		elif event.is_action_pressed("move_right") or event.is_action_pressed("move_down"):
			_target_i = (_target_i - 1 + _target_list.size()) % _target_list.size()
		elif event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			_set_phase(Phase.MENU)


func _party_center() -> Vector2:
	return (PARTY_AT["kairo"] + PARTY_AT["ilara"]) * 0.5 - Vector2(0, 70)


# ---------- رویدادها و افکت ----------

func _show_events() -> void:
	for ev in core.events:
		var who := String(ev.get("who", ""))
		var at := _unit_point(who)
		match String(ev["type"]):
			"damage":
				var g := String(ev.get("grade", ""))
				var col := C_NORMAL
				if core.unit(who).get("side", "") == "party":
					col = C_HURT
				elif g == "perfect":
					col = C_PERFECT
				elif g == "good":
					col = C_GOOD
				_float(Fa.num(int(ev["amount"])), at, col, 34 if g == "perfect" else 28)
				if core.unit(who).get("side", "") == "enemy":
					var fx := "hit_%s" % (g if g in ["perfect", "good"] else "normal")
					_spawn_fx("battle_fx/hits/%s_%%d.png" % fx, 3, at)
					_hurt(who)
				if g == "perfect" and core.unit(who).get("side", "") == "enemy":
					_float(Fa.t("battle_perfect"), at + Vector2(0, -40), C_PERFECT, 24)
			"interrupt":
				_float(Fa.t("battle_interrupt"), at + Vector2(0, -70), C_GOOD, 26)
				_spawn_fx("battle_fx/skills/interrupt_shatter_%d.png", 2, at + Vector2(0, -60))
			"heal":
				_float("+%s" % Fa.num(int(ev["amount"])), at, C_HEAL, 28)
			"skill":
				var fx_name := String(ev.get("fx", ""))
				if fx_name in ["hack", "light_leaf", "shield_block"]:
					var tgt := String(_pending.get("target", ""))
					_spawn_fx("battle_fx/skills/%s_%%d.png" % fx_name, 3,
						_unit_point(tgt) if tgt != "" else at)
			"guard", "barrier":
				_spawn_fx("battle_fx/skills/shield_block_%d.png", 3, at)
			"link":
				_flash(Color(1.0, 0.95, 0.8, 0.85))
			"phase":
				_float(Fa.t("battle_phase2"), at + Vector2(0, -90), C_HURT, 30)
			"defeat":
				pass


func _unit_point(id: String) -> Vector2:
	if _party_nodes.has(id):
		return PARTY_AT[id] - Vector2(0, 110)
	if _enemy_nodes.has(id):
		var n: Dictionary = _enemy_nodes[id]
		return (n["slot"] as Vector2) - Vector2(0, float(n["height"]) * 0.6)
	return Vector2(640, 360)


func _hurt(id: String) -> void:
	var n: Dictionary = _enemy_nodes.get(id, {})
	if n.is_empty():
		return
	var t := _tex("enemies/battle_nexa/%s_hurt.png" % String(n["art"]))
	if t != null:
		(n["sprite"] as Sprite2D).texture = t
	n["hurt"] = 14


func _float(text: String, at: Vector2, col: Color, size: int) -> void:
	var l := _label(text, size, col)
	_ui.add_child(l)
	l.add_theme_constant_override("outline_size", 7)
	l.add_theme_color_override("font_outline_color", Color(0.04, 0.04, 0.08))
	l.position = at - Vector2(40, 20)
	l.size = Vector2(80, 40)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_floaters.append({"node": l, "life": 48})


func _spawn_fx(pattern: String, frames: int, at: Vector2) -> void:
	var list: Array[Texture2D] = []
	for i in frames:
		var t := _tex(pattern % i)
		if t != null:
			list.append(t)
	if list.is_empty():
		return
	var s := Sprite2D.new()
	s.texture = list[0]
	s.position = at
	s.z_index = 8
	_stage.add_child(s)
	_fx.append({"node": s, "frames": list, "t": 0})


func _flash(col: Color) -> void:
	var r := ColorRect.new()
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(r)
	_floaters.append({"node": r, "life": 20, "flash": true})


func _pulse(node: Control) -> void:
	node.scale = Vector2(1.3, 1.3)


func _tick_visuals() -> void:
	for i in range(_floaters.size() - 1, -1, -1):
		var f: Dictionary = _floaters[i]
		var n: Control = f["node"]
		f["life"] = int(f["life"]) - 1
		if bool(f.get("flash", false)):
			n.modulate.a = float(f["life"]) / 20.0
		else:
			n.position.y -= 0.8
			n.modulate.a = clampf(float(f["life"]) / 20.0, 0.0, 1.0)
		if int(f["life"]) <= 0:
			n.queue_free()
			_floaters.remove_at(i)
	for i in range(_fx.size() - 1, -1, -1):
		var f: Dictionary = _fx[i]
		f["t"] = int(f["t"]) + 1
		var frames: Array = f["frames"]
		var idx := int(f["t"]) / 5
		if idx >= frames.size():
			(f["node"] as Node).queue_free()
			_fx.remove_at(i)
		else:
			(f["node"] as Sprite2D).texture = frames[idx]
	for id in _enemy_nodes:
		var n: Dictionary = _enemy_nodes[id]
		var u := core.unit(String(id))
		var spr: Sprite2D = n["sprite"]
		var icon: TextureRect = n["icon"]
		icon.scale = icon.scale.lerp(Vector2.ONE, 0.15)
		if int(n["hurt"]) > 0:
			n["hurt"] = int(n["hurt"]) - 1
			spr.offset.x = 3.0 if int(n["hurt"]) % 4 < 2 else -3.0
			if int(n["hurt"]) == 0:
				spr.offset.x = 0.0
				spr.texture = _tex("enemies/battle_nexa/%s_idle.png" % String(n["art"]))
		if not u.is_empty() and not u["alive"]:
			n["dead_fade"] = maxf(0.0, float(n["dead_fade"]) - 0.05)
			spr.modulate.a = float(n["dead_fade"])
			if float(n["dead_fade"]) <= 0.0:
				spr.visible = false
		# نفس آرام دشمن: بی آن مجسمه دیده می‌شود (سند ۱۳ بند ۵)
		if u.get("alive", false):
			var base: float = (n["slot"] as Vector2).y - float(n["height"]) * 0.5
			spr.position.y = base + sin(float(_frame) / 24.0 + float(n["slot"].x) * 0.01) * 1.5


# ---------- روبات ----------

func _auto_menu() -> void:
	var me := core.current()
	if autoplay == "idle":
		_on_cmd("guard", "")
		return
	if core.energy >= 10 and core.alive("party").size() == 2:
		_on_cmd("link", "")
		return
	for e in core.alive("enemy"):
		var it := core.intent_of(String(e["id"]))
		for sid in it.get("interrupt", []):
			# **هزینه به هدف بستگی دارد** (D-ART-55): هک و نور رو به
			# فرمانده ۳ است. با هزینهٔ پایهٔ ۲، ربات با ۲ انرژی مهارت را
			# می‌زد، هسته ردش می‌کرد، صحنه به منو برمی‌گشت و همین حلقه
			# تا ابد تکرار می‌شد — نبرد اوج در آزمون صحنه هرگز تمام نشد.
			var need := core.skill_cost(sid, String(e["kind"]))
			if sid in core.data["party"][me["kind"]]["skills"] and core.energy >= need:
				_pending = {"cmd": "skill", "arg": sid}
				_commit(String(e["id"]))
				return
	var target := ""
	var low := 9999
	for e in core.alive("enemy"):
		if int(e["hp"]) < low:
			low = int(e["hp"])
			target = String(e["id"])
	_pending = {"cmd": "strike", "arg": ""}
	_choose_target(target)
