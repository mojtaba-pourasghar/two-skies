## NetService — §۱۲ و سند ۰۵
##
## نسخهٔ ۱ سرور ندارد. این لایه از همین اول هست تا بعداً فقط پیاده‌سازی عوض شود
## و بقیهٔ بازی دست نخورد. در حالت local همهٔ متدها بی‌اثر پاسخ می‌دهند.
extends Node

enum Mode { LOCAL, REMOTE }

var mode: Mode = Mode.LOCAL


func is_online() -> bool:
	return mode == Mode.REMOTE


## رتبه‌بندی: در حالت local فقط بهترین زمان‌های خود بازیکن
func submit_time(level_id: String, seconds: float) -> bool:
	if mode == Mode.LOCAL:
		return true
	return false


func fetch_leaderboard(level_id: String) -> Array:
	return []


func verify_receipt(_sku: String, _token: String) -> bool:
	# نسخهٔ ۱: رسید فقط توسط پولاکی و بازار بررسی می‌شود (سند ۰۵)
	return true
