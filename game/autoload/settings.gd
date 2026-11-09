## Settings — تنظیمات بازیکن (§۲، §۹، §۱۴)
extends Node

signal changed

## مقیاس دکمه‌های لمسی، ۰٫۸ تا ۱٫۳ (§۲)
var touch_scale: float = 1.0
var haptics_enabled: bool = true
var camera_shake_enabled: bool = true
## دسترس‌پذیری نبرد: پنجرهٔ زمان‌بندی ×۲ (سند ۰۸ §۴)
var assist_timing: bool = false

## حجم هر باس صدا، ۰ تا ۱ (§۱۴)
var volume := {"Master": 1.0, "Music": 0.8, "SFX": 1.0, "UI": 1.0, "Ambience": 0.7}

## پروفایل اعداد فعال (از tuning.json خوانده می‌شود)
var tuning: Dictionary = {}


func _ready() -> void:
	_load_tuning()
	_load_strings()


## جدول رشته‌های فارسی به TranslationServer داده می‌شود تا `tr(key)` کار کند (§۱۹).
## متن‌ها در JSON نگه داشته می‌شوند نه در .po، چون سند §۱ می‌گوید
## «همهٔ متن‌های فارسی فقط در data/strings_fa.json و با کلید فراخوانی می‌شوند».
func _load_strings() -> void:
	var path := "res://data/strings_fa.json"
	if not FileAccess.file_exists(path):
		push_warning("Settings: strings_fa.json پیدا نشد؛ کلیدها خام نشان داده می‌شوند.")
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary) or not parsed.has("fa"):
		push_error("Settings: strings_fa.json خراب است.")
		return
	var tr_res := Translation.new()
	tr_res.locale = "fa"
	var table: Dictionary = parsed["fa"]
	for key in table.keys():
		tr_res.add_message(key, String(table[key]))
	TranslationServer.add_translation(tr_res)
	TranslationServer.set_locale("fa")


func _load_tuning() -> void:
	var path := "res://data/tuning.json"
	if not FileAccess.file_exists(path):
		push_warning("Settings: tuning.json پیدا نشد؛ مقادیر پیش‌فرض constants.gd استفاده می‌شود.")
		return
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Settings: tuning.json خراب است.")
		return
	tuning = parsed
	# کل بازی سه‌چهارم است (D-ART-32)، پس یک پروفایل بیشتر نیست.
	# `challenge_side` در tuning.json می‌ماند ولی استفاده نمی‌شود.
	TdConst.apply_profile(tuning, CameraDirector.PROFILE)
	KairoConst.apply_profile(tuning, CameraDirector.PROFILE)


## قاعده‌های عدالت که اعتبارسنج مرحله اجبار می‌کند (§۷ و «قاعدهٔ عدالت» سند ۰۱)
func fairness() -> Dictionary:
	return tuning.get("fairness_rules", {
		"min_warning_before_lethal": 0.4,
		"min_safe_window": 1.0,
		"max_gap_tiles_without_tool": 4.5,
		"max_restart_seconds": 0.3,
	})


## یک پارامتر عددی از پروفایل فعال. اگر پروفایل فعال آن کمیت را نداشته باشد
## (پروفایل‌های جزئی مثل design01) از spec02 و بعد از fallback خوانده می‌شود.
func param(group: String, key: String, fallback: float) -> float:
	var profiles: Dictionary = tuning.get("profiles", {})
	for name in [KairoConst.active_profile, "spec02"]:
		var g: Dictionary = profiles.get(name, {}).get(group, {})
		if g.has(key):
			return float(g[key])
	return fallback


## پارامترهای موانع از پروفایل فعال (§۷)
func hazard(key: String, fallback: float) -> float:
	return param("hazards", key, fallback)


func to_dict() -> Dictionary:
	return {
		"touch_scale": touch_scale,
		"haptics_enabled": haptics_enabled,
		"camera_shake_enabled": camera_shake_enabled,
		"assist_timing": assist_timing,
		"volume": volume.duplicate(),
	}


func from_dict(d: Dictionary) -> void:
	touch_scale = clampf(float(d.get("touch_scale", 1.0)), 0.8, 1.3)
	haptics_enabled = bool(d.get("haptics_enabled", true))
	camera_shake_enabled = bool(d.get("camera_shake_enabled", true))
	assist_timing = bool(d.get("assist_timing", false))
	var v = d.get("volume", null)
	if v is Dictionary:
		for k in volume.keys():
			if v.has(k):
				volume[k] = clampf(float(v[k]), 0.0, 1.0)
	changed.emit()
