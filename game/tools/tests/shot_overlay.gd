## عکس از پرده‌های روی‌هم (پایان فصل، شکست، ارتقا)
extends Node2D
func _ready() -> void:
	var which := "chapter_end"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--which="):
			which = a.substr(8)
	DirAccess.make_dir_recursive_absolute("res://docs_screens/ui/")
	var node: CanvasLayer
	match which:
		"defeat":
			node = DefeatScreen.new()
		"upgrade":
			node = UpgradeChoice.new()
		_:
			node = ChapterEnd.new()
	add_child(node)
	for i in 50:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		"res://docs_screens/ui/%s.png" % which)
	print("عکس: %s" % which)
	get_tree().quit(0)
