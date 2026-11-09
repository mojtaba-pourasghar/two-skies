## صحنهٔ اتاق نقاشی‌شده — M1
##
## اتاق را می‌سازد، بازیگران را در لایهٔ درست می‌نشاند، دوربین را طبق رفتار
## اتاق می‌چیند، و در را با گذار ۰٫۳ ثانیه‌ای به اتاق بعد وصل می‌کند.
##
## حرکت در این بازی **ماسک‌محور** است نه برخورد فیزیکی: بازیگر هر فریم
## می‌سنجد که قدم بعدی‌اش روی چندضلعی قابل‌راه‌رفتن می‌افتد یا نه. دلیلش
## سند ۱۱ است — دیوار در خود **تصویر** نقاشی شده و جسم فیزیکی ندارد.
class_name RoomGame
extends Node2D

@export var start_room: String = "r1a_living"
@export var debug_mask: bool = false
## اگر روشن باشد و ذخیره‌ای از اکتشاف باشد، از همان اتاق ادامه می‌دهد.
@export var resume: bool = false

var room: PaintedRoom
var director: CameraDirector
var camera: GameCamera
var kairo: TdKairo
var ilara: TdIlara

var _loader := RoomData.new()
var _visuals: Array[ActorVisual] = []
## کجا ایلارا منتظر مانده (D-ART-35): شناسهٔ اتاق و نقطهٔ کنار در.
var _ilara_waits_in: String = ""
var _ilara_waits_at := Vector2.ZERO
var _last_room_id: String = ""
var _last_door_at := Vector2.ZERO
var _door_block: String = ""
var _fade: ColorRect
var _hud: CanvasLayer
var _pending_spawn := Vector2.ZERO
## نقطهٔ شروع دوباره در اتاق چالش: همان جایی که کایرو وارد اتاق شد.
## سند ۰۹ §۲ب: «چک‌پوینت فقط بین بخش‌ها» — هر اتاق چالش یک بخش است.
var _restart_at := Vector2.ZERO
## شمارندهٔ مرگ همین اتاق چالش؛ با ورود به اتاق تازه صفر می‌شود.
var room_deaths: int = 0
var _deaths_label: Label


func _ready() -> void:
	director = CameraDirector.new()
	director.name = "Director"
	add_child(director)
	director.transition_finished.connect(_on_transition_finished)

	_build_hud()
	_build_camera()

	# «ادامه»: اگر ذخیره‌ای از اکتشاف هست، از همان‌جا شروع کن.
	# `resume` را آزمون و منوی تازه خاموش می‌کنند تا از اول شروع شود.
	var at := Vector2.ZERO
	if resume and GameState.explore_room() != "":
		start_room = GameState.explore_room()
		at = GameState.explore_at()
		GameState.restore_explore_flags()
	if not _enter_room(start_room, at):
		return

	GameMode.set_context(GameMode.Context.EXPLORE)
	GameMode.set_control(GameMode.ControlMode.PLAY)
	EventBus.level_started.emit(start_room)


func _build_hud() -> void:
	_hud = CanvasLayer.new()
	_hud.name = "HUD"
	_hud.layer = 10
	add_child(_hud)
	# پردهٔ محو گذار در به در
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_fade)
	# شمارندهٔ مرگ — فقط در اتاق چالش دیده می‌شود (سند ۰۹ §۱ قاعدهٔ ۱)
	_deaths_label = UIKit.make_label("", 22, Color(1.0, 0.92, 0.8))
	_deaths_label.name = "Deaths"
	_deaths_label.position = Vector2(1080, 20)
	_deaths_label.size = Vector2(180, 32)
	_deaths_label.visible = false
	_hud.add_child(_deaths_label)


func _build_camera() -> void:
	camera = GameCamera.new()
	camera.name = "Camera"
	camera.director = director
	add_child(camera)
	camera.make_current()


