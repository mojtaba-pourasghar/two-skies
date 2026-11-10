## آزمون هستهٔ نبرد نوبتی — M4-الف (سند ۰۸ §۴ و §۵، سند ۰۹ §۳ و §۴)
##
##   godot --headless --fixed-fps 60 res://tools/tests/test_battle.tscn
##
## هر بند سند ۰۸ §۴ یک سنجه دارد، به‌علاوهٔ دو چیز که سند فقط با کلمه
## گفته: «هرگز صفر» و «بدون جریمه». هر چهار نبرد v1 هم با دو روبات تا
## آخر بازی می‌شوند: بازیکن دقیق باید ببرد، و نبرد آموزشی باید حتی برای
## بازیکنی که هیچ‌وقت به‌موقع نمی‌زند بردنی باشد («بازی ناعادلانه نشود»).
extends Node

const V1 := ["ch1_a2_crawlers", "ch1_a3_guard_crawler", "ch1_a3_patrol_drone",
	"ch1_a3_commander"]

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	_t_data()
	_t_timing()
	_t_strike()
	_t_turn_order()
	_t_interrupt()
	_t_defense()
	_t_kamikaze()
	_t_energy_link()
	_t_flee()
	_t_restart()
	_t_phases()
	_t_determinism()
	_t_full_battles()
	_t_balance()
	_report()


func _new(id: String, seed: int = 7) -> BattleCore:
	var b := BattleCore.new()
	var ok := b.start(id, seed)
	if not ok:
		print("    خطا: %s" % str(b.errors))
	return b


## یار فعلی را تا نوبت یار مشخص جلو می‌برد؛ دشمن‌ها بی‌دفاع کنش می‌کنند.
func _until_party(b: BattleCore, who: String, guard_cap: int = 40) -> bool:
	for i in guard_cap:
		if b.outcome != BattleCore.Outcome.ONGOING:
			return false
		var c := b.current()
		if c["side"] == "party" and c["id"] == who:
			return true
		if c["side"] == "party":
			b.act("guard")
		else:
			b.run_enemy()
	return false


func _t_data() -> void:
	print("— دادهٔ نبرد —")
	var b := BattleCore.new()
	_check("data/battle.json بی‌خطا بار شد", b.load_data(), str(b.errors))
	for id in V1:
		_check("  نبرد «%s» تعریف شده" % id, b.data["encounters"].has(id))
	var p: Dictionary = b.data["party"]
	_check("جان پایه طبق سند ۰۹ §۳ (ایلارا ۶۰، کایرو ۷۰)",
		int(p["ilara"]["hp"]) == 60 and int(p["kairo"]["hp"]) == 70)
	var e: Dictionary = b.data["enemies"]
	_check("جان دشمن‌ها طبق سند ۰۹ §۴ (۲۴، ۴۵، ۳۶، ۱۸، ۸۰)",
		int(e["crawler"]["hp"]) == 24 and int(e["guard"]["hp"]) == 45
			and int(e["drone"]["hp"]) == 36 and int(e["kamikaze"]["hp"]) == 18
			and int(e["commander"]["hp"]) == 80)
	_check("نگهبان فقط با هک قطع می‌شود (سند ۰۹ §۴)",
		e["guard"]["intents"]["shoot"]["interrupt"] == ["hack"])

	var bad := BattleCore.new()
	var broken := b.data.duplicate(true)
	broken["enemies"]["crawler"]["pattern"] = ["nope"]
	broken["encounters"]["x"] = {"enemies": ["crawler", "crawler", "crawler",
		"crawler", "crawler"]}
	broken["party"]["kairo"]["skills"] = ["ghost"]
	_check("دادهٔ خراب سه خطا داد (قصد، تعداد دشمن، مهارت)",
		not bad.load_data(broken) and bad.errors.size() >= 3, "= %d" % bad.errors.size())


func _t_timing() -> void:
	print("— پنجرهٔ زمان‌بندی —")
	var b := _new("ch1_a2_crawlers")
	_check("۰٫۰۵ث = عالی", b.grade(0.05) == "perfect")
	_check("−۰٫۱۰ث = عالی (لبه، دو طرفه)", b.grade(-0.10) == "perfect")
	_check("۰٫۱۵ث = خوب", b.grade(0.15) == "good")
	_check("۰٫۳۰ث = بیرون", b.grade(0.30) == "miss")
	_check("نزدن = بیرون", b.grade(BattleCore.NO_PRESS) == "miss")
	b.assist = true
	_check("دسترس‌پذیری: ۰٫۱۸ث = عالی (پنجره ×۲)", b.grade(0.18) == "perfect")
	_check("دسترس‌پذیری: ۰٫۳۵ث = خوب", b.grade(0.35) == "good")


