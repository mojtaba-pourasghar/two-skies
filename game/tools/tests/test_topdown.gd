## آزمون همراهی ایلارا در نمای سه‌چهارم — §۵ سند ۰۲
##
##   godot --headless res://tools/tests/test_topdown.tscn
##
## این پوشش با بایگانی شدن `test_companion` (نمای کناری) از دست رفت و
## قانون §۵ چند گام بی‌آزمون ماند. اینجا برای `TdIlara` بازنوشته شد: صف،
## «بمان/بیا»، جهش از نشانه، و اینکه مرگ ایلارا شمرده می‌شود.
extends Node2D

var _failures: Array[String] = []
var _checks: int = 0

## اتاقی ساده و باز، فقط برای آزمون: ماسک یک مستطیل بزرگ است تا حرکت
## جایی گیر نکند و آزمون قانون همراهی را بسنجد نه برخورد را.
const MASK := {
	"id": "t_open",
	"bg": "x.png",
	"size": [2560, 1080],
	"walkable": [[0, 0, 2560, 0, 2560, 1080, 0, 1080]],
}


func _ready() -> void:
	await _t_queue()
	await _t_orders()
	await _t_hop_mark()
	_t_death()
	await _t_challenge_rooms()
	await _t_personal_space()
	_report()


func _make() -> Array:
	var room := PaintedRoom.new()
	add_child(room)
	var full: Dictionary = MASK.duplicate(true)
	var v := RoomData.new()
	v._normalize(full)
	room.build(full)

	var kairo := TdKairo.new()
	kairo.room = room
	kairo.global_position = Vector2(400, 400)
	room.actors.add_child(kairo)

	var ilara := TdIlara.new()
	ilara.room = room
	ilara.leader = kairo
	ilara.global_position = Vector2(400, 400)
	room.actors.add_child(ilara)
	return [room, kairo, ilara]


## §۵: ۴۸ فریم (۰٫۸ ثانیه) پشت رهبر. سنجه عدد را از ثابت می‌گیرد نه از
## وسط کد، تا اگر پروفایل عوض شد آزمون هم با آن برود.
func _t_queue() -> void:
	print("— صف همراه —")
	_check("تأخیر همراه ۴۸ فریم است (۰٫۸ ثانیه)",
		TdConst.COMPANION_DELAY_FRAMES == 48, "= %d" % TdConst.COMPANION_DELAY_FRAMES)

	var made := _make()
	var kairo: TdKairo = made[1]
	var ilara: TdIlara = made[2]

	# رهبر را با دست می‌بریم: ورودی واقعی در headless نیست
	var speed: float = TdConst.RUN_SPEED
	for i in 120:
		kairo.global_position.x += speed / float(TdConst.FPS)
		await get_tree().physics_frame

	var gap: float = kairo.global_position.x - ilara.global_position.x
	# فاصلهٔ انتظار: سرعت رهبر × زمان تأخیر. ایلارا تندتر می‌دود
	# (۱۰۵ در برابر ۹۶) پس عقب نمی‌افتد، ولی جلو هم نمی‌زند.
	var want: float = speed * float(TdConst.COMPANION_DELAY_FRAMES) / float(TdConst.FPS)
	_check("ایلارا پشت کایرو است، نه جلوی او", gap > 0.0, "= %.0f px" % gap)
	_check("فاصله حدود سرعت×تأخیر است", absf(gap - want) < want * 0.5,
		"= %.0f px، انتظار ~%.0f" % [gap, want])
	_check("ایلارا جا نماند (فاصله بی‌مرز رشد نکرد)", gap < want * 2.0,
		"= %.0f px" % gap)
	made[0].queue_free()


