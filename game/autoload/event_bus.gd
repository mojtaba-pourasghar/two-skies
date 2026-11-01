## EventBus — docs/02_godot_spec.md §۸
##
## همهٔ رویدادهای مهم بازی از همین‌جا منتشر می‌شوند تا آمار (§۱۶) و UI بتوانند
## بدون وابستگی مستقیم به بازیکن یا مرحله به آن‌ها گوش بدهند.
extends Node

signal level_started(level_id: String)
signal room_entered(level_id: String, room_id: String)
signal coin_collected(room_id: String, coin_index: int)
signal gem_collected(gem_id: String)
signal page_collected(page_id: String)
signal note_shown(text_key: String)
signal player_died(who: String)            ## "kairo" یا "ilara"
signal level_completed(level_id: String, result: Dictionary)
signal companion_command(command: String)  ## "stay" یا "come"
signal tool_used(tool_id: String)

## نوشتن رویدادها در user://events.log — در نسخهٔ نهایی خاموش می‌شود (§۱۶)
var log_events: bool = OS.is_debug_build()

const LOG_PATH := "user://events.log"
var _log: FileAccess = null


func _ready() -> void:
	if not log_events:
		return
	_log = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if _log == null:
		log_events = false
		return
	# هر سیگنال صریح وصل می‌شود؛ حلقه روی get_signal_list() سیگنال‌های خود Node را
	# هم می‌گیرد و با تعداد آرگومان اشتباه خطا می‌دهد.
	level_started.connect(func(a): _w("level_started", [a]))
	room_entered.connect(func(a, b): _w("room_entered", [a, b]))
	coin_collected.connect(func(a, b): _w("coin_collected", [a, b]))
	gem_collected.connect(func(a): _w("gem_collected", [a]))
	page_collected.connect(func(a): _w("page_collected", [a]))
	note_shown.connect(func(a): _w("note_shown", [a]))
	player_died.connect(func(a): _w("player_died", [a]))
	level_completed.connect(func(a, b): _w("level_completed", [a, b]))
	companion_command.connect(func(a): _w("companion_command", [a]))
	tool_used.connect(func(a): _w("tool_used", [a]))


func _w(event_name: String, args: Array) -> void:
	if _log == null:
		return
	_log.store_line("%d\t%s\t%s" % [Time.get_ticks_msec(), event_name, JSON.stringify(args)])
	_log.flush()


func _exit_tree() -> void:
	if _log != null:
		_log.close()
		_log = null