func _t_strike() -> void:
	print("— ضربهٔ هم‌زمان —")
	for row in [[0.0, 14, 1, "عالی ×۱٫۵ و +۱ انرژی"], [0.15, 11, 0, "خوب ×۱٫۲"],
			[BattleCore.NO_PRESS, 9, 0, "نزدن ×۱٫۰ — هرگز صفر"]]:
		var b := _new("ch1_a2_crawlers")
		_until_party(b, "kairo")
		var e0 := b.energy
		var hp0 := int(b.unit("crawler_1")["hp"])
		b.act("strike", "", "crawler_1", float(row[0]))
		var dealt := hp0 - int(b.unit("crawler_1")["hp"])
		_check("کایرو ۹: %s" % row[3], dealt == int(row[1]) and b.energy - e0 == int(row[2]),
			"= آسیب %d، انرژی %+d" % [dealt, b.energy - e0])


func _t_turn_order() -> void:
	print("— نوار ترتیب —")
	var b := _new("ch1_a3_guard_crawler")
	var pv := b.preview(6)
	_check("پیش‌نمایش ۶ نوبت دارد", pv.size() == 6, str(pv))
	var real: Array[String] = []
	for i in 6:
		real.append(String(b.current()["id"]))
		if b.is_party_turn():
			b.act("guard")
		else:
			b.run_enemy(0.0)
	_check("و همان ترتیبی است که واقعاً رخ داد", pv == real,
		"" if pv == real else "%s ≠ %s" % [pv, real])
	var kairo := 0
	var guard := 0
	for id in _sequence("ch1_a3_guard_crawler", 30):
		if id == "kairo":
			kairo += 1
		elif id.begins_with("guard"):
			guard += 1
	_check("سریع‌تر = نوبت بیشتر (کایرو ۱۲ در برابر نگهبان ۶)", kairo >= 2 * guard - 1,
		"= کایرو %d، نگهبان %d در ۳۰ نوبت" % [kairo, guard])

	# چسبیدن خزنده کند می‌کند: هدف یک نوبت دیرتر می‌آید
	var c := _new("ch1_a2_crawlers")
	var slowed := false
	for i in 40:
		if c.outcome != BattleCore.Outcome.ONGOING:
			break
		if c.is_party_turn():
			c.act("guard")
		else:
			c.run_enemy()
			for ev in c.events:
				if ev["type"] == "slow":
					slowed = true
	_check("«چسبیدن» خزنده کند می‌کند (سند ۰۹ §۴)", slowed)


func _sequence(id: String, n: int) -> Array[String]:
	var b := _new(id)
	var out: Array[String] = []
	for i in n:
		if b.outcome != BattleCore.Outcome.ONGOING:
			break
		out.append(String(b.current()["id"]))
		if b.is_party_turn():
			b.act("guard")
		else:
			b.run_enemy(0.0)
	return out