func _t_orders() -> void:
	print("— بمان و بیا —")
	var made := _make()
	var kairo: TdKairo = made[1]
	var ilara: TdIlara = made[2]

	ilara.set_order(TdIlara.Order.STAY)
	var held := ilara.global_position
	for i in 90:
		kairo.global_position.x += TdConst.RUN_SPEED / float(TdConst.FPS)
		await get_tree().physics_frame
	_check("با «بمان» سر جایش می‌ماند",
		ilara.global_position.distance_to(held) < 2.0,
		"= %.1f px جابه‌جایی" % ilara.global_position.distance_to(held))

	ilara.set_order(TdIlara.Order.FOLLOW)
	var before := ilara.global_position.x
	for i in 120:
		await get_tree().physics_frame
	_check("با «بیا» راه می‌افتد و فاصله را می‌بندد",
		ilara.global_position.x > before + 10.0,
		"= %.0f px پیش رفت" % (ilara.global_position.x - before))
	made[0].queue_free()


## نشانهٔ جهش: ایلارا کمان کایرو را حدس نمی‌زند، همان نقطهٔ فرود او را
## می‌گیرد. وگرنه روی چاله‌ای که کایرو پرید می‌افتد.
func _t_hop_mark() -> void:
	print("— جهش از نشانه —")
	var made := _make()
	var kairo: TdKairo = made[1]
	var ilara: TdIlara = made[2]

	_check("در شروع نشانهٔ جهشی نیست",
		kairo.hop_mark_at(TdConst.COMPANION_DELAY_FRAMES) == Vector2.ZERO)

	# حلقهٔ ضبط باید **اول پر شود**. جهش در فریم صفر نشانه‌اش هرگز خوانده
	# نمی‌شود: جای نشانه یک خانه پیش از قدیمی‌ترین جای‌گاه ضبط‌شده می‌افتد،
	# پس با تأخیر ۴۸ از دسترس بیرون می‌ماند. در بازی واقعی کایرو پس از
	# ده‌ها فریم می‌جهد و این پیش نمی‌آید، ولی آزمون باید همان حالت را
	# بسازد نه حالت مرزیِ فریم صفر.
	for i in TdConst.COMPANION_DELAY_FRAMES + 12:
		kairo.global_position.x += TdConst.RUN_SPEED / float(TdConst.FPS)
		await get_tree().physics_frame
	# ایلارا باید روی ردّ تأخیری نشسته باشد، وگرنه پنجرهٔ ۱۲ پیکسلی نشانه
	# را از دست می‌دهد و این سنجه چیزی را نمی‌سنجد
	var on_trail: float = ilara.global_position.distance_to(
		kairo.trail_at(TdConst.COMPANION_DELAY_FRAMES))
	_check("ایلارا روی ردّ تأخیری است (پیش‌شرط نشانه)",
		on_trail <= TdIlara.HOP_SNAP_PX, "= %.1f px از ردّ" % on_trail)

	kairo.start_hop(Vector2.RIGHT)
	_check("نشانهٔ جهش ضبط شد", kairo.state == TdActor.State.HOP)
	var hopped := false
	for i in TdConst.COMPANION_DELAY_FRAMES + TdConst.hop_frames() + 24:
		if kairo.state == TdActor.State.MOVE:
			kairo.global_position.x += TdConst.RUN_SPEED / float(TdConst.FPS)
		await get_tree().physics_frame
		if ilara.state == TdActor.State.HOP:
			hopped = true
	_check("ایلارا هم همان جهش را زد", hopped)
	made[0].queue_free()


## §۵: مرگ ایلارا شکست مرحله است، پس باید شمرده و اعلام شود — نه بی‌صدا.
func _t_death() -> void:
	print("— مرگ همراه —")
	var made := _make()
	var ilara: TdIlara = made[2]
	var heard: Array[int] = []
	ilara.fell.connect(func(): heard.append(1))
	ilara.die()
	_check("مرگ ایلارا شمرده شد", ilara.falls == 1, "= %d" % ilara.falls)
	_check("و اعلام شد", heard.size() == 1, "= %d" % heard.size())
	made[0].queue_free()


