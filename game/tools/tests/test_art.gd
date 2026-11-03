## آزمون هنر موقت — گام ۱۱
##
##   godot --headless res://tools/tests/test_art.tscn
##
## سه چیز را نگه می‌دارد:
##   ۱) هر بافتی که کد به آن ارجاع می‌دهد واقعاً وارد شده باشد — وگرنه بازی
##      بی‌صدا نامرئی می‌شود، نه اینکه کرش کند، و در بازی‌تست دیر پیدا می‌شود.
##   ۲) اندازهٔ اسپرایت‌ها با جعبه‌های برخورد بخواند، تا شخصیت روی زمین شناور
##      یا فرورفته دیده نشود.
##   ۳) همهٔ گونه‌های کاشی برخورد یکسان داشته باشند — گونه فقط ظاهری است و
##      نباید حل‌پذیری ۱۲ اتاق را تکان بدهد.
extends Node2D

## اندازهٔ انتظاری هر بافت، از tools/gen_art.py
const SIZES := {
	Art.KAIRO: Vector2i(12, 16),
	Art.ILARA: Vector2i(12, 16),
	Art.SPIKE: Vector2i(16, 8),
	Art.CRUMBLE: Vector2i(16, 8),
	Art.LASER_EMITTER: Vector2i(6, 16),
	Art.DRONE: Vector2i(32, 10),
	Art.PICKUPS: Vector2i(36, 12),
	Art.NOTE: Vector2i(12, 12),
	Art.GATE: Vector2i(32, 16),
	Art.EXIT: Vector2i(32, 24),
	Art.SKY: Vector2i(480, 270),
	Art.FAR: Vector2i(480, 270),
	Art.MID: Vector2i(480, 270),
	"res://art/tilesets/ch1_ground.png": Vector2i(64, 16),
}

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	_t_files()
	_t_sizes()
	_t_palette()
	_t_tileset()
	_report()


func _t_files() -> void:
	print("— هر بافتی که کد می‌خواهد روی دیسک هست —")
	var missing: Array[String] = []
	for path in Art.REQUIRED:
		if not ResourceLoader.exists(path):
			missing.append(path)
	_check("هر %d بافت وارد شده" % Art.REQUIRED.size(), missing.is_empty(),
		"" if missing.is_empty() else "گم‌شده: " + ", ".join(missing))


func _t_sizes() -> void:
	print("— اندازهٔ بافت با جعبهٔ برخورد می‌خواند —")
	for path in SIZES:
		if not ResourceLoader.exists(path):
			_check("اندازهٔ %s" % String(path).get_file(), false, "بافت نیست")
			continue
		var tex: Texture2D = load(path)
		var want: Vector2i = SIZES[path]
		_check("اندازهٔ %s" % String(path).get_file(), tex.get_size() == Vector2(want),
			"= %dx%d" % [int(tex.get_width()), int(tex.get_height())])

	# بوم شخصیت دقیقاً قد جعبهٔ برخورد (۱۶) است، پس پا روی زمین می‌نشیند
	var kairo: Texture2D = load(Art.KAIRO)
	_check("قد بافت کایرو = قد جعبهٔ برخورد", int(kairo.get_height()) == int(KairoConst.HITBOX.y),
		"= %d پیکسل" % int(kairo.get_height()))


func _t_palette() -> void:
	print("— لوحهٔ رنگ —")
	# قاعدهٔ ثابت سند ۰۴
	_check("پس‌زمینهٔ دور #14161F است", Palette.UI_PANEL == Color("#14161F"),
		"= %s" % Palette.UI_PANEL.to_html(false))
	_check("رنگ خطر #FF4D4D است", Palette.DANGER == Color("#FF4D4D"),
		"= %s" % Palette.DANGER.to_html(false))
	_check("خط بالایی سکو #C9CCD6 است", Palette.LIGHT_DUST == Color("#C9CCD6"),
		"= %s" % Palette.LIGHT_DUST.to_html(false))
	# فرمول سایه و هایلایت سند ۰۴
	var base := Palette.FIRE_ORANGE
	_check("سایه = رنگ پایه روی خاکستر شب با ۴۰٪",
		Palette.shade(base).is_equal_approx(base.lerp(Palette.NIGHT_ASH, 0.40)), "")
	_check("هایلایت = رنگ پایه روی سفید با ۳۰٪",
		Palette.light(base).is_equal_approx(base.lerp(Palette.WHITE, 0.30)), "")


func _t_tileset() -> void:
	print("— گونه‌های کاشی فقط ظاهری‌اند —")
	var ts := LevelLoader.make_placeholder_tileset()
	var src: TileSetAtlasSource = ts.get_source(0) as TileSetAtlasSource
	_check("اطلس %d گونه دارد" % LevelLoader.TILE_VARIANTS,
		src.get_tiles_count() == LevelLoader.TILE_VARIANTS,
		"= %d" % src.get_tiles_count())

	var first: PackedVector2Array = PackedVector2Array()
	var same := true
	for i in src.get_tiles_count():
		var data := src.get_tile_data(Vector2i(i, 0), 0)
		if data.get_collision_polygons_count(0) != 1:
			same = false
			break
		var pts := data.get_collision_polygon_points(0, 0)
		if i == 0:
			first = pts
		elif pts != first:
			same = false
	_check("هر گونه همان چندضلعی برخورد را دارد", same, "")
	_check("چندضلعی برخورد یک کاشی کامل است", first.size() == 4, "= %d رأس" % first.size())


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
