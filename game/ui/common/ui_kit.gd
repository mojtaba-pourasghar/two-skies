## ابزار ساخت صفحه‌های UI — docs/02_godot_spec.md §۱۳
##
## همهٔ صفحه‌ها Control با ساختار Container و Theme مشترک‌اند، راست‌به‌چپ، و
## دکمه‌ها حداقل ۴۸×۴۸ پیکسل مجازی لمس دارند.
##
## صفحه‌ها در کد ساخته می‌شوند نه در .tscn، تا چیدمان و قاعدهٔ RTL و اندازهٔ لمس
## در یک جا باشد و با رسیدن هنر نهایی (گام ۶ سند ۰۵) فقط همین فایل عوض شود.
class_name UIKit
extends RefCounted

const MIN_TOUCH: float = 48.0
const PANEL_BG := Color(Palette.UI_PANEL, 0.92)
const ACCENT := Palette.DIGITAL_CYAN
const MUTED := Palette.LIGHT_DUST


static func make_root(title_key: String) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.anchor_right = 1.0
	box.anchor_bottom = 1.0
	box.layout_direction = Control.LAYOUT_DIRECTION_RTL
	box.add_theme_constant_override("separation", 4)
	box.offset_left = 12
	box.offset_top = 8
	box.offset_right = -12
	box.offset_bottom = -8
	if title_key != "":
		box.add_child(make_title(title_key))
	return box


static func make_title(key: String) -> Label:
	var l := Label.new()
	l.text = Fa.t(key)
	l.add_theme_font_size_override("font_size", 16)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.layout_direction = Control.LAYOUT_DIRECTION_RTL
	return l


static func make_label(text: String, size: int = 10, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.layout_direction = Control.LAYOUT_DIRECTION_RTL
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return l


## دکمه با حداقل اندازهٔ لمس ۴۸×۴۸ (§۱۳)
static func make_button(text_key: String, enabled: bool = true,
		suffix: String = "") -> Button:
	var b := Button.new()
	b.text = Fa.t(text_key) + suffix
	b.custom_minimum_size = Vector2(MIN_TOUCH * 2.2, MIN_TOUCH * 0.75)
	b.add_theme_font_size_override("font_size", 11)
	b.layout_direction = Control.LAYOUT_DIRECTION_RTL
	b.disabled = not enabled
	if not enabled:
		b.add_theme_color_override("font_disabled_color", MUTED)
	return b


static func make_row() -> HBoxContainer:
	var h := HBoxContainer.new()
	h.layout_direction = Control.LAYOUT_DIRECTION_RTL
	h.add_theme_constant_override("separation", 6)
	return h


static func make_spacer(height: float = 6.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, height)
	return c


## نوار لغزان تنظیمات، با برچسب راست‌چین
static func make_slider(label_key: String, value: float, lo: float, hi: float,
		on_change: Callable) -> HBoxContainer:
	var row := make_row()
	row.add_child(make_label(Fa.t(label_key), 10))
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(120, MIN_TOUCH * 0.6)
	s.value_changed.connect(on_change)
	row.add_child(s)
	return row


static func make_toggle(label_key: String, value: bool, on_change: Callable) -> HBoxContainer:
	var row := make_row()
	row.add_child(make_label(Fa.t(label_key), 10))
	var c := CheckButton.new()
	c.button_pressed = value
	c.custom_minimum_size = Vector2(MIN_TOUCH, MIN_TOUCH * 0.7)
	c.toggled.connect(on_change)
	row.add_child(c)
	return row


## پس‌زمینهٔ تیره صفحه
static func make_backdrop(parent: Control) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = PANEL_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.anchor_right = 1.0
	bg.anchor_bottom = 1.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	parent.move_child(bg, 0)
	return bg


## نوار بالای صفحه: سکه و زمرد (§۱۳)
static func make_currency_bar() -> HBoxContainer:
	var row := make_row()
	row.add_child(make_label("%s %s" % [Fa.t("ui_coins"), Fa.num(int(GameState.data.get("coins", 0)))], 10,
		Palette.COIN))
	row.add_child(make_label("%s %s" % [Fa.t("ui_gems"), Fa.num(int(GameState.data.get("gems", 0)))], 10,
		Palette.EMERALD))
	return row
