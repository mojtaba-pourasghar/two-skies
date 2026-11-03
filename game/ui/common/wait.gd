## انتظار بی‌نشت — DECISIONS.md: D-045
##
## `get_tree().create_timer()` یک `SceneTreeTimer` می‌سازد که به صحنه وابسته نیست.
## اگر گرهی که انتظار می‌کشد پیش از سر رسیدن تایمر آزاد شود (یا بازی بسته شود)،
## آن تایمر در `ObjectDB` می‌ماند و موتور در خروج «ObjectDB instances leaked»
## می‌دهد.
##
## این کمک‌کار یک گرهٔ `Timer` **فرزند** می‌سازد: با آزاد شدن صاحبش آزاد می‌شود و
## چیزی نشت نمی‌کند.
class_name Wait
extends RefCounted


## `await Wait.seconds(self, 1.2)`
static func seconds(owner_node: Node, duration: float) -> Signal:
	var t := Timer.new()
	t.one_shot = true
	t.wait_time = maxf(duration, 0.001)
	t.autostart = true
	# با آزاد شدن صاحب، تایمر هم آزاد می‌شود
	owner_node.add_child(t)
	t.timeout.connect(t.queue_free)
	return t.timeout
