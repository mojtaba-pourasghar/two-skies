## GameState — پیشرفت و ذخیره (docs/02_godot_spec.md §۱۲ و §۲۰)
##
## قالب ذخیره از همین اول فیلدهای فصل‌های بعد (§۲۰) را دارد تا بعداً مهاجرت لازم نشود.
## پیادهٔ کامل نوشتن اتمیک و HMAC در گام ۵ تکمیل می‌شود؛ اینجا شکل داده و API قطعی است.
extends Node

const SAVE_VERSION: int = 2
const SAVE_PATH := "user://save.json"
const BAK_PATH := "user://save.bak"
const TMP_PATH := "user://save.tmp"

signal progress_changed

var data: Dictionary = {}

## وضعیت زندهٔ مرحلهٔ در جریان — در ذخیره نمی‌رود
var run := {
	"level_id": "",
	"room_id": "",
	"coins": 0,
	"gems": [],
	"pages": [],
	"deaths": 0,
	"ilara_falls": 0,
	"started_msec": 0,
}


func _ready() -> void:
	data = default_save()


func default_save() -> Dictionary:
	return {
		"version": SAVE_VERSION,
		"coins": 0,
		"gems": 0,
		"levels": {},          # شناسهٔ مرحله → {stars, best_time, deaths, gems_found, coins_best}
		"pages": [],
		"tools_unlocked": [],
		"daily": "",
		"settings": {},
		"purchases": [],
		"ads_stats": {},
		# §۲۰ — از ابتدا موجود، در نسخهٔ ۱ همه در مقدار پیش‌فرض می‌مانند
		"nexa_balance": 0,
		"stability": 50,
		"knowledge": 50,
		"unity": 50,
		"choices": {},
		"diary_pages": [],
		"father_letter_unlocked": false,
		"adaptive_counter": 0,
		"pillars": {},
		"ending": null,
	}


## مهاجرت قالب — هیچ فیلدی هرگز پاک نمی‌شود (§۱۲)
func migrate(loaded: Dictionary) -> Dictionary:
	var out := default_save()
	for key in loaded.keys():
		out[key] = loaded[key]
	var from_version := int(loaded.get("version", 1))
	if from_version < SAVE_VERSION:
		# نسخهٔ ۱ → ۲: فیلدهای §۲۰ مقدار پیش‌فرض می‌گیرند، که بالا اعمال شد.
		out["version"] = SAVE_VERSION
	out["nexa_balance"] = clampi(int(out["nexa_balance"]), -100, 100)
	for k in ["stability", "knowledge", "unity"]:
		out[k] = clampi(int(out[k]), 0, 100)
	return out


func is_tool_unlocked(tool_id: String) -> bool:
	return tool_id in data.get("tools_unlocked", [])


func unlock_tool(tool_id: String) -> void:
	var list: Array = data.get("tools_unlocked", [])
	if tool_id not in list:
		list.append(tool_id)
		data["tools_unlocked"] = list
		progress_changed.emit()


func level_record(level_id: String) -> Dictionary:
	return data.get("levels", {}).get(level_id, {
		"stars": 0, "best_time": 0.0, "deaths": 0, "gems_found": [], "coins_best": 0,
	})


## بالاترین مرحلهٔ باز — نسخهٔ ۱ فقط م۱ تا م۳ دارد (سند ۰۵)
func highest_unlocked_level() -> int:
	var n := 1
	for i in range(1, 4):
		if int(level_record("ch1_l%d" % i).get("stars", 0)) > 0:
			n = mini(i + 1, 3)
	return n
