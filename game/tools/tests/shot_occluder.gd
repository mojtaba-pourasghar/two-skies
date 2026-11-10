## اثبات بسته شدن occluder مبل — سه عکس در سه جای مبل
##
##   godot --path game --fixed-fps 60 --resolution 1280x720 \
##     res://tools/tests/shot_occluder.tscn
extends Node2D

const OUT := "res://docs_screens/"
## سه جا: پشت مبل، کنارش، و جلویش.
const SPOTS := [
	["behind", Vector2(420, 430)],
	["beside", Vector2(600, 470)],
	["front", Vector2(420, 580)],
]

var _game: Node2D


func _ready() -> void:
	_game = load("res://scenes/room_game.tscn").instantiate()
	_game.set("start_room", "r1a_living")
	add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame
	await _run()


func _run() -> void:
	var kairo = _game.get("kairo")
	if kairo == null:
		push_error("کایرو ساخته نشد")
		get_tree().quit(1)
		return
	kairo.set("use_scripted", true)
	var il = _game.get("ilara")
	if il != null:
		# ایلارا جلوی عکس نایستد
		il.set_order(TdIlara.Order.STAY)
		il.global_position = Vector2(140, 660)

	DirAccess.make_dir_recursive_absolute(OUT)
	for spot in SPOTS:
		kairo.global_position = spot[1]
		for i in 8:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(OUT + "occ_%s.png" % spot[0])
		print("  %s در %s" % [spot[0], str(spot[1])])
	print("سه عکس ساخته شد در %s" % OUT)
	get_tree().quit(0)
