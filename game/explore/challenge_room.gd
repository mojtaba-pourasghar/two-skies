## اتاق چالش — نمای کناری با مرگ بی‌نهایت (T15، سند ۰۹ §۲ب)
##
## قاعدهٔ مرگ اینجا **عکس** اکتشاف است: یک تماس = مرگ، ریستارت زیر ۰٫۳ ثانیه،
## مرگ بی‌نهایت، و شمارندهٔ مرگ دیده می‌شود. همان هویت «Super Meat Boy» که
## سند ۰۹ §۱۰ فقط برای اتاق چالش نگه داشت.
##
## ورود و خروج با `camera_zone` خودکار است (D-ART-09d): هیچ دکمه‌ای،
## هیچ صفحهٔ بارگذاری.
class_name ChallengeRoom
extends Node2D

signal entered(room_id: String)
signal exited(room_id: String, deaths: int, cleared: bool)
signal died(deaths: int)

@export var room_id: String = "challenge"

var deaths: int = 0
var is_active: bool = false
var cleared: bool = false
var entry_point := Vector2.ZERO

var _director: CameraDirector = null


func bind(director: CameraDirector) -> void:
	_director = director
	director.mode_changing.connect(_on_mode_changing)


func _on_mode_changing(_from: String, to: String) -> void:
	if to == CameraDirector.MODE_SIDE and _director.active_zone() == room_id:
		_enter()
	elif to == CameraDirector.MODE_TOPDOWN and is_active:
		_exit()


func _enter() -> void:
	if is_active:
		return
	is_active = true
	deaths = 0
	entered.emit(room_id)


func _exit() -> void:
	is_active = false
	exited.emit(room_id, deaths, cleared)


## یک مرگ در اتاق چالش. هیچ سقفی ندارد و هیچ جریمه‌ای.
func register_death(actor: TdActor) -> void:
	if not is_active:
		return
	deaths += 1
	actor.global_position = entry_point
	actor.velocity = Vector2.ZERO
	died.emit(deaths)


## ریستارت باید زیر ۰٫۳ ثانیه باشد (سند ۰۹ §۲ب). عدد از پروفایل می‌آید.
static func restart_seconds() -> float:
	return TdConst.RESPAWN_TIME


func mark_cleared() -> void:
	cleared = true