func _t_interrupt() -> void:
	print("— قصد دشمن و قطع کردن —")
	var b := _new("ch1_a3_guard_crawler")
	var it := b.intent_of("guard_1")
	_check("نگهبان قصد شلیک را با شمارنده نشان می‌دهد",
		it.get("id", "") == "shoot" and int(it.get("left", -1)) == 1, str(it))
	_until_party(b, "ilara")
	var hp0 := int(b.unit("guard_1")["hp"])
	b.act("skill", "light", "guard_1")
	_check("نور شلیک نگهبان را قطع **نمی‌کند** (فقط هک)",
		b.intent_of("guard_1").get("id", "") == "shoot"
			and not b.unit("guard_1")["fragile"])
	_check("ولی آسیبش را می‌زند (۱۲)", hp0 - int(b.unit("guard_1")["hp"]) == 12)

	b = _new("ch1_a3_guard_crawler")
	_until_party(b, "kairo")
	b.act("skill", "hack", "guard_1")
	var g := b.unit("guard_1")
	var broke := false
	for ev in b.events:
		if ev["type"] == "interrupt":
			broke = true
	_check("هک شلیک را قطع کرد", broke)
	_check("نگهبان شکننده شد و یک نوبت گیج", g["fragile"] and int(g["stunned"]) == 1)
	_check("آسیب هک روی شکننده ×۱٫۵ شد (۴ → ۶)", int(g["max_hp"]) - int(g["hp"]) == 6,
		"= %d" % (int(g["max_hp"]) - int(g["hp"])))
	_check("قصد بعدی الگو جایش آمد (سپر)", b.intent_of("guard_1").get("id", "") == "shield")
	# نوبت نگهبان سوخت
	var skipped := false
	for i in 12:
		if b.current()["id"] == "guard_1":
			b.run_enemy()
			skipped = b.events.size() > 0 and b.events[0]["type"] == "skip"
			break
		if b.is_party_turn():
			b.act("guard")
		else:
			b.run_enemy()
	_check("و نوبت بعدش واقعاً سوخت", skipped)
	_check("شکنندگی با همان نوبت تمام شد", not b.unit("guard_1")["fragile"])


func _t_defense() -> void:
	print("— دفاع به‌موقع —")
	# پنجهٔ خزنده ۶ (سند ۰۹) × ضریب آسیب ۱٫۵ (D-ART-51) = ۹؛
	# خوب ۴٫۵ → ۵، عالی ۲٫۷ → ۳
	for row in [[BattleCore.NO_PRESS, 9, "بی‌دفاع"], [0.15, 5, "خوب −۵۰٪"],
			[0.0, 3, "عالی −۷۰٪"]]:
		var b := _new("ch1_a2_crawlers", 3)
		while b.current()["side"] != "enemy":
			b.act("strike", "", "crawler_1", BattleCore.NO_PRESS)
		var total0 := int(b.unit("kairo")["hp"]) + int(b.unit("ilara")["hp"])
		b.run_enemy(float(row[0]))
		var lost := total0 - int(b.unit("kairo")["hp"]) - int(b.unit("ilara")["hp"])
		_check("پنجهٔ ۹: %s" % row[2], lost == int(row[1]), "= %d" % lost)
	# سپرِ فرمان و دفاع به‌موقع ضرب می‌شوند، هرگز ۱۰۰٪ نمی‌شوند
	var c := _new("ch1_a2_crawlers", 3)
	c.act("guard")
	while c.current()["side"] != "enemy":
		c.act("guard")
	var t0 := int(c.unit("kairo")["hp"]) + int(c.unit("ilara")["hp"])
	c.run_enemy(0.0)
	var t1 := int(c.unit("kairo")["hp"]) + int(c.unit("ilara")["hp"])
	_check("سپر + دفاع عالی هنوز دست‌کم ۱ آسیب", t0 - t1 >= 1, "= %d" % (t0 - t1))


func _t_kamikaze() -> void:
	print("— ربات انتحاری —")
	var b := BattleCore.new()
	b.load_data()
	b.data["encounters"]["t_kami"] = {"enemies": ["kamikaze"], "fleeable": true}
	b.start("t_kami", 1)
	_check("قصد انفجار با شمارندهٔ ۲", int(b.intent_of("kamikaze_1").get("left", -1)) == 2)
	var charges := 0
	var boomed := false
	for i in 30:
		if b.outcome != BattleCore.Outcome.ONGOING:
			break
		if b.is_party_turn():
			b.act("guard")
			continue
		b.run_enemy()
		for ev in b.events:
			if ev["type"] == "charge":
				charges += 1
			if ev["type"] == "intent" and ev["intent"] == "explode":
				boomed = true
		if boomed:
			break
	_check("دو نوبت شارژ، بعد انفجار", charges == 2 and boomed, "= %d شارژ" % charges)
	_check("انفجار به هر دو یار خورد",
		int(b.unit("kairo")["hp"]) < 70 and int(b.unit("ilara")["hp"]) < 60)
	_check("و خودش از بین رفت → برد", b.outcome == BattleCore.Outcome.WIN)


