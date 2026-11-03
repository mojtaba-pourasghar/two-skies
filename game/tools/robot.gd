## روبات کنترلی — docs/02_godot_spec.md §۲۲
##
## برنامهٔ کنش اتاق را از `levels/data/solutions/*.plan.json` می‌گیرد (تولید
## `tools/export_plans.py` از BFS اعتبارسنج) و هر فریم فیزیک یک ورودی می‌دهد.
##
## ورودی با `Input.action_press/release` اعمال می‌شود، یعنی از همان مسیری که
## دکمه‌های لمسی می‌روند؛ پس کد واقعی بازی سنجیده می‌شود نه یک نسخهٔ موازی.
##
## حلقهٔ بسته است نه باز: هر فریم موقعیت واقعی کایرو با کاشی هدف مقایسه و اصلاح
## می‌شود. رشتهٔ ورودی فریم‌به‌فریم **خروجی** این روبات است نه ورودی‌اش؛ ترجمهٔ
## بی‌بازخورد شکننده است، چون BFS گسسته است و فیزیک پیوسته.
class_name Robot
extends Node

const TILE: int = 16
const ACTIONS := ["move_left", "move_right", "jump", "action", "companion"]

## فاصله‌ای که هدف «رسیده» شمرده می‌شود
const REACH_X: float = 7.0
const REACH_Y: float = 12.0
## پس از این تعداد فریم بی‌پیشرفت، یک کنش رد می‌شود
const STUCK_FRAMES: int = 70
## سقف رد کردن کنش پیش از اعلام شکست اتاق
const MAX_SKIPS: int = 40

enum Phase { RUN, GATE_WAIT, GATE_RUN, STAY_BEFORE_CRUMBLE, WAIT_CRUMBLE, CALL_COME,
	WAIT_ILARA, AT_EXIT, DONE }

var game                      ## GameRunner (بدون تایپ: ریشهٔ صحنه Node2D است)
var plan: Dictionary = {}     ## برنامهٔ مرحله
var route: String = "direct"  ## "direct" یا "full"
var jitter: int = 0           ## افست زمانی برای تلاش‌های دوباره

## رشتهٔ ورودی ضبط‌شده: هر درایه یک bitmask از ACTIONS
var recorded: PackedByteArray = PackedByteArray()
var record_enabled: bool = true
## ردگیری: هر N فریم وضعیت را چاپ می‌کند (برای عیب‌یابی)
var trace_every: int = 0

var phase: Phase = Phase.RUN
var frames: int = 0
var skips: int = 0
var log_lines: Array[String] = []

var _room_id: String = ""
var _legs: Array = []
var _leg: int = 0
var _wp: int = 0
var _climb_dir: int = -1
var _climb_frames: int = 0
var _stuck: int = 0
var _last_pos := Vector2.ZERO
var _held := {}
var _jump_hold: int = 0
var _jump_pending: int = 0
var _wj_armed: bool = false
var _climb_x: float = 0.0
var _wait_hazard: int = 0
var _wait_ilara_frames: int = 0
## «دروازهٔ مانع»: جای مانعی که داریم با هم‌زمانی از آن رد می‌شویم
var _gate_hx: float = 0.0
var _gate_frames: int = 0
var _gates_done: Dictionary = {}
var _prev_falls: int = 0
var _ilara_trail: Array[Vector2] = []
var _companion_hold: int = 0
var _wait: int = 0
var _crumble_cols: Array = []
var _crumble_done: bool = false
var _hack_hold: int = 0


func _ready() -> void:
	for a in ACTIONS:
		_held[a] = false


## برنامهٔ مرحله را از فایل می‌خواند.
static func load_plan(level_id: String) -> Dictionary:
	var path := "res://levels/data/solutions/%s.plan.json" % level_id
	if not FileAccess.file_exists(path):
		push_error("Robot: برنامهٔ «%s» نیست. tools/export_plans.py را اجرا کن." % level_id)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}


func room_plan(room_id: String) -> Dictionary:
	for r in plan.get("rooms", []):
		if String(r.get("id", "")) == room_id:
			return r
	return {}


## ----- حلقهٔ کنترل -----

## هر فریم فیزیک از آزمون صدا زده می‌شود.
func step() -> void:
	frames += 1
	if game == null or game.kairo == null or phase == Phase.DONE:
		return
	if game.finished:
		phase = Phase.DONE
		_release_all()
		return

	# اتاق عوض شد: برنامهٔ اتاق تازه
	var rid := String(game.current_room_id)
	if rid != _room_id:
		_enter_room(rid)

	var kairo = game.kairo
	# در مرگ یا صحنهٔ داستانی ورودی بی‌اثر است؛ دکمه‌ها رها می‌شوند
	if kairo.state == PlatformActor.State.DEAD \
			or kairo.state == PlatformActor.State.CUTSCENE:
		_release_all()
		_record()
		return

	match phase:
		Phase.RUN:
			_phase_run(kairo)
		Phase.GATE_WAIT:
			_phase_gate_wait(kairo)
		Phase.GATE_RUN:
			_phase_gate_run(kairo)
		Phase.STAY_BEFORE_CRUMBLE:
			_phase_stay(kairo)
		Phase.WAIT_CRUMBLE:
			_phase_wait_crumble(kairo)
		Phase.CALL_COME:
			_phase_call_come(kairo)
		Phase.WAIT_ILARA:
			_phase_wait_ilara(kairo)
		Phase.AT_EXIT:
			_phase_at_exit(kairo)
		_:
			pass

	_tick_holds()
	_record()
	_watch_ilara(kairo)
	_trace(kairo)


