## کیت رابط — سازندهٔ قطعه‌های آمادهٔ صفحه‌ها (گام ۵۹، سند ۱۷)
##
## هر صفحه‌ای که بخواهد پنل، دکمه، آیکون یا تزئین بگذارد، از اینجا
## می‌گیرد. دو دلیل: یکی اینکه همه‌جا یک شکل باشد، و دیگری اینکه
## **چیدمان راست‌به‌چپ** یک‌بار اینجا درست شود نه در هر صفحه.
##
## قاعدهٔ راست‌به‌چپ که در گام ۵۷ گران تمام شد: پروژه
## `root_node_layout_direction=2` دارد و گودو `position.x` کنترل‌ها را
## آینه می‌کند. پس اینجا هیچ‌چیز با `position` مطلق چیده نمی‌شود؛
## همه‌چیز لنگر و offset دارد.
class_name UiKit
extends RefCounted

const KIT := "ui/kit/"
const ICONS := "ui/icons/"
const ORN := "ui/ornaments/"
## فضای طراحی مدیر هنر ۱۶۰۰×۹۰۰ است و پایهٔ بازی ۱۲۸۰×۷۲۰.
const ART_SCALE := 0.8


## ریشهٔ یک CanvasLayer با تم.
##
## **چرا لازم است:** تم روی پنجرهٔ ریشه نشسته، ولی ارث‌بری تم در گودو
## از زنجیرهٔ **Control**ها بالا می‌رود؛ یک CanvasLayer وسط زنجیره آن را
## می‌شکند و فرزندانش به تم پیش‌فرض موتور برمی‌گردند. پردهٔ پایان فصل
## دقیقاً همین‌طور با دکمهٔ خاکستری و فونت پیش‌فرض درآمد.
static func themed_root() -> Control:
	var c := Control.new()
	c.name = "Root"
	c.theme = UiTheme.get_theme()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	return c


static func tex(rel: String) -> Texture2D:
	return AssetPath.texture(rel)


static func icon(name: String) -> Texture2D:
	return tex(ICONS + name + ".png")


static func ornament(name: String) -> Texture2D:
	return tex(ORN + name + ".png")


## پنل نقاشی‌شده.
##
## نسخهٔ `_np` گوهرِ وسطِ لبه‌ها را ندارد تا کشیده نشود؛ پس گوهر را
## **جدا** از نسخهٔ اصلی برمی‌داریم و وسط لبهٔ بالا می‌گذاریم. اگر
## اندازهٔ پنل ثابت باشد (`stretch = false`)، همان نسخهٔ اصلی بی‌کشش
## استفاده می‌شود و گوهر جدا لازم نیست.
static func panel(which: String, stretch: bool = true) -> Control:
	var box := Control.new()
	box.name = "Panel_%s" % which
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art: Control
	if stretch:
		var np := NinePatchRect.new()
		np.texture = tex(KIT + "panels/%s_np.png" % which)
		if np.texture == null:
			np.texture = tex(KIT + "panels/%s.png" % which)
		var m := 48 if which in ["panel_xl", "panel_wide", "panel_l"] else 34
		np.patch_margin_left = m
		np.patch_margin_right = m
		np.patch_margin_top = m
		np.patch_margin_bottom = m
		np.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art = np
	else:
		var tr := TextureRect.new()
		tr.texture = tex(KIT + "panels/%s.png" % which)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		art = tr
	_fill(art)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(art)
	if stretch:
		box.add_child(_edge_gem(which))
	return box


## گوهری که از لبهٔ بالای پنل برداشته شده، دوباره وسط همان لبه.
static func _edge_gem(which: String) -> Control:
	var g := TextureRect.new()
	g.name = "Gem"
	g.texture = ornament("heart_gem")
	g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	g.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	g.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.anchor_left = 0.5
	g.anchor_right = 0.5
	g.anchor_top = 0.0
	g.anchor_bottom = 0.0
	# روی **خود لبه** بنشیند، نه بالای آن: قاب پنل کمی از لبهٔ کنترل
	# تورفته است، پس گوهر با آفست منفی شناور دیده می‌شد.
	g.offset_left = -26
	g.offset_right = 26
	g.offset_top = 20
	g.offset_bottom = 72
	return g


