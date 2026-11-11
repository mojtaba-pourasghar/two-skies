## عکس از یک صحنهٔ سینمایی در فریم مشخص
extends Node2D
func _ready() -> void:
	var id := "c1_intro"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--id="):
			id = a.substr(5)
	DirAccess.make_dir_recursive_absolute("res://docs_screens/")
	Cutscene.play(id)
	var shots := [90, 200, 330, 460, 600]
	var n := 0
	for i in 700:
		await get_tree().process_frame
		if i == 120:
			print("    viewport=%s box=%s text=%s layer=%d عمق=%d" % [
				str(get_viewport().get_visible_rect().size),
				str(Cutscene._box.get_global_rect()),
				str(Cutscene._text.get_global_rect()),
				Cutscene._layer.layer, Cutscene._layer.get_child_count()])
		if i % 60 == 0:
			print("    فریم %d: متن=%s جعبه=%s تصویر=%s" % [i,
				str(Cutscene._text.text).substr(0, 20), str(Cutscene._box.visible),
				str(Cutscene._bg.visible)])
		if i in shots:
			await RenderingServer.frame_post_draw
			n += 1
			get_viewport().get_texture().get_image().save_png(
				"res://docs_screens/shot_cut_%s_%d.png" % [id, n])
			print("  فریم %d → عکس %d" % [i, n])
	print("عکس گرفته شد")
	get_tree().quit(0)
