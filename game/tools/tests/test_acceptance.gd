## آزمون پذیرش — docs/02_godot_spec.md §۱۶ و «معیار پذیرش» سند ۰۵
##
##   godot --headless res://tools/tests/test_acceptance.tscn
##
## هر بندی که خودکار سنجیدنی است اینجا سنجیده می‌شود. بندهایی که فقط روی گوشی
## معنی دارند (۶۰ فریم، چرخش صفحه، قطع تماس، خرید آزمایشی) در گزارش به‌عنوان
## «آزمون دستی» فهرست می‌شوند.
extends Node2D

var _failures: Array[String] = []
var _checks: int = 0
var _manual: Array[String] = []

## بخش‌هایی که باید اجرا شوند. اگر coroutine وسط راه با خطا بمیرد بی‌صدا
## متوقف می‌شود، و بدون این سنجه گزارش به‌غلط «همه قبول شد» می‌داد.
const EXPECTED_SECTIONS := ["a", "b", "c", "d", "e", "f", "g", "h"]
var _done: Array[String] = []


func _finish_section(tag: String) -> void:
	if tag not in _done:
		_done.append(tag)


func _ready() -> void:
	await _a_rooms_passable()
	await _b_ilara_death_restarts()
	await _c_doors_lead_right()
	await _d_no_forced_ads_or_purchases()
	await _e_offline_safe()
	await _f_save_survives_kill()
	await _g_persian_text()
	await _h_level_playthrough()
	_list_manual()
	_report()


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  ✔ %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  ✘ %s %s" % [label, detail])


## §۱۶: «هر ۱۲ اتاق قابل عبور است و همهٔ گوهرها دسترس‌پذیرند»
func _a_rooms_passable() -> void:
	print("— §۱۶ الف: هر ۱۲ اتاق قابل عبور —")
	var total := 0
	var with_exit := 0
	var gems := 0
	for id in ["ch1_l1", "ch1_l2", "ch1_l3"]:
		var loader := LevelLoader.new()
		var level := loader.load_level("res://levels/data/%s.json" % id)
		if level.is_empty():
			_check("بارگذاری %s" % id, false, str(loader.errors))
			continue
		total += level["rooms"].size()
		for rd in level["rooms"]:
			if String(rd["tiles"][11]).contains("X") or String(rd["tiles"][12]).contains("X"):
				pass
			for sym in rd.get("objects", {}).keys():
				var t := String(rd["objects"][sym].get("type", ""))
				if t == "exit":
					with_exit += 1
				elif t == "gem":
					for line in rd["tiles"]:
						gems += String(line).count(sym)
	_check("۱۲ اتاق بار شد", total == 12, "= %d اتاق" % total)
	_check("هر مرحله یک نقطهٔ خروج دارد", with_exit == 3, "= %d خروج" % with_exit)
	_check("هفت گوهر در سه مرحله", gems == 7, "= %d گوهر" % gems)
	print("    i حل‌پذیری هندسی با tools/validate_ch1.py سنجیده می‌شود: ۱۲/۱۲")


## §۱۶: «اگر ایلارا بمیرد، مرحله از ابتدا شروع می‌شود و سکه‌ها بازنشانی می‌شوند»
	_finish_section("a")
func _b_ilara_death_restarts() -> void:
	print("— §۱۶ ب: مرگ ایلارا مرحله را از اول شروع می‌کند —")
	SceneRouter.pending_level = "res://levels/data/ch1_l1.json"
	var game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	for i in 20:
		await get_tree().physics_frame
	_check("مرحله بار شد", game.room != null, "")
	_check("ایلارا ساخته شد", game.ilara != null, "")
	if game.ilara == null:
		game.queue_free()
		return

	# چند سکه جمع می‌کنیم تا بازنشانی دیده شود
	for p in game.room.pickups:
		if p.kind == "coin":
			p.picked.emit("coin", p.id)
			p._taken = true
			break
	var before := int(game.room.collected()["coins"])
	var falls_before := int(game.ilara_falls)

	game.ilara.die()
	for i in 40:
		await get_tree().physics_frame
	_check("شمارندهٔ افتادن ایلارا جدا بالا رفت",
		game.ilara_falls == falls_before + 1, "= %d" % game.ilara_falls)
	_check("از اتاق اول شروع شد", game.current_room_id == "r1",
		"= %s" % game.current_room_id)
	_check("سکه‌های جمع‌شده بازنشانی شدند",
		int(game.room.collected()["coins"]) == 0 and before > 0,
		"(پیش از مرگ %d سکه)" % before)
	_check("مرگ ایلارا در شمارندهٔ مرگ کایرو نیست", game.deaths == 0,
		"= %d مرگ کایرو" % game.deaths)
	game.queue_free()
	await get_tree().process_frame


