## اسکرین‌شات M1 — اتاق R1a کنار تصویر مرجع
##
## بازی را واقعاً اجرا می‌کند و در چند جای اتاق عکس می‌گیرد، یک بار با
## ماسک نمایان تا بشود دید ماسک با تصویر می‌خواند یا نه.
extends Node2D

const OUT := "res://docs_screens/"

var _game: Node2D


func _ready() -> void:
	_game = load("res://scenes/room_game.tscn").instantiate()
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
	kairo.use_scripted = true

	await _settle(40)
	await _shot("m1_r1a_01_spawn")

	await _walk(kairo, Vector2(1, -1), 90)
	await _shot("m1_r1a_02_center")

	await _walk(kairo, Vector2(1, 0), 90)
	await _shot("m1_r1a_03_east")

	# با ماسک نمایان: سبز = قابل‌راه‌رفتن، قرمز = خطر، آبی = در
	var room = _game.get("room")
	room.show_mask(true)
	await _settle(5)
	await _shot("m1_r1a_04_mask")
	room.show_mask(false)

	print("جای کایرو: %s | روی ماسک: %s"
		% [str(kairo.global_position.round()),
		str(room.is_walkable(kairo.foot_position()))])
	print("هنر گم‌شده: %d" % room.missing_art.size())
	for m in room.missing_art:
		print("  ! %s" % m)
	get_tree().quit(0)


func _walk(actor, dir: Vector2, frames: int) -> void:
	actor.scripted_dir = dir
	for i in frames:
		await get_tree().physics_frame
	actor.scripted_dir = Vector2.ZERO
	await _settle(10)


func _settle(frames: int) -> void:
	for i in frames:
		await get_tree().physics_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var err := img.save_png(OUT + name + ".png")
	print("%s → %s" % [name, "ok" if err == OK else "خطا %d" % err])
