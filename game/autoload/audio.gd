## Audio — باس‌ها و استخر پخش (docs/02_godot_spec.md §۱۴)
##
## پنج باس: Master, Music, SFX, UI, Ambience — با استخر ۸ پخش‌کننده برای SFX.
## مهم‌ترین قاعدهٔ حس بازی: هنگام مرگ موسیقی قطع نمی‌شود.
extends Node

const SFX_POOL_SIZE: int = 8
const MUSIC_CROSSFADE: float = 0.8
const SFX_MAP_PATH := "res://data/sfx.json"

var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_on_a: bool = true
var _current_music: String = ""
var _sfx_map: Dictionary = {}
var _missing_reported: Dictionary = {}


func _ready() -> void:
	for i in SFX_POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_a.bus = "Music"
	add_child(_music_a)
	_music_b = AudioStreamPlayer.new()
	_music_b.bus = "Music"
	add_child(_music_b)
	_load_map()
	Settings.changed.connect(_apply_volumes)
	_apply_volumes()


func _load_map() -> void:
	if not FileAccess.file_exists(SFX_MAP_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SFX_MAP_PATH))
	if parsed is Dictionary:
		_sfx_map = parsed.get("sfx", {})


func _apply_volumes() -> void:
	for bus_name in Settings.volume.keys():
		var idx := AudioServer.get_bus_index(bus_name)
		if idx < 0:
			continue
		var v: float = float(Settings.volume[bus_name])
		AudioServer.set_bus_volume_db(idx, -80.0 if v <= 0.001 else linear_to_db(v))


## یک جلوهٔ صوتی با کلید پخش می‌کند (§۱۴). کلید نبود یا فایل نبود = سکوت، نه خطا:
## در نسخهٔ با مکان‌نگهدار همهٔ کلیدها به یک فایل بی‌صدا اشاره می‌کنند.
func play_sfx(key: String, bus: String = "SFX") -> void:
	var path := String(_sfx_map.get(key, ""))
	if path == "" or not ResourceLoader.exists(path):
		if not _missing_reported.has(key):
			_missing_reported[key] = true
			if OS.is_debug_build():
				print_rich("[color=orange]Audio: کلید صدا بدون فایل → «%s»[/color]" % key)
		return
	var p := _sfx_pool[_sfx_next]
	_sfx_next = (_sfx_next + 1) % SFX_POOL_SIZE
	p.bus = bus
	p.stream = load(path)
	p.play()


## تغییر آهنگ با کراس‌فید ۰٫۸ ثانیه (§۱۴)
func play_music(key: String) -> void:
	if key == _current_music:
		return
	var path := String(_sfx_map.get(key, ""))
	if path == "" or not ResourceLoader.exists(path):
		_current_music = key
		return
	var from := _music_a if _music_on_a else _music_b
	var to := _music_b if _music_on_a else _music_a
	to.stream = load(path)
	to.volume_db = -80.0
	to.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(to, "volume_db", 0.0, MUSIC_CROSSFADE)
	if from.playing:
		tw.tween_property(from, "volume_db", -80.0, MUSIC_CROSSFADE)
		tw.chain().tween_callback(from.stop)
	_music_on_a = not _music_on_a
	_current_music = key


func stop_music() -> void:
	_music_a.stop()
	_music_b.stop()
	_current_music = ""
