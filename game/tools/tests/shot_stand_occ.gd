## عکس هر occluder ایستادهٔ دستهٔ ۱۶ — اثبات REQ-032
##
##   godot --path game --fixed-fps 60 --resolution 1280x720 \
##     res://tools/tests/shot_stand_occ.tscn
##
## برای هر نقطه دو عکس: یکی کایرو **پشت** شیء (سیلوئت روشن) و یکی
## **جلویش** (کامل دیده می‌شود). نقطه‌ها همان‌هایی‌اند که آزمون
## test_rooms ثابت کرده رفتنی‌اند.
extends Node2D

const OUT := "res://docs_screens/"

const SPOTS := [
	["r1a_shelf", "r1a_living", Vector2(769, 600), Vector2(769, 680)],
	["r1b_shelf", "r1b_corridor", Vector2(299, 596), Vector2(299, 678)],
	["r1c_pantry", "r1c_kitchen", Vector2(649, 300), Vector2(649, 380)],
	["c1_pillar_west", "c1_balcony", Vector2(335, 558), Vector2(335, 634)],
	["c1_pillar_east", "c1_balcony", Vector2(1109, 228), Vector2(1107, 300)],
]


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	for spot in SPOTS:
		await _shoot(spot)
	print("%d نقطه عکس شد." % SPOTS.size())
	get_tree().quit(0)


func _shoot(spot: Array) -> void:
	var game: Node2D = load("res://scenes/room_game.tscn").instantiate()
	game.set("start_room", spot[1])
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	var kairo = game.get("kairo")
	if kairo == null:
		push_error("کایرو در «%s» ساخته نشد" % spot[1])
		get_tree().quit(1)
		return
	kairo.set("use_scripted", true)
	var il = game.get("ilara")
	if il != null:
		il.set_order(TdIlara.Order.STAY)
	for pair in [["behind", spot[2]], ["front", spot[3]]]:
		kairo.global_position = pair[1]
		# ۱۲ فریم ≈ ۰٫۲ ثانیه: بیش از گذار ۰٫۱۵ ثانیه‌ای سیلوئت
		for i in 12:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		var rm = game.get("room")
		var cov: float = rm.coverage_at(kairo.foot_position()) if rm != null else 0.0
		get_viewport().get_texture().get_image().save_png(
			OUT + "occ32_%s_%s.png" % [spot[0], pair[0]])
		print("  %s/%s: پوشش %.0f٪" % [spot[0], pair[0], cov * 100.0])
	game.queue_free()
	await get_tree().process_frame
