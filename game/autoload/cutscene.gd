## سیستم فیلم‌نامه — docs/02_godot_spec.md §۱۸
##
## هر صحنه یک فایل `res://data/cutscenes/c<فصل>_l<مرحله>.json` است که لیستی از
## نماهاست و این Autoload آن را نما به نما اجرا می‌کند.
##
## نسخهٔ ۱ فقط سه صحنه لازم دارد (سند ۰۵): مقدمهٔ داستانی (~۴۰ ثانیه)،
## عنوان فصل ۱، و صحنهٔ «پایان نسخهٔ اول». ولی قالب از همین اول کامل است تا
## فصل‌های بعد چیزی بازنویسی نکنند.
extends Node

signal finished(id: String)
signal shot_started(index: int, shot: Dictionary)
signal choice_made(key: String, index: int)

## باکس گفت‌وگو: حداکثر ۲ خط × ۴۰ کاراکتر، هر حرف ۰٫۰۳۵ ثانیه (§۱۸)
const MAX_LINES: int = 2
const MAX_CHARS: int = 40
const CHAR_TIME: float = 0.035
## بلیپ هر ۲ حرف پخش می‌شود (§۱۸)
const BLIP_EVERY: int = 2

## کد نما → زوم دوربین (§۱۸)
const SHOT_ZOOM := {
	"ج": 1.0,    # ثابت
	"س": 1.0,    # سه‌چهارم
	"ن": 0.75,   # باز
	"ک": 2.0,    # نزدیک
	"پ": 1.0,    # پیگیر با تأخیر ۰٫۲ ثانیه
	"ب": 0.8,    # بالا به پایین
	"ل": 1.0,    # لرزش
}

## تبدیل نما → مدت (§۱۸)
const TRANSITIONS := {
	"cut": 0.0,
	"dissolve": 0.4,
	"black": 0.8,
	"white": 0.6,
}

var is_playing: bool = false

var _layer: CanvasLayer
var _fade: ColorRect
var _bars_top: ColorRect
var _bars_bottom: ColorRect
var _text: Label
var _speaker: Label
var _skip_hint: Label
var _current_id: String = ""
var _skip_requested: bool = false


func _ready() -> void:
	_build_ui()


func _build_ui() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 100
	_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_layer)

	# نوار سینمایی ۱۶:۹ با نوارهای ۳۲ پیکسلی (§۱۸)
	_bars_top = ColorRect.new()
	_bars_top.color = Color.BLACK
	_bars_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_bars_top.anchor_right = 1.0
	_bars_top.offset_bottom = 32
	_bars_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars_top.visible = false
	_layer.add_child(_bars_top)

	_bars_bottom = ColorRect.new()
	_bars_bottom.color = Color.BLACK
	_bars_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bars_bottom.anchor_right = 1.0
	_bars_bottom.anchor_top = 1.0
	_bars_bottom.anchor_bottom = 1.0
	_bars_bottom.offset_top = -32
	_bars_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars_bottom.visible = false
	_layer.add_child(_bars_bottom)

	_speaker = Label.new()
	_speaker.add_theme_font_size_override("font_size", 9)
	_speaker.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_speaker.position = Vector2(12, 196)
	_speaker.size = Vector2(456, 12)
	_speaker.visible = false
	_layer.add_child(_speaker)

	_text = Label.new()
	_text.add_theme_font_size_override("font_size", 11)
	_text.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.position = Vector2(12, 210)
	_text.size = Vector2(456, 32)
	_text.visible = false
	_layer.add_child(_text)

	_skip_hint = Label.new()
	_skip_hint.add_theme_font_size_override("font_size", 8)
	_skip_hint.text = "⏭"
	_skip_hint.position = Vector2(452, 4)
	_skip_hint.visible = false
	_layer.add_child(_skip_hint)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.anchor_right = 1.0
	_fade.anchor_bottom = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_fade)


## یک صحنه را از JSON اجرا می‌کند. تا پایان صحنه await می‌شود.
func play(id: String) -> void:
	var path := "res://data/cutscenes/%s.json" % id
	if not FileAccess.file_exists(path):
		push_warning("Cutscene: صحنهٔ «%s» پیدا نشد؛ رد می‌شود." % id)
		finished.emit(id)
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		push_error("Cutscene: فایل صحنهٔ «%s» خراب است." % id)
		finished.emit(id)
		return

	_current_id = id
	is_playing = true
	_skip_requested = false
	_show_frame(true)

	var shots: Array = parsed.get("shots", [])
	for i in shots.size():
		if _skip_requested:
			break
		await _play_shot(i, shots[i])

	_show_frame(false)
	is_playing = false
	_mark_seen(id)
	finished.emit(id)


func _play_shot(index: int, shot: Dictionary) -> void:
	shot_started.emit(index, shot)

	# تبدیل ورودی نما
	var tin := String(shot.get("transition_in", "cut"))
	await _transition(tin)

	# صدا: موسیقی و محیط
	for entry in shot.get("sound", []):
		if not (entry is Dictionary):
			continue
		var tag := String(entry.get("tag", ""))
		var sid := String(entry.get("id", ""))
		if tag == "music":
			Audio.play_music(sid)
		else:
			Audio.play_sfx(sid, "Ambience")

	# افکت‌ها: "shake:2"، "particles:dust"
	for fx in shot.get("effects", []):
		_apply_effect(String(fx))

	# دیالوگ
	var lines: Array = shot.get("lines", [])
	if lines.is_empty():
		await _wait(float(shot.get("duration", 2.0)))
	else:
		for line in lines:
			if _skip_requested:
				break
			await _type_line(line)

	# انتخاب — در نسخهٔ ۱ هیچ صحنه‌ای انتخاب ندارد، ولی قالب آماده است (§۱۸)
	var choice = shot.get("choice", null)
	if choice is Dictionary and not _skip_requested:
		await _present_choice(choice)


