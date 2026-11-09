## اسکرین‌شات M4-ب — صحنهٔ نبرد در لحظه‌های کلیدی
##
##   xvfb-run godot --path game --fixed-fps 60 --resolution 1280x720 res://tools/tests/shot_battle.tscn -- --encounter=ch1_a3_guard_crawler
##
## سه عکس: منوی نوبت یار، حلقهٔ زمان‌بندی وسط جمع شدن، و عدد آسیب.
extends Node

const OUT := "res://docs_screens/"

var _b: BattleScene
var _enc := "ch1_a3_guard_crawler"


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--encounter="):
			_enc = a.split("=")[1]
	_b = load("res://battle/battle_scene.tscn").instantiate()
	_b.encounter_id = _enc
	add_child(_b)
	# تا منوی اولین نوبت یار
	for i in 400:
		await get_tree().physics_frame
		if _b.phase == BattleScene.Phase.MENU:
			break
	await _frames(6)
	await _shot("m4_%s_01_menu" % _enc)
	# ضربه روی اولین دشمن، عکس وسط حلقه
	_b._on_cmd("strike", "")
	_b._choose_target(_b._target_list[0])
	await _frames(int(_b._ring_total * 0.55))
	await _shot("m4_%s_02_ring" % _enc)
	_b.autoplay = "skilled"
	await _frames(int(_b._ring_total * 0.45) + 14)
	await _shot("m4_%s_03_hit" % _enc)
	# بازیکن بی‌دفاع، تا دشمن واقعاً حمله کند و حلقهٔ دفاع دیده شود
	_b.autoplay = "idle"
	# تا نوبت دشمن و حلقهٔ دفاع
	for i in 600:
		await get_tree().physics_frame
		if _b.phase == BattleScene.Phase.DEFENSE and _b._ring_t > 20:
			break
	await _shot("m4_%s_04_defense" % _enc)
	get_tree().quit(0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := ProjectSettings.globalize_path(OUT + name + ".png")
	img.save_png(path)
	print("  عکس: %s" % path)