## دکمهٔ منو. `kind`: "" عادی، "Gold" اصلی، "Square" مربعی، "Tab" تب.
static func button(text_key: String, kind: String = "",
		min_size: Vector2 = Vector2(360, 70)) -> Button:
	var b := Button.new()
	b.text = Fa.t(text_key)
	b.custom_minimum_size = min_size
	b.focus_mode = Control.FOCUS_ALL
	if kind != "":
		b.theme_type_variation = kind
	# هدف لمسی ≥۷۲px (سند ۱۷). ارتفاع کمتر فقط برای تب مجاز است.
	# هدف لمسی سند ۱۷ ≥۷۲px است؛ در صفحه‌های فشرده (مکث) ۵۶ هم با
	# حاشیهٔ ردیف به بالای ۷۲ می‌رسد، پس کف را ۵۶ گذاشتم و نه بیشتر.
	if kind != "Tab" and b.custom_minimum_size.y < 56:
		b.custom_minimum_size.y = 56
	return b


## دکمهٔ آیکن‌دار مربعی.
static func icon_button(icon_name: String, tip: String = "",
		size: float = 86.0) -> Button:
	var b := Button.new()
	b.theme_type_variation = "Square"
	b.custom_minimum_size = Vector2(size, size)
	b.focus_mode = Control.FOCUS_ALL
	b.tooltip_text = tip
	b.icon = icon(icon_name)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", int(size * 0.52))
	return b


## برچسب.
##
## `wrap` پیش‌فرض **خاموش** است: برچسبی که در یک ردیف کنار اسلایدر
## بنشیند، عرضش را از کانتینر می‌گیرد و اگر شکستن خط روشن باشد، متن
## فارسی **حرف‌به‌حرف** عمودی می‌شود. این را در اولین عکس صفحهٔ تنظیمات
## دیدیم. شکستن خط فقط جایی که عرض معلوم است (گفت‌وگو، توضیح کارت).
static func label(text: String, variation: String = "",
		align: int = HORIZONTAL_ALIGNMENT_RIGHT, wrap: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	if variation != "":
		l.theme_type_variation = variation
	l.horizontal_alignment = align
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	return l


## عنوان با نشان و جداکنندهٔ تزئینی زیرش — سرِ همهٔ صفحه‌های بزرگ.
static func title_block(text: String, with_emblem: bool = true) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	if with_emblem:
		var e := TextureRect.new()
		e.texture = ornament("emblem_small")
		e.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		e.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		e.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		e.custom_minimum_size = Vector2(0, 76)
		e.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(e)
	v.add_child(label(text, "Heading", HORIZONTAL_ALIGNMENT_CENTER))
	var d := TextureRect.new()
	d.texture = ornament("divider_ornate")
	d.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	d.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	d.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	d.custom_minimum_size = Vector2(0, 34)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(d)
	return v


## حلقهٔ انتخاب چهارفریمی دور گرهٔ فوکوس‌شده (≈۴ فریم بر ثانیه).
static func focus_ring() -> Node:
	var r := TextureRect.new()
	r.name = "FocusRing"
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.set_script(load("res://ui/theme/focus_ring.gd"))
	return r


## چهار گوشهٔ تزئینی روی یک قاب.
static func corners(parent: Control, size: float = 72.0) -> void:
	for spec in [["corner_tl", 0.0, 0.0], ["corner_tr", 1.0, 0.0],
			["corner_bl", 0.0, 1.0], ["corner_br", 1.0, 1.0]]:
		var c := TextureRect.new()
		c.texture = ornament(String(spec[0]))
		if c.texture == null:
			continue
		c.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		c.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		c.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var ax := float(spec[1])
		var ay := float(spec[2])
		c.anchor_left = ax
		c.anchor_right = ax
		c.anchor_top = ay
		c.anchor_bottom = ay
		c.offset_left = -size * ax
		c.offset_right = size * (1.0 - ax)
		c.offset_top = -size * ay
		c.offset_bottom = size * (1.0 - ay)
		parent.add_child(c)


## تیره‌کردن پشت صفحه‌های روی‌هم.
static func dim(alpha: float = 0.72) -> ColorRect:
	var d := ColorRect.new()
	d.name = "Dim"
	d.color = Color(0.02, 0.03, 0.05, alpha)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill(d)
	return d


## گذار ورود پنل: ۰٫۲ ثانیه، محو + جابه‌جایی کم (سند ۱۷).
static func slide_in(c: Control, from: Vector2 = Vector2(0, 24)) -> void:
	c.modulate.a = 0.0
	var to := c.position
	c.position = to + from
	var tw := c.create_tween()
	tw.set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, 0.2)
	tw.tween_property(c, "position", to, 0.2).set_trans(Tween.TRANS_SINE)


static func _fill(c: Control) -> void:
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.anchor_right = 1.0
	c.anchor_bottom = 1.0
	c.offset_left = 0
	c.offset_right = 0
	c.offset_top = 0
	c.offset_bottom = 0