## جای مرگ ایلارا را ثبت می‌کند تا بشود فهمید کجا و چرا می‌افتد.
func _watch_ilara(kairo) -> void:
	if game.ilara == null:
		return
	_ilara_trail.append(game.ilara.global_position)
	if _ilara_trail.size() > 6:
		_ilara_trail.remove_at(0)
	if game.ilara_falls == _prev_falls:
		return
	_prev_falls = game.ilara_falls
	var p: Vector2 = _ilara_trail[0]
	log_lines.append("  ایلارا افتاد #%d در اتاق %s کاشی(%d,%d) — کایرو کاشی(%d,%d) %s"
		% [_prev_falls, _room_id, int(p.x / TILE), int(p.y / TILE),
			int(kairo.global_position.x / TILE), int(kairo.global_position.y / TILE),
			_current_action()])


func _trace(kairo) -> void:
	if trace_every <= 0 or frames % trace_every != 0:
		return
	var wp := _current_wp()
	var p: Vector2 = kairo.global_position
	var ilara_txt := "-"
	if game.ilara != null:
		ilara_txt = "%s(%d,%d)%s" % [
			"بمان" if game.ilara.mode == Ilara.Mode.STAY else "دنبال",
			int(game.ilara.global_position.x / TILE),
			int(game.ilara.global_position.y / TILE),
			PlatformActor.State.keys()[game.ilara.state].substr(0, 4)]
	var jev := 0
	var cur := 0
	if kairo.jump_events != null:
		jev = kairo.jump_events.size()
	if game.ilara != null:
		cur = game.ilara._jump_cursor
	print("    f%-5d %s cell(%d,%d) %-10s wp%d/%d %-9s→%s  ایلارا %s  مرگ %d  jev=%d/cur=%d" % [
		frames, _room_id, int(p.x / TILE), int(p.y / TILE),
		PlatformActor.State.keys()[kairo.state], _leg, _wp,
		String(wp.get("kind", "-")), str(wp.get("cell", [])),
		ilara_txt, game.deaths, jev, cur])


func _enter_room(rid: String) -> void:
	_room_id = rid
	var rp := room_plan(rid)
	_legs = rp.get(route, [])
	_crumble_cols = rp.get("crumble_cols", [])
	_crumble_done = false
	_gates_done.clear()
	_leg = 0
	_wp = 0
	_climb_frames = 0
	_stuck = 0
	_wait = 0
	phase = Phase.RUN
	_release_all()
	var n_wp := 0
	for leg in _legs:
		n_wp += (leg.get("waypoints", []) as Array).size()
	log_lines.append("اتاق %s: %d پا، %d نقطهٔ راه، سکوی شکننده در %d ستون"
		% [rid, _legs.size(), n_wp, _crumble_cols.size()])


## ----- فاز اصلی: دنبال کردن نقطه‌های راه -----

