## پردهٔ بارگذاری — سند ۱۷ بند ۱۳
##
## آرم، اسپینر چهارفریمی (`ring_0..3`)، و یک نکتهٔ کوتاه. دست‌کم ۰٫۸
## ثانیه دیده می‌شود، حتی اگر بارگذاری زودتر تمام شود — پریدنِ یک‌فریمی
## پرده بدتر از نبودنش است.
class_name LoadingScreen
extends CanvasLayer

const MIN_SECONDS := 0.8
const TIPS := ["tip_hack", "tip_stealth", "tip_statue"]

var _t: float = 0.0
var _done: bool = false


func _init() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS


func _ready() -> void:
	var root := UiKit.themed_root()
	add_child(root)
	root.add_child(UiKit.dim(0.96))

	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	v.anchor_left = 0.0
	v.anchor_right = 1.0
	v.anchor_top = 0.0
	v.anchor_bottom = 1.0
	root.add_child(v)

	var em := TextureRect.new()
	em.texture = UiKit.ornament("emblem_large")
	em.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	em.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	em.custom_minimum_size = Vector2(0, 150)
	em.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(em)

	var ring := UiKit.focus_ring()
	(ring as Control).custom_minimum_size = Vector2(0, 74)
	v.add_child(ring)

	v.add_child(UiKit.label(Fa.t("ui_loading"), "Hud", HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UiKit.label(Fa.t(TIPS[randi() % TIPS.size()]), "Small",
			HORIZONTAL_ALIGNMENT_CENTER, true))


func _process(delta: float) -> void:
	_t += delta


## پرده را می‌بندد، ولی نه پیش از `MIN_SECONDS`.
func finish() -> void:
	if _done:
		return
	_done = true
	while _t < MIN_SECONDS:
		await get_tree().process_frame
	var tw := create_tween()
	tw.tween_property(self, "offset:y", 0.0, 0.01)
	queue_free()
