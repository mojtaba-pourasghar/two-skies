## اتاق آزمایش گام ۱ — خروجی قابل دیدن: کایرو در یک اتاق خالی حرکت و پرش و دیوارپرش می‌کند.
##
## هندسه از یک رشتهٔ ASCII با همان نمادهای §۱۰ ساخته می‌شود؛ همین کار در گام ۲ به
## level_loader.gd منتقل می‌شود. اینجا فقط برای حس گرفتن از فیزیک است.
extends Node2D

const TILE: int = 16
const ROOM_W: int = 30
const ROOM_H: int = 17

## اتاق آزمایش: دو دیوار موازی برای دیوارپرش، یک شکاف ۴ کاشی، و یک پله.
const ROOM := [
	"##############################",
	"##############################",
	"#............................#",
	"#............................#",
	"#....##................##....#",
	"#....##................##....#",
	"#....##................##....#",
	"#....##................##....#",
	"#....##................##....#",
	"#....##................##....#",
	"#....##................##....#",
	"#....##................##....#",
	"#....##................##....#",
	"#I...##................##....#",
	"#####################...######",
	"#####################...######",
	"#####################...######",
]

var _kairo: Kairo
var _label: Label


func _ready() -> void:
	_build_geometry()
	_spawn_kairo()
	_build_camera()
	_build_hud()
	# گام ۱: دیوارپرش و دش را باز می‌کنیم تا همین حالا قابل آزمایش باشند.
	# در بازی واقعی دیوارپرش در م۲ و دش در م۳ باز می‌شود (§۶).
	GameState.unlock_tool("wall_jump")
	GameState.unlock_tool("dash")


func _build_geometry() -> void:
	var body := StaticBody2D.new()
	body.name = "Solids"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	var visual := Node2D.new()
	visual.name = "SolidsVisual"
	add_child(visual)

	for r in ROOM_H:
		for c in ROOM_W:
			if ROOM[r][c] != "#":
				continue
			var shape := CollisionShape2D.new()
			var rect := RectangleShape2D.new()
			rect.size = Vector2(TILE, TILE)
			shape.shape = rect
			shape.position = Vector2((c + 0.5) * TILE, (r + 0.5) * TILE)
			body.add_child(shape)

			var poly := Polygon2D.new()
			poly.color = Palette.NIGHT_ASH
			poly.polygon = PackedVector2Array([
				Vector2(c * TILE, r * TILE),
				Vector2((c + 1) * TILE, r * TILE),
				Vector2((c + 1) * TILE, (r + 1) * TILE),
				Vector2(c * TILE, (r + 1) * TILE),
			])
			visual.add_child(poly)


func _spawn_kairo() -> void:
	_kairo = load("res://actors/kairo/kairo.tscn").instantiate()
	add_child(_kairo)
	_kairo.reset_to(_find_symbol("I"))
	_kairo.respawn_ready.connect(func(): _kairo.reset_to(_find_symbol("I")))


func _find_symbol(sym: String) -> Vector2:
	for r in ROOM_H:
		for c in ROOM_W:
			if ROOM[r][c] == sym:
				# پای شخصیت روی کف کاشی می‌نشیند: مرکز جعبه ۸ پیکسل بالاتر است
				return Vector2((c + 0.5) * TILE, (r + 1) * TILE - KairoConst.HITBOX.y * 0.5)
	return Vector2(TILE * 2, TILE * 2)


## دوربین قفل به اتاق: ۳۰×۱۷ کاشی = دقیقاً ۴۸۰×۲۷۰ (§۹)
func _build_camera() -> void:
	var cam := Camera2D.new()
	cam.position_smoothing_enabled = false
	cam.anchor_mode = Camera2D.ANCHOR_MODE_FIXED_TOP_LEFT
	cam.position = Vector2.ZERO
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = ROOM_W * TILE
	cam.limit_bottom = ROOM_H * TILE
	add_child(cam)
	cam.make_current()


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(load("res://ui/touch_controls/touch_controls.tscn").instantiate())
	_label = Label.new()
	_label.position = Vector2(4, 2)
	_label.add_theme_font_size_override("font_size", 8)
	layer.add_child(_label)


func _process(_dt: float) -> void:
	if _kairo == null or _label == null:
		return
	_label.text = "state=%s  vel=(%.0f, %.0f)  profile=%s" % [
		PlatformActor.State.keys()[_kairo.state],
		_kairo.velocity.x, _kairo.velocity.y,
		KairoConst.active_profile,
	]
