## تابلوی آموزشی — docs/02_godot_spec.md §۷ (نماد B)
##
## با نزدیک شدن تا ۳۲ پیکسل یک متن کوتاه نشان می‌دهد. آموزش بازی بدون متن است
## (مصوبات طراحی سند ۰۱)، پس این‌ها فقط یادداشت‌های داستانی‌اند نه راهنمای مکانیک.
class_name Note
extends Area2D

signal shown(text_key: String)

const RANGE_PX: float = 32.0

@export var text_key: String = ""

var _shown_once: bool = false
var _label: Label


func _ready() -> void:
	collision_layer = Layers.TRIGGER
	collision_mask = Layers.ACTORS
	var shape := CollisionShape2D.new()
	var c := CircleShape2D.new()
	c.radius = RANGE_PX
	shape.shape = c
	add_child(shape)

	add_child(Art.sprite(Art.NOTE))

	_label = Label.new()
	_label.add_theme_font_size_override("font_size", 8)
	_label.position = Vector2(-40, -26)
	_label.size = Vector2(80, 16)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.visible = false
	add_child(_label)

	body_entered.connect(_on_enter)
	body_exited.connect(_on_exit)


func _on_enter(body: Node2D) -> void:
	if not (body is Kairo):
		return
	_label.text = tr(text_key) if text_key != "" else ""
	_label.visible = _label.text != ""
	if not _shown_once:
		_shown_once = true
		shown.emit(text_key)
		EventBus.note_shown.emit(text_key)


func _on_exit(body: Node2D) -> void:
	if body is Kairo:
		_label.visible = false
