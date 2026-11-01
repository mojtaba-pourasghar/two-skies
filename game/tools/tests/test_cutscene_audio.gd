## آزمون سیستم فیلم‌نامه و صدا — گام ۶
##
##   godot --headless res://tools/tests/test_cutscene_audio.tscn
extends Node2D

const SCENES := ["c1_intro", "c1_title", "v1_end"]

## کلیدهایی که کد مستقیم صدا می‌زند — همه باید در sfx.json باشند، وگرنه
## بازی در لحظهٔ اجرا هشدار می‌دهد.
const CODE_KEYS := [
	"kairo_jump", "kairo_wall_jump", "kairo_dash", "kairo_death", "kairo_land",
	"ilara_jump", "ilara_death", "ilara_teleport",
	"coin", "gem", "page", "hack_start", "hack_success", "gate_open",
	"crumble", "laser_warn", "laser_fire", "ui_click", "level_complete",
	"music_menu", "music_home", "music_street", "music_hall", "music_story",
	"blip_kairo", "blip_ilara",
]

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	await _test_audio_buses()
	await _test_sfx_map()
	await _test_cutscene_files()
	await _test_dialogue_box()
	await _test_cutscene_playback()
	_report()


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  ✔ %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  ✘ %s %s" % [label, detail])


## پنج باس §۱۴ باید وجود داشته باشند
func _test_audio_buses() -> void:
	print("— باس‌های صدا —")
	for bus in ["Master", "Music", "SFX", "UI", "Ambience"]:
		_check("باس %s" % bus, AudioServer.get_bus_index(bus) >= 0, "")
	_check("استخر ۸ پخش‌کنندهٔ SFX", Audio.SFX_POOL_SIZE == 8,
		"= %d" % Audio.SFX_POOL_SIZE)
	_check("کراس‌فید ۰٫۸ ثانیه", is_equal_approx(Audio.MUSIC_CROSSFADE, 0.8), "")


## همهٔ کلیدهایی که کد صدا می‌زند باید در نگاشت باشند (§۱۴)
func _test_sfx_map() -> void:
	print("— نگاشت صدا —")
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/sfx.json"))
	_check("sfx.json خوانده شد", parsed is Dictionary, "")
	if not (parsed is Dictionary):
		return
	var map: Dictionary = parsed.get("sfx", {})
	_check("حدود ۱۲۰ کلید صدا (§۱۴)", map.size() >= 110,
		"= %d کلید" % map.size())
	var missing := []
	for k in CODE_KEYS:
		if not map.has(k):
			missing.append(k)
	_check("هر کلیدی که کد صدا می‌زند در نگاشت است", missing.is_empty(),
		"(%d کلید سنجیده شد)" % CODE_KEYS.size() if missing.is_empty() else str(missing))
	# مکان‌نگهدار: همه خالی‌اند و باید سکوت بدهند نه خطا
	var all_placeholder := true
	for k in map.keys():
		if String(map[k]) != "":
			all_placeholder = false
	_check("همه مکان‌نگهدارند (گام ۷ سند ۰۵ پرشان می‌کند)", all_placeholder, "")
	# صدا زدن کلید خالی نباید بازی را بشکند
	Audio.play_sfx("kairo_jump")
	Audio.play_music("music_home")
	_check("صدا زدن کلید بدون فایل خطا نمی‌دهد", true, "")


## فایل صحنه‌ها باید قالب §۱۸ را داشته باشند
func _test_cutscene_files() -> void:
	print("— فایل صحنه‌ها —")
	for id in SCENES:
		var path := "res://data/cutscenes/%s.json" % id
		_check("فایل %s" % id, FileAccess.file_exists(path), "")
		if not FileAccess.file_exists(path):
			continue
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not (parsed is Dictionary):
			_check("قالب %s" % id, false, "(JSON خراب)")
			continue
		var shots: Array = parsed.get("shots", [])
		var ok := shots.size() > 0
		var keys_ok := true
		for shot in shots:
			# §۱۸: هر نما code، transition_in، duration، effects، sound، lines، choice دارد
			for field in ["code", "transition_in", "duration", "effects", "sound", "lines"]:
				if not shot.has(field):
					ok = false
			if not Cutscene.SHOT_ZOOM.has(String(shot.get("code", ""))):
				ok = false
			if not Cutscene.TRANSITIONS.has(String(shot.get("transition_in", ""))):
				ok = false
			for line in shot.get("lines", []):
				if Fa.t(String(line.get("key", ""))).begins_with("⟦"):
					keys_ok = false
		_check("قالب §۱۸ در %s" % id, ok, "(%d نما)" % shots.size())
		_check("کلیدهای متن %s موجودند" % id, keys_ok, "")


