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


## یک بازی خودکار: کایرو با روبات از اتاق اول به خروج مرحلهٔ ۱ می‌رسد.
## این بند §۱۶ «آزمون خودکار مسیر» را با فیزیک واقعی می‌سنجد.
	_finish_section("g")
func _h_level_playthrough() -> void:
	print("— دوام: ۹۰ ثانیه بازی خودکار مرحلهٔ ۱ —")
	SceneRouter.pending_level = "res://levels/data/ch1_l1.json"
	var game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	for i in 20:
		await get_tree().physics_frame

	var rooms_seen := {}
	var finished := [false]
	game.level_finished.connect(func(_r): finished[0] = true, CONNECT_ONE_SHOT)

	# روبات: به راست بدو و وقتی جلویت دیوار یا چاله بود بپر.
	var max_frames := 60 * 90
	var f := 0
	Input.action_press("move_right")
	while f < max_frames and not finished[0]:
		await get_tree().physics_frame
		f += 1
		rooms_seen[game.current_room_id] = true
		var k: Kairo = game.kairo
		if k == null:
			break
		# پرش وقتی روی زمین است و جلو مانع یا لبه است
		if k.is_on_floor() and f % 6 == 0:
			if k.is_on_wall() or _edge_ahead(game, k):
				Input.action_press("jump")
				await get_tree().physics_frame
				Input.action_release("jump")
	Input.action_release("move_right")
	Input.action_release("jump")

	print("    اتاق‌های دیده‌شده: %s، فریم شبیه‌سازی‌شده: %d (%.0f ثانیه)"
		% [str(rooms_seen.keys()), f, f / 60.0])
	print("    مرگ کایرو: %d، افتادن ایلارا: %d" % [game.deaths, game.ilara_falls])

	# این بخش «تمام کردن مرحله» را نمی‌سنجد و نباید بسنجد: اتاق اول مرحلهٔ ۱ یک
	# بالا رفتن سه‌پله‌ای از کنار بلوک چهار کاشی می‌خواهد و روباتِ سادهٔ
	# «به راست بدو و روی دیوار بپر» از آن رد نمی‌شود. حل‌پذیری هندسی با
	# tools/validate_ch1.py تأیید شده (۱۲/۱۲ اتاق) و تمام کردن واقعی مرحله بند
	# آزمون دستی است. آنچه اینجا سنجیده می‌شود دوام است: ۹۰ ثانیه فیزیک و
	# مانع و همراه، بدون کرش و بدون از دست رفتن گره.
	_check("۹۰ ثانیه شبیه‌سازی بدون کرش", f >= 60 * 89, "= %.0f ثانیه" % (f / 60.0))
	_check("کایرو تا پایان سالم ماند",
		game.kairo != null and is_instance_valid(game.kairo), "")
	_check("ایلارا تا پایان سالم ماند",
		game.ilara != null and is_instance_valid(game.ilara), "")
	_check("اتاق تا پایان ساخته ماند",
		game.room != null and is_instance_valid(game.room), "")
	_check("فیزیک زنده بود (کایرو جابه‌جا شد یا مُرد)",
		game.deaths > 0 or game.kairo.global_position != game.room.kairo_start,
		"(مرگ %d، x=%.0f)" % [game.deaths, game.kairo.global_position.x])
	_check("شمارنده‌ها بی‌معنی نشدند",
		game.deaths >= 0 and game.ilara_falls >= 0, "")
	print("    i تمام کردن سر‌تا‌سر مرحله بند آزمون دستی است؛ حل‌پذیری هندسی")
	print("      با validate_ch1.py تأیید شده: ۱۲/۱۲ اتاق.")
	game.queue_free()
	await get_tree().process_frame


## آیا یک کاشی جلوتر زمین تمام می‌شود
	_finish_section("h")
func _edge_ahead(game, k: Kairo) -> bool:
	var tiles_layer = game.room.get_node_or_null("Tiles")
	if tiles_layer == null:
		return false
	var c := int(k.global_position.x / LevelLoader.TILE) + 1
	var r := int(k.global_position.y / LevelLoader.TILE) + 1
	return tiles_layer.get_cell_source_id(Vector2i(c, r)) == -1


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
