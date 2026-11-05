## آزمون حل‌پذیری با موتور واقعی — docs/02_godot_spec.md §۲۲ و §۱۶
##
##   godot --headless res://tools/tests/test_solvable.tscn
##
## اعتبارسنج پایتونی (tools/validate_ch1.py) روی شبکهٔ کاشی کار می‌کند؛ این آزمون
## با فیزیک واقعی کار می‌کند و چیزهایی را می‌سنجد که فقط در موتور دیده می‌شوند:
## برخورد واقعی، زمان‌بندی مانع، هک کردن در، و این‌که ایلارا زنده می‌ماند.
extends Node2D

const LEVELS := ["res://levels/data/ch1_l1.json", "res://levels/data/ch1_l2.json",
	"res://levels/data/ch1_l3.json"]

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	for path in LEVELS:
		await _check_level(path)
	await _check_jump_reach()
	await _check_hazards()
	_report()


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  ✔ %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  ✘ %s %s" % [label, detail])


## هر اتاق بار می‌شود و با فیزیک واقعی بررسی می‌شود که نقطهٔ شروع روی زمین است،
## خروج وجود دارد، و موانع و اشیاء بدون خطا ساخته می‌شوند.
func _check_level(path: String) -> void:
	var loader := LevelLoader.new()
	var level := loader.load_level(path)
	print("\n— %s —" % path.get_file())
	if level.is_empty():
		_check("بارگذاری", false, str(loader.errors))
		return

	var tileset := LevelLoader.make_placeholder_tileset()
	var built_ok := true
	var hazard_counts := {"spike": 0, "crumble": 0, "laser": 0, "drone": 0, "gate": 0}
	var gem_total := 0

	for rd in level["rooms"]:
		var room := Room.new()
		add_child(room)
		room.build(level, rd, tileset)
		await get_tree().physics_frame

		for child in room.get_node("Objects").get_children():
			if child is Spike:
				hazard_counts["spike"] += 1
			elif child is Crumble:
				hazard_counts["crumble"] += 1
			elif child is Laser:
				hazard_counts["laser"] += 1
			elif child is Drone:
				hazard_counts["drone"] += 1
			elif child is Gate:
				hazard_counts["gate"] += 1
			elif child is Pickup and (child as Pickup).kind == "gem":
				gem_total += 1
			if String(child.name).begins_with("TODO_"):
				built_ok = false

		room.queue_free()
		await get_tree().process_frame

	_check("هیچ شیء مکان‌نگهداری نماند", built_ok, "")
	_check("موانع ساخته شدند",
		hazard_counts["spike"] + hazard_counts["crumble"] + hazard_counts["laser"]
		+ hazard_counts["drone"] + hazard_counts["gate"] > 0,
		"= %s" % str(hazard_counts))
	_check("گوهرها ساخته شدند", gem_total > 0, "= %d گوهر" % gem_total)


