## رابط کاربری — گام ۵۹ (سند ۱۶ و ۱۷)
##
##   godot --headless --fixed-fps 60 res://tools/tests/test_ui.tscn
##
## چهار ادعا:
##   ۱ تم مرکزی هست و فونت و رنگ‌هایش همان‌هایی است که سند ۱۶ می‌گوید
##   ۲ هنر کیت (پنل، دکمه، آیکن، تزئین) کامل در assets هست
##   ۳ هیچ متنی از قابش بیرون نمی‌زند — در **دو** نسبت صفحه
##   ۴ هر صفحه بی‌خطا ساخته می‌شود و پس‌زمینه و قاب نقاشی‌شده دارد
extends Node2D

## دو اندازه‌ای که سند خواسته: پایهٔ بازی و یک صفحهٔ کشیدهٔ ۲۰:۹.
const SIZES := [Vector2i(1280, 720), Vector2i(1600, 720)]
const SCREENS := [
	"res://ui/main_menu/main_menu.tscn",
	"res://ui/save_select/save_select.tscn",
	"res://ui/settings/settings.tscn",
	"res://ui/inventory/inventory.tscn",
	"res://ui/status/status.tscn",
	"res://ui/about/about.tscn",
	"res://ui/pause/pause.tscn",
]
## هنری که کیت بدون آن ناقص است (نام‌ها از asset.json دستهٔ ۲۵).
const KIT_ART := [
	"ui/kit/panels/panel_xl_np.png", "ui/kit/panels/panel_l_np.png",
	"ui/kit/panels/panel_m_np.png", "ui/kit/panels/panel_s_np.png",
	"ui/kit/panels/panel_wide_np.png", "ui/kit/panels/panel_sq_np.png",
	"ui/kit/panels/slot_normal.png", "ui/kit/panels/slot_selected.png",
	"ui/kit/controls/btn_normal.png", "ui/kit/controls/btn_hover.png",
	"ui/kit/controls/btn_pressed.png", "ui/kit/controls/btn_disabled.png",
	"ui/kit/controls/btn_highlight_gold.png",
	"ui/kit/controls/btn_sq_normal.png", "ui/kit/controls/btn_sq_hover.png",
	"ui/kit/controls/tab_active.png", "ui/kit/controls/tab_inactive.png",
	"ui/kit/controls/toggle_on.png", "ui/kit/controls/toggle_off.png",
	"ui/kit/controls/checkbox_on.png", "ui/kit/controls/checkbox_off.png",
	"ui/kit/controls/radio_on.png", "ui/kit/controls/radio_off.png",
	"ui/kit/controls/slider_track.png", "ui/kit/controls/slider_fill.png",
	"ui/kit/controls/bar_empty.png", "ui/kit/controls/bar_fill.png",
	"ui/kit/controls/cursor_hand.png", "ui/kit/controls/ability_slot_fire.png",
	"ui/ornaments/emblem_large.png", "ui/ornaments/emblem_small.png",
	"ui/ornaments/divider_ornate.png", "ui/ornaments/wreath_arc.png",
	"ui/ornaments/heart_gem.png", "ui/ornaments/sparkle_star.png",
	"ui/ornaments/lock_closed.png", "ui/ornaments/lock_open.png",
	"ui/ornaments/corner_tl.png", "ui/ornaments/corner_tr.png",
	"ui/ornaments/corner_bl.png", "ui/ornaments/corner_br.png",
	"ui/ornaments/ring_0.png", "ui/ornaments/ring_1.png",
	"ui/ornaments/ring_2.png", "ui/ornaments/ring_3.png",
	"ui/menu/menu_two_skies.png", "ui/menu/defeat_bg.png",
]
const ICONS := [
	"settings", "sound_on", "sound_off", "music", "save", "load", "back",
	"close", "pause", "play", "home", "language", "backpack", "companions",
	"compass", "map", "quest_scroll", "journal", "chip", "lantern", "shield",
	"sword", "heart", "energy", "toolbox", "medkit", "battery",
	"circuit_board", "key", "paper_note", "scrap_metal", "glow_herb",
	"water_bottle", "food_can", "wire_coil", "drone_core",
]

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	_t_theme()
	_t_art()
	await _t_screens()
	_report()


