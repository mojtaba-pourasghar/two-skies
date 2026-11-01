## دش — docs/02_godot_spec.md §۳ و §۶
##
## خود حرکت در PlatformActor._start_dash است (چون حالت DASH بخشی از ماشین حالت §۴
## است و گرانش در آن صفر می‌شود). این کلاس فقط قرارداد Tool را برای منو و خنک‌شدن
## و باز شدن ابزار فراهم می‌کند.
class_name DashTool
extends Tool


func _ready() -> void:
	tool_id = "dash"


func cooldown() -> float:
	return KairoConst.DASH_COOLDOWN
