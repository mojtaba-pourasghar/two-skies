## اثبات سیلوئت — بازیگر زیر occluder گذاشته می‌شود
##
##   godot --path game --fixed-fps 60 --resolution 1280x720 \
##     res://tools/tests/shot_silhouette.tscn
##
## **این نمایش سازوکار است، نه بازی.** در ناحیهٔ ۱ هیچ جایی نیست که
## بازیکن بتواند زیر occluder بایستد و بماند: تنها جیبی که زیر ستون
## سنگی هست، خودش مستطیل **در** است. پس بازیگر مستقیم آنجا گذاشته
## می‌شود و پیش از آنکه در فعال شود عکس گرفته می‌شود.
extends Node2D

const OUT := "res://docs_screens/"
const SPOT := Vector2(912, 460)

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
	var vis: Array = _game.get("_visuals")
	if kairo == null or vis.is_empty():
		push_error("بازیگر ساخته نشد")
		get_tree().quit(1)
		return
	var il = _game.get("ilara")
	if il != null:
		il.set_order(TdIlara.Order.STAY)
		il.global_position = Vector2(200, 660)

	var room = _game.get("room")
	# **تنها جیب زیر ستون، خودِ مستطیل در است.** بدون این، گذاشتن
	# بازیگر آنجا بلافاصله گذار به راهرو را می‌زند و عکس از اتاق دیگری
	# گرفته می‌شود. در همین عکس خاموش می‌شود.
	room.data["doors"] = []
	kairo.global_position = SPOT
	var cov: float = room.coverage_at(kairo.foot_position())
	print("  پوشش در %s: %.0f٪" % [str(SPOT), cov * 100.0])

	# سیلوئت را دستی تا ته بالا می‌بریم (گذار ۰٫۱۵ث در `_process` است و
	# اینجا فریم فیزیک جلو نمی‌رود تا در فعال نشود)
	for i in 90:
		vis[0].set_coverage(cov)
		await get_tree().process_frame
	print("  شدت سیلوئت: %.2f" % vis[0].ghost_amount())

	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(OUT)
	get_viewport().get_texture().get_image().save_png(OUT + "silhouette_on.png")

	# و یک بار بی سیلوئت، برای مقایسه
	for i in 90:
		vis[0].set_coverage(0.0)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(OUT + "silhouette_off.png")
	print("  دو عکس ساخته شد")
	get_tree().quit(0 if vis[0] != null else 1)
