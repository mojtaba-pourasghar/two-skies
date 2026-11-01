## آزمون خودکار فیزیک و ماشین حالت — گام ۱
##
## با موتور واقعی و بدون پنجره اجرا می‌شود:
##   godot --headless res://tools/tests/test_physics.tscn
## از همان مسیر ورودی‌ای استفاده می‌کند که دکمه‌های لمسی استفاده می‌کنند
## (Input.action_press)، پس خود کد بازی سنجیده می‌شود نه یک نسخهٔ موازی.
extends Node2D

const TILE: int = 16
const FLOOR_ROW: int = 14

var _kairo: Kairo
var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	_build_world()
	_kairo = load("res://actors/kairo/kairo.tscn").instantiate()
	add_child(_kairo)
	await get_tree().physics_frame
	await _run_all()
	_report()


func _build_world() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	# کف سراسری روی سطر ۱۴
	_add_box(body, Vector2(0, FLOOR_ROW * TILE), Vector2(40 * TILE, 3 * TILE))
	# دو دیوار موازی برای آزمون پرش دیواری: فاصلهٔ ۳ کاشی
	_add_box(body, Vector2(20 * TILE, 4 * TILE), Vector2(TILE, 10 * TILE))
	_add_box(body, Vector2(24 * TILE, 4 * TILE), Vector2(TILE, 10 * TILE))


func _add_box(parent: Node, top_left: Vector2, size: Vector2) -> void:
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	cs.position = top_left + size * 0.5
	parent.add_child(cs)


func _floor_y() -> float:
	return float(FLOOR_ROW * TILE) - KairoConst.HITBOX.y * 0.5


func _place(col: float) -> void:
	_release_all()
	_kairo.reset_to(Vector2(col * TILE, _floor_y()))
	# چند فریم تا روی کف بنشیند و is_on_floor درست شود
	for i in 6:
		await get_tree().physics_frame


func _release_all() -> void:
	for a in ["move_left", "move_right", "jump", "action", "companion"]:
		Input.action_release(a)


