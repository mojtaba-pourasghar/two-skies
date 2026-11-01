## بوت — اولین صحنه. Autoload‌ها آماده‌اند، اینجا فقط مسیر شروع تعیین می‌شود.
extends Node

func _ready() -> void:
	# tuning.json در Settings._ready خوانده و روی KairoConst اعمال شده است.
	print("دو آسمان — پروفایل اعداد فعال: %s" % KairoConst.active_profile)
	print("  ارتفاع پرش: %.1f px (%.2f کاشی)" % [
		KairoConst.jump_height_px(), KairoConst.jump_height_px() / float(KairoConst.TILE)])
	print("  برد افقی پرش: %.1f px (%.2f کاشی)" % [
		KairoConst.jump_range_px(), KairoConst.jump_range_px() / float(KairoConst.TILE)])

	if OS.has_feature("editor") and ResourceLoader.exists(SceneRouter.SCENES["sandbox"]):
		# گام ۱: منوها هنوز ساخته نشده‌اند، پس مستقیم به اتاق آزمایش می‌رویم.
		SceneRouter.goto("sandbox", false)
		return
	if ResourceLoader.exists(SceneRouter.SCENES["splash"]):
		SceneRouter.goto("splash", false)
	else:
		SceneRouter.goto("sandbox", false)
