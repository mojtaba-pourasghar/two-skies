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
	# دوربین زنده (D-ART-42) هم باید در کلیپ دیده شود، نه فقط در آزمون.
	# فقط زوم **نزدیک** نشان داده می‌شود: این اتاق دقیقاً ۱۲۸۰×۷۲۰ است، پس
	# زوم باز لبهٔ تصویر را می‌برد و تا REQ-018 نرسیده، نمایشش گمراه‌کننده
	# است. همین محدودیت دلیل REQ-018 است.
	var cam = _game.get("camera")
	await _hold(kairo, 18)
	# مسیر عمداً از کنار هر مانع می‌گذرد تا در کلیپ دیده شود ماسک با
	# گوشه‌ها و مبلمان می‌خواند: دور مبل، کنار بوفه، پای ستون، لبهٔ نرده.
	await _walk(kairo, Vector2(0, -1), 48)      # بالا، تا پای مبل
	await _walk(kairo, Vector2(1, -1), 52)      # بالا-راست، دور کردن مبل
	if cam != null:
		cam.request_zoom("close")                # زوم آرام، ۱ ثانیه
	await _walk(kairo, Vector2(1, 0), 85)       # راست، زیر دیوار پشتی
	if cam != null:
		cam.request_zoom("normal")               # un-zoom، همان‌قدر آرام
	await _walk(kairo, Vector2(1, 1), 40)       # پایین-راست، کنار بوفه
	await _walk(kairo, Vector2(0, 1), 45)       # پایین، پای ستون
	await _walk(kairo, Vector2(-1, 1), 45)      # پایین-چپ، تا لبهٔ نرده
	await _walk(kairo, Vector2(-1, 0), 80)      # برگشت از جلوی قالی
	await _hold(kairo, 22)

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
