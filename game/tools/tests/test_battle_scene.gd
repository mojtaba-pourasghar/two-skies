## آزمون صحنهٔ نبرد — M4-ب (سند ۰۸ §۴ و §۶، معیار M4 سند ۱۲ §۸:
## «سه نبرد، زمان‌بندی، شروع دوبارهٔ <۲ث»)
##
##   godot --headless --fixed-fps 60 res://tools/tests/test_battle_scene.tscn
##
## هستهٔ نبرد جدا سنجیده شده (test_battle)؛ اینجا **صحنه** سنجیده می‌شود:
## اینکه حلقه همان عددی را به هسته می‌دهد که بازیکن زد، شکست واقعاً زیر
## ۲ ثانیه دوباره شروع می‌شود، و رابط روی صفحه است. سنجهٔ آخر از
## M4-ب آمد: ریشهٔ RTL پروژه هر `position` را که پیش از `add_child`
## گذاشته می‌شد آینه می‌کرد و منو بیرون صفحه می‌رفت — هیچ سنجهٔ عددی
## دیگری آن را نمی‌دید، فقط اسکرین‌شات.
extends Node

const V1 := ["ch1_a2_crawlers", "ch1_a3_guard_crawler", "ch1_a3_patrol_drone",
	"ch1_a3_commander"]
const SCREEN := Rect2(0, 0, 1280, 720)

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	await _t_layout()
	await _t_ring_timing()
	await _t_input_press()
	await _t_wins()
	await _t_lose_restart()
	_report()


func _make(enc: String, auto: String = "") -> BattleScene:
	var b: BattleScene = load("res://battle/battle_scene.tscn").instantiate()
	b.encounter_id = enc
	b.autoplay = auto
	add_child(b)
	return b


func _until(b: BattleScene, p: BattleScene.Phase, cap: int = 600) -> bool:
	for i in cap:
		if b.phase == p:
			return true
		await get_tree().physics_frame
	return b.phase == p


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _t_layout() -> void:
	print("— رابط روی صفحه —")
	var b := _make("ch1_a3_guard_crawler")
	_check("به منوی نوبت اول رسید", await _until(b, BattleScene.Phase.MENU))
	await _frames(2)
	var menu: Control = b.get("_menu_frame")
	_check("قاب منو پایین-چپ است (سند ۰۹ §۷)",
		menu.get_global_rect().position.x < 400 and menu.get_global_rect().end.y > 600,
		"= %s" % str(menu.get_global_rect()))
	var off: Array[String] = []
	var ui: Control = b.get("_ui")
	for c in ui.find_children("*", "Control", true, false):
		var ctl := c as Control
		if not ctl.visible or ctl.size == Vector2.ZERO:
			continue
		var r := ctl.get_global_rect()
		if not SCREEN.grow(8).encloses(r):
			off.append("%s %s" % [ctl.name, str(r)])
	_check("هیچ گرهٔ رابطی بیرون صفحه نیست (دام آینهٔ RTL)", off.is_empty(),
		"= %s" % str(off.slice(0, 3)))
	var strip: Array = b.get("_strip_labels")
	var filled := 0
	for l in strip:
		if (l as Label).text != "":
			filled += 1
	_check("نوار ترتیب ۶ نام دارد", filled == 6, "= %d" % filled)
	var buttons := (b.get("_menu_box") as Node).get_children()
	_check("منو شش فرمان دارد (ضربه، مهارت، پیوند، سپر، شیء، فرار)",
		buttons.size() == 6, "= %d" % buttons.size())
	_check("پیوند با انرژی ۳ غیرفعال است", (buttons[2] as Button).disabled)
	var nodes: Dictionary = b.get("_enemy_nodes")
	var icon: TextureRect = nodes["guard_1"]["icon"]
	_check("آیکن قصد نگهبان دیده می‌شود و تصویر دارد",
		icon.visible and icon.texture != null)
	_check("و شمارندهٔ نوبتش «۱» است",
		(nodes["guard_1"]["left"] as Label).text == "۱",
		"= «%s»" % (nodes["guard_1"]["left"] as Label).text)
	var bg: TextureRect = b.get("_bg")
	_check("پس‌زمینهٔ نبرد کل صفحه را می‌پوشاند",
		bg.texture != null and bg.get_global_rect().size == Vector2(1280, 720),
		"= %s" % str(bg.get_global_rect()))
	b.queue_free()
	await _frames(2)


