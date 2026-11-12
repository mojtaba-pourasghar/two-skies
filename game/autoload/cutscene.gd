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
## چیدمان برای ۱۲۸۰×۷۲۰. تا گام ۵۷ عددها برای ۴۸۰×۲۷۰ بودند، یعنی جعبهٔ
## متن وسط صفحه می‌افتاد و فونت ۱۱ پیکسلی روی ۷۲۰ خوانا نبود.
const BAR_H: int = 56
const BOX_X: int = 64
const BOX_Y: int = 520
const BOX_W: int = 1152
const BOX_H: int = 132

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
var _root: Control
var _bg: TextureRect
var _portrait: TextureRect
var _box: NinePatchRect
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

	# **ریشهٔ چیدمان LTR.** پروژه `root_node_layout_direction=2` (راست‌به‌چپ)
	# دارد، و در آن حالت گودو `position.x` کنترل‌ها را آینه می‌کند: جعبهٔ
	# متن با x=۶۴ در واقع روی ۱۳۴۴ می‌نشست، یعنی **بیرون صفحه**. متن و
	# جعبه هر دو «visible=true» بودند و هیچ‌کدام دیده نمی‌شدند — فقط با
	# چاپ `get_global_rect()` معلوم شد. مختصات‌ها اینجا LTR می‌مانند؛
	# راست‌به‌چپ بودن **متن** کار خود Labelهاست.
	_root = UiKit.themed_root()
	_root.name = "Ui"
	_root.layout_direction = Control.LAYOUT_DIRECTION_LTR
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.anchor_right = 1.0
	_root.anchor_bottom = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_root)

	# تصویر صحنه، **زیر** همهٔ چیزهای رابط. تا گام ۵۷ هیچ صحنه‌ای تصویر
	# نداشت و صحنهٔ آغاز فصل یک صفحهٔ خاکستری با نوار سینمایی بود — در
	# عکس گرفته شد و دیده شد، هیچ آزمونی نمی‌گفت.
	_bg = TextureRect.new()
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.anchor_right = 1.0
	_bg.anchor_bottom = 1.0
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.visible = false
	_root.add_child(_bg)

	# پرتره‌ی گوینده، گوشهٔ پایین-راست بالای جعبهٔ متن
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# لنگر نسبی، نه مختصات مطلق: در چیدمان راست‌به‌چپ مختصات آینه می‌شود
	# و پرتره بیرون صفحه می‌افتاد.
	_portrait.anchor_left = 0.72
	_portrait.anchor_right = 0.98
	_portrait.anchor_top = 0.40
	_portrait.anchor_bottom = 0.84
	_portrait.offset_left = 0
	_portrait.offset_right = 0
	_portrait.offset_top = 0
	_portrait.offset_bottom = 0
	_portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_portrait.visible = false
	_root.add_child(_portrait)

	# جعبهٔ متن: پس‌زمینهٔ نیمه‌شفاف تا متن روی هر تصویری خوانا بماند
	# **کادر نقاشی‌شده، نه مستطیل.** تا گام ۵۹ یک ColorRect تیره بود.
	_box = NinePatchRect.new()
	_box.texture = UiKit.tex("ui/kit/panels/panel_wide_np.png")
	_box.patch_margin_left = 48
	_box.patch_margin_right = 48
	_box.patch_margin_top = 44
	_box.patch_margin_bottom = 44
	_box.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_anchor_box(_box, 200, 68)
	_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_box.visible = false
	_root.add_child(_box)

	# نوار سینمایی ۱۶:۹ با نوارهای ۳۲ پیکسلی (§۱۸)
	_bars_top = ColorRect.new()
	_bars_top.color = Color.BLACK
	_bars_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_bars_top.anchor_right = 1.0
	_bars_top.offset_bottom = BAR_H
	_bars_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars_top.visible = false
	_root.add_child(_bars_top)

	_bars_bottom = ColorRect.new()
	_bars_bottom.color = Color.BLACK
	_bars_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bars_bottom.anchor_right = 1.0
	_bars_bottom.anchor_top = 1.0
	_bars_bottom.anchor_bottom = 1.0
	_bars_bottom.offset_top = -BAR_H
	_bars_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bars_bottom.visible = false
	_root.add_child(_bars_bottom)

	_speaker = Label.new()
	_speaker.theme_type_variation = "Name"
	_speaker.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_anchor_box(_speaker, 186, 156, 110)
	_speaker.visible = false
	_root.add_child(_speaker)

	_text = Label.new()
	_text.theme_type_variation = "Dialog"
	_text.layout_direction = Control.LAYOUT_DIRECTION_RTL
	_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_anchor_box(_text, 150, 86, 110)
	_text.visible = false
	_root.add_child(_text)

	_skip_hint = Label.new()
	_skip_hint.theme_type_variation = "Small"
	_skip_hint.text = "⏭"
	_skip_hint.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_skip_hint.anchor_right = 1.0
	_skip_hint.offset_left = 0
	_skip_hint.offset_right = -24
	_skip_hint.offset_top = 64
	_skip_hint.offset_bottom = 90
	_skip_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_skip_hint.visible = false
	_root.add_child(_skip_hint)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.anchor_right = 1.0
	_fade.anchor_bottom = 1.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_fade)


