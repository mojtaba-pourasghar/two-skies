## کلیپ حرکت در اتاق R1a — فریم‌به‌فریم برای ویدیو
##
## بازی را واقعاً اجرا می‌کند و هر فریم فیزیک یک عکس می‌گیرد، تا حرکت و
## انیمیشن و Y-sort و گذار occluder در ویدیو دیده شوند — چیزی که عکس ثابت
## نشان نمی‌دهد.
extends Node2D

const OUT := "user://clip/"
## یک فریم در میان: ۳۰ فریم بر ثانیه، نصف حجم، حرکت همچنان روان.
const EVERY: int = 2

var _game: Node2D
var _n: int = 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
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

	# مسیر: از گوشهٔ جنوب-غربی، کنار مجسمهٔ ذخیره، دور مبل، تا طاق.
	# عمداً از کنار مبل و از پشت ستون رد می‌شود تا Y-sort و occluder
	# در کلیپ دیده شوند.
	await _hold(kairo, 20)
	await _walk(kairo, Vector2(0, -1), 55)      # بالا، کنار مجسمه
	await _walk(kairo, Vector2(1, 0), 70)       # راست، پشت مبل
	await _walk(kairo, Vector2(1, 1), 45)       # پایین-راست، روی قالی
	await _walk(kairo, Vector2(1, 0), 60)       # راست، به سمت بوفه
	await _walk(kairo, Vector2(1, -1), 40)      # بالا-راست، پشت ستون
	await _walk(kairo, Vector2(0, 1), 50)       # پایین، جلوی ستون
	await _walk(kairo, Vector2(-1, 0), 70)      # برگشت به چپ
	await _hold(kairo, 25)

	print("فریم: %d" % _n)
	print("جای کایرو: %s" % str(kairo.global_position.round()))
	get_tree().quit(0)


func _walk(actor, dir: Vector2, frames: int) -> void:
	actor.scripted_dir = dir
	for i in frames:
		await get_tree().physics_frame
		await _grab()
	actor.scripted_dir = Vector2.ZERO


func _hold(actor, frames: int) -> void:
	actor.scripted_dir = Vector2.ZERO
	for i in frames:
		await get_tree().physics_frame
		await _grab()


func _grab() -> void:
	_n += 1
	if _n % EVERY != 0:
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT + "f%05d.png" % _n)
