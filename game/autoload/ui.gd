## Ui — تم مرکزی را روی کل بازی می‌نشاند و توست نشان می‌دهد (گام ۵۹)
##
## **چرا autoload:** تم باید روی ریشهٔ درخت بنشیند تا هر صفحه‌ای که باز
## می‌شود — از منو تا آزمون‌ها — همان فونت و همان قاب را داشته باشد.
## تا پیش از این هر صفحه فونت پیش‌فرض گودو را می‌گرفت و متن فارسی با
## حروف جدا و چپ‌چین درمی‌آمد.
extends Node

## توست‌ها (سند ۱۷ بند ۱۵): «ذخیره شد»، «آیتم گرفتی»، «هدف تازه».
const TOAST_SECONDS := 2.2
const TOAST_FADE := 0.25

var _toast_layer: CanvasLayer
var _toast_box: VBoxContainer


func _ready() -> void:
	var t := UiTheme.get_theme()
	get_tree().root.theme = t
	# صفحه‌هایی که بعداً باز می‌شوند هم همین تم را می‌گیرند، چون تم
	# ریشه به همهٔ فرزندان ارث می‌رسد.
	_build_toasts()
	EventBus.connect("toast", Callable(self, "toast")) if EventBus.has_signal("toast") else null


func _build_toasts() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 120
	_toast_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_toast_layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.anchor_right = 1.0
	root.anchor_bottom = 1.0
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_layer.add_child(root)
	_toast_box = VBoxContainer.new()
	_toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	_toast_box.add_theme_constant_override("separation", 10)
	_toast_box.anchor_left = 0.0
	_toast_box.anchor_right = 1.0
	_toast_box.anchor_top = 0.0
	_toast_box.anchor_bottom = 0.0
	_toast_box.offset_left = 40
	_toast_box.offset_right = -40
	_toast_box.offset_top = 28
	_toast_box.offset_bottom = 200
	_toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_toast_box)


## یک پیام کوتاه بالای صفحه. `icon_name` از `ui/icons` است یا خالی.
func toast(text: String, icon_name: String = "") -> void:
	if _toast_box == null:
		return
	var holder := UiKit.panel("panel_s")
	holder.custom_minimum_size = Vector2(0, 86)
	holder.size_flags_horizontal = Control.SIZE_SHRINK_END
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.anchor_right = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = 30
	row.offset_right = -30
	row.offset_top = 16
	row.offset_bottom = -16
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	holder.add_child(row)
	if icon_name != "":
		var ic := TextureRect.new()
		ic.texture = UiKit.icon(icon_name)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ic.custom_minimum_size = Vector2(44, 44)
		row.add_child(ic)
	row.add_child(UiKit.label(text, "Hud", HORIZONTAL_ALIGNMENT_CENTER))
	_toast_box.add_child(holder)
	holder.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(holder, "modulate:a", 1.0, TOAST_FADE)
	tw.tween_interval(TOAST_SECONDS)
	tw.tween_property(holder, "modulate:a", 0.0, TOAST_FADE)
	tw.tween_callback(holder.queue_free)