## D-ART-35: ایلارا وارد اتاق چالش نمی‌شود؛ کنار در منتظر می‌ماند و
## هنگام برگشت دوباره دنبال می‌کند.
##
## این یک **باگ واقعی** بود، نه قاعدهٔ تازه: تا اینجا ایلارا با کایرو
## وارد C1 می‌شد، و چون در اتاق چالش مرگ بی‌نهایت است، قانون §۵ (مرگ
## ایلارا = شکست مرحله) با قانون اتاق چالش می‌جنگید.
func _t_challenge_rooms() -> void:
	print("— ایلارا و اتاق چالش —")
	var l := RoomData.new()
	var challenge := 0
	for rid in ["c1_balcony", "c2_laser_alley", "c3_electric_hall"]:
		var r := l.load_room(rid)
		if r.is_empty():
			_check("اتاق «%s» بار شد" % rid, false)
			continue
		var is_c: bool = RoomGame.is_challenge(r)
		_check("«%s» اتاق چالش علامت خورده" % rid, is_c)
		if is_c:
			challenge += 1
	_check("هر سه اتاق چالش علامت دارند", challenge == 3, "= %d" % challenge)

	for rid in ["r1a_living", "r1b_corridor", "r1c_kitchen"]:
		var r := l.load_room(rid)
		_check("«%s» اتاق چالش **نیست**" % rid,
			not r.is_empty() and not RoomGame.is_challenge(r))

	# اجرای واقعی: ورود به C1 نباید ایلارا بسازد
	var game: Node2D = load("res://scenes/room_game.tscn").instantiate()
	game.set("play_story", false)
	game.set("start_room", "c1_balcony")
	add_child(game)
	await get_tree().process_frame
	await get_tree().process_frame
	_check("کایرو در اتاق چالش هست", game.get("kairo") != null)
	_check("ولی ایلارا وارد نشده است", game.get("ilara") == null)
	var in_tree := 0
	for n in get_tree().get_nodes_in_group("ilara"):
		if game.is_ancestor_of(n):
			in_tree += 1
	_check("و هیچ گرهٔ ایلارایی در صحنه نیست", in_tree == 0, "= %d" % in_tree)
	game.queue_free()
	await get_tree().process_frame

	# و در اتاق عادی باید باشد و دنبال کند
	var game2: Node2D = load("res://scenes/room_game.tscn").instantiate()
	game2.set("play_story", false)
	game2.set("start_room", "r1a_living")
	add_child(game2)
	await get_tree().process_frame
	await get_tree().process_frame
	var il = game2.get("ilara")
	_check("در اتاق عادی ایلارا هست", il != null)
	if il != null:
		_check("و در حالت «بیا» است", il.order == TdIlara.Order.FOLLOW)
		_check("و رهبرش کایروست", il.leader == game2.get("kairo"))
	game2.queue_free()


## کایروی ایستاده: ایلارا کنارش می‌ایستد نه رویش (گام ۵۳، S3a). روی
## هم ایستادن یعنی یکی از دو شخصیت روی صفحه ناپدید است.
func _t_personal_space() -> void:
	print("— فاصلهٔ شخصی ایلارا —")
	var game: RoomGame = load("res://scenes/room_game.tscn").instantiate()
	game.set("play_story", false)
	game.start_room = "s3a_plaza"
	game.resume = false
	add_child(game)
	for i in 120:
		await get_tree().physics_frame
	var d: float = game.ilara.global_position.distance_to(game.kairo.global_position)
	_check("ایلارا روی کایروی ایستاده نمی‌ایستد", d >= 24.0, "= %.0f پیکسل" % d)
	_check("ولی نزدیکش می‌ماند", d <= 64.0, "= %.0f پیکسل" % d)
	game.queue_free()
	await get_tree().physics_frame


func _check(label: String, ok: bool, detail: String = "") -> void:
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
