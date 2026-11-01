## پایهٔ همهٔ صفحه‌های UI — docs/02_godot_spec.md §۱۳
##
## دکمهٔ بازگشت اندروید را می‌گیرد: یک مرحله به عقب، و در منوی اصلی تأیید خروج.
## جابه‌جایی صفحه ۰٫۲۵ ثانیه با اسلاید افقی.
class_name Screen
extends Control

## اگر true، دکمهٔ بازگشت تأیید خروج می‌خواهد (منوی اصلی)
var confirm_exit_on_back: bool = false

var _root: VBoxContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	anchor_right = 1.0
	anchor_bottom = 1.0
	layout_direction = Control.LAYOUT_DIRECTION_RTL
	UIKit.make_backdrop(self)
	_root = build()
	if _root != null:
		add_child(_root)
	_slide_in()


## زیرکلاس محتوای صفحه را می‌سازد.
func build() -> VBoxContainer:
	return null


func _slide_in() -> void:
	if _root == null:
		return
	var from := Vector2(-get_viewport_rect().size.x, 0.0)
	_root.position = from
	var tw := create_tween()
	tw.tween_property(_root, "position", Vector2.ZERO, SceneRouter.TRANSITION_TIME)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


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