## نمایش حرف‌به‌حرف. لمس برای رد کردن فقط اگر گفت‌وگو قبلاً دیده شده باشد (§۱۸).
func _type_line(line: Dictionary) -> void:
	var key := String(line.get("key", ""))
	var full := Fa.t(key)
	var speaker := String(line.get("speaker", ""))
	var blip := String(line.get("blip", speaker))

	_speaker.visible = speaker != ""
	_speaker.text = _speaker_name(speaker)
	_text.visible = true
	_text.text = ""

	var seen := _was_seen(_current_id)
	_skip_hint.visible = seen

	var shown := ""
	for i in full.length():
		shown += full[i]
		_text.text = _clamp_box(shown)
		if i % BLIP_EVERY == 0 and blip != "":
			Audio.play_sfx("blip_%s" % blip, "UI")
		var t := 0.0
		while t < CHAR_TIME:
			await get_tree().process_frame
			t += get_process_delta_time()
			if seen and _tapped():
				_text.text = _clamp_box(full)
				await _wait_for_tap_release()
				return
		if _skip_requested:
			_text.text = _clamp_box(full)
			return

	# صبر تا لمس یا مدت پیش‌فرض
	var waited := 0.0
	while waited < 2.5:
		await get_tree().process_frame
		waited += get_process_delta_time()
		if _tapped():
			await _wait_for_tap_release()
			break
		if _skip_requested:
			break


## حداکثر ۲ خط × ۴۰ کاراکتر (§۱۸)
func _clamp_box(text: String) -> String:
	var lines := []
	var current := ""
	for word in text.split(" "):
		var candidate := word if current == "" else current + " " + word
		if candidate.length() > MAX_CHARS and current != "":
			lines.append(current)
			current = word
		else:
			current = candidate
		if lines.size() >= MAX_LINES:
			break
	if current != "" and lines.size() < MAX_LINES:
		lines.append(current)
	return "\n".join(lines)


func _speaker_name(id: String) -> String:
	match id:
		"kairo":
			return "کایرو"
		"ilara":
			return "ایلارا"
		"nexa":
			return "نکسا"
		"bolt":
			return "بولت"
		_:
			return ""


func _present_choice(choice: Dictionary) -> void:
	# نسخهٔ ۱ انتخاب داستانی ندارد؛ اگر صحنه‌ای داشت، اثرش در save ثبت می‌شود (§۱۸).
	var key := String(choice.get("key", ""))
	var effects: Dictionary = choice.get("effects", {})
	for k in effects.keys():
		if k == "nexa":
			GameState.data["nexa_balance"] = clampi(
				int(GameState.data.get("nexa_balance", 0)) + int(effects[k]), -100, 100)
		elif k in ["stability", "knowledge", "unity"]:
			GameState.data[k] = clampi(
				int(GameState.data.get(k, 50)) + int(effects[k]), 0, 100)
	choice_made.emit(key, 0)


func _apply_effect(fx: String) -> void:
	var parts := fx.split(":")
	match parts[0]:
		"shake":
			var amp := float(parts[1]) if parts.size() > 1 else 2.0
			# در صحنهٔ فیلم‌نامه فقط کد «ل» لرزش مجاز است (§۲۳)؛ دامنه حداکثر ۴ پیکسل
			_shake(minf(amp, 4.0))
		"particles":
			pass  # ذرات با رسیدن هنر نهایی اضافه می‌شود


func _shake(amp: float) -> void:
	if not Settings.camera_shake_enabled:
		return
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	var tw := create_tween()
	for i in 3:
		tw.tween_property(cam, "offset",
			Vector2(randf_range(-amp, amp), randf_range(-amp, amp)).round(), 0.05)
	tw.tween_property(cam, "offset", Vector2.ZERO, 0.05)


func _transition(kind: String) -> void:
	var dur: float = TRANSITIONS.get(kind, 0.0)
	if dur <= 0.0:
		return
	var col := Color.WHITE if kind == "white" else Color.BLACK
	_fade.color = Color(col.r, col.g, col.b, 1.0)
	var tw := create_tween()
	tw.tween_property(_fade, "color:a", 0.0, dur)
	await tw.finished


func _show_frame(on: bool) -> void:
	_bars_top.visible = on
	_bars_bottom.visible = on
	if not on:
		_text.visible = false
		_speaker.visible = false
		_skip_hint.visible = false
		_fade.color = Color(0, 0, 0, 0)


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds and not _skip_requested:
		await get_tree().process_frame
		t += get_process_delta_time()


func _tapped() -> bool:
	return Input.is_action_just_pressed("jump") or Input.is_action_just_pressed("action") \
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)


func _wait_for_tap_release() -> void:
	await get_tree().process_frame


## دکمهٔ رد کردن: نگه داشتن ۱ ثانیه (سند ۰۱ «دوربین» فصل ۱)
func request_skip() -> void:
	_skip_requested = true


func _was_seen(id: String) -> bool:
	return id in GameState.data.get("cutscenes_seen", [])


func _mark_seen(id: String) -> void:
	var seen: Array = GameState.data.get("cutscenes_seen", [])
	if id not in seen:
		seen.append(id)
		GameState.data["cutscenes_seen"] = seen
		GameState.save_game()
