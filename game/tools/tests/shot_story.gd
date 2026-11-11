## اجرای بیت‌های داستان در اتاق و عکس از گفت‌وگو و صفحهٔ ارتقا
extends Node2D

var _game: Node2D


func _ready() -> void:
	for b in ["b_intro", "b_r1a", "b_r1b"]:
		GameState.set_flag(StoryDirector.flag_of(b), false)
	DirAccess.make_dir_recursive_absolute("res://docs_screens/")
	_game = load("res://scenes/room_game.tscn").instantiate()
	_game.set("start_room", "r1b_corridor")
	add_child(_game)
	for i in 260:
		await get_tree().process_frame
		if i == 180:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(
				"res://docs_screens/shot_story_say.png")
			print("گفت‌وگو: متن=%s" % str(Cutscene._text.text).substr(0, 24))
	# صفحهٔ ارتقا — پس از تمام شدن گفت‌وگو، وگرنه روی هم می‌افتند
	while Cutscene.is_playing:
		await get_tree().process_frame
	var ui := UpgradeChoice.new()
	add_child(ui)
	for i in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://docs_screens/shot_upgrade.png")
	ui.choose("chip")
	print("ارتقا: %s" % str(GameState.data.get("upgrades", [])))
	print("عکس‌ها ساخته شدند")
	get_tree().quit(0)
