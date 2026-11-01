## Ads — لایهٔ انتزاع تبلیغ (docs/02_godot_spec.md §۱۵)
##
## دو پیاده‌سازی: AdiveryProvider (اندروید، افزونهٔ Kotlin) و StubProvider
## (محیط توسعه: پاسخ موفق بعد از ۲ ثانیه). همهٔ تبلیغ‌ها اختیاری‌اند و هیچ تبلیغ
## اجباری وجود ندارد. پاداش فقط در سیگنال rewarded_completed داده می‌شود.
extends Node

signal rewarded_completed(placement: String)
signal rewarded_closed(placement: String)
signal failed(placement: String, reason: String)

const PLACEMENTS := [
	"rewarded_double_coins",
	"rewarded_hint",
	"rewarded_revive_check",
	"rewarded_daily_bonus",
]

## فاصلهٔ حداقل بین دو تبلیغ (§۱۵)
const MIN_INTERVAL_SEC: float = 90.0

const CONFIG_PATH := "res://data/ads_config.json"

var _provider: Object = null
var _config: Dictionary = {}
var _last_shown_msec: int = -1


func _ready() -> void:
	if FileAccess.file_exists(CONFIG_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
		if parsed is Dictionary:
			_config = parsed
	_provider = _pick_provider()


func _pick_provider() -> Object:
	# افزونهٔ ادیوری فقط روی اندروید و فقط اگر بیلد شده باشد موجود است.
	if OS.get_name() == "Android" and Engine.has_singleton("AdiveryGodot"):
		return Engine.get_singleton("AdiveryGodot")
	return null


func using_stub() -> bool:
	return _provider == null


func prepare(placement: String) -> void:
	if placement not in PLACEMENTS:
		push_warning("Ads: جایگاه ناشناخته «%s»" % placement)
		return
	if _provider != null and _provider.has_method("prepare"):
		_provider.call("prepare", _placement_id(placement))


func is_loaded(placement: String) -> bool:
	if not _cooldown_passed():
		return false
	if _provider != null and _provider.has_method("isLoaded"):
		return bool(_provider.call("isLoaded", _placement_id(placement)))
	# Stub: همیشه آماده (در محیط توسعه)
	return true


func show(placement: String) -> void:
	if not is_loaded(placement):
		failed.emit(placement, "not_loaded")
		return
	_last_shown_msec = Time.get_ticks_msec()
	if _provider != null and _provider.has_method("showAd"):
		_provider.call("showAd", _placement_id(placement))
		return
	await _stub_show(placement)


func _stub_show(placement: String) -> void:
	await get_tree().create_timer(2.0).timeout
	rewarded_completed.emit(placement)
	rewarded_closed.emit(placement)


func _cooldown_passed() -> bool:
	if _last_shown_msec < 0:
		return true
	return (Time.get_ticks_msec() - _last_shown_msec) / 1000.0 >= MIN_INTERVAL_SEC


func seconds_until_ready() -> float:
	if _cooldown_passed():
		return 0.0
	return MIN_INTERVAL_SEC - (Time.get_ticks_msec() - _last_shown_msec) / 1000.0


func _placement_id(placement: String) -> String:
	return String(_config.get("placements", {}).get(placement, placement))
