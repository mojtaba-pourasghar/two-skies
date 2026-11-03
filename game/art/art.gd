## دسترسی یک‌جا به بافت‌های هنر موقت.
##
## همهٔ PNGها با tools/gen_art.py ساخته می‌شوند. هیچ‌جای دیگری در کد مسیر بافت
## نوشته نمی‌شود، تا وقتی هنر نهایی رسید فقط همین فایل عوض شود (سند ۰۵، گام ۶).
class_name Art
extends RefCounted

const SPRITES := "res://art/sprites/"
const FX := "res://art/fx/"

const KAIRO := SPRITES + "kairo.png"
const ILARA := SPRITES + "ilara.png"
const SPIKE := SPRITES + "spike.png"
const CRUMBLE := SPRITES + "crumble.png"
const LASER_EMITTER := SPRITES + "laser_emitter.png"
const DRONE := SPRITES + "drone.png"          # ۲ فریم: فعال، هک‌شده
const PICKUPS := SPRITES + "pickups.png"      # ۳ فریم: سکه، زمرد، تراشه
const NOTE := SPRITES + "note.png"
const GATE := SPRITES + "gate.png"            # ۲ فریم: دروازه، در کلیددار
const EXIT := SPRITES + "exit.png"            # ۲ فریم: خروج، نقطهٔ ذخیره

const SKY := FX + "ch1_sky.png"
const FAR := FX + "ch1_far.png"
const MID := FX + "ch1_mid.png"

## فهرست هر چیزی که باید روی دیسک باشد — آزمون هنر از همین می‌خواند.
const REQUIRED: Array[String] = [
	KAIRO, ILARA, SPIKE, CRUMBLE, LASER_EMITTER, DRONE,
	PICKUPS, NOTE, GATE, EXIT, SKY, FAR, MID,
	"res://art/tilesets/ch1_ground.png",
]


## یک Sprite2D مرکزچین می‌سازد. اگر بافت وارد نشده باشد اسپرایت بی‌بافت
## برمی‌گردد (نامرئی) تا بازی به‌جای کرش، فقط ظاهرش ناقص باشد.
static func sprite(path: String, hframes: int = 1, frame: int = 0) -> Sprite2D:
	var s := Sprite2D.new()
	s.centered = true
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if ResourceLoader.exists(path):
		s.texture = load(path)
	s.hframes = maxi(1, hframes)
	s.frame = clampi(frame, 0, s.hframes - 1)
	return s
