## SceneRouter — جریان صحنه‌ها (docs/02_godot_spec.md §۱۳)
##
## جریان: splash ← main_menu ←→ (play → world_map → level_intro → game → result
##        → world_map | shop | settings | letters)
## زمان هر جابه‌جایی ۰٫۲۵ ثانیه با اسلاید افقی.
extends Node

const TRANSITION_TIME: float = 0.25

const SCENES := {
	"boot": "res://scenes/boot.tscn",
	"splash": "res://ui/splash/splash.tscn",
	"main_menu": "res://ui/main_menu/main_menu.tscn",
	"world_map": "res://ui/world_map/world_map.tscn",
	"level_intro": "res://ui/level_intro/level_intro.tscn",
	"game": "res://scenes/game.tscn",
	"result": "res://ui/result/result.tscn",
	"shop": "res://ui/shop/shop.tscn",
	"settings": "res://ui/settings/settings.tscn",
	"letters": "res://ui/letters/letters.tscn",
	"about": "res://ui/about/about.tscn",
	"sandbox": "res://scenes/sandbox.tscn",
	"save_select": "res://ui/save_select/save_select.tscn",
	"status": "res://ui/status/status.tscn",
	"inventory": "res://ui/inventory/inventory.tscn",
}

## پشتهٔ صفحه‌ها، برای هماهنگی با دکمهٔ بازگشت اندروید (§۱۳)
var _stack: Array[String] = []
var current: String = ""

## بار مرحله‌ای که باید بعد از level_intro اجرا شود
var pending_level: String = ""

## نتیجهٔ آخرین مرحله، برای صفحهٔ نتیجه
var last_result: Dictionary = {}


func goto(key: String, push: bool = true) -> void:
	if not SCENES.has(key):
		push_error("SceneRouter: صحنهٔ ناشناخته «%s»" % key)
		return
	var path: String = SCENES[key]
	if not ResourceLoader.exists(path):
		push_warning("SceneRouter: صحنهٔ «%s» هنوز ساخته نشده (%s)" % [key, path])
		return
	if push and current != "":
		_stack.append(current)
	current = key
	# صدا زدن از داخل _ready یک صحنه، وقتی درخت مشغول افزودن گره است، خطا می‌دهد.
	get_tree().change_scene_to_file.call_deferred(path)


## یک مرحله به عقب. در منوی اصلی تأیید خروج لازم است (§۱۳) که UI آن را می‌گیرد.
func back() -> bool:
	if _stack.is_empty():
		return false
	var key: String = _stack.pop_back()
	current = key
	get_tree().change_scene_to_file.call_deferred(SCENES[key])
	return true


func reload_current() -> void:
	get_tree().reload_current_scene.call_deferred()


func clear_stack() -> void:
	_stack.clear()
