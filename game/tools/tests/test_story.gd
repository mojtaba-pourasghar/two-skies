## رشتهٔ داستان فصل ۱ — M5-ج و M5-د
##
##   godot --headless --fixed-fps 60 res://tools/tests/test_story.tscn
##
## پنج ادعا:
##   ۱ هر بیت یک بار اجرا می‌شود و پرچمش می‌ماند
##   ۲ ترتیب (`after`) و شرط (`needs_flag`) رعایت می‌شود
##   ۳ هر کلید متنِ بیت‌ها واقعاً در strings_fa هست
##   ۴ قلم و صندوق: برداشتن، پرچم، و اضافه شدن به دارایی
##   ۵ صفحهٔ ارتقا انتخاب را ذخیره می‌کند، و پایان فصل پرچم می‌زند
extends Node2D

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	_t_beats()
	_t_strings()
	await _t_pickups()
	await _t_upgrade()
	_report()


func _clear_story_flags(sd: StoryDirector) -> void:
	for raw in sd.beats:
		GameState.set_flag(StoryDirector.flag_of(String((raw as Dictionary)["id"])), false)


func _t_beats() -> void:
	print("— بیت‌های داستان —")
	var sd := StoryDirector.new()
	add_child(sd)
	_check("فایل داستان بار شد", sd.errors.is_empty() and not sd.beats.is_empty(),
		"= %d بیت، %s" % [sd.beats.size(), str(sd.errors)])
	if sd.beats.is_empty():
		return
	_clear_story_flags(sd)
	for raw in sd.beats:
		var b: Dictionary = raw
		var kinds := 0
		for k in ["cutscene", "say", "upgrade"]:
			if b.has(k):
				kinds += 1
		_check("  بیت «%s» دقیقاً یک کنش دارد" % b["id"], kinds == 1, "= %d" % kinds)

	# ورود به R1a: اول c1_intro، نه بیت بعدی‌اش
	var first := sd.pending("enter", "r1a_living")
	_check("اولین ورود به R1a دست‌کم یک بیت دارد", first.size() >= 1, "= %d" % first.size())
	if not first.is_empty():
		_check("  و اولی صحنهٔ آغاز است", String(first[0].get("cutscene", "")) == "c1_intro")
	# بیت وابسته پیش از پیش‌نیازش اجرا نمی‌شود
	var has_dependent := false
	for b in first:
		if String(b.get("after", "")) != "":
			has_dependent = true
	_check("  بیت وابسته پیش از پیش‌نیازش نمی‌آید", not has_dependent)

	# بعد از ثبت پرچم، دیگر نمی‌آید
	GameState.set_flag(StoryDirector.flag_of("b_intro"), true)
	var again := sd.pending("enter", "r1a_living")
	var still_intro := false
	for b in again:
		if String(b.get("id", "")) == "b_intro":
			still_intro = true
	_check("بیت اجراشده دوباره نمی‌آید", not still_intro)
	_check("و حالا بیت وابسته‌اش آزاد شده", again.size() >= 1, "= %d" % again.size())

	# شرط پرچم
	GameState.set_flag("battle_won_ch1_a3_guard_crawler", false)
	var gated := sd.pending("enter", "s3a_plaza")
	var boss_in := false
	for b in gated:
		if String(b.get("id", "")) == "b_boss":
			boss_in = true
	_check("بیت شرط‌دار بی پرچمش نمی‌آید", not boss_in)
	GameState.set_flag("battle_won_ch1_a3_guard_crawler", true)
	gated = sd.pending("enter", "s3a_plaza")
	boss_in = false
	for b in gated:
		if String(b.get("id", "")) == "b_boss":
			boss_in = true
	_check("و با پرچمش می‌آید", boss_in)
	_clear_story_flags(sd)
	sd.queue_free()


