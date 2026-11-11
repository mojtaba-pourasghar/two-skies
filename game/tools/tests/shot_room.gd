## عکس یک اتاق با بازیکن در جای دلخواه — ابزار عمومی اسکرین‌شات
##
##   godot --path game --fixed-fps 60 --resolution 1280x720 \
##     res://tools/tests/shot_room.tscn -- --room=c2_laser_alley --at=640,560 --name=c2
extends Node2D

const OUT := "res://docs_screens/"

var _game: Node2D


func _ready() -> void:
	var rid := "r1a_living"
	var at := Vector2.ZERO
	var nm := ""
	var hacks: Array[String] = []
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--room="):
			rid = a.substr(7)
		elif a.begins_with("--at="):
			var p := a.substr(5).split(",")
			at = Vector2(float(p[0]), float(p[1]))
		elif a.begins_with("--name="):
			nm = a.substr(7)
		elif a.begins_with("--hack="):
			for h in a.substr(7).split(","):
				hacks.append(h)
	for h in hacks:
		GameState.set_flag("hacked_%s" % h, true)
	DirAccess.make_dir_recursive_absolute(OUT)
	_game = load("res://scenes/room_game.tscn").instantiate()
	_game.set("start_room", rid)
	add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame
	var kairo = _game.get("kairo")
	if kairo != null and at != Vector2.ZERO:
		kairo.set("use_scripted", true)
		kairo.global_position = at
	for i in 40:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	var file := "shot_%s.png" % (nm if nm != "" else rid)
	get_viewport().get_texture().get_image().save_png(OUT + file)
	print("عکس: %s" % file)
	get_tree().quit(0)
