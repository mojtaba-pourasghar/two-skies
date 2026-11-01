## آزمون کامپایل همهٔ اسکریپت‌ها — گام ۷
##
##   godot --headless res://tools/tests/test_compile.tscn
##
## چرا لازم است: `--import` خطای Parse اسکریپت صحنه‌ها را نشان نمی‌دهد. اسکریپتی
## که کامپایل نشود بی‌صدا به گره وصل نمی‌شود و نتیجه‌اش به شکل «صفحه ۰ گره دارد»
## یا «property موجود نیست» دیده می‌شود، نه به شکل خطای واضح.
## این آزمون به‌عنوان صحنه اجرا می‌شود تا Autoload‌ها در دسترس باشند.
extends Node2D

var _bad: Array[String] = []
var _total: int = 0


func _ready() -> void:
	print("— کامپایل همهٔ اسکریپت‌ها —")
	for path in _walk("res://"):
		# اسکریپت Autoload در حال اجراست؛ بار کردن دوبارهٔ آن با CACHE_MODE_IGNORE
		# موتور را segfault می‌کند. خود بوت شدن بازی ثابت می‌کند این‌ها کامپایل شده‌اند.
		if path.begins_with("res://autoload/"):
			continue
		_total += 1
		var res = ResourceLoader.load(path, "Script")
		if res == null:
			_bad.append(path)
			print("  ✘ %s" % path)
	print("")
	if _bad.is_empty():
		print("همهٔ %d اسکریپت کامپایل شد." % _total)
		get_tree().quit(0)
	else:
		print("%d از %d اسکریپت کامپایل نشد:" % [_bad.size(), _total])
		for p in _bad:
			print("  - %s" % p)
		get_tree().quit(1)


func _walk(dir: String) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	d.list_dir_begin()
	var entry := d.get_next()
	while entry != "":
		if entry.begins_with("."):
			entry = d.get_next()
			continue
		var full := dir.path_join(entry)
		if d.current_is_dir():
			out.append_array(_walk(full))
		elif entry.ends_with(".gd"):
			out.append(full)
		entry = d.get_next()
	d.list_dir_end()
	return out