## جعبه را به **لبهٔ پایین** می‌چسباند با حاشیهٔ چپ و راست قرینه.
## قرینه بودن عمدی است: در چیدمان راست‌به‌چپ گودو چپ و راست را عوض
## می‌کند، و با حاشیهٔ برابر، عوض شدنشان هیچ فرقی نمی‌کند.
func _anchor_box(c: Control, from_bottom: int, to_bottom: int, side: int = 64) -> void:
	c.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	c.anchor_left = 0.0
	c.anchor_right = 1.0
	c.anchor_top = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = side
	c.offset_right = -side
	c.offset_top = -from_bottom
	c.offset_bottom = -to_bottom


## رد کردن فوری — برای آزمون سرتاسری و برای دکمهٔ «رد کردن».
func skip_now() -> void:
	if is_playing:
		_skip_requested = true


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


## گفت‌وگوی **داخل اتاق** (M5-ج): همان جعبه و همان تایپ، بی نوار
## سینمایی و بی پرده. دوربین و اتاق سر جایشان می‌مانند و فقط کنترل
## گرفته می‌شود، چون این‌ها لحظه‌های کوتاه‌اند نه صحنه.
##
## `lines` فهرستی از {key, speaker, portrait} است، یا رشتهٔ ساده‌ی کلید.
func say(lines: Array, source: String = "say") -> void:
	if lines.is_empty() or is_playing:
		return
	is_playing = true
	_skip_requested = false
	_current_id = source
	var before := GameMode.control
	GameMode.set_control(GameMode.ControlMode.CUTSCENE)
	for raw in lines:
		if _skip_requested:
			break
		var line: Dictionary = raw if raw is Dictionary else {"key": String(raw)}
		await _type_line(line)
	_box.visible = false
	_portrait.visible = false
	_text.visible = false
	_speaker.visible = false
	GameMode.set_control(before)
	is_playing = false
	finished.emit(source)


func _play_shot(index: int, shot: Dictionary) -> void:
	shot_started.emit(index, shot)

	# تصویر صحنه
	var bg_rel := String(shot.get("bg", ""))
	if bg_rel != "":
		var tex: Texture2D = AssetPath.texture(bg_rel)
		_bg.texture = tex
		_bg.visible = tex != null
		if tex == null:
			push_warning("Cutscene: تصویر «%s» پیدا نشد." % bg_rel)

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
	_box.visible = true
	# پرتره: `portrait` خط، وگرنه حالت خنثای گوینده
	var mood := String(line.get("portrait", "neutral"))
	if speaker in ["kairo", "ilara"] and mood != "":
		var ptex: Texture2D = AssetPath.texture("portraits/%s/%s_alpha.png" % [speaker, mood])
		_portrait.texture = ptex
		_portrait.visible = ptex != null
	else:
		_portrait.visible = false
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
		_box.visible = false
		_portrait.visible = false
		_bg.visible = false
		_bg.texture = null
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