func _phase_run(kairo) -> void:
	# اگر میدان سکوی شکننده جلو است و ایلارا دنبال می‌کند، اول «بمان»
	if not _crumble_done and _crumble_ahead(kairo):
		_crumble_done = true
		phase = Phase.STAY_BEFORE_CRUMBLE
		_companion_hold = 24  # ۰٫۴ ثانیه نگه‌داشتن = دستور «بمان» (§۵)
		log_lines.append("  میدان سکوی شکننده جلو است → «بمان»")
		return

	var wp := _current_wp()
	if wp.is_empty():
		phase = Phase.AT_EXIT
		return

	# نقطه‌های رسیده را رد کن
	while not wp.is_empty() and _reached(wp, kairo):
		_advance()
		wp = _current_wp()
	if wp.is_empty():
		phase = Phase.AT_EXIT
		return

	var kind := String(wp.get("kind", "walk"))
	var target := _cell_px(wp.get("cell", [0, 0]))

	# از ایلارا جلو نزن: او ۰٫۸ ثانیه عقب‌تر و کندتر است (۱۰۵ مقابل ۱۲۰)، و اگر
	# فاصله زیاد شود از نقطه‌های پرش جا می‌ماند و در شکاف می‌افتد (D-037).
	if game.ilara != null and game.ilara.mode == Ilara.Mode.FOLLOW \
			and kairo.is_on_floor():
		var gap: float = kairo.global_position.x - game.ilara.global_position.x
		if absf(gap) > 6.0 * float(TILE):
			_wait_ilara_frames += 1
			if _wait_ilara_frames < 300:
				_release("move_left")
				_release("move_right")
				return
		else:
			_wait_ilara_frames = 0

	# مانع زمان‌بندی‌دار جلو است: وارد «دروازه» می‌شویم.
	#
	# عبور از لیزر L3R1 فقط در ۰٫۲۵ ثانیهٔ نخستِ پنجرهٔ ۱٫۲ ثانیه‌ای ممکن است،
	# چون ایلارا ۰٫۸ ثانیه عقب‌تر است و عبورش ۰٫۱۵ ثانیه طول می‌کشد. کنترلری که
	# هر فریم دوباره تصمیم بگیرد این هم‌زمانی را از دست می‌دهد و وسط عبور
	# می‌ایستد. پس دروازه یک دنبالهٔ **متعهد** است: ایستادن در فاصلهٔ امن،
	# جمع کردن ایلارا، هک پهپاد، انتظار تا باز شدن پنجره، و بعد عبور یکسره
	# بدون تصمیم تازه (DECISIONS.md: D-040).
	if kairo.is_on_floor() and kind != "wallclimb":
		var hx := _gate_ahead(kairo, target)
		if hx != INF:
			_gate_hx = hx
			_gate_frames = 0
			phase = Phase.GATE_WAIT
			return

	match kind:
		"wallclimb":
			_do_climb(wp, target, kairo)
		"dash":
			_steer_to(target, kairo)
			if kairo.can_dash:
				if kairo.active_tool != "dash":
					kairo.set_active_tool("dash")
				elif kairo.is_on_floor():
					_press("action")
		"hop":
			_steer_to(target, kairo)
			if kairo.is_on_floor():
				_request_jump(16)
		_:  # walk، drop
			_steer_to(target, kairo)
			# اگر دیوار جلو است یا هدف بالاتر است، بپر
			var above: bool = target.y < kairo.global_position.y - float(TILE) * 0.6
			if kairo.is_on_floor() and (above or kairo.is_on_wall()):
				_request_jump(16)
			# روی مسیر بلند و بی‌مانع دش می‌زنیم: هم سریع‌تر است و هم ورودی دش
			# را واقعاً می‌سنجد (خواستهٔ گام ۸). مسیر از دش مستقل است (D-036).
			elif kairo.can_dash and kairo.is_on_floor() \
					and absf(target.x - kairo.global_position.x) > 5.0 * float(TILE) \
					and not _hazard_near(kairo.global_position, 7.0 * float(TILE)) \
					and _ilara_close(kairo, 3.0):
				if kairo.active_tool != "dash":
					kairo.set_active_tool("dash")
				else:
					_press("action")

	_maybe_hack(kairo)
	_check_stuck(kairo)


## آیا باید این فریم سر جا ایستاد تا مانع زمان‌بندی‌دار رد شود؟
##
## ایلارا ۰٫۸ ثانیه عقب‌تر مسیر کایرو را می‌رود، پس عبور در لحظهٔ آخر پنجرهٔ امن
## او را می‌کشد و طبق قانون همراهی مرحله از اول شروع می‌شود. بنابراین برای لیزر
## نه‌تنها «خاموش بودن» لازم است، بلکه باید دست‌کم تأخیر ایلارا هم از پنجره
## باقی مانده باشد (DECISIONS.md: D-033).
func _hazard_block(kairo, target: Vector2) -> bool:
	if game.room == null:
		return false
	var p: Vector2 = kairo.global_position
	var lo := minf(p.x, target.x) - 4.0
	var hi := maxf(p.x, target.x) + 4.0
	var need_off: float = float(Ilara.FOLLOW_DELAY_FRAMES) / 60.0 + 0.2

	# اگر مانعی در ۴ کاشی پیش رو هست، تا ایلارا نزدیک نشده عبور نمی‌کنیم.
	# او ۰٫۸ ثانیه عقب‌تر و کندتر است؛ اگر فاصله زیاد باشد وقتی به مانع می‌رسد
	# پنجرهٔ امن بسته شده یا پهپاد برگشته است. با فاصلهٔ ≤۲٫۵ کاشی هر دو در یک
	# پنجره رد می‌شوند و یک بار هک پهپاد برای هر دو کافی است (D-039).
	if game.ilara != null and game.ilara.mode == Ilara.Mode.FOLLOW:
		if absf(game.ilara.global_position.x - p.x) > 2.5 * float(TILE) \
				and _hazard_near(p, 4.0 * float(TILE)):
			return true
		# قاعدهٔ اصلی همراهی: تا ایلارا از مانع رد نشده، از آن جلوتر نرو.
		# وگرنه کایرو در پنجرهٔ امن رد می‌شود و او ۰٫۸ ثانیه بعد تنها به مانعِ
		# دوباره فعال می‌رسد — که طبق §۵ شکست مرحله است (D-039).
		if _ilara_behind_hazard(p, target):
			return true

	for h in game.room.hazards:
		if not is_instance_valid(h):
			continue
		if h is Laser:
			var laser := h as Laser
			var rect := laser.beam_global_rect()
			# آیا پرتو روی مسیر افقی ما و در ارتفاع ما است؟
			if rect.position.x > hi or rect.end.x < lo:
				continue
			if p.y < rect.position.y - float(TILE) or p.y > rect.end.y + float(TILE):
				continue
			if laser.is_lethal() or laser.off_time_left() < need_off:
				return true
		elif h is Drone:
			var drone := h as Drone
			if drone.is_disabled:
				continue
			var d: Vector2 = drone.global_position
			if d.x < lo - float(TILE) or d.x > hi + float(TILE):
				continue
			if absf(d.y - p.y) > 1.6 * float(TILE):
				continue
			# پهپاد روی مسیر است: اگر در برد هک نیست، صبر تا دور شود
			if absf(d.x - p.x) < 2.5 * float(TILE):
				return true
	return false


