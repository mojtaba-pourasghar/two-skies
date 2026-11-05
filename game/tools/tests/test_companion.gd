## آزمون ایلارا و قانون همراهی — گام ۳
##
##   godot --headless res://tools/tests/test_companion.tscn
extends Node2D

## اندازهٔ کاشی از ثابت بازی می‌آید، نه عدد دست‌نویس: مقیاس جهان یک بار
## عوض شد (CLAUDE.md قانون ۳) و این عدد عقب ماند، پس «بر حسب کاشی»ها
## دو برابر خوانده شدند.
const TILE: int = KairoConst.TILE
const FLOOR_ROW: int = 14

var _kairo: Kairo
var _ilara: Ilara
var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	_build_world()
	_kairo = load("res://actors/kairo/kairo.tscn").instantiate()
	add_child(_kairo)
	_ilara = load("res://actors/ilara/ilara.tscn").instantiate()
	add_child(_ilara)
	_ilara.kairo = _kairo
	await get_tree().physics_frame
	await _run_all()
	_report()


func _build_world() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = Layers.GROUND
	body.collision_mask = 0
	add_child(body)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(60 * TILE, 3 * TILE)
	cs.shape = r
	cs.position = Vector2(30 * TILE, (FLOOR_ROW + 1.5) * TILE)
	body.add_child(cs)


func _floor_y() -> float:
	return float(FLOOR_ROW * TILE) - KairoConst.HITBOX.y * 0.5


func _reset(col: float) -> void:
	for a in ["move_left", "move_right", "jump", "action", "companion"]:
		Input.action_release(a)
	_kairo.reset_to(Vector2(col * TILE, _floor_y()))
	_ilara.reset_to(Vector2(col * TILE, _floor_y()))
	for i in 6:
		await get_tree().physics_frame


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
	print("— آزمون قانون همراهی —")
	await _test_constants()
	await _test_follow_delay()
	await _test_follows_path()
	await _test_stay_and_come()
	await _test_teleport_on_distance()
	await _test_no_dash_no_walljump()
	await _test_replay_determinism()


## ثابت‌های خودش را دارد، نه ثابت‌های کایرو (§۵)
func _test_constants() -> void:
	# عدد را از پروفایل می‌خوانیم، نه دست‌نویس: مقیاس جهان یک بار عوض شد
	# (CLAUDE.md قانون ۳) و سنجهٔ دست‌نویس شکست، در حالی که رفتار درست بود.
	# چیزی که §۵ می‌گوید «ایلارا ثابت‌های خودش را دارد» است، نه یک عدد خاص.
	var prof: Dictionary = Settings.tuning.get("profiles", {}).get(
		CameraDirector.PROFILE[CameraDirector.MODE_SIDE], {})
	var want_speed := float((prof.get("ilara", {}) as Dictionary).get("RUN_SPEED", 0.0))
	var want_jump := float((prof.get("ilara", {}) as Dictionary).get("JUMP_VELOCITY", 0.0))
	_check("سرعت دویدن ایلارا از پروفایل می‌آید",
		want_speed > 0.0 and is_equal_approx(_ilara.run_speed, want_speed),
		"= %.0f (پروفایل %.0f، کایرو %.0f)" % [_ilara.run_speed, want_speed, _kairo.run_speed])
	_check("پرش ایلارا از پروفایل می‌آید",
		want_jump < 0.0 and is_equal_approx(_ilara.jump_velocity, want_jump),
		"= %.0f (پروفایل %.0f، کایرو %.0f)" % [_ilara.jump_velocity, want_jump, _kairo.jump_velocity])
	_check("ایلارا کندتر از کایرو نیست و ثابت‌هایش جداست",
		not is_equal_approx(_ilara.run_speed, _kairo.run_speed),
		"(ایلارا %.0f، کایرو %.0f)" % [_ilara.run_speed, _kairo.run_speed])


## تأخیر ۴۸ فریم: تا پر شدن صف، ایلارا تکان نمی‌خورد
func _test_follow_delay() -> void:
	await _reset(4)
	var ilara_x0 := _ilara.global_position.x
	Input.action_press("move_right")
	await _step(40)
	var early_dx := absf(_ilara.global_position.x - ilara_x0)
	await _step(40)
	var later_dx := absf(_ilara.global_position.x - ilara_x0)
	Input.action_release("move_right")
	_check("تا پر شدن صف ۴۸ فریمی حرکت نمی‌کند", early_dx <= 2.0,
		"(جابه‌جایی پس از ۴۰ فریم = %.1f px)" % early_dx)
	_check("پس از تأخیر دنبال می‌کند", later_dx > 8.0,
		"(جابه‌جایی پس از ۸۰ فریم = %.1f px)" % later_dx)