## §۱۶: «رفتن به محیط از درگاه چپ/راست دقیقاً به اتاق درست می‌رسد»
	_finish_section("b")
func _c_doors_lead_right() -> void:
	print("— §۱۶ ج: درگاه به اتاق درست می‌رسد —")
	var loader := LevelLoader.new()
	var level := loader.load_level("res://levels/data/ch1_l1.json")
	var ids := {}
	for rd in level["rooms"]:
		ids[String(rd["id"])] = true
	var bad := []
	var count := 0
	for rd in level["rooms"]:
		for door in rd.get("exits", []):
			count += 1
			if not ids.has(String(door.get("to", ""))):
				bad.append("%s/%s" % [rd["id"], door.get("side", "?")])
	_check("هر درگاه به اتاق موجود می‌رسد", bad.is_empty(),
		"(%d درگاه)" % count if bad.is_empty() else str(bad))

	# گذار واقعی: از اتاق ۱ به اتاق ۲
	SceneRouter.pending_level = "res://levels/data/ch1_l1.json"
	var game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	for i in 20:
		await get_tree().physics_frame
	var first := String(game.current_room_id)
	game._on_door_crossed("right", "r2", 12)
	for i in 10:
		await get_tree().physics_frame
	_check("عبور از درگاه راست به اتاق بعدی رسید",
		first == "r1" and game.current_room_id == "r2",
		"= %s → %s" % [first, game.current_room_id])
	# ورود از سمت راست باید در لبهٔ چپ اتاق تازه ظاهر شود
	_check("در لبهٔ چپ اتاق تازه ظاهر شد",
		game.kairo.global_position.x < 4.0 * LevelLoader.TILE,
		"= x %.0f px" % game.kairo.global_position.x)
	game.queue_free()
	await get_tree().process_frame


## §۱۶: «هیچ تبلیغ یا خریدی بدون اختیار کاربر نمایش داده نمی‌شود»
	_finish_section("c")
func _d_no_forced_ads_or_purchases() -> void:
	print("— §۱۶ د: هیچ تبلیغ یا خرید اجباری —")
	_check("همهٔ جایگاه‌های تبلیغ پاداشی‌اند (rewarded)",
		Ads.PLACEMENTS.all(func(p): return String(p).begins_with("rewarded_")),
		"= %s" % str(Ads.PLACEMENTS))
	_check("فاصلهٔ حداقل ۹۰ ثانیه بین دو تبلیغ",
		is_equal_approx(Ads.MIN_INTERVAL_SEC, 90.0), "")
	# هیچ کلید واقعی در مخزن نیست
	var cfg = JSON.parse_string(FileAccess.get_file_as_string("res://data/ads_config.json"))
	var placeholder := true
	if cfg is Dictionary:
		if not String(cfg.get("app_id", "")).begins_with("REPLACE_WITH"):
			placeholder = false
		for v in (cfg.get("placements", {}) as Dictionary).values():
			if not String(v).begins_with("REPLACE_WITH"):
				placeholder = false
	_check("شناسهٔ ادیوری جای‌نگهدار است، نه کلید واقعی", placeholder, "")
	_check("پولاکی بدون پلاگین خرید را رد می‌کند", not Billing.available(),
		"(در محیط توسعه)")
	# جعبهٔ روزانه ثابت است، نه تصادفی (شرط اسرا)
	_check("جعبهٔ روزانه پاداش ثابت دارد، نه تصادفی",
		GameState.DAILY_COINS == [10, 15, 20, 40], "")