## حلقه باید دقیقاً همان فاصله‌ای را بدهد که بازیکن زد: سر وقت = عالی،
## ۹ فریم (۰٫۱۵ث) دیر = خوب، نزدن = ×۱٫۰.
func _t_ring_timing() -> void:
	print("— حلقهٔ زمان‌بندی در صحنه —")
	for row in [[0, 14, "سر وقت = عالی ۱۴"], [9, 11, "۰٫۱۵ث دیر = خوب ۱۱"],
			[-1, 9, "نزدن = ۹، هرگز صفر"]]:
		var b := _make("ch1_a2_crawlers")
		await _until(b, BattleScene.Phase.MENU)
		# کایرو اول است (سرعت ۱۲)
		var core: BattleCore = b.core
		var hp0 := int(core.unit("crawler_1")["hp"])
		b._on_cmd("strike", "")
		b._choose_target("crawler_1")
		_check("  حلقه شروع شد", b.phase == BattleScene.Phase.RING)
		var total: int = b.get("_ring_total")
		var late: int = int(row[0])
		if late >= 0:
			while int(b.get("_ring_t")) < total + late:
				await get_tree().physics_frame
			b._press()
		await _until(b, BattleScene.Phase.RESOLVE, 200)
		var dealt := hp0 - int(core.unit("crawler_1")["hp"])
		_check("  %s" % row[2], dealt == int(row[1]), "= %d" % dealt)
		b.queue_free()
		await _frames(2)


## دکمهٔ «عمل» واقعی (نه صدا زدن مستقیم) حلقه را می‌گیرد.
func _t_input_press() -> void:
	print("— ورودی واقعی —")
	var b := _make("ch1_a2_crawlers")
	await _until(b, BattleScene.Phase.MENU)
	b._on_cmd("strike", "")
	b._choose_target("crawler_1")
	var total: int = b.get("_ring_total")
	while int(b.get("_ring_t")) < total:
		await get_tree().physics_frame
	var ev := InputEventAction.new()
	ev.action = "action"
	ev.pressed = true
	get_viewport().push_input(ev)
	_check("کنش «action» فشار را ثبت کرد", int(b.get("_pressed_at")) == total,
		"= %d (باید %d)" % [int(b.get("_pressed_at")), total])
	b.queue_free()
	await _frames(2)


func _t_wins() -> void:
	print("— هر چهار نبرد v1 در صحنه —")
	for enc in V1:
		GameState.data = GameState.default_save()
		var coins0 := int(GameState.data.get("coins", 0))
		var b := _make(enc, "skilled")
		var got: Array = []
		b.finished.connect(func(o, id): got.append([o, id]))
		var frames := 0
		while got.is_empty() and frames < 60 * 120:
			await get_tree().physics_frame
			frames += 1
		_check("  «%s» برده و اعلام شد" % enc,
			not got.is_empty() and int(got[0][0]) == BattleCore.Outcome.WIN,
			"= %s در %.1f ثانیه" % [str(got), frames / 60.0])
		var reward := int(b.core.encounter.get("reward", {}).get("coins", 0))
		_check("  پاداش سکه رسید (%d)" % reward,
			int(GameState.data.get("coins", 0)) - coins0 == reward)
		_check("  پرچم برد ثبت شد",
			bool(GameState.get_flag("battle_won_%s" % enc, false)))
		b.queue_free()
		await _frames(2)
	GameState.data = GameState.default_save()


## معیار M4: شکست → شروع دوباره زیر ۲ ثانیه، بدون جریمه.
func _t_lose_restart() -> void:
	print("— شکست و شروع دوباره —")
	var b := _make("ch1_a3_commander", "idle")
	var frames := 0
	while int(b.get("retries")) == 0 and frames < 60 * 300:
		await get_tree().physics_frame
		frames += 1
	_check("بی‌دفاع ماندن به شکست و شروع دوباره رسید", int(b.get("retries")) == 1,
		"= پس از %.1f ثانیه" % (frames / 60.0))
	var took: int = b.get("last_restart_frames")
	_check("از لحظهٔ شکست تا شروع دوباره زیر ۲ ثانیه", took > 0 and took <= 120,
		"= %d فریم (%.2f ث)" % [took, took / 60.0])
	_check("جان یاران پر برگشت",
		int(b.core.unit("kairo")["hp"]) == 70 and int(b.core.unit("ilara")["hp"]) == 60)
	_check("انرژی و کیف همان شروع",
		b.core.energy == int(b.core.data["energy"]["start"])
			and int(b.core.items.get("repair_kit", 0)) == 2)
	await _until(b, BattleScene.Phase.MENU, 200)
	_check("و نبرد دوباره به منو رسید", b.phase == BattleScene.Phase.MENU
		or b.phase == BattleScene.Phase.RING)
	b.queue_free()
	await _frames(2)


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
