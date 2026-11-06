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