## سنجهٔ پرش که کاربر خواست: چند کاشی بالا و چند کاشی افقی، اندازه‌گیری در موتور.
## سند §۳ ارتفاع ۳٫۲۵ و برد ۵ کاشی می‌دهد؛ فرض مولّد فصل ۲ تا ۸ ۴ و ۶ است.
func _check_jump_reach() -> void:
	print("\n— برد پرش در موتور واقعی —")
	var body := StaticBody2D.new()
	body.collision_layer = Layers.GROUND
	body.collision_mask = 0
	add_child(body)
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = Vector2(80 * 16, 48)
	cs.shape = r
	cs.position = Vector2(40 * 16, 14 * 16 + 24)
	body.add_child(cs)

	var kairo: Kairo = load("res://actors/kairo/kairo.tscn").instantiate()
	add_child(kairo)
	GameState.unlock_tool("wall_jump")
	kairo._refresh_tools()
	var floor_y := float(14 * 16) - KairoConst.HITBOX.y * 0.5
	kairo.reset_to(Vector2(3 * 16, floor_y))
	for i in 8:
		await get_tree().physics_frame

	# ارتفاع
	var y0 := kairo.global_position.y
	Input.action_press("jump")
	var apex := y0
	for i in 70:
		await get_tree().physics_frame
		apex = minf(apex, kairo.global_position.y)
		if kairo.is_on_floor() and kairo.velocity.y >= 0.0 and i > 10:
			break
	Input.action_release("jump")
	var up_tiles := (y0 - apex) / float(KairoConst.TILE)

	# برد افقی
	kairo.reset_to(Vector2(3 * 16, floor_y))
	for i in 6:
		await get_tree().physics_frame
	Input.action_press("move_right")
	for i in 45:
		await get_tree().physics_frame
	var x0 := kairo.global_position.x
	Input.action_press("jump")
	for i in 4:
		await get_tree().physics_frame
	for i in 90:
		await get_tree().physics_frame
		if kairo.is_on_floor():
			break
	var across_tiles := (kairo.global_position.x - x0) / float(KairoConst.TILE)
	Input.action_release("move_right")
	Input.action_release("jump")

	print("    اندازه‌گیری: %.2f کاشی بالا، %.2f کاشی افقی" % [up_tiles, across_tiles])
	print("    سند §۳:     %.2f کاشی بالا، %.2f کاشی افقی"
		% [KairoConst.jump_height_px() / float(KairoConst.TILE), KairoConst.jump_range_px() / float(KairoConst.TILE)])
	print("    فرض مولّد:   4.00 کاشی بالا، 6.00 کاشی افقی")

	# سنجه‌ها به عدد سند بسته‌اند، نه به فرض مولّد (DECISIONS.md: D-008)
	_check("ارتفاع پرش با §۳ می‌خواند",
		absf(up_tiles - KairoConst.jump_height_px() / float(KairoConst.TILE)) <= 0.3,
		"= %.2f کاشی" % up_tiles)
	_check("برد افقی ≥ ۴٫۵ کاشی (حد شکاف §۳)", across_tiles >= 4.5,
		"= %.2f کاشی" % across_tiles)
	_check("ارتفاع پرش کمتر از فرض ۴ کاشی مولّد است", up_tiles < 4.0,
		"= %.2f کاشی — پس اتاق‌های فصل ۲ تا ۸ باید دوباره سنجیده شوند" % up_tiles)
	_check("برد افقی کمتر از فرض ۶ کاشی مولّد است", across_tiles < 6.0,
		"= %.2f کاشی" % across_tiles)

	kairo.queue_free()
	body.queue_free()
	await get_tree().process_frame


## زمان‌بندی موانع و قاعدهٔ عدالت در موتور
func _check_hazards() -> void:
	print("\n— زمان‌بندی موانع —")
	var laser := Laser.new()
	laser.dir = "down"
	laser.length_tiles = 5
	add_child(laser)
	await get_tree().process_frame
	var window := laser.safe_window()
	var min_window: float = Settings.fairness().get("min_safe_window", 1.0)
	_check("پنجرهٔ امن لیزر ≥ ۱ ثانیه", window >= min_window - 0.001,
		"= %.2f ثانیه" % window)
	var warn: float = Settings.hazard("laser_warn", 0.4)
	var min_warn: float = Settings.fairness().get("min_warning_before_lethal", 0.4)
	_check("هشدار پیش از کشنده شدن ≥ ۰٫۴ ثانیه", warn >= min_warn - 0.001,
		"= %.2f ثانیه" % warn)
	laser.queue_free()

	var crumble := Crumble.new()
	add_child(crumble)
	await get_tree().process_frame
	_check("پلتفرم شکننده در فاز اول جامد است", crumble.phase == Crumble.Phase.IDLE, "")
	crumble.queue_free()

	var drone := Drone.new()
	add_child(drone)
	await get_tree().process_frame
	drone.on_hacked()
	_check("پهپاد با هک خاموش می‌شود", drone.is_disabled, "")
	drone.queue_free()
	await get_tree().process_frame


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