func _t_theme() -> void:
	print("— تم مرکزی —")
	var t := UiTheme.get_theme()
	_check("تم ساخته شد", t != null)
	if t == null:
		return
	_check("فونت پیش‌فرض Aref Ruqaa است",
		t.default_font != null and t.default_font.get_font_name() == "Aref Ruqaa",
		"= %s" % (t.default_font.get_font_name() if t.default_font else "—"))
	_check("ریشهٔ درخت تم دارد (فونت پیش‌فرض گودو برداشته شد)",
		get_tree().root.theme != null)
	# متن ریز باید Vazirmatn باشد (سند ۱۶: زیر ۲۴px)
	var small := UiTheme.font_for(20)
	var big := UiTheme.font_for(30)
	_check("زیر ۲۴px → Vazirmatn", small != null and
		String(small.get_font_name()).begins_with("Vazirmatn"),
		"= %s" % (small.get_font_name() if small else "—"))
	_check("بالای ۲۴px → Aref Ruqaa", big != null and
		big.get_font_name() == "Aref Ruqaa")
	# رنگ‌ها دقیقاً همان‌های سند ۱۶
	_check("رنگ عنوان #F3D38A", UiTheme.C_TITLE.to_html(false).to_upper() == "F3D38A",
		"= %s" % UiTheme.C_TITLE.to_html(false))
	_check("رنگ نام #6FE6D8", UiTheme.C_NAME.to_html(false).to_upper() == "6FE6D8")
	_check("رنگ گفت‌وگو #F4EAD2", UiTheme.C_DIALOG.to_html(false).to_upper() == "F4EAD2")
	_check("دکمه قاب نقاشی‌شده دارد",
		t.get_stylebox("normal", "Button") is StyleBoxTexture)
	_check("دکمهٔ طلایی هم", t.get_stylebox("normal", "Gold") is StyleBoxTexture)
	# مجوز فونت‌ها باید کنار فایل‌ها باشد
	for lic in ["LICENSE-aref-ruqaa.txt", "LICENSE-vazirmatn.txt"]:
		_check("مجوز «%s» هست" % lic,
			FileAccess.file_exists(UiTheme.FONT_DIR + lic))


func _t_art() -> void:
	print("— هنر کیت —")
	var missing: Array[String] = []
	for rel in KIT_ART:
		if not AssetPath.exists(rel):
			missing.append(rel)
	_check("هر %d تکهٔ کیت در assets هست" % KIT_ART.size(), missing.is_empty(),
		"= %s" % str(missing))
	var mi: Array[String] = []
	for name in ICONS:
		if not AssetPath.exists("ui/icons/%s.png" % name):
			mi.append(name)
	_check("هر ۳۶ آیکن هست", mi.is_empty(), "= %s" % str(mi))


func _t_screens() -> void:
	print("— صفحه‌ها در دو نسبت صفحه —")
	for size in SIZES:
		get_tree().root.size = size
		await get_tree().process_frame
		print("  اندازهٔ %dx%d" % [size.x, size.y])
		for path in SCREENS:
			if not ResourceLoader.exists(path):
				_check("  صحنهٔ «%s» هست" % path, false)
				continue
			var inst = load(path).instantiate()
			get_tree().root.add_child(inst)
			for i in 8:
				await get_tree().process_frame
			var over: Array[String] = []
			_scan(inst, over)
			var nm: String = path.get_file().get_basename()
			_check("  «%s» بی سرریز متن" % nm, over.is_empty(),
				"= %s" % str(over.slice(0, 3)))
			if size == SIZES[0]:
				_check("  «%s» قاب یا پس‌زمینهٔ نقاشی‌شده دارد" % nm,
					_has_art(inst))
			inst.queue_free()
			await get_tree().process_frame
	get_tree().root.size = SIZES[0]


## متنی که از جعبه‌اش بیرون زده.
##
## معیار: پهنای واقعی متن با فونت و اندازهٔ همان برچسب، در برابر پهنای
## جعبه. فقط برچسب‌هایی که شکستن خط ندارند سنجیده می‌شوند؛ آن‌که
## می‌شکند، سرریز عمودی‌اش را `get_minimum_size` می‌گوید.
func _scan(n: Node, out: Array[String]) -> void:
	if n is Label:
		var l := n as Label
		if l.visible and l.text.strip_edges() != "":
			if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
				var f := l.get_theme_font("font")
				var fs := l.get_theme_font_size("font_size")
				var w: float = f.get_string_size(l.text,
					HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
				if w > l.size.x + 2.0:
					out.append("%s «%s» %d>%d" % [l.name, l.text.substr(0, 12),
						int(w), int(l.size.x)])
			elif l.get_minimum_size().y > l.size.y + 2.0:
				out.append("%s ارتفاع %d>%d" % [l.name,
					int(l.get_minimum_size().y), int(l.size.y)])
	elif n is Button:
		var b := n as Button
		if b.visible and b.text.strip_edges() != "":
			var f := b.get_theme_font("font")
			var fs := b.get_theme_font_size("font_size")
			var w: float = f.get_string_size(b.text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			if w > b.size.x - 10.0:
				out.append("دکمه «%s» %d>%d" % [b.text.substr(0, 12),
					int(w), int(b.size.x)])
	for c in n.get_children():
		_scan(c, out)


## صفحه پس‌زمینه یا قاب نقاشی‌شده دارد؟ (هیچ مستطیل تخت تنها نباشد)
func _has_art(n: Node) -> bool:
	if n is NinePatchRect and (n as NinePatchRect).texture != null:
		return true
	if n is TextureRect and (n as TextureRect).texture != null:
		return true
	for c in n.get_children():
		if _has_art(c):
			return true
	return false


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  ✔ %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  ✘ %s %s" % [label, detail])


func _report() -> void:
	print("")
	if _failures.is_empty():
		print("همهٔ %d سنجه قبول شد." % _checks)
		get_tree().quit(0)
	else:
		print("%d از %d سنجه رد شد." % [_failures.size(), _checks])
		get_tree().quit(1)
