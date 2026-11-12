## حلقهٔ چهارفریمی دور گره فوکوس‌شده. ۴ فریم بر ثانیه، بی‌پرش.
extends TextureRect

const FPS := 4.0
var _t: float = 0.0
var _frames: Array[Texture2D] = []


func _ready() -> void:
	for i in 4:
		var t := UiKit.ornament("ring_%d" % i)
		if t != null:
			_frames.append(t)
	if not _frames.is_empty():
		texture = _frames[0]


func _process(delta: float) -> void:
	if _frames.size() < 2:
		return
	_t += delta
	texture = _frames[int(_t * FPS) % _frames.size()]
