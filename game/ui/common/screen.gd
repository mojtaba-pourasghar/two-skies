## پایهٔ همهٔ صفحه‌های UI — docs/02_godot_spec.md §۱۳
##
## دکمهٔ بازگشت اندروید را می‌گیرد: یک مرحله به عقب، و در منوی اصلی تأیید خروج.
## جابه‌جایی صفحه ۰٫۲۵ ثانیه با اسلاید افقی.
class_name Screen
extends Control

## اگر true، دکمهٔ بازگشت تأیید خروج می‌خواهد (منوی اصلی)
var confirm_exit_on_back: bool = false

var _root: VBoxContainer
var _frame: Control
## کدام پنل قاب صفحه باشد (سند ۱۷). صفحه‌های شلوغ `panel_xl`.
var panel_kind: String = "panel_xl"
## حاشیهٔ قاب از لبهٔ صفحه.
var frame_margin: Vector2 = Vector2(96, 40)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_right = 1.0
	anchor_bottom = 1.0
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	_build_backdrop()
	_root = build()
	if _root != null:
		# **محتوا داخل پنل نقاشی‌شده می‌نشیند، نه روی خود نقاشی.**
		# بی آن، متن روی پس‌زمینهٔ پرجزئیات منو خوانده نمی‌شود و صفحه
		# همان «مستطیل تخت»ی می‌ماند که کاربر گفت نباشد (سند ۱۷).
		_frame = UiKit.panel(panel_kind)
		_frame.anchor_left = 0.0
		_frame.anchor_right = 1.0
		_frame.anchor_top = 0.0
		_frame.anchor_bottom = 1.0
		_frame.offset_left = frame_margin.x
		_frame.offset_right = -frame_margin.x
		_frame.offset_top = frame_margin.y
		_frame.offset_bottom = -frame_margin.y
		_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_frame)
		# **محتوا اسکرول می‌شود.** صفحهٔ تنظیمات با شش ردیف از قاب
		# بیرون می‌زد؛ کوتاه کردن ردیف‌ها جواب موقتی است، چون هر صفحهٔ
		# تازه‌ای دوباره همان مشکل را می‌سازد.
		var scroll := ScrollContainer.new()
		scroll.anchor_right = 1.0
		scroll.anchor_bottom = 1.0
		scroll.offset_left = 64
		scroll.offset_right = -64
		scroll.offset_top = 56
		scroll.offset_bottom = -52
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_frame.add_child(scroll)
		_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_root.set_anchors_preset(Control.PRESET_TOP_WIDE)
		_root.offset_left = 0
		_root.offset_right = 0
		_root.offset_top = 0
		_root.offset_bottom = 0
		scroll.add_child(_root)
	_slide_in()


## پس‌زمینهٔ صفحه. پیش‌فرض نقاشی منو با تیرگی؛ صفحه‌هایی که روی بازی
## باز می‌شوند (مکث) این را جای دیگری می‌برند.
func _build_backdrop() -> void:
	UIKit.make_backdrop(self)


## زیرکلاس محتوای صفحه را می‌سازد.
func build() -> VBoxContainer:
	return null


func _slide_in() -> void:
	if _root == null:
		return
	# گذار ۰٫۲ ثانیه‌ای، محو + جابه‌جایی کم (سند ۱۷ بند «انیمیشن»).
	# اسلاید عرضِ کاملِ قبلی در ۱۲۸۰ پهنا پرشی دیده می‌شد.
	var target: Control = _frame if _frame != null else _root
	UiKit.slide_in(target, Vector2(0, 28))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
		_on_back()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# دکمهٔ بازگشت اندروید
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()


func _on_back() -> void:
	if confirm_exit_on_back:
		_show_exit_confirm()
		return
	if not SceneRouter.back():
		SceneRouter.goto("main_menu", false)


func _show_exit_confirm() -> void:
	var d := ConfirmationDialog.new()
	d.dialog_text = Fa.t("ui_quit_confirm")
	d.ok_button_text = Fa.t("ui_yes")
	d.cancel_button_text = Fa.t("ui_no")
	add_child(d)
	d.confirmed.connect(func():
		GameState.save_game()
		get_tree().quit())
	d.popup_centered()


## دکمهٔ «بازگشت» درون صفحه
func add_back_button(box: VBoxContainer) -> void:
	box.add_child(UIKit.make_spacer(8))
	var b := UIKit.make_button("ui_back")
	b.pressed.connect(_on_back)
	box.add_child(b)
