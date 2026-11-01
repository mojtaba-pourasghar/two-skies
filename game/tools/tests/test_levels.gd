## آزمون بارگذاری و اعتبارسنجی مرحله‌ها — گام ۲
##
##   godot --headless res://tools/tests/test_levels.tscn
extends Node2D

const LEVELS := ["res://levels/data/ch1_l1.json", "res://levels/data/ch1_l2.json",
	"res://levels/data/ch1_l3.json"]

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	var tileset := LevelLoader.make_placeholder_tileset()
	for path in LEVELS:
		await _check_level(path, tileset)
	_report()


func _check_level(path: String, tileset: TileSet) -> void:
	var loader := LevelLoader.new()
	var level := loader.load_level(path)
	print("\n— %s —" % path.get_file())
	_check("بارگذاری بدون خطا", level.size() > 0,
		"" if loader.errors.is_empty() else "\n      " + "\n      ".join(loader.errors))
	if level.is_empty():
		return
	for w in loader.warnings:
		print("    i هشدار: %s" % w)

	# هر اتاق پس از باز شدن قالب فشرده باید ۱۷ سطر × ۳۰ کاراکتر باشد
	var all_ok := true
	for room in level["rooms"]:
		var tiles: Array = room["tiles"]
		if tiles.size() != LevelLoader.ROOM_H:
			all_ok = false
		for line in tiles:
			if String(line).length() != LevelLoader.ROOM_W:
				all_ok = false
	_check("۱۷ سطر × ۳۰ ستون در همهٔ اتاق‌ها", all_ok, "(%d اتاق)" % level["rooms"].size())

	# ساخت واقعی هر اتاق در صحنه
	var built := 0
	var kairo_start_found := false
	var exit_found := false
	var placeholders := 0
	for rd in level["rooms"]:
		var room := Room.new()
		add_child(room)
		room.build(level, rd, tileset)
		built += 1
		if room.kairo_start != Vector2.ZERO:
			kairo_start_found = true
		if room.exit_point != null:
			exit_found = true
		for child in room.get_node("Objects").get_children():
			if String(child.name).begins_with("TODO_"):
				placeholders += 1
		room.queue_free()
		await get_tree().process_frame
	_check("ساخت همهٔ اتاق‌ها در صحنه", built == level["rooms"].size(), "(%d اتاق)" % built)
	_check("نقطهٔ شروع کایرو پیدا شد", kairo_start_found, "")
	_check("نقطهٔ خروج پیدا شد", exit_found, "")
	if placeholders > 0:
		print("    i %d شیء هنوز مکان‌نگهدار است (موانع گام ۴)" % placeholders)

	# سوراخ‌های بی‌مقصد لبهٔ اتاق باید مُهر شده باشند، وگرنه بازیکن از نقشه
	# بیرون می‌افتد. نقشه‌های §۱۱ در L2R2 و L2R4 لبهٔ چپ را باز کشیده‌اند ولی
	# برگشت از آن‌ها بازیکن را داخل سنگ می‌گذاشت (DECISIONS.md: D-010).
	await _check_sealing(level, tileset)


## هر خانهٔ باز لبهٔ اتاق که درگاه اعلام‌شده نیست باید در TileMapLayer جامد شده باشد،
## و هر درگاه اعلام‌شده باید باز مانده باشد.
func _check_sealing(level: Dictionary, tileset: TileSet) -> void:
	var unsealed := []
	var blocked_doors := []
	var sealed_count := 0
	for rd in level["rooms"]:
		var declared := {}
		for door in rd.get("exits", []):
			var side := String(door.get("side", ""))
			for v in (door.get("rows", []) as Array):
				declared[Vector2i(0 if side == "left" else LevelLoader.ROOM_W - 1, int(v))] = true

		var room := Room.new()
		add_child(room)
		room.build(level, rd, tileset)
		var tiles_layer: TileMapLayer = room.get_node("Tiles")
		var tiles: Array = rd["tiles"]
		for r in range(2, 14):
			for c in [0, LevelLoader.ROOM_W - 1]:
				var cell := Vector2i(c, r)
				var solid_in_map := String(tiles[r])[c] == LevelLoader.SOLID
				var solid_now := tiles_layer.get_cell_source_id(cell) != -1
				if declared.has(cell):
					if solid_now:
						blocked_doors.append("%s(%d,%d)" % [rd["id"], c, r])
				elif not solid_in_map:
					if solid_now:
						sealed_count += 1
					else:
						unsealed.append("%s(%d,%d)" % [rd["id"], c, r])
		room.queue_free()
		await get_tree().process_frame

	_check("سوراخ بی‌مقصد لبه مُهر شد", unsealed.is_empty(),
		"(%d خانه مُهر شد)" % sealed_count if unsealed.is_empty() else str(unsealed))
	_check("درگاه اعلام‌شده باز ماند", blocked_doors.is_empty(),
		"" if blocked_doors.is_empty() else str(blocked_doors))


func _check(label: String, ok: bool, detail: String) -> void:
	_checks += 1
	if ok:
		print("  ✔ %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  ✘ %s %s" % [label, detail])


func _report() -> void:
	print("")
	if _failures.is_empty():
		print("همهٔ %d سنجه قبول شد." % _checks)
		get_tree().quit(0)
	else:
		print("%d از %d سنجه رد شد." % [_failures.size(), _checks])
		get_tree().quit(1)
