## اسکرین‌شات M4-پ — دشمن دیدنی روی نقشه و ورود به نبرد
##
##   xvfb-run -a godot --path game --fixed-fps 60 --resolution 1280x720 res://tools/tests/shot_encounter.tscn
extends Node

const OUT := "res://docs_screens/"


func _ready() -> void:
	(GameState.run["flags"] as Dictionary).clear()
	var game: RoomGame = load("res://scenes/room_game.tscn").instantiate()
	game.start_room = "s3a_plaza"
	game.resume = false
	add_child(game)
	await _frames(4)
	var m: MapEnemy = game.room.enemies[0]
	game.kairo.global_position = m.position + Vector2(-150, 30)
	game.camera.snap_to_target()
	await _frames(70)
	await _shot("m4p_s3a_01_enemies")
	game.kairo.global_position = m.position - Vector2(0, TdConst.FOOT_OFFSET_Y)
	await _frames(74)
	await _shot("m4p_s3a_03_battle")
	get_tree().quit(0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(ProjectSettings.globalize_path(OUT + name + ".png"))
	print("  عکس: %s" % name)