func _t_energy_link() -> void:
	print("— انرژی رشته و پیوند دو آسمان —")
	var b := _new("ch1_a3_commander")
	_check("پیوند با انرژی کم ممنوع است", not b.commands("kairo").filter(
		func(c): return c["cmd"] == "link")[0]["ok"])
	b.energy = 9
	_until_party(b, "kairo")
	b.act("strike", "", "commander_1", 0.0)
	_check("ضربهٔ عالی انرژی را به ۱۰ رساند", b.energy == 10)
	b.energy = 10
	b._gain(5)
	_check("سقف ۱۰ است", b.energy == 10)
	_until_party(b, "ilara")
	var hp0 := int(b.unit("commander_1")["hp"])
	_check("پیوند حاضر است", b.act("link"))
	_check("۱۰ انرژی رفت", b.energy == 0)
	_check("۴۰ آسیب زد", hp0 - int(b.unit("commander_1")["hp"]) == 40,
		"= %d" % (hp0 - int(b.unit("commander_1")["hp"])))
	_check("و همه را شکننده کرد", b.unit("commander_1")["fragile"])


func _t_flee() -> void:
	print("— فرار —")
	var b := _new("ch1_a3_guard_crawler")
	_until_party(b, "kairo")
	var e0 := b.energy
	_check("فرار پذیرفته شد", b.act("flee"))
	_check("۱ انرژی هزینه داشت", e0 - b.energy == 1)
	_check("نتیجه «فرار»", b.outcome == BattleCore.Outcome.FLED)
	_check("و پاداشی ندارد", b.reward().is_empty())
	var c := _new("ch1_a3_commander")
	_until_party(c, "kairo")
	_check("از اوج نمی‌شود فرار کرد", not c.act("flee") and not c.can_flee())
	_check("حتی با بمب دود", not c.act("item", "smoke_bomb"))
	var d := _new("ch1_a2_crawlers")
	d.energy = 0
	_until_party(d, "kairo")
	_check("بی انرژی فرار ممکن نیست", not d.act("flee"))


func _t_restart() -> void:
	print("— شکست = شروع دوباره بدون جریمه —")
	var b := _new("ch1_a3_commander")
	var sig0 := b.state_signature()
	var first := String(b.current()["id"])
	b.act("item", "battery")
	for i in 200:
		if b.outcome != BattleCore.Outcome.ONGOING:
			break
		if b.is_party_turn():
			b.act("guard")
		else:
			b.run_enemy()
	_check("بی‌دفاع ماندن به شکست رسید", b.outcome == BattleCore.Outcome.LOSE)
	b.restart()
	_check("شروع دوباره همان وضعیت اول است (جان، انرژی، کیف، دشمن‌ها)",
		b.state_signature() == sig0)
	_check("کیف پر برگشت (باتری مصرف‌شده)", int(b.items.get("battery", 0)) == 1)
	_check("و نوبت اول همان است", String(b.current()["id"]) == first)
	_check("نتیجه دوباره «در جریان»", b.outcome == BattleCore.Outcome.ONGOING)


func _t_phases() -> void:
	print("— پهپاد فرمانده: دو فاز و فراخوان —")
	var b := _new("ch1_a3_commander")
	var c := b.unit("commander_1")
	_check("فاز ۱ با لیزر شروع می‌شود", b.intent_of("commander_1").get("id", "") == "laser")
	b._hurt_enemy(c, float(c["max_hp"]) * 0.55, "skill", "test")
	_check("زیر ۵۰٪ جان فاز ۲ شد", int(c["phase"]) == 1, "= جان %d" % int(c["hp"]))
	_check("و قصد همان لحظه عوض شد (فراخوان)",
		b.intent_of("commander_1").get("id", "") == "summon")
	var summoned := 0
	for i in 60:
		if b.outcome != BattleCore.Outcome.ONGOING:
			break
		if b.is_party_turn():
			b.act("guard")
		else:
			b.run_enemy(0.0)
			for ev in b.events:
				if ev["type"] == "summon":
					summoned += 1
	_check("پهپاد کوچک فراخوانده شد", summoned >= 1, "= %d" % summoned)
	var small := 0
	for u in b.alive("enemy"):
		if u["kind"] == "drone_small":
			small += 1
	_check("ولی هرگز بیش از ۲ تا هم‌زمان", small <= 2, "= %d" % small)


func _t_determinism() -> void:
	print("— تکرارپذیری —")
	var a := _sequence("ch1_a3_guard_crawler", 25)
	var b := _sequence("ch1_a3_guard_crawler", 25)
	_check("همان بذر، همان نبرد", a == b)