func _enter_room(room_id: String, spawn_override: Vector2) -> bool:
	var data := _loader.load_room(room_id)
	if data.is_empty():
		for e in _loader.errors:
			push_error("RoomGame: %s" % e)
		return false
	for w in _loader.warnings:
		push_warning("RoomGame: %s" % w)

	if room != null:
		room.queue_free()
		room = null
	room = PaintedRoom.new()
	room.name = "Room_%s" % room_id
	add_child(room)
	move_child(room, 0)
	room.build(data)
	if debug_mask:
		room.show_mask(true)
	if not room.missing_art.is_empty():
		push_warning("RoomGame: %d دارایی پیدا نشد: %s"
			% [room.missing_art.size(), ", ".join(room.missing_art.slice(0, 4))])

	director.setup(String(data.get("camera", "room")), room_id)
	_spawn_actors(spawn_override if spawn_override != Vector2.ZERO
		else room.spawn_position())

	camera.follow_mode = String(data.get("camera", "room"))
	camera.set_bounds(room.bounds())
	camera.set_room(room.bounds())
	camera.target = kairo
	# زوم قبل از اولین قاب بنشیند، وگرنه ورود به اتاق با یک گذار زوم
	# شروع می‌شود که کسی نخواسته (D-ART-42).
	# گذار در به در «تغییر نور» است نه خاموشی: پرده به رنگ نور اتاق مقصد
	# می‌رود (سند ۱۳ بند ۶).
	_fade.color = room.light_tint()
	# سقف زوم اتاق: با نسخهٔ پرجزئیات ۱٫۳×، بی آن ۱٫۱۲×
	camera.max_zoom = room.max_zoom()
	camera.snap_zoom(GameCamera.ZOOM_NORMAL)
	camera.set_zoom_zones(room.zoom_zones())
	camera.snap_to_target()
	room_deaths = 0
	_update_deaths_label()
	return true


## «ایلارا وارد C1/C2/C3 نمی‌شود؛ کنار در منتظر می‌ماند» (D-ART-35،
## سند ۱۲ §۶ب). این یک **باگ** بود: او تا اینجا با کایرو وارد اتاق چالش
## می‌شد، و چون در اتاق چالش مرگ بی‌نهایت است، قانون §۵ (مرگ ایلارا =
## شکست مرحله) با قانون اتاق چالش می‌جنگید.
static func is_challenge(room_data: Dictionary) -> bool:
	return bool(room_data.get("challenge", false))


func _spawn_actors(at: Vector2) -> void:
	_visuals.clear()
	kairo = TdKairo.new()
	kairo.name = "Kairo"
	room.actors.add_child(kairo)
	kairo.global_position = at
	kairo.room = room
	# `spawn_point` در `_ready` از جای گره خوانده می‌شود، ولی آن موقع هنوز
	# (۰،۰) است؛ بی این خط کایرو بعد از مرگ گوشهٔ بالا-چپ اتاق زنده می‌شد.
	kairo.spawn_point = at
	_restart_at = at
	kairo.hazard_hit.connect(_on_hazard_hit)
	kairo.died.connect(_on_kairo_died)
	_dress(kairo, "kairo")

	if is_challenge(room.data):
		# ایلارا ساخته نمی‌شود. جایی که منتظر مانده ثبت می‌شود تا موقع
		# برگشت دقیقاً همان‌جا باشد، نه کنار کایرو.
		ilara = null
		_ilara_waits_in = _last_room_id
		_ilara_waits_at = _last_door_at
		return

	ilara = TdIlara.new()
	ilara.name = "Ilara"
	room.actors.add_child(ilara)
	ilara.leader = kairo
	# اگر اینجا منتظر مانده بود، سر همان در پیدایش می‌شود و دوباره دنبال
	# می‌کند؛ وگرنه کنار کایرو
	if _ilara_waits_in == String(room.data.get("id", "")):
		ilara.global_position = _ilara_waits_at
		_ilara_waits_in = ""
	else:
		ilara.global_position = at - Vector2(40, 0)
	ilara.set_order(TdIlara.Order.FOLLOW)
	ilara.room = room
	_dress(ilara, "ilara")


func _dress(actor: TdActor, who: String) -> void:
	var vis := ActorVisual.new()
	vis.name = "Visual"
	actor.add_child(vis)
	vis.setup(who)
	actor.attach_visual(vis, vis.shadow())
	_visuals.append(vis)


