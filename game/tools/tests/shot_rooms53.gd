## اسکرین‌شات گام ۵۳ — C3 با پنل‌های استخراج‌شده و نور بریده، و S3a با ماسک
##
##   xvfb-run -a godot --path game --fixed-fps 60 --resolution 1280x720 res://tools/tests/shot_rooms53.tscn
extends Node

const OUT := "res://docs_screens/"


func _ready() -> void:
	for rid in ["c3_electric_hall", "s3a_plaza"]:
		var game: RoomGame = load("res://scenes/room_game.tscn").instantiate()
		game.start_room = rid
		game.resume = false
		add_child(game)
		for i in 50:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			ProjectSettings.globalize_path(OUT + "s53_%s.png" % rid))
		print("  عکس: s53_%s" % rid)
		game.queue_free()
		await get_tree().physics_frame
	get_tree().quit(0)