func _current_wp() -> Dictionary:
	if _leg >= _legs.size():
		return {}
	var wps: Array = _legs[_leg].get("waypoints", [])
	if _wp >= wps.size():
		return {}
	return wps[_wp]


func _current_action() -> String:
	var wp := _current_wp()
	return String(wp.get("kind", "")) if not wp.is_empty() else ""


func _advance() -> void:
	_stuck = 0
	_climb_frames = 0
	_wp += 1
	var wps: Array = _legs[_leg].get("waypoints", []) if _leg < _legs.size() else []
	if _wp >= wps.size():
		_leg += 1
		_wp = 0


func _cell_px(cell) -> Vector2:
	return Vector2((int(cell[0]) + 0.5) * TILE, (int(cell[1]) + 0.5) * TILE)


func _reached(wp: Dictionary, kairo) -> bool:
	var target := _cell_px(wp.get("cell", [0, 0]))
	var p: Vector2 = kairo.global_position
	var kind := String(wp.get("kind", "walk"))
	if kind == "wallclimb":
		# بالا رفتن تمام است وقتی به سطر هدف یا بالاتر رسیدیم و روی زمینیم
		return p.y <= target.y + float(TILE) * 0.75 and kairo.is_on_floor()
	if absf(p.x - target.x) > REACH_X:
		return false
	if absf(p.y - target.y) > REACH_Y:
		return false
	# نقطه‌های روی زمین باید با فرود تأیید شوند، نه در میانهٔ پرش
	if kind in ["walk", "hop", "dash", "drop"]:
		return kairo.is_on_floor()
	return true


## هدایت افقی به سمت هدف
func _steer_to(target: Vector2, kairo) -> void:
	var dx: float = target.x - kairo.global_position.x
	if dx > 3.0:
		_press("move_right")
		_release("move_left")
	elif dx < -3.0:
		_press("move_left")
		_release("move_right")
	else:
		_release("move_left")
		_release("move_right")


## زنجیرهٔ دیوارپرش در شفت.
##
## نکتهٔ کلیدی: `PlatformActor` فقط وقتی پرش دیواری می‌زند که **در همان فریم** جهت
## به سمت دیوار فشار داده شود (شرط `sliding` در §۴). اگر در فریمِ درخواست پرش
## جهت را به سمت مخالف عوض کنیم، `sliding` false می‌شود و پرش بی‌صدا دور ریخته
## می‌شود. پس جهت فقط **پس از** انجام شدن پرش عوض می‌شود (DECISIONS.md: D-032).
func _do_climb(wp: Dictionary, target: Vector2, kairo) -> void:
	if _climb_frames == 0:
		_climb_dir = -1 if String(wp.get("push", "left")) == "left" else 1
		_wj_armed = false
		# x لحظهٔ شروع بالا رفتن = مرکز شفت
		_climb_x = kairo.global_position.x
	_climb_frames += 1

	# پرش دیواری انجام شد؟ (از WALL_SLIDE در آمدیم و روی زمین نیستیم)
	if _wj_armed and kairo.state != PlatformActor.State.WALL_SLIDE \
			and not kairo.is_on_floor():
		_wj_armed = false
		_climb_dir = -_climb_dir

	# به ارتفاع هدف رسیدیم: شفت خودش کف ندارد، پاگرد در ستون هدف است.
	# پس از اینجا افقی به سمت هدف می‌رویم تا روی پاگرد فرود بیاید.
	if kairo.global_position.y <= target.y + float(TILE) * 0.75:
		_steer_to(target, kairo)
		return

	var toward := "move_left" if _climb_dir < 0 else "move_right"
	var away := "move_right" if _climb_dir < 0 else "move_left"

	if kairo.state == PlatformActor.State.WALL_SLIDE:
		# چسبیده‌ایم: پرش بزن و جهت را **همان به سمت دیوار** نگه دار تا شرط
		# sliding در فریم بعد هم برقرار بماند و پرش واقعاً اجرا شود.
		_request_jump(12)
		_press(toward)
		_release(away)
		_wj_armed = true
		return

	if kairo.is_on_floor():
		# کف شفت: دیوارها فقط از سطر ۱۱ به بالا وجود دارند (پایهٔ ستون ۹–۱۱ و
		# بلوک ۱۵–۲۹ هر دو از سطر ۴ تا ۱۱/۱۳). پس روی کف **نباید** به سمت
		# دیوار فشار داد — جای دیوار خالی است و بازیگر از شفت بیرون می‌رود و
		# در گوشهٔ اتاق گیر می‌کند. اینجا فقط صاف بالا می‌پریم و x شفت را
		# نگه می‌داریم؛ فشار به دیوار پس از بلند شدن اعمال می‌شود (D-032).
		_request_jump(16)
		_steer_to(Vector2(_climb_x, kairo.global_position.y), kairo)
		_wj_armed = false
		return

	# در هوا: به دیوار هدف فشار بده تا بچسبد
	_press(toward)
	_release(away)


