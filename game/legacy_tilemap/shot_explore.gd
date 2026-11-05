## اسکرین‌شات headless از ناحیهٔ ۱ (T15)
##
## بازی را واقعاً اجرا می‌کند، کایرو را با ورودی اسکریپتی در ناحیه می‌برد و
## در چند لحظه عکس می‌گیرد. اگر چیزی در چیدمان یا هنر غلط باشد، در عکس
## دیده می‌شود — چیزی که هیچ سنجهٔ عددی نشان نمی‌دهد.
extends Node2D

const OUT := "res://docs_screens/"

var _game: Node2D


func _ready() -> void:
	_game = load("res://scenes/explore_game.tscn").instantiate()
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

	# ۱) شروع: نشیمن، گوشهٔ جنوب-غربی (جایی که تصویر مرجع گلدان دارد)
	await _settle(30)
	await _shot("a1_01_start")

	# ۲) میانهٔ نشیمن: مبل، قالی، قفسه و بوفه در قاب
	await _walk(kairo, Vector2(1, -1), 150)
	await _shot("a1_02_living_room")

	# ۳) نزدیک تله (کف شکسته)
	await _walk(kairo, Vector2(1, 1), 90)
	await _shot("a1_03_trap")

	# ۴) گذرگاه طاق به راهرو
	await _walk(kairo, Vector2(1, -1), 150)
	await _walk(kairo, Vector2(1, 0), 120)
	await _shot("a1_04_archway")

	# ۵) راهرو، نزدیک مرز اتاق چالش
	await _walk(kairo, Vector2(1, 0), 240)
	await _shot("a1_05_corridor")

	# ۶) داخل اتاق چالش: دوربین به side می‌رود و فیزیک پلتفرمر می‌شود
	await _walk(kairo, Vector2(1, 0), 150)
	await _settle(50)
	await _shot("a1_06_challenge_side")

	# ۷) داخل اتاق چالش، روی سکوهای میانی.
	# با ورودی اسکریپتی نمی‌شود پلتفرم‌بازی کرد (پرش از دکمه می‌آید)، پس
	# کایرو را مستقیم روی سکو می‌گذاریم تا قاب را نشان بدهد.
	var area_node = _game.get("area_node")
	var zone: Dictionary = (area_node.area["camera_zones"] as Array)[0]
	var rect: Array = zone["rect"]
	kairo.global_position = Vector2(
		(int(rect[0]) + 12) * 32, (int(rect[1]) + 13) * 32)
	await _settle(60)
	await _shot("a1_07_challenge_platforms")

	var director = _game.get("director")
	print("حالت دوربین در اتاق چالش: %s | ناحیهٔ فعال: %s"
		% [director.mode, director.active_zone()])
	print("جان: %.0f٪ | سکه: %d" % [GameState.hp_percent(), GameState.run.get("coins", 0)])
	get_tree().quit(0)


## در حالت کناری پرش با ورودی اسکریپتی ممکن نیست (پرش از دکمه می‌آید)،
## پس مستقیم سرعت عمودی می‌دهیم تا بالا برود و قاب را نشان بدهد.
func _hop(actor, dir: Vector2, frames: int) -> void:
	actor.scripted_dir = dir
	actor.velocity.y = -612.0
	for i in frames:
		await get_tree().physics_frame
	actor.scripted_dir = Vector2.ZERO


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
	print("%s → %s (%dx%d)" % [name, "ok" if err == OK else "خطا %d" % err,
		img.get_width(), img.get_height()])
