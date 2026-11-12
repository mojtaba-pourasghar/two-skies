## تم مرکزی رابط — گام ۵۹ (سند ۱۶ و ۱۷)
##
## **هیچ صفحه‌ای رنگ و فونت را مستقیم نمی‌نویسد.** هر چیزی که روی صفحه
## دیده می‌شود از اینجا می‌آید: فونت، اندازه، رنگ، و قاب دکمه و پنل.
## دلیلش ساده است — تا امروز هر صفحه رنگ و اندازهٔ خودش را داشت و
## نتیجه‌اش این بود که «پایان فصل» با «منو» هیچ شباهتی نداشت.
##
## فونت‌ها (تصمیم کاربر، D-ART-61): **Aref Ruqaa 700** فونت اصلی است —
## عنوان، منو، دکمه، نام شخصیت، گفت‌وگو. **Vazirmatn** فقط برای متن
## کوچک‌تر از ۲۴px (عدد، قیمت، توضیح)، چون Aref Ruqaa در اندازهٔ ریز
## خوانا نیست.
class_name UiTheme
extends RefCounted

const FONT_DIR := "res://assets/fonts/"
const MAIN := FONT_DIR + "aref-ruqaa-arabic-700-normal.woff2"
const MAIN_LATIN := FONT_DIR + "aref-ruqaa-latin-700-normal.woff2"
const SMALL := FONT_DIR + "vazirmatn-arabic-500-normal.woff2"
const SMALL_BOLD := FONT_DIR + "vazirmatn-arabic-700-normal.woff2"
const SMALL_LATIN := FONT_DIR + "vazirmatn-latin-500-normal.woff2"

## مرز «کوچک»: زیر این اندازه Vazirmatn، بالایش Aref Ruqaa (سند ۱۶).
const SMALL_MAX := 24

## رنگ‌ها — همه از سند ۱۶، هیچ‌کدام من‌درآوردی.
const C_TITLE := Color("#F3D38A")
const C_TITLE_OUTLINE := Color("#1A0F05")
const C_TITLE_SHADOW := Color("#5A3A12")
const C_TITLE_GLOW := Color("#FF9A3A")
const C_NAME := Color("#6FE6D8")
const C_NAME_OUTLINE := Color("#04141A")
const C_DIALOG := Color("#F4EAD2")
const C_DIALOG_OUTLINE := Color("#120B05")
const C_HUD := Color("#E8D9B0")
const C_DANGER := Color("#FF6A5A")
const C_GOOD := Color("#7FE6A0")
const C_DIM := Color("#9FB0B8")

const KIT := "ui/kit/"

static var _theme: Theme = null
static var _fonts: Dictionary = {}


## تم ساخته و نگه داشته می‌شود؛ ساختش یک‌بار است.
static func get_theme() -> Theme:
	if _theme != null:
		return _theme
	_theme = Theme.new()
	var main := font(MAIN, MAIN_LATIN)
	var small := font(SMALL, SMALL_LATIN)
	_theme.default_font = main
	_theme.default_font_size = 28

	_label(_theme, "", 28, C_DIALOG, C_DIALOG_OUTLINE, 4)
	_label(_theme, "Title", 72, C_TITLE, C_TITLE_OUTLINE, 5, C_TITLE_SHADOW)
	_label(_theme, "Heading", 44, C_TITLE, C_TITLE_OUTLINE, 4, C_TITLE_SHADOW)
	_label(_theme, "Name", 26, C_NAME, C_NAME_OUTLINE, 3)
	_label(_theme, "Dialog", 30, C_DIALOG, C_DIALOG_OUTLINE, 4)
	_label(_theme, "Hud", 26, C_HUD, C_DIALOG_OUTLINE, 3)
	_label(_theme, "Small", 20, C_HUD, C_DIALOG_OUTLINE, 2, Color(0, 0, 0, 0), small)
	_label(_theme, "Tiny", 16, C_DIM, C_DIALOG_OUTLINE, 0, Color(0, 0, 0, 0), small)
	_label(_theme, "Danger", 26, C_DANGER, C_DIALOG_OUTLINE, 3)
	_label(_theme, "Good", 26, C_GOOD, C_DIALOG_OUTLINE, 3)

	_button(_theme, "", "btn_normal", "btn_hover", "btn_pressed", "btn_disabled",
			main, 30, C_TITLE)
	_button(_theme, "Gold", "btn_highlight_gold", "btn_hover", "btn_pressed",
			"btn_disabled", main, 30, Color("#FFF1CF"))
	_button(_theme, "Square", "btn_sq_normal", "btn_sq_hover", "btn_sq_pressed",
			"btn_sq_disabled", main, 24, C_TITLE)
	_button(_theme, "Tab", "tab_inactive", "tab_active", "tab_active",
			"btn_disabled", main, 26, C_NAME)

	# نوار پیشرفت از هنر، نه از مستطیل
	_theme.set_type_variation("Bar", "ProgressBar")
	_theme.set_stylebox("background", "Bar", _tex_box("controls/bar_empty", 10, 6))
	_theme.set_stylebox("fill", "Bar", _tex_box("controls/bar_fill", 10, 6))

	# اسلایدر
	_theme.set_stylebox("slider", "HSlider", _tex_box("controls/slider_track", 8, 4))
	_theme.set_stylebox("grabber_area", "HSlider", _tex_box("controls/slider_fill", 8, 4))
	_theme.set_stylebox("grabber_area_highlight", "HSlider",
			_tex_box("controls/slider_fill", 8, 4))
	var knob := _tex("controls/slider_with_knob")
	if knob != null:
		_theme.set_icon("grabber", "HSlider", _tex("controls/radio_on"))
		_theme.set_icon("grabber_highlight", "HSlider", _tex("controls/radio_on"))

	_theme.set_icon("checked", "CheckBox", _tex("controls/checkbox_on"))
	_theme.set_icon("unchecked", "CheckBox", _tex("controls/checkbox_off"))
	_theme.set_icon("radio_checked", "CheckBox", _tex("controls/radio_on"))
	_theme.set_icon("radio_unchecked", "CheckBox", _tex("controls/radio_off"))
	_theme.set_font("font", "CheckBox", main)
	_theme.set_font_size("font_size", "CheckBox", 24)
	_theme.set_color("font_color", "CheckBox", C_DIALOG)

	# پنل‌ها
	_theme.set_stylebox("panel", "PanelContainer", panel_box("panel_m"))
	return _theme