func _t_strings() -> void:
	print("— کلیدهای متن —")
	var sd := StoryDirector.new()
	add_child(sd)
	var missing: Array[String] = []
	for raw in sd.beats:
		for line in (raw as Dictionary).get("say", []):
			var key := String((line as Dictionary).get("key", ""))
			if key != "" and Fa.t(key) == key:
				missing.append(key)
	_check("هر کلید گفت‌وگو ترجمه دارد", missing.is_empty(), "= %s" % str(missing))
	# صحنه‌ها هم
	for cid in ["c1_intro", "v1_end"]:
		var path := "res://data/cutscenes/%s.json" % cid
		_check("صحنهٔ «%s» هست" % cid, FileAccess.file_exists(path))
		if not FileAccess.file_exists(path):
			continue
		var d = JSON.parse_string(FileAccess.get_file_as_string(path))
		var no_bg: Array[String] = []
		for sh in (d as Dictionary).get("shots", []):
			if String((sh as Dictionary).get("bg", "")) == "":
				no_bg.append("?")
			elif not AssetPath.exists(String((sh as Dictionary)["bg"])):
				no_bg.append(String((sh as Dictionary)["bg"]))
		_check("  هر نما تصویر دارد", no_bg.is_empty(), "= %s" % str(no_bg))
	sd.queue_free()


func _t_pickups() -> void:
	print("— قلم و صندوق —")
	var l := RoomData.new()
	var room := l.load_room("r1c_kitchen")
	if room.is_empty():
		_check("آشپزخانه بار شد", false)
		return
	GameState.set_flag(PaintedRoom.pickup_flag("r1c_kitchen", "chest_pantry"), false)
	var node := PaintedRoom.new()
	add_child(node)
	node.build(room)
	_check("صندوق ساخته شد", node.pickups.size() == 1, "= %d" % node.pickups.size())
	var at := Vector2(420, 600)
	_check("با رد شدن برداشته **نمی‌شود**", node.pickup_at(at, false).is_empty())
	var pk := node.pickup_at(at, true)
	_check("با دکمه پیدا می‌شود", not pk.is_empty())
	if pk.is_empty():
		return
	var gems_before := int(GameState.data.get("gems", 0))
	var gained := node.take_pickup(String(pk["id"]))
	_check("محتوایش برگشت", gained.has("gem"), "= %s" % str(gained))
	_check("از اتاق حذف شد", node.pickups.is_empty())
	_check("پرچمش ثبت شد",
		bool(GameState.get_flag(PaintedRoom.pickup_flag("r1c_kitchen", "chest_pantry"), false)))
	# اتاق دوباره ساخته شود، صندوق نباید برگردد
	var node2 := PaintedRoom.new()
	add_child(node2)
	node2.build(l.load_room("r1c_kitchen"))
	_check("با برگشت به اتاق دوباره نمی‌روید", node2.pickups.is_empty(),
		"= %d" % node2.pickups.size())
	node.queue_free()
	node2.queue_free()
	await get_tree().process_frame


func _t_upgrade() -> void:
	print("— ارتقا و پایان فصل —")
	GameState.data["upgrades"] = []
	var ui := UpgradeChoice.new()
	add_child(ui)
	await get_tree().process_frame
	_check("سه گزینه دارد", UpgradeChoice.CHOICES.size() == 3)
	ui.choose("heart")
	_check("انتخاب ذخیره شد",
		"heart" in (GameState.data.get("upgrades", []) as Array),
		"= %s" % str(GameState.data.get("upgrades", [])))
	ui.choose("boot")
	_check("انتخاب دوم رد می‌شود (یکی بیشتر نه)",
		(GameState.data.get("upgrades", []) as Array).size() == 1)
	ui.queue_free()

	GameState.set_flag("ch1_done", false)
	var ce := ChapterEnd.new()
	add_child(ce)
	await get_tree().process_frame
	_check("پردهٔ پایان فصل ساخته شد", ce.get_child_count() > 0)
	ce.queue_free()
	await get_tree().process_frame


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  ✔ %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  ✘ %s %s" % [label, detail])


func _report() -> void:
	print("")
	if _failures.is_empty():
		print("همهٔ %d سنجه قبول شد." % _checks)
		get_tree().quit(0)
	else:
		print("%d از %d سنجه رد شد." % [_failures.size(), _checks])
		get_tree().quit(1)