func _step(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  ✔ %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  ✘ %s %s" % [label, detail])


func _run_all() -> void:
	print("— آزمون فیزیک (پروفایل %s) —" % KairoConst.active_profile)
	await _test_jump_height()
	await _test_jump_cut()
	await _test_jump_range()
	await _test_coyote()
	await _test_jump_buffer()
	await _test_wall_jump()
	await _test_death_respawn()
	await _test_determinism()


## ارتفاع پرش باید با عدد §۳ بخواند (۵۲px ≈ ۳٫۲۵ کاشی)
func _test_jump_height() -> void:
	await _place(5)
	var y0 := _kairo.global_position.y
	Input.action_press("jump")
	var apex := y0
	for i in 60:
		await get_tree().physics_frame
		apex = minf(apex, _kairo.global_position.y)
		if _kairo.velocity.y > 0.0 and _kairo.is_on_floor():
			break
	_release_all()
	var h := y0 - apex
	var want := KairoConst.jump_height_px()
	_check("ارتفاع پرش", absf(h - want) <= 4.0,
		"= %.1f px (انتظار %.1f ± 4)" % [h, want])


## رها کردن پرش در هوا ارتفاع را کم می‌کند — پرش متغیر (§۲)
func _test_jump_cut() -> void:
	await _place(5)
	var y0 := _kairo.global_position.y
	Input.action_press("jump")
	await _step(4)
	Input.action_release("jump")
	var apex := _kairo.global_position.y
	for i in 60:
		await get_tree().physics_frame
		apex = minf(apex, _kairo.global_position.y)
		if _kairo.is_on_floor() and _kairo.velocity.y >= 0.0:
			break
	_release_all()
	var h := y0 - apex
	_check("پرش کوتاه کمتر از پرش کامل", h < KairoConst.jump_height_px() * 0.85,
		"= %.1f px" % h)


## برد افقی پرش در حداکثر سرعت ≥ ۴٫۵ کاشی، چون طراح مرحله اجازه دارد
## شکاف تا ۴٫۵ کاشی بدون ابزار بگذارد (§۳)
func _test_jump_range() -> void:
	await _place(3)
	Input.action_press("move_right")
	await _step(40)  # تا رسیدن به حداکثر سرعت
	var x0 := _kairo.global_position.x
	Input.action_press("jump")
	await _step(3)
	var airborne := true
	for i in 90:
		await get_tree().physics_frame
		if _kairo.is_on_floor():
			airborne = false
			break
	var dx := _kairo.global_position.x - x0
	_release_all()
	var tiles := dx / float(TILE)
	_check("برد افقی پرش", tiles >= 4.5,
		"= %.2f کاشی (حداقل لازم ۴٫۵)" % tiles)


## پرش تا ۰٫۱۰ ثانیه پس از ترک لبه هنوز کار می‌کند (COYOTE_TIME)
func _test_coyote() -> void:
	# از لبهٔ کف اصلی رد می‌شویم: یک سکوی کوچک جدا می‌سازیم
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	_add_box(body, Vector2(2 * TILE, 8 * TILE), Vector2(4 * TILE, TILE))
	_release_all()
	_kairo.reset_to(Vector2(5.0 * TILE, 8 * TILE - KairoConst.HITBOX.y * 0.5))
	await _step(6)
	var grounded := _kairo.is_on_floor()
	Input.action_press("move_right")
	# تا لحظه‌ای که از لبه جدا شود
	var left_ledge := false
	for i in 30:
		await get_tree().physics_frame
		if not _kairo.is_on_floor():
			left_ledge = true
			break
	var coyote_frames := int(round(KairoConst.COYOTE_TIME * 60.0))
	await _step(maxi(coyote_frames - 2, 1))
	Input.action_press("jump")
	await _step(2)
	var jumped := _kairo.velocity.y < -50.0
	_release_all()
	body.queue_free()
	_check("coyote time", grounded and left_ledge and jumped,
		"(روی زمین=%s، ترک لبه=%s، پرش=%s)" % [grounded, left_ledge, jumped])


## پرش ۰٫۱۲ ثانیه جلوتر ثبت می‌شود و هنگام فرود اجرا می‌شود (§۲)
func _test_jump_buffer() -> void:
	await _place(5)
	# یک پرش می‌کنیم تا در هوا باشیم
	Input.action_press("jump")
	await _step(2)
	Input.action_release("jump")
	# تا نزدیک فرود صبر می‌کنیم
	for i in 60:
		await get_tree().physics_frame
		if _kairo.velocity.y > 150.0:
			break
	# پرش را درست پیش از فرود می‌زنیم
	Input.action_press("jump")
	await _step(1)
	Input.action_release("jump")
	var bounced := false
	for i in 12:
		await get_tree().physics_frame
		if _kairo.velocity.y < -50.0:
			bounced = true
			break
	_release_all()
	_check("بافر پرش", bounced, "(پرش پیش از فرود در لحظهٔ فرود اجرا شد=%s)" % bounced)


## پرش دیواری: سرعت افقی به سمت مخالف دیوار و سرعت عمودی منفی (§۴)
func _test_wall_jump() -> void:
	GameState.unlock_tool("wall_jump")
	_kairo._refresh_tools()
	_release_all()
	# کنار دیوار سمت چپِ شکافِ بین دو دیوار (دیوار در ستون ۲۰)
	_kairo.reset_to(Vector2(21.4 * TILE, 6 * TILE))
	await _step(2)
	Input.action_press("move_left")
	var sliding := false
	for i in 40:
		await get_tree().physics_frame
		if _kairo.state == PlatformActor.State.WALL_SLIDE:
			sliding = true
			break
	var capped := _kairo.velocity.y <= KairoConst.WALL_SLIDE_MAX + 1.0
	var slide_vy := _kairo.velocity.y
	Input.action_press("jump")
	await _step(2)
	var vx := _kairo.velocity.x
	var vy := _kairo.velocity.y
	_release_all()
	_check("سُر خوردن روی دیوار", sliding and capped,
		"(حالت=%s، vy=%.0f ≤ %.0f)" % [sliding, slide_vy, KairoConst.WALL_SLIDE_MAX])
	_check("پرش دیواری به سمت مخالف", vx > 50.0 and vy < -100.0,
		"(vx=%.0f > 0، vy=%.0f < 0)" % [vx, vy])


## مرگ فوری و شروع دوباره در RESPAWN_TIME (§۳)
func _test_death_respawn() -> void:
	await _place(5)
	_kairo.die()
	_check("حالت مرگ", _kairo.state == PlatformActor.State.DEAD, "")
	var want := int(round(KairoConst.RESPAWN_TIME * 60.0))
	var n := 0
	for i in 120:
		await get_tree().physics_frame
		n += 1
		if _kairo.state != PlatformActor.State.DEAD:
			break
	_check("زمان شروع دوباره", absi(n - want) <= 1,
		"= %d فریم (%.2f ثانیه؛ انتظار %d)" % [n, n / 60.0, want])
	# دو سند دو بودجهٔ متفاوت می‌دهند (DECISIONS.md: D-004):
	#   سند ۰۲ §۳ — RESPAWN_TIME=0.35 و «شروع دوباره در کمتر از ۰٫۴ ثانیه»
	#   سند ۰۱ و ۰۵ — «ریستارت زیر ۰٫۳ ثانیه»
	# مقدار فعال از سند ۰۲ است (قید ۲ کاربر)، پس سنجه هم به بودجهٔ همان سند است.
	var budget_02: float = Settings.fairness().get("respawn_budget_spec02", 0.4)
	_check("ریستارت در بودجهٔ سند ۰۲ (< ۰٫۴s)", (n / 60.0) <= budget_02 + 0.001,
		"= %.3f ثانیه، بودجه %.3f" % [n / 60.0, budget_02])
	var budget_05: float = Settings.fairness().get("respawn_budget_doc01_doc05", 0.3)
	var meets_05: bool = (n / 60.0) <= budget_05 + 0.001
	print("  i بودجهٔ سند ۰۱/۰۵ (< ۰٫۳s): %s — با پروفایل design01 برآورده می‌شود"
		% ("برآورده" if meets_05 else "برآورده نمی‌شود"))


## تکرارپذیری: ده بار اجرای یکسان ورودی‌ها باید نتیجهٔ یکسان بدهد (معیار پذیرش سند ۰۵)
func _test_determinism() -> void:
	var results: Array[Vector2] = []
	for trial in 10:
		await _place(4)
		Input.action_press("move_right")
		Input.action_press("jump")
		await _step(10)
		Input.action_release("jump")
		await _step(30)
		results.append(_kairo.global_position.round())
		_release_all()
	var same := true
	for r in results:
		if not r.is_equal_approx(results[0]):
			same = false
	_check("تکرارپذیری ۱۰ اجرا", same, "= %s" % str(results[0]))


func _report() -> void:
	print("")
	if _failures.is_empty():
		print("همهٔ %d سنجه قبول شد." % _checks)
		get_tree().quit(0)
	else:
		print("%d از %d سنجه رد شد:" % [_failures.size(), _checks])
		for f in _failures:
			print("  - %s" % f)
		get_tree().quit(1)