## روی رد پای کایرو می‌ماند و پشت سر او است
func _test_follows_path() -> void:
	await _reset(4)
	Input.action_press("move_right")
	await _step(150)
	var dx := _kairo.global_position.x - _ilara.global_position.x
	Input.action_release("move_right")
	await _step(60)
	_check("پشت سر کایرو می‌ماند", dx > 0.0, "= %.0f px عقب‌تر" % dx)
	_check("فاصله کمتر از ۱۲ کاشی می‌ماند", dx < 12.0 * TILE,
		"= %.1f کاشی" % (dx / TILE))
	_check("روی همان ارتفاع می‌ماند",
		absf(_kairo.global_position.y - _ilara.global_position.y) < TILE,
		"= %.1f px" % absf(_kairo.global_position.y - _ilara.global_position.y))


## «بمان» با نگه‌داشتن، «بیا» با یک ضربه (§۵)
func _test_stay_and_come() -> void:
	await _reset(4)
	_ilara.command_stay()
	_check("حالت بمان", _ilara.mode == Ilara.Mode.STAY, "")
	var x_at_stay := _ilara.global_position.x
	Input.action_press("move_right")
	await _step(120)
	Input.action_release("move_right")
	var stayed := absf(_ilara.global_position.x - x_at_stay) < 2.0
	_check("در حالت بمان همان‌جا می‌ماند", stayed,
		"(جابه‌جایی %.1f px)" % absf(_ilara.global_position.x - x_at_stay))
	_ilara.command_come()
	_check("حالت بیا", _ilara.mode == Ilara.Mode.FOLLOW, "")


## فاصلهٔ افقی بیش از ۱۲ کاشی → ظاهر شدن کنار کایرو (§۵)
func _test_teleport_on_distance() -> void:
	await _reset(4)
	# lambda در GDScript متغیر محلی را **کپی** می‌گیرد، پس شمارنده در یک آرایه
	# نگه داشته می‌شود تا با ارجاع تغییر کند.
	var teleports := [0]
	_ilara.teleported.connect(func(): teleports[0] += 1)
	_ilara.command_stay()
	# کایرو دور می‌شود در حالی که ایلارا ایستاده
	Input.action_press("move_right")
	await _step(200)
	Input.action_release("move_right")
	var far := absf(_kairo.global_position.x - _ilara.global_position.x)
	_check("در حالت بمان teleport نمی‌شود", teleports[0] == 0,
		"(فاصله %.1f کاشی)" % (far / TILE))
	# حالا «بیا»: فاصله بیش از ۱۲ کاشی است، پس باید کنار کایرو ظاهر شود
	_ilara.command_come()
	await _step(5)
	var near := absf(_kairo.global_position.x - _ilara.global_position.x)
	# ایلارا یک کاشی کنار کایرو می‌نشیند، ولی کایرو در همان ۵ فریمِ انتظار
	# به دویدنش ادامه می‌دهد. حد مجاز را از همین دو عدد می‌سازیم تا با عوض
	# شدن سرعت یا مقیاس نشکند.
	var drift := _kairo.run_speed * 5.0 / 60.0
	var allowed := float(TILE) + drift + 8.0
	_check("با فاصلهٔ بیش از ۱۲ کاشی کنار کایرو ظاهر می‌شود",
		teleports[0] >= 1 and near <= allowed,
		"(teleport=%d، فاصلهٔ تازه %.1f کاشی، حد %.1f کاشی)"
			% [teleports[0], near / TILE, allowed / TILE])


## در فصل ۱ نه دش دارد نه پرش دیواری (§۵)
func _test_no_dash_no_walljump() -> void:
	GameState.unlock_tool("wall_jump")
	GameState.unlock_tool("dash")
	_kairo._refresh_tools()
	_check("ایلارا دش ندارد", not _ilara.can_dash, "")
	_check("ایلارا پرش دیواری ندارد", not _ilara.can_wall_jump, "")
	_check("کایرو هر دو را دارد", _kairo.can_dash and _kairo.can_wall_jump, "")


## بازپخش باید کاملاً تکرارپذیر باشد (معیار پذیرش سند ۰۵)
func _test_replay_determinism() -> void:
	var results: Array[Vector2] = []
	for trial in 10:
		await _reset(4)
		Input.action_press("move_right")
		await _step(60)
		Input.action_press("jump")
		await _step(8)
		Input.action_release("jump")
		await _step(80)
		Input.action_release("move_right")
		await _step(20)
		results.append(_ilara.global_position.round())
	var same := true
	for r in results:
		if not r.is_equal_approx(results[0]):
			same = false
	_check("تکرارپذیری بازپخش ایلارا در ۱۰ اجرا", same, "= %s" % str(results[0]))


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
