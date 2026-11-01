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


## امضای HMAC سادهٔ ضد دستکاری (§۱۲).
## این «دفاع در برابر دستکاری ساده» است، نه امنیت واقعی — کلید در خود برنامه است و
## هر کسی که APK را باز کند پیدایش می‌کند. §۱۲ هم همین را می‌گوید. امنیت واقعی
## خرید از تأیید رسید بازار می‌آید، نه از این امضا.
const SIGN_KEY := "two-skies-v1-local-save"

func _ready() -> void:
	data = default_save()
	load_game()


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
		"cutscenes_seen": [],
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
	# JSON گودو هنگام خواندن همهٔ عددها را float می‌کند؛ شمارنده‌های صحیح
	# برگردانده می‌شوند تا جایی که انتظار int است (مثل نمایش سکه) درست بماند.
	for k in ["version", "coins", "gems", "adaptive_counter"]:
		out[k] = int(out.get(k, 0))
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


## ----- ثبت نتیجهٔ مرحله -----

## نتیجهٔ یک مرحله را در ذخیره می‌نشاند. بهترین‌ها فقط بهتر می‌شوند، بدتر نمی‌شوند.
func record_level_result(result: Dictionary) -> void:
	var id := String(result.get("level_id", ""))
	if id == "":
		return
	var rec := level_record(id)
	rec["stars"] = maxi(int(rec.get("stars", 0)), int(result.get("stars", 0)))
	var t := float(result.get("time", 0.0))
	var best := float(rec.get("best_time", 0.0))
	rec["best_time"] = t if best <= 0.0 else minf(best, t)
	rec["deaths"] = int(rec.get("deaths", 0)) + int(result.get("deaths", 0))
	rec["coins_best"] = maxi(int(rec.get("coins_best", 0)), int(result.get("coins", 0)))
	var found: Array = rec.get("gems_found", [])
	for g in result.get("gems", []):
		if g not in found:
			found.append(g)
	rec["gems_found"] = found

	var levels: Dictionary = data.get("levels", {})
	levels[id] = rec
	data["levels"] = levels

	# سکه و گوهر فقط هنگام رسیدن به خروج قطعی می‌شوند (§۸)
	data["coins"] = int(data.get("coins", 0)) + int(result.get("coins", 0))
	data["gems"] = int(data.get("gems", 0)) + int(result.get("gems", []).size())
	var pages: Array = data.get("pages", [])
	for pg in result.get("pages", []):
		if pg not in pages:
			pages.append(pg)
			var diary: Array = data.get("diary_pages", [])
			diary.append(pages.size())
			data["diary_pages"] = diary
	data["pages"] = pages

	progress_changed.emit()
	save_game()


func add_coins(n: int) -> void:
	data["coins"] = maxi(0, int(data.get("coins", 0)) + n)
	progress_changed.emit()
	save_game()


func spend_coins(n: int) -> bool:
	if int(data.get("coins", 0)) < n:
		return false
	data["coins"] = int(data["coins"]) - n
	progress_changed.emit()
	save_game()
	return true


func add_gems(n: int) -> void:
	data["gems"] = maxi(0, int(data.get("gems", 0)) + n)
	progress_changed.emit()
	save_game()


func spend_gems(n: int) -> bool:
	if int(data.get("gems", 0)) < n:
		return false
	data["gems"] = int(data["gems"]) - n
	progress_changed.emit()
	save_game()
	return true


func owns(sku: String) -> bool:
	return sku in data.get("purchases", [])


func grant_purchase(sku: String) -> void:
	var p: Array = data.get("purchases", [])
	if sku not in p:
		p.append(sku)
		data["purchases"] = p
		progress_changed.emit()
		save_game()


## ----- ذخیره و بازخوانی (§۱۲) -----

