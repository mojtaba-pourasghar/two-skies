## ایلارا در نمای سه‌چهارم — همراه در صف.
##
## §۵ بی‌تغییر: ۴۸ فریم (۰٫۸ ثانیه) پشت کایرو، «بمان/بیا»، و مرگ او شکست
## مرحله است. تفاوتش با نمای کناری فقط این است که به‌جای تکرار پرش، **نقطهٔ
## فرود** کایرو را می‌گیرد و همان جهش را می‌زند.
class_name TdIlara
extends TdActor

signal fell

enum Order { FOLLOW, STAY }

var order: Order = Order.FOLLOW
var leader: TdKairo = null
var falls: int = 0

## نزدیک‌تر از این به هدف، دیگر فشار نمی‌آورد؛ وگرنه روی هدف می‌لرزد.
const ARRIVE_PX: float = 3.0
## فاصله‌ای که تا نشانهٔ جهش می‌پذیرد تا همان جهش را بزند.
const HOP_SNAP_PX: float = 12.0

var _wish := Vector2.ZERO


func _ready() -> void:
	super()
	actor_name = "ilara"
	speed = TdConst.ILARA_RUN_SPEED
	add_to_group("ilara")
	died.connect(_on_died)


func _on_died() -> void:
	falls += 1
	fell.emit()


func _input_dir() -> Vector2:
	return _wish


func _physics_process(delta: float) -> void:
	_think()
	super(delta)


func _think() -> void:
	if leader == null or order == Order.STAY or state != State.MOVE:
		_wish = Vector2.ZERO
		return
	var delay: int = TdConst.COMPANION_DELAY_FRAMES
	var target: Vector2 = leader.trail_at(delay)

	# نشانهٔ جهش: وقتی به همان نقطه‌ای رسید که کایرو از آن جهید، می‌جهد
	var mark: Vector2 = leader.hop_mark_at(delay)
	if mark != Vector2.ZERO and global_position.distance_to(target) <= HOP_SNAP_PX:
		var dir := (mark - global_position)
		if dir.length() > 1.0:
			start_hop(dir)
			_wish = Vector2.ZERO
			return

	var to_target := target - global_position
	_wish = Vector2.ZERO if to_target.length() <= ARRIVE_PX else to_target.normalized()


func set_order(new_order: Order) -> void:
	order = new_order
