## رشتهٔ داستان فصل ۱ — M5-ج (سند ۰۹)
##
## «بیت»های داستان از `data/story_ch1.json` می‌آیند و هر کدام **یک بار**
## اجرا می‌شوند؛ پرچمشان در `GameState` می‌ماند، پس بارگذاری ذخیره،
## دیالوگ‌های دیده‌شده را دوباره پخش نمی‌کند.
##
## سه ماشه هست:
##   `enter`        اولین ورود به اتاقی
##   `after_battle` پس از **برد** یک نبرد مشخص
##   `needs_flag`   شرط اضافه: پرچمی باید باشد
##
## و سه کنش: `cutscene` (صحنهٔ تمام‌صفحه)، `say` (گفت‌وگوی داخل اتاق)،
## `upgrade` (صفحهٔ انتخاب ارتقا).
class_name StoryDirector
extends Node

const DATA := "res://data/story_ch1.json"

signal beat_played(id: String)
signal chapter_ended()

var beats: Array = []
var errors: Array[String] = []


func _ready() -> void:
	load_beats()


func load_beats() -> void:
	beats.clear()
	if not FileAccess.file_exists(DATA):
		errors.append("فایل داستان پیدا نشد: %s" % DATA)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if not (parsed is Dictionary):
		errors.append("فایل داستان خراب است.")
		return
	beats = (parsed as Dictionary).get("beats", [])


static func flag_of(id: String) -> String:
	return "story_%s" % id


func is_done(id: String) -> bool:
	return bool(GameState.get_flag(flag_of(id), false))


## بیت‌هایی که همین حالا باید اجرا شوند، به ترتیب فایل.
func pending(trigger: String, value: String) -> Array:
	var out: Array = []
	for raw in beats:
		var b: Dictionary = raw
		var id := String(b.get("id", ""))
		if id == "" or is_done(id):
			continue
		if String(b.get(trigger, "")) != value:
			continue
		# بیت پیش‌نیاز هنوز اجرا نشده؟ صبر کن.
		var after := String(b.get("after", ""))
		if after != "" and not is_done(after):
			continue
		var needs := String(b.get("needs_flag", ""))
		if needs != "" and not bool(GameState.get_flag(needs, false)):
			continue
		out.append(b)
	return out


## اجرای یک بیت. `owner_node` صحنه‌ای است که صفحهٔ ارتقا را روی آن
## باز می‌کنیم.
func play(b: Dictionary, owner_node: Node) -> void:
	var id := String(b.get("id", ""))
	if String(b.get("cutscene", "")) != "":
		await Cutscene.play(String(b["cutscene"]))
	elif (b.get("say", []) as Array).size() > 0:
		await Cutscene.say(b["say"], id)
	elif bool(b.get("upgrade", false)):
		await _run_upgrade(owner_node)
	GameState.set_flag(flag_of(id), true)
	beat_played.emit(id)
	if bool(b.get("chapter_end", false)):
		GameState.set_flag("ch1_done", true)
		chapter_ended.emit()


func _run_upgrade(owner_node: Node) -> void:
	var ui := UpgradeChoice.new()
	if owner_node == null:
		owner_node = self
	owner_node.add_child(ui)
	await ui.pick()
	ui.queue_free()