## دو روبات هر چهار نبرد v1 را تا آخر بازی می‌کنند.
func _t_full_battles() -> void:
	print("— هر چهار نبرد v1 تا آخر —")
	for id in V1:
		var r := _play(id, true)
		_check("  «%s»: بازیکن دقیق می‌برد" % id, r["outcome"] == BattleCore.Outcome.WIN,
			"= %d کنش یار، %d نوبت" % [r["party_actions"], r["turns"]])
		# سند ۰۸ §۴: نبرد ۳۰ تا ۹۰ ثانیه، اوج ۲ تا ۳ دقیقه. با ~۳ ثانیه برای هر
		# کنش یار (منو + حلقه + پویانمایی)، سقف کنش‌ها:
		var cap: int = 60 if id.ends_with("commander") else 30
		_check("  «%s»: کوتاه می‌ماند" % id, int(r["party_actions"]) <= cap,
			"= %d کنش (سقف %d)" % [r["party_actions"], cap])
	var t := _play("ch1_a2_crawlers", false)
	_check("نبرد آموزشی حتی بدون یک ضربهٔ به‌موقع بردنی است",
		t["outcome"] == BattleCore.Outcome.WIN, "= %s" % str(t))


## تعادل D-ART-51 مدیر با شرط‌های گام ۵۳، روی ۶۰ اجرا با BattleSim (مدل
## زمان بازیکن انسانی). «دقیق» = بازیکن دقیق انسانی (خطای زمان ۸۰ms)؛
## پیشگوی بی‌خطا فقط باید همیشه ببرد (D-ART-54).
const RUNS := 60
## شرط‌هایی که با اعداد فعلی برآورده نمی‌شوند و تصمیم کاربر می‌خواهند.
## دیده می‌شوند (⚠)، و اگر برآورده شدند سنجه رد می‌شود تا فهرست پاک شود.
##
## ردیف «climax_taken» با تصمیم مدیر در گام ۵۴ بسته شد (D-ART-55): لیزر
## فاز ۲ قطع‌نشدنی و هزینهٔ هک/نور ۳ رو به فرمانده. معیار هم از «≥۴۰٪»
## به **۲۵ تا ۴۰٪** عوض شد.
const PENDING_BALANCE := {}

## معیار تازهٔ مدیر برای نبرد اوج (گام ۵۴).
const CLIMAX_TAKEN_MIN := 0.25
const CLIMAX_TAKEN_MAX := 0.40


