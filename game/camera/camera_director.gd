## کارگردان دوربین (T3؛ بازنویسی M1 طبق D-ART-32)
##
## **کل بازی سه‌چهارم است.** حالت `side` و `camera_zone` با D-ART-32 لغو
## شدند؛ اتاق چالش هم سه‌چهارم است و مانعش تلهٔ زمین‌محور. آنچه از T3 ماند و
## هنوز کار می‌کند: انتخاب رفتار دوربین هر اتاق و زمان‌بندی گذار در به در.
##
## دو رفتار دوربین (سند ۱۲ §۲):
##   `room`   — داخلی: هر اتاق یک صفحهٔ نقاشی‌شدهٔ کامل، دوربین ثابت.
##   `follow` — بیرونی: پانورامای عریض، دوربین دنبال‌کنندهٔ نرم با مرز.
class_name CameraDirector
extends Node

## گذار در به در شروع شد / تمام شد.
signal transition_started(from_room: String, to_room: String)
signal transition_finished(room_id: String)

const BEHAVIOR_ROOM := "room"
const BEHAVIOR_FOLLOW := "follow"

## گذار در به در: ۰٫۳ ثانیه (سند ۱۲ §۲ و سند ۱۱ §۲).
const DOOR_FADE: float = 0.3
## یک فریم ورودی پس از گذار نادیده گرفته می‌شود، تا دکمه‌ای که در را باز کرد
## در اتاق تازه دوباره شلیک نکند. همان قاعدهٔ GameMode (D-ART-20).
const SKIP_INPUT_FRAMES: int = 1

const FPS: int = 60

## همهٔ بازی یک پروفایل دارد؛ `challenge_side` با D-ART-32 بی‌موضوع شد.
const PROFILE := "topdown"

var behavior: String = BEHAVIOR_ROOM
var room_id: String = ""

var _fade_frames_left: int = 0
var _skip_frames_left: int = 0
var _from_room: String = ""


static func fade_frames() -> int:
	return int(round(DOOR_FADE * float(FPS)))


func setup(room_behavior: String, starting_room: String = "") -> void:
	behavior = _valid(room_behavior)
	room_id = starting_room
	_fade_frames_left = 0
	_skip_frames_left = 0


func _valid(b: String) -> String:
	return b if b in [BEHAVIOR_ROOM, BEHAVIOR_FOLLOW] else BEHAVIOR_ROOM


## گذار به اتاق تازه را شروع می‌کند.
func go_to_room(next_id: String, next_behavior: String = "") -> void:
	if _fade_frames_left > 0 or next_id == room_id:
		return
	_from_room = room_id
	room_id = next_id
	if next_behavior != "":
		behavior = _valid(next_behavior)
	_fade_frames_left = fade_frames()
	_skip_frames_left = SKIP_INPUT_FRAMES
	transition_started.emit(_from_room, room_id)


## هر فریم فیزیک صدا زده می‌شود.
func tick() -> void:
	if _skip_frames_left > 0:
		_skip_frames_left -= 1
	if _fade_frames_left > 0:
		_fade_frames_left -= 1
		if _fade_frames_left == 0:
			transition_finished.emit(room_id)


func is_transitioning() -> bool:
	return _fade_frames_left > 0


func should_ignore_input() -> bool:
	return _skip_frames_left > 0


## پیشرفت گذار، ۰ تا ۱ — لایهٔ محو از همین می‌خواند.
func fade_t() -> float:
	if _fade_frames_left <= 0:
		return 1.0
	var total := fade_frames()
	return clampf(float(total - _fade_frames_left) / float(total), 0.0, 1.0)


## شفافیت پردهٔ محو: وسط گذار تیره‌ترین است (محو به بیرون، بعد به درون).
func fade_alpha() -> float:
	if _fade_frames_left <= 0:
		return 0.0
	var t := fade_t()
	return 1.0 - absf(t - 0.5) * 2.0


func profile_name() -> String:
	return PROFILE
