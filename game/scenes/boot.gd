## بوت — اولین صحنه. Autoload‌ها آماده‌اند، اینجا فقط مسیر شروع تعیین می‌شود.
extends Node

func _ready() -> void:
	# tuning.json در Settings._ready خوانده و روی KairoConst اعمال شده است.
	print("دو آسمان — پروفایل اعداد فعال: %s" % KairoConst.active_profile)
	print("  ارتفاع پرش: %.1f px (%.2f کاشی)" % [
		KairoConst.jump_height_px(), KairoConst.jump_height_px() / float(KairoConst.TILE)])
	print("  برد افقی پرش: %.1f px (%.2f کاشی)" % [
		KairoConst.jump_range_px(), KairoConst.jump_range_px() / float(KairoConst.TILE)])

	# ابزارهای هر مرحله طبق §۶ باز می‌شوند: دیوارپرش و هک در م۲، دش در م۳.
	# تا وقتی منوی اصلی و نقشهٔ فصل ساخته نشده‌اند (گام ۵)، مستقیم مرحلهٔ ۱ اجرا می‌شود.
	if ResourceLoader.exists(SceneRouter.SCENES["main_menu"]):
		SceneRouter.goto("main_menu", false)
		return
	SceneRouter.pending_level = "res://levels/data/ch1_l1.json"
	SceneRouter.goto("game", false)