func _t_balance() -> void:
	print("— تعادل (D-ART-51، شرط‌های گام ۵۳) —")
	for id in ["ch1_a2_crawlers", "ch1_a3_guard_crawler", "ch1_a3_patrol_drone"]:
		var r := BattleSim.summary(id, "skilled", RUNS)
		_check("  «%s»: دقیق می‌برد" % id, r["win_rate"] >= 0.95, "= %.0f٪" % (r["win_rate"] * 100))
		_check("  «%s»: ۳۰–۹۰ ثانیه" % id, r["median_s"] >= 30.0 and r["median_s"] <= 90.0,
			"= میانه %.0fث [%.0f–%.0f]" % [r["median_s"], r["min_s"], r["max_s"]])
	var p := BattleSim.summary("ch1_a3_commander", "perfect", RUNS)
	_check("  اوج: پیشگوی بی‌خطا همیشه می‌برد", p["win_rate"] == 1.0)
	var k := BattleSim.summary("ch1_a3_commander", "skilled", RUNS)
	_check("  اوج: دقیق می‌برد", k["win_rate"] >= 0.95, "= %.0f٪" % (k["win_rate"] * 100))
	_check("  اوج: ۱۲۰–۱۸۰ ثانیه", k["median_s"] >= 120.0 and k["median_s"] <= 180.0,
		"= میانه %.0fث [%.0f–%.0f]" % [k["median_s"], k["min_s"], k["max_s"]])
	var taken: float = k["median_taken"]
	_check("  اوج: دقیق ۲۵ تا ۴۰٪ جان از دست می‌دهد (گام ۵۴)",
		taken >= CLIMAX_TAKEN_MIN and taken <= CLIMAX_TAKEN_MAX,
		"= %.0f٪" % (taken * 100.0))

	# ساختار تصمیم مدیر، نه فقط نتیجه‌اش: اگر کسی لیزر فاز ۲ را دوباره
	# قطع‌شدنی کند یا هزینه را به ۲ برگرداند، عدد بالا ممکن است هنوز
	# تصادفاً در بازه بیفتد ولی تصمیم از بین رفته باشد.
	var core := BattleCore.new()
	core.load_data()
	var cmd: Dictionary = core.data["enemies"]["commander"]
	var p2: Array = (cmd["phases"][1] as Dictionary)["pattern"]
	_check("  اوج: فاز ۲ لیزر قطع‌نشدنی دارد", "laser_locked" in p2,
		"= %s" % str(p2))
	_check("  و آن لیزر واقعاً قطع نمی‌شود",
		(cmd["intents"]["laser_locked"] as Dictionary).get("interrupt", []).is_empty())
	_check("  اوج: هک رو به فرمانده ۳ است", core.skill_cost("hack", "commander") == 3,
		"= %d" % core.skill_cost("hack", "commander"))
	_check("  اوج: نور رو به فرمانده ۳ است", core.skill_cost("light", "commander") == 3,
		"= %d" % core.skill_cost("light", "commander"))
	_check("  ولی رو به بقیه همان ۲ می‌ماند",
		core.skill_cost("hack", "guard") == 2 and core.skill_cost("light", "crawler") == 2)
	for bot in ["clumsy", "guard_only"]:
		var r := BattleSim.summary("ch1_a3_commander", bot, RUNS)
		_check("  اوج: «%s» در ≥۳۰٪ اجراها می‌بازد" % bot, r["lose_rate"] >= 0.30,
			"= %.0f٪" % (r["lose_rate"] * 100))
	# دشمن واقعاً حمله می‌کند: در هر نبرد، روبات دقیق دست‌کم یک آسیب می‌خورد
	for id in V1:
		var r := BattleSim.summary(id, "skilled", 20)
		var reach: bool = r["median_taken"] > 0.0
		var key := "reach_%s" % id
		if PENDING_BALANCE.has(key):
			print("  ⚠   «%s»: دشمن به بازیکن دقیق نمی‌رسد (۰٪)؛ منتظر %s" % [id, PENDING_BALANCE[key]])
			_check("  «%s»: هنوز واقعاً نمی‌رسد (وگرنه از فهرست بردار)" % id, not reach)
		else:
			_check("  «%s»: دشمن به یاران می‌رسد" % id, reach,
				"= %.0f٪ آسیب" % (r["median_taken"] * 100))


## روبات ساده: هر جا قصد قطع‌شدنی هست و انرژی هست قطع می‌کند، جان کم را
## شفا می‌دهد، وگرنه می‌زند. «دقیق» همیشه عالی می‌زند و عالی دفاع می‌کند؛
## «ناشی» هرگز به‌موقع نمی‌زند و هرگز دفاع نمی‌کند.
func _play(id: String, skilled: bool) -> Dictionary:
	var b := _new(id, 11)
	var timing: float = 0.0 if skilled else BattleCore.NO_PRESS
	var party_actions := 0
	for i in 400:
		if b.outcome != BattleCore.Outcome.ONGOING:
			break
		if not b.is_party_turn():
			b.run_enemy(timing)
			continue
		party_actions += 1
		var me := b.current()
		if skilled and b.energy >= 10 and b.alive("party").size() == 2 and b.act("link"):
			continue
		var done := false
		if skilled:
			for e in b.alive("enemy"):
				var it := b.intent_of(String(e["id"]))
				for sid in it.get("interrupt", []):
					if sid in b.data["party"][me["kind"]]["skills"] \
							and b.act("skill", sid, String(e["id"]), timing):
						done = true
						break
				if done:
					break
		if done:
			continue
		if me["kind"] == "ilara" and b.energy >= 3:
			for ally in b.alive("party"):
				if int(ally["hp"]) * 2 < int(ally["max_hp"]):
					done = b.act("skill", "heal", String(ally["id"]))
					break
		if done:
			continue
		var target := ""
		var low := 9999
		for e in b.alive("enemy"):
			if int(e["hp"]) < low:
				low = int(e["hp"])
				target = String(e["id"])
		b.act("strike", "", target, timing)
	return {"outcome": b.outcome, "party_actions": party_actions, "turns": b.turn}


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
