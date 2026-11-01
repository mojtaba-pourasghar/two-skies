## آزمون ذخیره، اقتصاد و صفحه‌های UI — گام ۵
##
##   godot --headless res://tools/tests/test_save_ui.tscn
extends Node2D

const SCREENS := [
	"res://ui/splash/splash.tscn",
	"res://ui/main_menu/main_menu.tscn",
	"res://ui/world_map/world_map.tscn",
	"res://ui/level_intro/level_intro.tscn",
	"res://ui/result/result.tscn",
	"res://ui/pause/pause.tscn",
	"res://ui/settings/settings.tscn",
	"res://ui/shop/shop.tscn",
	"res://ui/letters/letters.tscn",
	"res://ui/about/about.tscn",
]

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	await _test_save_roundtrip()
	await _test_tamper_detection()
	await _test_backup_fallback()
	await _test_migrate()
	await _test_economy()
	await _test_daily()
	await _test_level_result()
	await _test_strings()
	await _test_screens()
	_report()


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  ✔ %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  ✘ %s %s" % [label, detail])


func _wipe() -> void:
	for p in [GameState.SAVE_PATH, GameState.BAK_PATH, GameState.TMP_PATH]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
	GameState.data = GameState.default_save()


## ذخیره و بازخوانی باید همان داده را بدهد (§۱۲)
func _test_save_roundtrip() -> void:
	print("— ذخیره و بازخوانی —")
	_wipe()
	GameState.data["coins"] = 123
	GameState.data["gems"] = 7
	GameState.data["pages"] = ["ch1_p1"]
	_check("نوشتن ذخیره", GameState.save_game(), "")
	_check("فایل ساخته شد", FileAccess.file_exists(GameState.SAVE_PATH), "")
	_check("فایل موقت نماند", not FileAccess.file_exists(GameState.TMP_PATH),
		"(نوشتن اتمیک: tmp سپس rename)")
	GameState.data = GameState.default_save()
	_check("بازخوانی", GameState.load_game(), "")
	_check("سکه برگشت", int(GameState.data["coins"]) == 123,
		"= %d" % int(GameState.data["coins"]))
	_check("گوهر برگشت", int(GameState.data["gems"]) == 7, "")
	_check("صفحهٔ دفتر برگشت", "ch1_p1" in GameState.data["pages"], "")


## امضای HMAC باید فایل دستکاری‌شده را رد کند (§۱۲)
func _test_tamper_detection() -> void:
	print("— امضای ضد دستکاری —")
	_wipe()
	GameState.data["coins"] = 50
	GameState.save_game()
	# سکه را در فایل دست می‌بریم بدون عوض کردن امضا
	var text := FileAccess.get_file_as_string(GameState.SAVE_PATH)
	# payload یک رشتهٔ JSON داخل JSON است، پس گیومه‌هایش escape شده‌اند.
	var hacked := text.replace("\\\"coins\\\":50", "\\\"coins\\\":999999")
	_check("متن ذخیره قابل دستکاری است", hacked != text, "(شبیه‌سازی تقلب)")
	var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	f.store_string(hacked)
	f.close()
	GameState.data = GameState.default_save()
	var loaded := GameState.load_game()
	_check("ذخیرهٔ دستکاری‌شده پذیرفته نشد",
		not loaded or int(GameState.data.get("coins", 0)) != 999999,
		"= %d سکه" % int(GameState.data.get("coins", 0)))


## اگر فایل اصلی خراب بود، از save.bak بازیابی می‌شود (§۱۲)
func _test_backup_fallback() -> void:
	print("— پشتیبان save.bak —")
	_wipe()
	GameState.data["coins"] = 42
	GameState.save_game()
	GameState.data["coins"] = 77
	GameState.save_game()  # نسخهٔ قبلی به bak می‌رود
	_check("پشتیبان ساخته شد", FileAccess.file_exists(GameState.BAK_PATH), "")
	# فایل اصلی را خراب می‌کنیم
	var f := FileAccess.open(GameState.SAVE_PATH, FileAccess.WRITE)
	f.store_string("{ این JSON خراب است")
	f.close()
	GameState.data = GameState.default_save()
	var loaded := GameState.load_game()
	_check("با فایل خراب از پشتیبان خواند", loaded,
		"= %d سکه" % int(GameState.data.get("coins", 0)))


## مهاجرت نسخهٔ ۱ → ۲: هیچ فیلدی پاک نمی‌شود، فیلد تازه پیش‌فرض می‌گیرد (§۱۲، §۲۰)
func _test_migrate() -> void:
	print("— مهاجرت قالب ذخیره —")
	var old_save := {"version": 1, "coins": 500, "levels": {"ch1_l1": {"stars": 3}}}
	var migrated := GameState.migrate(old_save)
	_check("نسخه بالا رفت", int(migrated["version"]) == GameState.SAVE_VERSION,
		"= %d" % int(migrated["version"]))
	_check("پیشرفت قدیمی نگه داشته شد", int(migrated["coins"]) == 500
		and int(migrated["levels"]["ch1_l1"]["stars"]) == 3, "")
	_check("فیلدهای §۲۰ پیش‌فرض گرفتند",
		migrated.has("nexa_balance") and migrated.has("pillars")
		and int(migrated["stability"]) == 50, "")
	_check("ترازوی نکسا کلمپ می‌شود",
		int(GameState.migrate({"version": 2, "nexa_balance": 500})["nexa_balance"]) == 100, "")


