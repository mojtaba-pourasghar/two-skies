## عکس از یک صفحهٔ رابط
##   ... res://tools/tests/shot_screen.tscn -- --scene=main_menu --name=menu
extends Node2D
func _ready() -> void:
	var key := "main_menu"
	var nm := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			key = a.substr(8)
		elif a.begins_with("--name="):
			nm = a.substr(7)
	DirAccess.make_dir_recursive_absolute("res://docs_screens/ui/")
	var path: String = SceneRouter.SCENES.get(key, key)
	if not ResourceLoader.exists(path):
		push_error("صحنه نیست: %s" % path)
		get_tree().quit(1)
		return
	# **به ریشه اضافه می‌شود، نه به این گره.** صفحه‌ها Control‌اند و
	# لنگرهایشان فقط وقتی معنا دارد که والدشان Control یا پنجره باشد؛
	# زیر یک Node2D اندازه‌شان صفر می‌ماند و عکس، چیدمان واقعی بازی را
	# نشان نمی‌دهد. اولین عکس همین‌طور گمراه‌کننده درآمد.
	var inst = load(path).instantiate()
	# ریشه در لحظهٔ `_ready` مشغول است، پس افزودن باید به فریم بعد
	# موکول شود (خطای «Parent node is busy setting up children»).
	get_tree().root.add_child.call_deferred(inst)
	await get_tree().process_frame
	await get_tree().process_frame
	for i in 70:
		await get_tree().process_frame
	if inst is Control:
		print("  اندازه=%s موقعیت=%s دیده‌شدنی=%s فرزند=%d" % [
			str((inst as Control).size), str((inst as Control).position),
			str((inst as Control).visible), inst.get_child_count()])
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		"res://docs_screens/ui/%s.png" % (nm if nm != "" else key))
	print("عکس: %s" % (nm if nm != "" else key))
	get_tree().quit(0)
