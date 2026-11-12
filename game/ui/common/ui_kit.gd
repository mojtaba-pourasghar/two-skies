## ابزار ساخت صفحه‌های UI — بازنویسی گام ۵۹ روی کیت نقاشی‌شدهٔ دستهٔ ۲۵
##
## این فایل از گام ۵ مانده بود و همه‌چیزش مستطیل تخت با رنگ کد بود:
## `ColorRect` خاکستری، دکمهٔ پیش‌فرض گودو، فونت ۱۱ پیکسلی ساخته‌شده برای
## ۴۸۰×۲۷۰. نتیجه‌اش همان صفحه‌ای بود که کاربر دید و گفت «هیچ منویی
## دیزاین ندارد».
##
## حالا هر چیزی که اینجا ساخته می‌شود از **هنر** می‌آید (`UiKit` در
## `ui/theme`) و رنگ و فونتش از **تم مرکزی** (`UiTheme`). امضای
## تابع‌ها عمداً دست‌نخورده ماند تا هر هشت صفحهٔ موجود — تنظیمات،
## فروشگاه، نامه‌ها، درباره، نقشهٔ جهان، نتیجه، مکث، splash — بی هیچ
## تغییری ظاهر تازه بگیرند.
class_name UIKit
extends RefCounted

## هدف لمسی سند ۱۷: ≥۷۲px (قبلاً ۴۸ بود، برای پایهٔ ۴۸۰×۲۷۰).
const MIN_TOUCH: float = 72.0
## سه رنگ قدیمی که صفحه‌های موجود صدایشان می‌زنند، حالا به رنگ‌های تم
## اشاره می‌کنند — نه به پالت خام. (صفحه‌ها دست‌نخورده می‌مانند.)
const ACCENT := UiTheme.C_NAME
const MUTED := UiTheme.C_DIM
const PANEL_BG := Color(0.02, 0.03, 0.05, 0.62)


static func make_root(title_key: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.anchor_right = 1.0
	box.anchor_bottom = 1.0
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	# حاشیهٔ داخل قاب پنل (قاب را خود `Screen` می‌گذارد)
	box.offset_left = 72
	box.offset_top = 46
	box.offset_right = -72
	box.offset_bottom = -46
	if title_key != "":
		box.add_child(UiKit.title_block(Fa.t(title_key)))
	return box


static func make_title(key: String) -> Label:
	return UiKit.label(Fa.t(key), "Heading", HORIZONTAL_ALIGNMENT_CENTER)


static func make_label(text: String, size: int = 10, color: Color = Color.WHITE) -> Label:
	# اندازهٔ قدیمی ۱۰ و ۱۱ برای ۴۸۰×۲۷۰ بود؛ اینجا به گونهٔ تم نگاشت
	# می‌شود، نه اینکه عدد خام را بگیرد.
	var variation := "Small" if size <= 12 else "Hud"
	var l := UiKit.label(text, variation)
	if color != Color.WHITE:
		l.add_theme_color_override("font_color", color)
	return l


static func make_button(text_key: String, enabled: bool = true,
		suffix: String = "") -> Button:
	var b := UiKit.button(text_key, "", Vector2(MIN_TOUCH * 4.4, MIN_TOUCH))
	b.text = Fa.t(text_key) + suffix
	b.disabled = not enabled
	return b


static func make_row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	return h


static func make_spacer(height: float = 6.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


static func make_slider(label_key: String, value: float, lo: float, hi: float,
		on_change: Callable) -> HBoxContainer:
	var row := make_row()
	var lab := UiKit.label(Fa.t(label_key), "Hud")
	lab.custom_minimum_size = Vector2(240, 0)
	row.add_child(lab)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(320, 44)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.value_changed.connect(on_change)
	row.add_child(s)
	return row


static func make_toggle(label_key: String, value: bool, on_change: Callable) -> HBoxContainer:
	var row := make_row()
	var lab2 := UiKit.label(Fa.t(label_key), "Hud")
	lab2.custom_minimum_size = Vector2(240, 0)
	row.add_child(lab2)
	# سوییچ نقاشی‌شده: دو تکه هنر، نه CheckButton پیش‌فرض
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = value
	b.flat = true
	b.custom_minimum_size = Vector2(118, 58)
	b.focus_mode = Control.FOCUS_ALL
	var on_tex := UiKit.tex("ui/kit/controls/toggle_on.png")
	var off_tex := UiKit.tex("ui/kit/controls/toggle_off.png")
	var img := TextureRect.new()
	img.texture = on_tex if value else off_tex
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	img.mouse_filter = Control.MOUSE_FILTER_IGNORE
	img.set_anchors_preset(Control.PRESET_FULL_RECT)
	img.anchor_right = 1.0
	img.anchor_bottom = 1.0
	b.add_child(img)
	b.toggled.connect(func(on: bool):
		img.texture = on_tex if on else off_tex
		on_change.call(on))
	row.add_child(b)
	return row


## پس‌زمینهٔ صفحه: نقاشی منو با تیرگی، نه مستطیل خاکستری.
static func make_backdrop(parent: Control) -> Control:
	var holder := Control.new()
	holder.name = "Backdrop"
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.anchor_right = 1.0
	holder.anchor_bottom = 1.0
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := TextureRect.new()
	art.texture = UiKit.tex("ui/menu/menu_two_skies.png")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art.set_anchors_preset(Control.PRESET_FULL_RECT)
	art.anchor_right = 1.0
	art.anchor_bottom = 1.0
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(art)
	holder.add_child(UiKit.dim(0.62))
	parent.add_child(holder)
	parent.move_child(holder, 0)
	return holder


## نوار سکه و زمرد با آیکن نقاشی‌شده.
static func make_currency_bar() -> HBoxContainer:
	var row := make_row()
	row.alignment = BoxContainer.ALIGNMENT_END
	for spec in [["coin", int(GameState.data.get("coins", 0))],
			["gem", int(GameState.data.get("gems", 0))]]:
		var ic := TextureRect.new()
		ic.texture = UiKit.icon("key" if spec[0] == "coin" else "chip")
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.custom_minimum_size = Vector2(36, 36)
		row.add_child(ic)
		row.add_child(UiKit.label(Fa.num(int(spec[1])), "Hud"))
	return row
