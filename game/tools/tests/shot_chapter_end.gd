## عکس پردهٔ پایان فصل
extends Node2D
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("res://docs_screens/")
	var ui := ChapterEnd.new()
	add_child(ui)
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs_screens/shot_chapter_end.png")
	print("عکس گرفته شد")
	get_tree().quit(0)