## اگر هدف قابل‌هکی در برد است، ابزار را hack کن و دکمهٔ عمل را نگه دار (§۶).
func _maybe_hack(kairo) -> void:
	if not GameState.is_tool_unlocked("hack") or kairo.hack == null:
		return
	# حالت HACK کایرو را ثابت می‌کند (§۶). در هوا یا در میانهٔ بالا رفتن از شفت
	# این یعنی سقوط. فقط روی زمین و بیرون از wallclimb هک می‌کنیم.
	if not kairo.is_on_floor() or _current_action() == "wallclimb":
		return
	var t = kairo.hack.current_target
	if t == null:
		return
	var want := false
	if t is Gate and not (t as Gate).is_open:
		# فقط دری که سر راه است، نه در تزئینی بیرون مسیر
		want = _gate_on_path(t as Gate, kairo)
	elif t is Drone and not (t as Drone).is_disabled:
		# هک ۰٫۶ ثانیه کایرو را **ثابت** می‌کند (§۶). اگر پهپاد در این مدت
		# برسد، همان هک او را می‌کشد. پس فقط وقتی هک می‌کنیم که زمان رسیدن
		# پهپاد بیشتر از مدت هک باشد (D-041).
		want = _safe_to_hack_drone(t as Drone, kairo)
	if not want:
		return
	if kairo.active_tool != "hack":
		kairo.set_active_tool("hack")
	# ۰٫۶ ثانیه نگه‌داشتن + حاشیه؛ کایرو در این مدت ثابت است (§۶)
	_hack_hold = maxi(_hack_hold, 44)


## نزدیک‌ترین مانعِ رد نشدهٔ پیش رو؛ INF اگر نیست.
func _gate_ahead(kairo, target: Vector2) -> float:
	if game.room == null:
		return INF
	var p: Vector2 = kairo.global_position
	var rightward: bool = target.x >= p.x
	var best := INF
	for h in game.room.hazards:
		if not is_instance_valid(h):
			continue
		var hx: float = 0.0
		if h is Laser:
			var rect := (h as Laser).beam_global_rect()
			if p.y < rect.position.y - float(TILE) or p.y > rect.end.y + float(TILE):
				continue
			hx = rect.get_center().x
		elif h is Drone:
			var d: Vector2 = (h as Drone).global_position
			if absf(d.y - p.y) > 1.8 * float(TILE):
				continue
			hx = d.x
		else:
			continue
		if _gates_done.has(_gate_key(hx)):
			continue
		# فقط مانع‌های پیش رو و در ۶ کاشی
		var ahead: float = (hx - p.x) if rightward else (p.x - hx)
		if ahead < 0.5 * float(TILE) or ahead > 6.0 * float(TILE):
			continue
		if ahead < best:
			best = ahead
			_gate_hx = hx
	return _gate_hx if best != INF else INF


func _gate_key(hx: float) -> int:
	return int(round(hx / float(TILE)))