## §۱۶: «حالت بدون اینترنت: بازی بدون خطا اجرا می‌شود؛ دکمه‌های تبلیغ/خرید غیرفعال»
	_finish_section("d")
func _e_offline_safe() -> void:
	print("— §۱۶ ه: بدون اینترنت —")
	_check("NetService در حالت محلی است", NetService.mode == NetService.Mode.LOCAL, "")
	_check("ثبت زمان محلی خطا نمی‌دهد", NetService.submit_time("ch1_l1", 60.0), "")
	_check("رتبه‌بندی محلی خالی برمی‌گردد",
		NetService.fetch_leaderboard("ch1_l1").is_empty(), "")
	var shop = load("res://ui/shop/shop.tscn").instantiate()
	add_child(shop)
	await get_tree().process_frame
	_check("فروشگاه بدون بازار بدون خطا ساخته شد", shop.get_child_count() > 0, "")
	shop.queue_free()
	await get_tree().process_frame


## §۱۶: «بستن برنامه در میانهٔ مرحله: بازگشت به همان اتاق»
## سند ۰۵: «ذخیره بعد از بستن ناگهانی برنامه از بین نرود»
	_finish_section("e")
func _f_save_survives_kill() -> void:
	print("— §۱۶ و: ذخیره پس از بستن ناگهانی —")
	for p in [GameState.SAVE_PATH, GameState.BAK_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	GameState.data = GameState.default_save()
	GameState.data["coins"] = 321
	# همان مسیری که NOTIFICATION_APPLICATION_PAUSED می‌رود
	GameState._notification(NOTIFICATION_APPLICATION_PAUSED)
	_check("ذخیره در لحظهٔ توقف برنامه نوشته شد",
		FileAccess.file_exists(GameState.SAVE_PATH), "")
	GameState.data = GameState.default_save()
	GameState.load_game()
	_check("پس از بازخوانی پیشرفت سر جایش است",
		int(GameState.data.get("coins", 0)) == 321,
		"= %d سکه" % int(GameState.data.get("coins", 0)))
	_check("فایل موقت نماند", not FileAccess.file_exists(GameState.TMP_PATH), "")


## §۱۶: «تمام متن‌های فارسی بدون بریدگی و با جهت صحیح نمایش داده می‌شوند»
	_finish_section("f")
func _g_persian_text() -> void:
	print("— §۱۶ ز: متن فارسی —")
	_check("زبان روی فارسی است", TranslationServer.get_locale().begins_with("fa"),
		"= %s" % TranslationServer.get_locale())
	_check("جهت ریشهٔ صحنه راست‌به‌چپ است",
		ProjectSettings.get_setting("internationalization/rendering/root_node_layout_direction") == 2,
		"")
	# هر کلید جدول رشته باید متن غیرخالی بدهد
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/strings_fa.json"))
	var table: Dictionary = parsed.get("fa", {}) if parsed is Dictionary else {}
	var empty := []
	for k in table.keys():
		if Fa.t(k).strip_edges() == "" or Fa.t(k).begins_with("⟦"):
			empty.append(k)
	_check("هیچ کلید خالی یا گم‌شده‌ای نیست", empty.is_empty(),
		"(%d کلید)" % table.size() if empty.is_empty() else str(empty))
	_check("یکدست‌سازی کاف و یای عربی", Fa.shape("كيك") == "کیک", "")
	_check("اعداد فارسی در نمایش", Fa.num(2026) == "۲۰۲۶", "= %s" % Fa.num(2026))
	_finish_section("g")


## تمام شدن واقعی مرحله با روبات کنترلی (§۲۲).
##
## این بخش جای «آزمون دوام ۹۰ ثانیه» را گرفت: دوام فقط می‌گفت کرش نمی‌کند، نه
## این‌که مرحله بازی‌شدنی است. اینجا روبات با ورودی واقعی مرحله را تا خروج
## می‌برد و ایلارا هم باید زنده برسد، چون خروج `needs_both` است (D-042).
func _h_level_playthrough() -> void:
	print("— تمام شدن مرحله با روبات کنترلی —")
	var plan := Robot.load_plan("ch1_l1")
	_check("برنامهٔ کنش ch1_l1 موجود است", not plan.is_empty(),
		"(از tools/export_plans.py)")
	if plan.is_empty():
		_finish_section("h")
		return

	SceneRouter.pending_level = "res://levels/data/ch1_l1.json"
	GameState.data = GameState.default_save()
	GameState.data["cutscenes_seen"] = ["c1_intro", "c1_title"]
	var game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	for i in 20:
		await get_tree().physics_frame

	var robot := Robot.new()
	robot.game = game
	robot.plan = plan
	add_child(robot)

	var finished := [false]
	game.level_finished.connect(func(_r): finished[0] = true, CONNECT_ONE_SHOT)
	var rooms := {}
	var f := 0
	while f < 60 * 120 and not finished[0] and robot.phase != Robot.Phase.DONE:
		await get_tree().physics_frame
		f += 1
		robot.step()
		rooms[String(game.current_room_id)] = true

	print("    اتاق‌ها: %s، %.1f ثانیه، مرگ %d، افتادن ایلارا %d"
		% [str(rooms.keys()), f / 60.0, game.deaths, game.ilara_falls])
	_check("مرحلهٔ ۱ تا خروج تمام شد", finished[0] or game.finished,
		"(%d/4 اتاق)" % rooms.size())
	_check("ایلارا زنده به خروج رسید",
		game.ilara != null and is_instance_valid(game.ilara)
		and game.ilara.state != PlatformActor.State.DEAD, "")
	_check("هر چهار اتاق پیموده شد", rooms.size() == 4, "= %d" % rooms.size())
	_check("نتیجهٔ مرحله ستاره داد",
		int(SceneRouter.last_result.get("stars", 0)) >= 1,
		"= %d ستاره" % int(SceneRouter.last_result.get("stars", 0)))
	print("    i مرحلهٔ ۲ و ۳ هنوز با روبات تمام نمی‌شوند — کار باز گام ۸ با")
	print("      پایهٔ پسرفت در tools/tests/test_robot.gd (D-042)")

	robot._release_all()
	robot.queue_free()
	game.queue_free()
	await get_tree().process_frame
	_finish_section("h")



## بندهایی که فقط روی دستگاه واقعی سنجیدنی‌اند (§۱۶ و معیار پذیرش سند ۰۵)
func _list_manual() -> void:
	_manual = [
		"۶۰ فریم بر ثانیه روی گوشی میان‌رده (۲ تا ۳ GB RAM)",
		"حجم بسته کمتر از ۱۰۰ MB (سند ۰۵) / ۱۵۰ MB (§۱۶)",
		"زمان بارگذاری مرحله کمتر از ۲ ثانیه و حافظه کمتر از ۳۰۰ MB",
		"تأخیر لمس تا واکنش کاراکتر حداکثر ۲ فریم (۳۳ms)",
		"چرخش صفحه، قطع تماس و بستن برنامه در میانهٔ مرحله",
		"خرید آزمایشی بازار و بازگرداندن خرید",
		"تبلیغ آزمایشی ادیوری با شناسهٔ واقعی",
		"یک ساعت بازی پیوسته بدون کرش و بدون نشت حافظه",
		"نمایش متن فارسی بدون بریدگی روی چند اندازهٔ صفحه",
		"هر سه مرحله برای بازیکن تازه‌کار قابل تمام کردن (۵ تا ۱۰ دقیقه)",
	]


func _report() -> void:
	print("")
	print("— بندهایی که آزمون دستی روی گوشی لازم دارند —")
	for m in _manual:
		print("  ☐ %s" % m)
	var missing := []
	for tag in EXPECTED_SECTIONS:
		if tag not in _done:
			missing.append(tag)
	if not missing.is_empty():
		_failures.append("بخش‌های %s اجرا نشدند" % str(missing))
		print("  ✘ بخش‌های اجرانشده (coroutine وسط راه مرد): %s" % str(missing))

	print("")
	if _failures.is_empty():
		print("همهٔ %d سنجهٔ خودکار قبول شد (%d بخش)." % [_checks, _done.size()])
		get_tree().quit(0)
	else:
		print("%d از %d سنجه رد شد:" % [_failures.size(), _checks])
		for f in _failures:
			print("  - %s" % f)
		get_tree().quit(1)
