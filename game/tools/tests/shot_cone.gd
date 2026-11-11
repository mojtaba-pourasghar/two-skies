## عکس مخروط دید در سه حالت و دو فاصله — اثبات گام ۵۷ بند ۱
extends Node2D

const OUT := "res://docs_screens/"
## دور از برد، داخل برد، و تعقیب
const SPOTS := [
	["far", Vector2(420, 780)],
	["near", Vector2(640, 760)],
]

var _game: Node2D


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_game = load("res://scenes/room_game.tscn").instantiate()
	_game.set("start_room", "s3a_plaza")
	add_child(_game)
	await get_tree().process_frame
	await get_tree().process_frame
	var kairo = _game.get("kairo")
	kairo.set("use_scripted", true)
	for spot in SPOTS:
		kairo.global_position = spot[1]
		for i in 60:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OUT + "cone_%s.png" % spot[0])
		var rm = _game.get("room")
		var g: MapEnemy = null
		for m in rm.enemies:
			if m.patrol.size() >= 2:
				g = m
				break
		print("  %s: شدت %.2f، حالت %d" % [spot[0], g.get("_intensity"), g.state])
	print("دو عکس ساخته شد.")
	get_tree().quit(0)