## ایستادن در فاصلهٔ امن، جمع کردن ایلارا، هک پهپاد، انتظار تا باز شدن پنجره.
func _phase_gate_wait(kairo) -> void:
	_gate_frames += 1
	var p: Vector2 = kairo.global_position
	var rightward: bool = _gate_hx >= p.x
	# فاصلهٔ ایستادن: ۲٫۵ کاشی پیش از مانع
	var standoff: float = _gate_hx + 2.5 * float(TILE)
	if rightward:
		standoff = _gate_hx - 2.5 * float(TILE)
	# فاصلهٔ ایستادن ثابت کافی نیست: پهپاد L3R1 بین ستون ۸ و ۱۴ گشت می‌زند و
	# «۲٫۵ کاشی پیش از لیزر ستون ۱۱» یعنی ستون ۸٫۵ — وسط مسیر پهپاد. پس اگر
	# جای فعلی خطرناک است عقب می‌نشینیم، وگرنه سر جا می‌مانیم (D-040).
	var retreat := _retreat_dir(kairo)
	if retreat > 0:
		_press("move_right")
		_release("move_left")
	elif retreat < 0:
		_press("move_left")
		_release("move_right")
	else:
		_steer_to(Vector2(standoff, p.y), kairo)
	_maybe_hack(kairo)

	# شرط‌های عبور
	var ilara_ready: bool = _ilara_close(kairo, 2.0)
	var drones_ready := true
	var laser_ready := true
	var need_off: float = float(Ilara.FOLLOW_DELAY_FRAMES) / 60.0 + 0.25
	for h in game.room.hazards:
		if not is_instance_valid(h):
			continue
		if h is Drone and not (h as Drone).is_disabled:
			var drone := h as Drone
			if absf(drone.global_position.y - p.y) > 1.8 * float(TILE):
				continue
			# «دور بودن» کافی نیست: پهپاد برمی‌گردد. باید در حال **دور شدن** و
			# دست‌کم ۳٫۵ کاشی آن‌طرف‌تر باشد تا ۱٫۷۱ ثانیهٔ لازم برای عبور هر دو
			# نفر جا شود (گشت ۶ کاشی = ۲٫۴ ثانیه پشت سرش باز است) — D-041.
			var ddx: float = drone.global_position.x - p.x
			var away: bool = (ddx > 0.0 and drone.velocity.x > 0.0) \
				or (ddx < 0.0 and drone.velocity.x < 0.0)
			if absf(ddx) < 3.5 * float(TILE) or not away:
				drones_ready = false
		elif h is Laser and absf((h as Laser).beam_global_rect().get_center().x - _gate_hx) <= float(TILE):
			if (h as Laser).off_time_left() < need_off:
				laser_ready = false

	# اگر مجبور به عقب نشستن شده‌ایم، «رسیدن به فاصلهٔ ایستادن» شرط نیست
	var at_standoff: bool = retreat != 0 or absf(p.x - standoff) < 1.5 * float(TILE)
	if (ilara_ready and drones_ready and laser_ready and at_standoff) 			or _gate_frames > 600:
		phase = Phase.GATE_RUN
		_gate_frames = 0
		log_lines.append("  دروازهٔ مانع در کاشی %d باز شد (ایلارا %s، پهپاد %s، لیزر %s)"
			% [_gate_key(_gate_hx), str(ilara_ready), str(drones_ready), str(laser_ready)])


## عبور یکسره: تا ۲٫۵ کاشی آن‌سوی مانع هیچ تصمیم تازه‌ای گرفته نمی‌شود.
func _phase_gate_run(kairo) -> void:
	_gate_frames += 1
	var p: Vector2 = kairo.global_position
	var wp := _current_wp()
	var target: Vector2 = Vector2(_gate_hx + 64.0, p.y)
	if not wp.is_empty():
		target = _cell_px(wp.get("cell", [0, 0]))
	var rightward: bool = target.x >= _gate_hx
	_steer_to(target, kairo)
	if kairo.is_on_floor() and kairo.is_on_wall():
		_request_jump(16)

	var past: bool = p.x < _gate_hx - 2.5 * float(TILE)
	if rightward:
		past = p.x > _gate_hx + 2.5 * float(TILE)
	if past or _gate_frames > 180:
		_gates_done[_gate_key(_gate_hx)] = true
		phase = Phase.RUN
		_gate_frames = 0


## اگر داخل ناحیهٔ خطر ایستاده‌ایم، به کدام سمت عقب بنشینیم؟ ۰ = همین‌جا امن است.
func _retreat_dir(kairo) -> int:
	if game.room == null:
		return 0
	var p: Vector2 = kairo.global_position
	for h in game.room.hazards:
		if not is_instance_valid(h):
			continue
		if h is Laser:
			var rect := (h as Laser).beam_global_rect()
			if p.y < rect.position.y - float(TILE) or p.y > rect.end.y + float(TILE):
				continue
			var cx: float = rect.get_center().x
			# یک کاشی و نیم حاشیه از پرتو
			if absf(p.x - cx) <= 1.5 * float(TILE):
				return -1 if p.x <= cx else 1
		elif h is Drone and not (h as Drone).is_disabled:
			var d: Vector2 = (h as Drone).global_position
			if absf(d.y - p.y) > 1.6 * float(TILE):
				continue
			if absf(p.x - d.x) <= 2.0 * float(TILE):
				return -1 if p.x <= d.x else 1
	return 0


## ایلارا نزدیک است؟ (یا اصلاً همراهی نداریم)
func _ilara_close(kairo, tiles: float) -> bool:
	if game.ilara == null or game.ilara.mode == Ilara.Mode.STAY:
		return true
	return absf(game.ilara.global_position.x - kairo.global_position.x) <= tiles * float(TILE)