## فونت با پشتیبان لاتین. گودو `.woff2` را مستقیم می‌خواند (سنجیده شد).
static func font(path: String, latin: String = "") -> FontFile:
	if _fonts.has(path):
		return _fonts[path]
	var f := ResourceLoader.load(path) as FontFile
	if f == null:
		push_error("UiTheme: فونت «%s» بار نشد." % path)
		return null
	if latin != "":
		var l := ResourceLoader.load(latin) as FontFile
		if l != null:
			var fb: Array[Font] = f.fallbacks.duplicate()
			fb.append(l)
			f.fallbacks = fb
	_fonts[path] = f
	return f


## فونت درست برای یک اندازه: زیر ۲۴ Vazirmatn، بالا Aref Ruqaa.
static func font_for(size: int, bold: bool = false) -> FontFile:
	if size < SMALL_MAX:
		return font(SMALL_BOLD if bold else SMALL, SMALL_LATIN)
	return font(MAIN, MAIN_LATIN)


static func _label(t: Theme, name: String, size: int, col: Color, outline: Color,
		outline_px: int, shadow: Color = Color(0, 0, 0, 0), f: Font = null) -> void:
	var type := "Label" if name == "" else name
	if name != "":
		t.set_type_variation(name, "Label")
	t.set_font("font", type, f if f != null else font(MAIN, MAIN_LATIN))
	t.set_font_size("font_size", type, size)
	t.set_color("font_color", type, col)
	t.set_color("font_outline_color", type, outline)
	t.set_constant("outline_size", type, outline_px * 2)
	if shadow.a > 0.0:
		t.set_color("font_shadow_color", type, shadow)
		t.set_constant("shadow_offset_x", type, 0)
		t.set_constant("shadow_offset_y", type, 4)


static func _button(t: Theme, name: String, n: String, h: String, p: String,
		d: String, f: Font, size: int, col: Color) -> void:
	var type := "Button" if name == "" else name
	if name != "":
		t.set_type_variation(name, "Button")
	t.set_stylebox("normal", type, _tex_box("controls/" + n))
	t.set_stylebox("hover", type, _tex_box("controls/" + h))
	t.set_stylebox("pressed", type, _tex_box("controls/" + p))
	t.set_stylebox("disabled", type, _tex_box("controls/" + d))
	t.set_stylebox("focus", type, _tex_box("controls/" + h))
	t.set_font("font", type, f)
	t.set_font_size("font_size", type, size)
	for st in ["font_color", "font_hover_color", "font_pressed_color",
			"font_focus_color"]:
		t.set_color(st, type, col)
	t.set_color("font_disabled_color", type, Color(col.r, col.g, col.b, 0.45))
	t.set_color("font_outline_color", type, C_TITLE_OUTLINE)
	t.set_constant("outline_size", type, 6)


static func _tex(rel: String) -> Texture2D:
	return AssetPath.texture(KIT + rel + ".png")


## StyleBox از یک تکه هنر، با حاشیهٔ ۹تکه.
static func _tex_box(rel: String, mx: int = 26, my: int = 18) -> StyleBox:
	var tex := _tex(rel)
	if tex == null:
		# **رنگ ساده جایگزین هنر نمی‌شود** (دستور کاربر): اگر هنر نبود،
		# جعبهٔ خالی برمی‌گردد و در لاگ می‌آید تا دیده شود، نه اینکه یک
		# مستطیل تخت بی‌صدا جایش بنشیند.
		push_warning("UiTheme: هنر «%s» نیست." % rel)
		return StyleBoxEmpty.new()
	var b := StyleBoxTexture.new()
	b.texture = tex
	b.texture_margin_left = mx
	b.texture_margin_right = mx
	b.texture_margin_top = my
	b.texture_margin_bottom = my
	b.content_margin_left = mx + 8
	b.content_margin_right = mx + 8
	b.content_margin_top = my + 2
	b.content_margin_bottom = my + 2
	return b


## پنل نقاشی‌شده به شکل StyleBox. از نسخهٔ `_np` استفاده می‌شود، چون در
## آن گوهرِ وسطِ لبه‌ها برداشته شده و کش آمدن قاب، گوهر را کشیده و زشت
## نمی‌کند (توضیح مدیر هنر، دستهٔ ۲۵).
static func panel_box(which: String) -> StyleBox:
	var tex := _tex("panels/%s_np" % which)
	if tex == null:
		tex = _tex("panels/%s" % which)
	if tex == null:
		push_warning("UiTheme: پنل «%s» نیست." % which)
		return StyleBoxEmpty.new()
	var b := StyleBoxTexture.new()
	b.texture = tex
	var m := 48 if which in ["panel_xl", "panel_wide", "panel_l"] else 36
	b.texture_margin_left = m
	b.texture_margin_right = m
	b.texture_margin_top = m
	b.texture_margin_bottom = m
	b.content_margin_left = m + 10
	b.content_margin_right = m + 10
	b.content_margin_top = m + 6
	b.content_margin_bottom = m + 6
	return b