func _test_economy() -> void:
	print("— اقتصاد —")
	_wipe()
	GameState.add_coins(100)
	_check("افزودن سکه", int(GameState.data["coins"]) == 100, "")
	_check("خرج کردن سکهٔ موجود", GameState.spend_coins(60), "")
	_check("موجودی درست", int(GameState.data["coins"]) == 40,
		"= %d" % int(GameState.data["coins"]))
	_check("خرج بیش از موجودی رد می‌شود", not GameState.spend_coins(1000), "")
	_check("موجودی دست نخورد", int(GameState.data["coins"]) == 40, "")
	GameState.grant_purchase("skin_test")
	_check("خرید ثبت شد", GameState.owns("skin_test"), "")


## جعبهٔ روزانه پاداش ثابت دارد، نه تصادفی — شرط محتوایی اسرا (سند ۰۵)
func _test_daily() -> void:
	print("— جعبهٔ روزانه —")
	_wipe()
	_check("در آغاز قابل دریافت است", GameState.daily_available(), "")
	var first := GameState.claim_daily(3)
	_check("جایگاه چهارم ۴۰ سکه و ۱ گوهر می‌دهد",
		int(first.get("coins", 0)) == 40 and int(first.get("gems", 0)) == 1,
		"= %s" % str(first))
	_check("دو بار در یک روز نمی‌شود", not GameState.daily_available(), "")
	_check("دریافت دوم خالی برمی‌گردد", GameState.claim_daily(3).is_empty(), "")
	# ثابت بودن: همان جایگاه همیشه همان عدد
	var fixed := true
	for slot in GameState.DAILY_COINS.size():
		if GameState.DAILY_COINS[slot] != [10, 15, 20, 40][slot]:
			fixed = false
	_check("پاداش‌ها ثابت‌اند نه تصادفی", fixed, "= %s" % str(GameState.DAILY_COINS))


func _test_level_result() -> void:
	print("— ثبت نتیجهٔ مرحله —")
	_wipe()
	GameState.record_level_result({
		"level_id": "ch1_l1", "coins": 13, "gems": ["ch1_l1_g1"],
		"pages": ["ch1_p1"], "deaths": 5, "time": 65.0, "stars": 3,
	})
	var rec := GameState.level_record("ch1_l1")
	_check("ستاره ثبت شد", int(rec["stars"]) == 3, "= %d" % int(rec["stars"]))
	_check("بهترین زمان ثبت شد", is_equal_approx(float(rec["best_time"]), 65.0), "")
	_check("سکه به موجودی رفت", int(GameState.data["coins"]) == 13, "")
	_check("مرحلهٔ ۲ باز شد", GameState.highest_unlocked_level() >= 2,
		"= مرحلهٔ %d" % GameState.highest_unlocked_level())
	# زمان بدتر نباید بهترین را خراب کند
	GameState.record_level_result({
		"level_id": "ch1_l1", "coins": 5, "gems": [], "pages": [],
		"deaths": 2, "time": 120.0, "stars": 1,
	})
	var rec2 := GameState.level_record("ch1_l1")
	_check("زمان بدتر بهترین را عوض نمی‌کند",
		is_equal_approx(float(rec2["best_time"]), 65.0), "= %.1f" % float(rec2["best_time"]))
	_check("ستارهٔ کمتر ستارهٔ بیشتر را پاک نمی‌کند", int(rec2["stars"]) == 3, "")


## هر کلیدی که UI استفاده می‌کند باید در strings_fa.json باشد (§۱۹)
func _test_strings() -> void:
	print("— رشته‌های فارسی —")
	var keys := [
		"ch1_l1_title", "ch1_l2_title", "ch1_l3_title",
		"ui_play", "ui_continue", "ui_shop", "ui_settings", "ui_letters",
		"ui_back", "ui_resume", "ui_restart", "ui_coins", "ui_gems", "ui_time",
		"ui_deaths", "ui_ilara_falls", "ui_result_title", "ui_next_level",
		"ui_double_coins", "ui_no_ad", "ui_locked", "ui_soon", "ui_about",
		"ui_quit_confirm", "ui_yes", "ui_no", "ui_market_unavailable",
		"c1_title", "letter_1_title", "letter_1_body",
	]
	var missing := []
	for k in keys:
		if Fa.t(k).begins_with("⟦"):
			missing.append(k)
	_check("همهٔ کلیدهای UI موجودند", missing.is_empty(),
		"(%d کلید)" % keys.size() if missing.is_empty() else str(missing))
	_check("کاف و یای عربی به فارسی تبدیل می‌شود",
		Fa.shape("كيف") == "کیف", "= %s" % Fa.shape("كيف"))
	_check("اعداد فارسی", Fa.num(1403) == "۱۴۰۳", "= %s" % Fa.num(1403))
	_check("زمان فارسی", Fa.time(65.0) == "۱:۰۵", "= %s" % Fa.time(65.0))


## هر صفحهٔ UI باید بدون خطا ساخته شود
func _test_screens() -> void:
	print("— صفحه‌های UI —")
	SceneRouter.pending_level = "res://levels/data/ch1_l1.json"
	SceneRouter.last_result = {
		"level_id": "ch1_l1", "coins": 13, "gems": ["g1"], "pages": [],
		"deaths": 3, "ilara_falls": 1, "time": 72.5, "par_time": 70.0, "stars": 2,
	}
	for path in SCREENS:
		if not ResourceLoader.exists(path):
			_check(path.get_file(), false, "(فایل نیست)")
			continue
		var scene = load(path)
		if scene == null:
			_check(path.get_file(), false, "(بار نشد — خطای کامپایل)")
			continue
		var inst = scene.instantiate()
		if inst == null:
			_check(path.get_file(), false, "(نمونه ساخته نشد)")
			continue
		add_child(inst)
		await get_tree().process_frame
		var built: bool = inst.get_child_count() > 0
		_check(path.get_file(), built, "(%d گره)" % inst.get_child_count())
		inst.queue_free()
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