## نوشتن اتمیک: ابتدا فایل موقت، بعد rename — تا با قطع برق فایل خراب نشود.
## نسخهٔ قبلی به save.bak می‌رود.
func save_game() -> bool:
	data["settings"] = Settings.to_dict()
	# امضا روی **همان متنی** زده می‌شود که ذخیره می‌شود، و خودِ آن متن نگه داشته
	# می‌شود. اگر داده دوباره stringify شود امضا هرگز نمی‌خواند، چون JSON گودو
	# همهٔ عددها را هنگام خواندن float می‌کند و ۱۲۳ به «123.0» برمی‌گردد.
	var payload := JSON.stringify(data)
	var blob := JSON.stringify({"sig": _sign(payload), "payload": payload})

	var tmp := FileAccess.open(TMP_PATH, FileAccess.WRITE)
	if tmp == null:
		push_error("GameState: نوشتن فایل موقت ذخیره نشد.")
		return false
	tmp.store_string(blob)
	tmp.close()

	var dir := DirAccess.open("user://")
	if dir == null:
		return false
	if dir.file_exists(SAVE_PATH.get_file()):
		dir.copy(SAVE_PATH, BAK_PATH)
	var err := dir.rename(TMP_PATH, SAVE_PATH)
	if err != OK:
		push_error("GameState: rename ذخیره ناموفق (%d)" % err)
		return false
	return true


func load_game() -> bool:
	if _try_load(SAVE_PATH):
		return true
	# فایل اصلی خراب یا نیمه‌نوشته بود: پشتیبان (§۱۲)
	if _try_load(BAK_PATH):
		push_warning("GameState: ذخیرهٔ اصلی خوانده نشد؛ از save.bak بازیابی شد.")
		return true
	data = default_save()
	return false


func _try_load(path: String) -> bool:
	if not FileAccess.file_exists(path):
		return false
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var blob: Dictionary = parsed
	if not blob.has("payload"):
		return false
	var payload := String(blob["payload"])
	if String(blob.get("sig", "")) != _sign(payload):
		push_warning("GameState: امضای ذخیره نمی‌خواند؛ فایل دستکاری یا خراب شده.")
		return false
	var inner = JSON.parse_string(payload)
	if typeof(inner) != TYPE_DICTIONARY:
		return false
	data = migrate(inner)
	if data.has("settings") and data["settings"] is Dictionary:
		Settings.from_dict(data["settings"])
	return true


func _sign(payload: String) -> String:
	var ctx := HMACContext.new()
	if ctx.start(HashingContext.HASH_SHA256, SIGN_KEY.to_utf8_buffer()) != OK:
		return ""
	ctx.update(payload.to_utf8_buffer())
	return Marshalls.raw_to_base64(ctx.finish())


## ذخیره هنگام بسته شدن برنامه (§۱۲)
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED \
			or what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()


## ----- جعبهٔ روزانه (سند ۰۵) -----
##
## پاداش **ثابت** است نه تصادفی، تا خرید شبه‌قمار نشود و با ضوابط اسرا مشکل نداشته باشد.
const DAILY_COINS := [10, 15, 20, 40]
const DAILY_GEM_SLOT: int = 3   # جایگاه چهارم ۱ گوهر


func daily_available() -> bool:
	return String(data.get("daily", "")) != _today()


## جایگاه i را می‌گیرد (۰ تا ۳) و پاداش ثابتش را برمی‌گرداند.
func claim_daily(slot: int) -> Dictionary:
	if not daily_available() or slot < 0 or slot >= DAILY_COINS.size():
		return {}
	data["daily"] = _today()
	var coins: int = DAILY_COINS[slot]
	var gems: int = 1 if slot == DAILY_GEM_SLOT else 0
	data["coins"] = int(data.get("coins", 0)) + coins
	data["gems"] = int(data.get("gems", 0)) + gems
	progress_changed.emit()
	save_game()
	return {"coins": coins, "gems": gems}


## نسخهٔ ۱ سرور ندارد، پس ساعت گوشی مرجع است. سند ۰۵ این محدودیت را
## صریح پذیرفته: بازیکن می‌تواند ساعت را عوض کند و جعبه را زودتر باز کند.
func _today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]