## آیا کایرو از مانعی گذشته که ایلارا هنوز نگذشته است؟
func _ilara_behind_hazard(p: Vector2, target: Vector2) -> bool:
	var ix: float = game.ilara.global_position.x
	var rightward: bool = target.x >= p.x
	for h in game.room.hazards:
		if not is_instance_valid(h):
			continue
		var hx: float = 0.0
		if h is Laser:
			hx = (h as Laser).beam_global_rect().get_center().x
		elif h is Drone:
			# پهپاد خاموش بی‌خطر است و لازم نیست منتظرش بمانیم
			if (h as Drone).is_disabled:
				continue
			hx = (h as Drone).global_position.x
		else:
			continue
		if absf(h.global_position.y - p.y) > 4.0 * float(TILE):
			continue
		if rightward:
			if p.x > hx + float(TILE) and ix < hx - float(TILE):
				return true
		else:
			if p.x < hx - float(TILE) and ix > hx + float(TILE):
				return true
	return false


## آیا مانعی (لیزر یا پهپاد فعال) در فاصلهٔ داده‌شده هست؟
func _hazard_near(p: Vector2, dist: float) -> bool:
	if game.room == null:
		return false
	for h in game.room.hazards:
		if not is_instance_valid(h):
			continue
		if h is Laser:
			var rect := (h as Laser).beam_global_rect()
			if absf(rect.get_center().x - p.x) <= dist \
					and p.y >= rect.position.y - float(TILE) \
					and p.y <= rect.end.y + float(TILE):
				return true
		elif h is Drone and not (h as Drone).is_disabled:
			var d: Vector2 = (h as Drone).global_position
			if absf(d.x - p.x) <= dist and absf(d.y - p.y) <= 2.0 * float(TILE):
				return true
	return false


## آیا فرصت هک کردن این پهپاد هست؟ هک ۰٫۶ ثانیه بی‌حرکتی می‌خواهد.
func _safe_to_hack_drone(drone: Drone, kairo) -> bool:
	var hack_time: float = Settings.param("hack", "hold_time", 0.6) + 0.25
	var dx: float = drone.global_position.x - kairo.global_position.x
	var dist: float = absf(dx) - float(TILE)
	if dist <= 0.0:
		return false
	var vx: float = drone.velocity.x
	# پهپاد به ما نزدیک می‌شود؟
	var closing: bool = (dx > 0.0 and vx < 0.0) or (dx < 0.0 and vx > 0.0)
	if not closing:
		return true
	var speed: float = absf(vx)
	if speed < 1.0:
		return true
	return dist / speed > hack_time


## آیا این در روی مسیر فعلی ما است؟ در L2R1 دروازه بالای پایهٔ ستون و بیرون
## مسیر بحرانی است (DECISIONS.md: D-003)، و هک کردنش فقط وقت تلف می‌کند.
func _gate_on_path(gate: Gate, kairo) -> bool:
	var wp := _current_wp()
	if wp.is_empty():
		return false
	var target := _cell_px(wp.get("cell", [0, 0]))
	var lo := minf(kairo.global_position.x, target.x) - 8.0
	var hi := maxf(kairo.global_position.x, target.x) + 8.0
	var g: Vector2 = gate.global_position
	return g.x >= lo and g.x <= hi and absf(g.y - kairo.global_position.y) < 2.0 * float(TILE)


## ----- فازهای همراه -----

func _crumble_ahead(kairo) -> bool:
	if _crumble_cols.is_empty() or game.ilara == null:
		return false
	var col := int(kairo.global_position.x / TILE)
	var first: int = int(_crumble_cols[0])
	# دو کاشی پیش از ورود به میدان
	return col >= first - 3 and col < first


func _phase_stay(kairo) -> void:
	# نگه‌داشتن دکمهٔ همراه تا دستور «بمان» ثبت شود
	if _companion_hold > 0:
		return
	if game.ilara != null and game.ilara.mode == Ilara.Mode.STAY:
		phase = Phase.RUN
		log_lines.append("  ایلارا ایستاد؛ عبور از میدان")
	else:
		_companion_hold = 24


func _phase_wait_crumble(kairo) -> void:
	_wait -= 1
	if _wait <= 0:
		phase = Phase.CALL_COME


func _phase_call_come(kairo) -> void:
	# یک ضربهٔ کوتاه = «بیا»
	_press("companion")
	if _companion_hold == 0:
		_companion_hold = 3
	if game.ilara != null and game.ilara.mode == Ilara.Mode.FOLLOW:
		_release("companion")
		phase = Phase.WAIT_ILARA
		_wait = 60 * 8
		log_lines.append("  «بیا» زده شد؛ انتظار برای ایلارا")


func _phase_wait_ilara(kairo) -> void:
	_wait -= 1
	var close := false
	if game.ilara != null:
		close = absf(game.ilara.global_position.x - kairo.global_position.x) < 3.0 * TILE
	if close or _wait <= 0:
		phase = Phase.RUN
		log_lines.append("  ایلارا رسید؛ ادامهٔ مسیر")