func _physics_process(_delta: float) -> void:
	GameMode.tick()
	director.tick()
	_fade.color.a = director.fade_alpha()
	if kairo == null or director.is_transitioning():
		return
	for i in _visuals.size():
		var a: TdActor = kairo if i == 0 else ilara
		if a != null:
			_visuals[i].update_from(a)
	# محیط باید عبور بازیکن را حس کند (سند ۱۳ بند ۷)
	room.react_to(kairo.foot_position(), kairo.velocity.length())
	# زوم که از حد بی‌هایرز گذشت، تصویر پرجزئیات بیاید
	room.use_hires(camera.zoom.x > PaintedRoom.ZOOM_WITHOUT_HIRES)
	_check_door()


signal door_refused(door: Dictionary, flag: String)
## تلهٔ اکتشاف جان گرفت و بازیکن به خانهٔ امن برگشت.
signal hazard_hurt(hazard: Dictionary, hp_pct: float)


## سه قاعدهٔ مرگ سند ۰۹ §۱ — اینجا دو تای اول:
##   ۱ اتاق چالش: یک تماس = مرگ، شروع دوباره زیر ۰٫۳ ثانیه، بی‌نهایت، شمارنده
##   ۲ اکتشاف: بدون مرگ؛ آسیب جزئی (`damage_pct`) + برگشت به خانهٔ امن
## خطری با `damage_pct` ۱۰۰ بیرون اتاق چالش هم نمی‌کشد: اکتشاف مرگ ندارد
## (GameState.damage_percent جان را زیر صفر نمی‌برد).
func _on_hazard_hit(h: Dictionary) -> void:
	if kairo == null or director.is_transitioning():
		return
	if is_challenge(room.data):
		kairo.die()
		return
	GameState.damage_percent(float(h.get("damage_pct", 10.0)))
	var safe: Array = h.get("safe", [])
	var back := _restart_at
	if safe.size() == 2:
		back = Vector2(float(safe[0]), float(safe[1]))
	# جای امن هم‌قرارداد نقطهٔ ورود در است: جای خود بازیگر، نه پا
	kairo.global_position = back
	kairo.velocity = Vector2.ZERO
	hazard_hurt.emit(h, GameState.hp_percent())


func _on_kairo_died() -> void:
	room_deaths += 1
	GameState.run["deaths"] = int(GameState.run.get("deaths", 0)) + 1
	EventBus.player_died.emit("kairo")
	_update_deaths_label()


func _update_deaths_label() -> void:
	if _deaths_label == null:
		return
	var on := room != null and is_challenge(room.data)
	_deaths_label.visible = on
	_deaths_label.text = "%s: %s" % [Fa.t("ui_deaths"), Fa.num(room_deaths)]


## دری که پرچمی لازم دارد (R1d تا فلش‌بک، R1e تا کلید) بدون آن باز
## نمی‌شود — **و بی‌صدا هم نمی‌ماند**: اعلام می‌شود تا رابط بتواند
## بگوید چرا. در بی‌صدا، بازیکن فکر می‌کند بازی خراب است.
func _check_door() -> void:
	var door := room.door_at(kairo.foot_position())
	if door.is_empty():
		_door_block = ""
		return
	var need := String(door.get("needs_flag", ""))
	if need != "" and not bool(GameState.get_flag(need, false)):
		if _door_block != need:
			_door_block = need
			door_refused.emit(door, need)
		return
	var sp: Array = door.get("spawn", [0, 0])
	_pending_spawn = Vector2(float(sp[0]), float(sp[1]))
	# اتاقی که داریم ترک می‌کنیم و جای همین در، برای وقتی ایلارا باید
	# اینجا بماند
	_last_room_id = String(room.data.get("id", ""))
	_last_door_at = kairo.foot_position()
	# ذخیره **پیش از** گذار: اگر بازی همین‌جا بسته شود، بازیکن در اتاقی
	# که داشت ترکش می‌کرد ادامه می‌دهد، نه در جایی که هرگز نرسید.
	GameState.save_explore(String(door.get("to", "")), _pending_spawn)
	director.go_to_room(String(door.get("to", "")), "")


func _on_transition_finished(room_id: String) -> void:
	_enter_room(room_id, _pending_spawn)
	_pending_spawn = Vector2.ZERO
