## شبیه‌ساز تعادل نبرد — سه روبات و مدل زمان بازیکن انسانی (M4-ج)
##
## برای سنجهٔ تعادل D-ART-51 مدیر: طول نبرد معمولی ۳۰–۹۰ث و اوج ۱۲۰–۱۸۰ث،
## بازیکن دقیق می‌برد با ≥۴۰٪ جان از دست رفته، و «ناشی» و «فقط‌سپر» اوج را
## در ≥۳۰٪ اجراها می‌بازند.
##
## مدل زمان از خود صحنه (`BattleScene`) اندازه گرفته شده، به‌علاوهٔ زمان
## تصمیم بازیکن که روبات صحنه ندارد:
##   کنش یار  = تصمیم ۱٫۵ + (حلقه ۰٫۸ اگر زمان‌دار) + نمایش ۰٫۵۳
##   نوبت دشمن = قصد ۰٫۳۷ + (حلقهٔ دفاع ۱٫۰ اگر حمله) + نمایش ۰٫۵۳
class_name BattleSim
extends RefCounted

const DECIDE_S := 1.5
const RING_S := 0.8
const RESOLVE_S := 32.0 / 60.0
const TELEGRAPH_S := 22.0 / 60.0
const DEFENSE_S := 1.0

## انحراف معیار زمان فشار بازیکن دقیق انسانی (ثانیه). با ۰٫۰۸ حدود ۷۹٪
## فشارها «عالی»، ۱۹٪ «خوب» و ۲٪ «بیرون» است.
const HUMAN_SIGMA_S := 0.08

## روبات:
##   "perfect"    همیشه دقیقاً سر وقت (پیشگو؛ فقط باید همیشه ببرد)
##   "skilled"    دقیق انسانی: هوشمند مثل perfect، زمان فشار با خطای HUMAN_SIGMA_S
##   "clumsy"     هرگز به‌موقع نمی‌زند و دفاع نمی‌کند، قطع نمی‌کند
##   "guard_only" فقط سپر، بی دفاع
static func play(enc: String, bot: String, seed: int, balance: Dictionary = {},
		patch: Callable = Callable()) -> Dictionary:
	var b := BattleCore.new()
	b.load_data()
	if not balance.is_empty():
		(b.data["encounters"][enc] as Dictionary)["balance"] = balance
	# فقط برای سنجیدن گزینه‌های طراحی پیش از تصمیم؛ داده روی دیسک دست نمی‌خورد
	if patch.is_valid():
		patch.call(b.data)
	b.start(enc, seed)
	var secs := 0.0
	var actions := 0
	var party_max := 0
	for u in b.alive("party"):
		party_max += int(u["max_hp"])
	var noise := RandomNumberGenerator.new()
	noise.seed = seed * 7919 + 13
	var smart := bot == "perfect" or bot == "skilled"
	var taken := 0
	for i in 800:
		if b.outcome != BattleCore.Outcome.ONGOING:
			break
		var timing: float = BattleCore.NO_PRESS
		if bot == "perfect":
			timing = 0.0
		elif bot == "skilled":
			timing = noise.randfn(0.0, HUMAN_SIGMA_S)
		if not b.is_party_turn():
			var attack := b.pending_attack()
			b.run_enemy(timing)
			for ev in b.events:
				if ev["type"] == "damage" and b.unit(String(ev["who"])).get("side", "") == "party":
					taken += int(ev["amount"])
			secs += TELEGRAPH_S + RESOLVE_S + (DEFENSE_S if attack else 0.0)
			continue
		actions += 1
		secs += DECIDE_S + RESOLVE_S + _act(b, bot, smart, timing)
	var party_hp := 0
	for u in b.units:
		if u["side"] == "party":
			party_hp += int(u["hp"])
	return {"outcome": b.outcome, "seconds": secs, "actions": actions,
		"hp_lost": 1.0 - float(party_hp) / float(party_max),
		# کل آسیب گرفته‌شده در طول نبرد، به نسبت جان کل یاران؛ شفا آن را
		# پاک نمی‌کند (معنای «با ≥۴۰٪ جان از دست رفته»، D-ART-54)
		"taken": float(taken) / float(party_max)}


## یک کنش یار؛ برمی‌گرداند چند ثانیه حلقه داشت.
static func _act(b: BattleCore, bot: String, smart: bool, timing: float) -> float:
	var me := b.current()
	if bot == "guard_only":
		b.act("guard")
		return 0.0
	if smart:
		if b.energy >= 10 and b.alive("party").size() == 2 and b.act("link"):
			return RING_S
		for e in b.alive("enemy"):
			var it := b.intent_of(String(e["id"]))
			for sid in it.get("interrupt", []):
				if sid in b.data["party"][me["kind"]]["skills"] \
						and b.act("skill", sid, String(e["id"]), timing):
					return 0.0
	if me["kind"] == "ilara" and b.energy >= 3:
		for ally in b.units:
			if ally["side"] == "party" and int(ally["hp"]) * 2 < int(ally["max_hp"]):
				if b.act("skill", "heal", String(ally["id"])):
					return 0.0
	var target := ""
	var low := 99999
	for e in b.alive("enemy"):
		if int(e["hp"]) < low:
			low = int(e["hp"])
			target = String(e["id"])
	b.act("strike", "", target, timing)
	return RING_S


## خلاصهٔ چند اجرا: نرخ برد، میانهٔ ثانیه، میانهٔ جان ازدست‌رفته.
static func summary(enc: String, bot: String, runs: int = 40, balance: Dictionary = {},
		patch: Callable = Callable()) -> Dictionary:
	var wins := 0
	var secs: Array[float] = []
	var lost: Array[float] = []
	var taken: Array[float] = []
	for s in range(1, runs + 1):
		var r := play(enc, bot, s, balance, patch)
		if r["outcome"] == BattleCore.Outcome.WIN:
			wins += 1
		secs.append(float(r["seconds"]))
		lost.append(float(r["hp_lost"]))
		taken.append(float(r["taken"]))
	secs.sort()
	lost.sort()
	taken.sort()
	return {"win_rate": float(wins) / float(runs), "lose_rate": 1.0 - float(wins) / float(runs),
		"median_s": secs[runs / 2], "min_s": secs[0], "max_s": secs[runs - 1],
		"median_hp_lost": lost[runs / 2], "median_taken": taken[runs / 2],
		"min_taken": taken[0]}