## روی خروج ایستادن تا هر دو شخصیت برسند (§۸: needs_both)
func _phase_at_exit(kairo) -> void:
	var ex := _exit_px()
	_steer_to(ex, kairo)
	# اگر ایلارا در حالت بمان مانده، صدایش کن
	if game.ilara != null and game.ilara.mode == Ilara.Mode.STAY:
		_press("companion")
		if _companion_hold == 0:
			_companion_hold = 3


func _at_exit_cell(kairo) -> bool:
	var ex := _exit_px()
	return absf(kairo.global_position.x - ex.x) < 1.5 * TILE


func _exit_px() -> Vector2:
	var rp := room_plan(_room_id)
	var exits: Array = rp.get("exits", [])
	if exits.is_empty():
		return Vector2(28 * TILE, 13 * TILE)
	var cell: Array = exits[0]
	return Vector2((int(cell[0]) + 0.5) * TILE, (int(cell[1]) + 0.5) * TILE)


## ----- گیر کردن -----

func _check_stuck(kairo) -> void:
	if kairo.global_position.distance_to(_last_pos) > 1.0:
		_stuck = 0
		_last_pos = kairo.global_position
		return
	_stuck += 1
	if _stuck < STUCK_FRAMES:
		return
	_stuck = 0
	skips += 1
	if skips > MAX_SKIPS:
		phase = Phase.DONE
		log_lines.append("  شکست: سقف رد کردن کنش (%d) پر شد در اتاق %s"
			% [MAX_SKIPS, _room_id])
		return
	var wp := _current_wp()
	log_lines.append("  گیر کرد در %s → %s؛ رد می‌شود (%d)"
		% [_current_action(), str(wp.get("cell", [])), skips])
	_advance()
	# یک پرش برای در آمدن از گیر
	_request_jump(14 + (jitter % 6))


## ----- ورودی -----

## درخواست پرش تازه؛ خود `_tick_holds` یک فریم رها کردن را تضمین می‌کند.
##
## اگر پرشی در جریان باشد درخواست تازه نادیده گرفته می‌شود. بدون این نگهبان،
## صدا زدن هر فریم باعث می‌شد دکمه یک فریم فشرده و فریم بعد رها شود، و
## `JUMP_CUT` (ضرب ۰٫۴۵ روی سرعت عمودی) ارتفاع را به یک‌پنجم می‌رساند؛
## بازیگر عملاً از زمین بلند نمی‌شد (DECISIONS.md: D-032).
func _request_jump(hold: int) -> void:
	if _jump_hold > 0 or _jump_pending > 0:
		return
	if _held["jump"]:
		_release("jump")
		_jump_pending = hold
	else:
		_jump_hold = hold


func _press(a: String) -> void:
	if not _held[a]:
		_held[a] = true
		Input.action_press(a)


func _release(a: String) -> void:
	if _held[a]:
		_held[a] = false
		Input.action_release(a)


func _release_all() -> void:
	for a in ACTIONS:
		_release(a)


func _tick_holds() -> void:
	# پرشِ تازه نیاز به یک فریم رها کردن دارد: اگر دکمه از پرش قبلی هنوز
	# نگه داشته شده باشد، `is_action_just_pressed` false است و بافر پرش
	# مسلح نمی‌شود (DECISIONS.md: D-032).
	if _jump_pending > 0 and not _held["jump"]:
		_jump_hold = _jump_pending
		_jump_pending = 0

	if _jump_hold > 0:
		_press("jump")
		_jump_hold -= 1
	else:
		_release("jump")

	if _hack_hold > 0:
		_press("action")
		_hack_hold -= 1
	elif not _held_action_wanted():
		_release("action")

	if _companion_hold > 0:
		_press("companion")
		_companion_hold -= 1
	else:
		_release("companion")


func _held_action_wanted() -> bool:
	return _current_action() == "dash"


## ورودی این فریم به‌عنوان یک بایت ضبط می‌شود — همان `solution_path` §۲۲
func _record() -> void:
	if not record_enabled:
		return
	var mask := 0
	for i in ACTIONS.size():
		if _held[ACTIONS[i]]:
			mask |= 1 << i
	recorded.append(mask)


## ----- بازپخش حلقه‌باز -----

## یک فریم از رشتهٔ ضبط‌شده را پخش می‌کند. برای اثبات تکرارپذیری (سند ۰۵).
func replay_frame(index: int) -> bool:
	if index >= recorded.size():
		_release_all()
		return false
	var mask: int = recorded[index]
	for i in ACTIONS.size():
		if (mask & (1 << i)) != 0:
			_press(ACTIONS[i])
		else:
			_release(ACTIONS[i])
	return true


func recorded_to_base64() -> String:
	return Marshalls.raw_to_base64(recorded)


func load_recorded_base64(b64: String) -> void:
	recorded = Marshalls.base64_to_raw(b64)