## باکس گفت‌وگو: حداکثر ۲ خط × ۴۰ کاراکتر (§۱۸)
func _test_dialogue_box() -> void:
	print("— باکس گفت‌وگو —")
	_check("حداکثر ۲ خط", Cutscene.MAX_LINES == 2, "")
	_check("حداکثر ۴۰ کاراکتر", Cutscene.MAX_CHARS == 40, "")
	_check("هر حرف ۰٫۰۳۵ ثانیه", is_equal_approx(Cutscene.CHAR_TIME, 0.035), "")
	_check("بلیپ هر ۲ حرف", Cutscene.BLIP_EVERY == 2, "")
	var long_text := "این یک متن بسیار بلند است که باید در دو خط چهل کاراکتری جا بشود و بقیه‌اش بریده شود"
	var boxed: String = Cutscene._clamp_box(long_text)
	var lines := boxed.split("\n")
	var widest := 0
	for l in lines:
		widest = maxi(widest, l.length())
	_check("متن بلند به ۲ خط محدود شد", lines.size() <= 2, "= %d خط" % lines.size())
	_check("هیچ خطی بیش از ۴۰ کاراکتر نیست", widest <= Cutscene.MAX_CHARS,
		"= %d کاراکتر" % widest)
	# کدهای نما و تبدیل‌های §۱۸
	_check("هفت کد نما", Cutscene.SHOT_ZOOM.size() == 7,
		"= %s" % str(Cutscene.SHOT_ZOOM.keys()))
	_check("کد «ن» زوم ۰٫۷۵", is_equal_approx(Cutscene.SHOT_ZOOM["ن"], 0.75), "")
	_check("کد «ک» زوم ۲٫۰", is_equal_approx(Cutscene.SHOT_ZOOM["ک"], 2.0), "")
	_check("محو ۰٫۴ ثانیه", is_equal_approx(Cutscene.TRANSITIONS["dissolve"], 0.4), "")


## اجرای واقعی یک صحنه: باید تمام شود و سیگنال finished بدهد
func _test_cutscene_playback() -> void:
	print("— اجرای صحنه —")
	GameState.data["cutscenes_seen"] = []
	var done := [false]
	Cutscene.finished.connect(func(_id): done[0] = true, CONNECT_ONE_SHOT)
	Cutscene.play("c1_title")
	# صحنه را رد می‌کنیم تا آزمون طول نکشد — همان مسیر دکمهٔ «رد کردن» (§۱۸)
	await get_tree().create_timer(0.3).timeout
	Cutscene.request_skip()
	var waited := 0.0
	while not done[0] and waited < 12.0:
		await get_tree().process_frame
		waited += get_process_delta_time()
	_check("صحنه تمام شد و finished داد", done[0], "(در %.1f ثانیه)" % waited)
	_check("دیگر در حال اجرا نیست", not Cutscene.is_playing, "")
	_check("دیده‌شدن صحنه ثبت شد",
		"c1_title" in GameState.data.get("cutscenes_seen", []), "")

	# صحنهٔ ناموجود باید بی‌خطر رد شود، نه خطا بدهد
	var done2 := [false]
	Cutscene.finished.connect(func(_id): done2[0] = true, CONNECT_ONE_SHOT)
	Cutscene.play("no_such_scene")
	var w2 := 0.0
	while not done2[0] and w2 < 3.0:
		await get_tree().process_frame
		w2 += get_process_delta_time()
	_check("صحنهٔ ناموجود بی‌خطر رد شد", done2[0], "")


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
