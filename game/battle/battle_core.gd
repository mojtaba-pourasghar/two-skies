## هستهٔ نبرد نوبتی — M4 (سند ۰۸ §۴، سند ۰۹ §۳ و §۴)
##
## منطق خالص: نه گره، نه ورودی، نه زمان واقعی. صحنهٔ نبرد (M4-ب) فقط
## «چه دکمه‌ای، با چه فاصله‌ای از لحظهٔ درست» را به اینجا می‌دهد و رویدادها
## را برای نمایش برمی‌دارد. این جدایی عمدی است: هر قاعدهٔ سند ۰۸ بدون
## پنجره و بدون فریم سنجیده می‌شود (test_battle)، و رابط هرگز عدد بازی را
## خودش حساب نمی‌کند.
##
## ترتیب نوبت «زمان شارژ» است (CTB): هر یکا `ct` دارد؛ کمترین `ct` نوبت
## می‌گیرد، همه به همان اندازه جلو می‌روند، و کنشگر `ct_base / speed`
## دوباره منتظر می‌ماند. پس سریع‌تر = نوبت بیشتر، و پیش‌نمایش ۶ نوبت
## بعدی فقط شبیه‌سازی همین است (سند ۰۸: «نوار ترتیب، ۶ نوبت بعدی»).
##
## زمان‌بندی: `timing` فاصلهٔ فشار دکمه از لحظهٔ درست به ثانیه است.
## `NO_PRESS` یعنی اصلاً نزد. ضربه هرگز صفر نمی‌شود (×۱٫۰)، دفاعِ نزده
## فقط کاهشی ندارد.
class_name BattleCore
extends RefCounted

const DATA_PATH := "res://data/battle.json"
## «اصلاً نزد» — بیرون هر پنجره‌ای
const NO_PRESS := INF

enum Outcome { ONGOING, WIN, LOSE, FLED }

var data: Dictionary = {}
var errors: Array[String] = []
var encounter_id: String = ""
var encounter: Dictionary = {}
var outcome: Outcome = Outcome.ONGOING
## پنجرهٔ دسترس‌پذیری ×۲ (سند ۰۸ §۴)
var assist: bool = false
## پرچم‌های داستان که مهارت باز می‌کنند (مثلاً `emp_unlocked`)
var flags: Dictionary = {}

## یکاها به ترتیب ساخت. هر یکا یک Dictionary است تا رونوشت و برگشت ساده
## باشد: {id, side, kind, hp, max_hp, speed, ct, alive, guard, shield,
## barrier, fragile, marked, stunned, slowed, intent, intent_left, step, phase}
var units: Array[Dictionary] = []
var energy: int = 0
var items: Dictionary = {}
var turn: int = 0
## رویدادهای این نوبت برای نمایش: {type, ...}. هر کنش پاکش می‌کند.
var events: Array[Dictionary] = []

var _rng := RandomNumberGenerator.new()
var _seed: int = 0
var _start_snapshot: Dictionary = {}
var _current: int = -1
var _summoned: int = 0


## داده را بار می‌کند (یا دادهٔ داده‌شده را برای آزمون می‌گیرد).
func load_data(override: Dictionary = {}) -> bool:
	errors.clear()
	if not override.is_empty():
		data = override
	else:
		var f := FileAccess.open(DATA_PATH, FileAccess.READ)
		if f == null:
			errors.append("دادهٔ نبرد پیدا نشد: %s" % DATA_PATH)
			return false
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if typeof(parsed) != TYPE_DICTIONARY:
			errors.append("دادهٔ نبرد JSON معتبر نیست.")
			return false
		data = parsed
	_validate()
	return errors.is_empty()


func _validate() -> void:
	for key in ["timing", "energy", "rules", "party", "skills", "items", "enemies", "encounters"]:
		if not data.has(key):
			errors.append("دادهٔ نبرد «%s» ندارد." % key)
	if not errors.is_empty():
		return
	var skills: Dictionary = data["skills"]
	for pid in data["party"]:
		var p: Dictionary = data["party"][pid]
		for k in ["hp", "speed", "strike"]:
			if float(p.get(k, 0)) <= 0.0:
				errors.append("یار «%s»: «%s» باید مثبت باشد." % [pid, k])
		for sid in p.get("skills", []):
			if not skills.has(sid):
				errors.append("یار «%s»: مهارت ناشناختهٔ «%s»." % [pid, sid])
	var enemies: Dictionary = data["enemies"]
	for eid in enemies:
		var e: Dictionary = enemies[eid]
		var intents: Dictionary = e.get("intents", {})
		if float(e.get("hp", 0)) <= 0.0 or float(e.get("speed", 0)) <= 0.0:
			errors.append("دشمن «%s»: جان و سرعت باید مثبت باشند." % eid)
		var patterns: Array = []
		if e.has("phases"):
			for ph in e["phases"]:
				patterns.append((ph as Dictionary).get("pattern", []))
		else:
			patterns.append(e.get("pattern", []))
		for pat in patterns:
			if (pat as Array).is_empty():
				errors.append("دشمن «%s»: الگوی قصد خالی است." % eid)
			for iid in pat:
				if not intents.has(iid):
					errors.append("دشمن «%s»: قصد ناشناختهٔ «%s» در الگو." % [eid, iid])
		for iid in intents:
			var it: Dictionary = intents[iid]
			for sid in it.get("interrupt", []):
				if not skills.has(sid):
					errors.append("دشمن «%s» قصد «%s»: قطع با مهارت ناشناختهٔ «%s»."
						% [eid, iid, sid])
			if it.has("summon") and not enemies.has(String(it["summon"])):
				errors.append("دشمن «%s»: فراخوان دشمن ناشناختهٔ «%s»." % [eid, it["summon"]])
	for nid in data["encounters"]:
		var n: Dictionary = data["encounters"][nid]
		var list: Array = n.get("enemies", [])
		if list.is_empty() or list.size() > 4:
			errors.append("نبرد «%s»: باید ۱ تا ۴ دشمن داشته باشد (سند ۰۸ §۴)." % nid)
		for eid in list:
			if not enemies.has(eid):
				errors.append("نبرد «%s»: دشمن ناشناختهٔ «%s»." % [nid, eid])


## نبرد را می‌چیند. `seed` ثابت = نبرد تکرارپذیر (هدف‌گیری دشمن تصادفی است).
func start(id: String, seed: int = 1, inventory: Dictionary = {}) -> bool:
	if data.is_empty() and not load_data():
		return false
	if not data["encounters"].has(id):
		errors.append("نبرد ناشناخته: %s" % id)
		return false
	encounter_id = id
	encounter = data["encounters"][id]
	_seed = seed
	_rng.seed = seed
	units.clear()
	events.clear()
	outcome = Outcome.ONGOING
	turn = 0
	_summoned = 0
	energy = int(data["energy"].get("start", 0))
	items = (inventory if not inventory.is_empty() else data.get("start_items", {})).duplicate()
	for pid in ["kairo", "ilara"]:
		var p: Dictionary = data["party"][pid]
		units.append(_make_unit(pid, "party", pid, int(p["hp"]), float(p["speed"])))
	var n := 0
	for eid in encounter["enemies"]:
		n += 1
		_add_enemy(String(eid), "%s_%d" % [eid, n])
	_start_snapshot = _snapshot()
	_advance()
	return true


## شکست = شروع دوبارهٔ همان نبرد، **بدون جریمه** (سند ۰۸ §۱). همه‌چیز،
## حتی انرژی و کیف و بذر تصادفی، به لحظهٔ شروع برمی‌گردد.
func restart() -> void:
	_restore(_start_snapshot)
	_rng.seed = _seed
	events.clear()
	_current = -1
	_advance()


func _make_unit(id: String, side: String, kind: String, hp: int, speed: float) -> Dictionary:
	return {
		"id": id, "side": side, "kind": kind, "hp": hp, "max_hp": hp,
		"speed": speed, "ct": _ct_base() / speed, "alive": true,
		"guard": false, "shield": 0.0, "barrier": 0, "fragile": false,
		"marked": false, "stunned": 0, "slowed": false,
		"intent": "", "intent_left": 0, "step": 0, "phase": 0,
	}


func _add_enemy(kind: String, id: String) -> Dictionary:
	var e: Dictionary = data["enemies"][kind]
	var hp := int(round(float(e["hp"]) * _bal("enemy_hp_mult")))
	var u := _make_unit(id, "enemy", kind, hp, float(e["speed"]))
	units.append(u)
	_next_intent(u)
	return u


## ضریب تعادل (D-ART-51 مدیر). نبرد می‌تواند ضریب خودش را داشته باشد
## (اوج)، وگرنه ضریب سراسری؛ نبودن هر دو = ۱، یعنی اعداد خام سند.
func _bal(key: String) -> float:
	var own: Dictionary = encounter.get("balance", {})
	if own.has(key):
		return float(own[key])
	return float((data.get("balance", {}) as Dictionary).get(key, 1.0))


func _ct_base() -> float:
	return float(data["rules"].get("ct_base", 100.0))


# ---------- پرس‌وجو ----------

func unit(id: String) -> Dictionary:
	for u in units:
		if u["id"] == id:
			return u
	return {}


func current() -> Dictionary:
	if _current < 0 or _current >= units.size():
		return {}
	return units[_current]


func is_party_turn() -> bool:
	return outcome == Outcome.ONGOING and current().get("side", "") == "party"


func alive(side: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for u in units:
		if u["side"] == side and u["alive"]:
			out.append(u)
	return out


## قصد فعلی دشمن برای نمایش بالای سرش: {id, icon, left} — `left` شمارندهٔ
## نوبت تا اجرا (سند ۰۸ §۴ «آیکن عملش با شمارندهٔ نوبت»).
func intent_of(id: String) -> Dictionary:
	var u := unit(id)
	if u.is_empty() or u["side"] != "enemy" or not u["alive"] or u["intent"] == "":
		return {}
	var it: Dictionary = _intent_def(u)
	return {"id": u["intent"], "icon": it.get("icon", "strike"), "left": u["intent_left"],
		"interrupt": it.get("interrupt", [])}


## نوبت دشمن فعلی واقعاً حمله است؟ (نه گیج، نه در حال شارژ، و قصدش آسیب
## دارد). صحنه فقط آن موقع حلقهٔ دفاع به‌موقع را نشان می‌دهد.
func pending_attack() -> bool:
	var u := current()
	if u.is_empty() or u["side"] != "enemy" or outcome != Outcome.ONGOING:
		return false
	if int(u["stunned"]) > 0 or int(u["intent_left"]) > 0:
		return false
	return float(_intent_def(u).get("damage", 0)) > 0.0


## شناسهٔ ۶ نوبت بعدی (سند ۰۸ §۴). شبیه‌سازی روی رونوشت `ct`؛ کند شدن و
## گیج شدن هم حساب می‌شوند چون روی `ct` اثر دارند، نه روی این تابع.
func preview(n: int = 6) -> Array[String]:
	var out: Array[String] = []
	var ct: Dictionary = {}
	for u in units:
		if u["alive"]:
			ct[u["id"]] = float(u["ct"])
	if _current >= 0 and current()["alive"]:
		out.append(String(current()["id"]))
		ct[current()["id"]] = _ct_base() / float(current()["speed"])
	while out.size() < n and not ct.is_empty():
		var best := ""
		for u in units:
			var id := String(u["id"])
			if ct.has(id) and (best == "" or float(ct[id]) < float(ct[best]) - 0.0001):
				best = id
		var step := float(ct[best])
		for id in ct:
			ct[id] = float(ct[id]) - step
		out.append(best)
		ct[best] = _ct_base() / float(unit(best)["speed"])
	return out


## فرمان‌هایی که یار الان می‌تواند بدهد، با دلیل ممنوعیت برای رابط.
func commands(id: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var u := unit(id)
	if u.is_empty() or u["side"] != "party":
		return out
	out.append({"cmd": "strike", "ok": true})
	for sid in data["party"][u["kind"]].get("skills", []):
		var s: Dictionary = data["skills"][sid]
		var need := String(s.get("needs_flag", ""))
		if need != "" and not bool(flags.get(need, false)):
			continue
		out.append({"cmd": "skill", "skill": sid, "cost": int(s["cost"]),
			"ok": energy >= int(s["cost"])})
	var link: Dictionary = data["skills"]["link"]
	out.append({"cmd": "link", "cost": int(link["cost"]),
		"ok": energy >= int(link["cost"]) and alive("party").size() == 2})
	out.append({"cmd": "guard", "ok": true})
	for iid in items:
		if int(items[iid]) > 0:
			out.append({"cmd": "item", "item": iid, "count": int(items[iid]), "ok": true})
	out.append({"cmd": "flee", "cost": int(data["rules"]["flee_cost"]),
		"ok": can_flee()})
	return out


func can_flee() -> bool:
	return bool(encounter.get("fleeable", true)) \
		and energy >= int(data["rules"]["flee_cost"])


## «عالی» / «خوب» / «بیرون» برای فاصلهٔ زمانی.
func grade(timing: float) -> String:
	var t: Dictionary = data["timing"]
	var w := float(t["assist_window_mult"]) if assist else 1.0
	var a := absf(timing)
	if a <= float(t["perfect_s"]) * w:
		return "perfect"
	if a <= float(t["good_s"]) * w:
		return "good"
	return "miss"


func _strike_mult(g: String) -> float:
	var t: Dictionary = data["timing"]
	match g:
		"perfect": return float(t["perfect_mult"])
		"good": return float(t["good_mult"])
	return float(t["miss_mult"])


# ---------- کنش یار ----------

## یار فعلی کنش می‌کند. `arg` شناسهٔ مهارت یا شیء است، `target` شناسهٔ
## یکا. برمی‌گرداند که کنش پذیرفته شد یا نه؛ کنش ردشده نوبت را نمی‌سوزاند.
func act(cmd: String, arg: String = "", target: String = "", timing: float = NO_PRESS) -> bool:
	if not is_party_turn():
		return false
	var me := current()
	events.clear()
	var ok := false
	match cmd:
		"strike":
			ok = _do_strike(me, target, timing, 1)
		"skill":
			ok = _do_skill(me, arg, target, timing)
		"link":
			ok = _do_link(me, timing)
		"guard":
			me["guard"] = true
			events.append({"type": "guard", "who": me["id"]})
			ok = true
		"item":
			ok = _do_item(me, arg, target)
		"flee":
			if can_flee():
				energy -= int(data["rules"]["flee_cost"])
				outcome = Outcome.FLED
				events.append({"type": "fled"})
				ok = true
	if not ok:
		return false
	_end_turn(me)
	return true


func _enemy_target(target: String) -> Dictionary:
	var t := unit(target)
	if t.is_empty() or t["side"] != "enemy" or not t["alive"]:
		var list := alive("enemy")
		return list[0] if not list.is_empty() else {}
	return t


func _ally_target(target: String, allow_down: bool) -> Dictionary:
	var t := unit(target)
	if t.is_empty() or t["side"] != "party":
		return {}
	if not t["alive"] and not allow_down:
		return {}
	return t


func _do_strike(me: Dictionary, target: String, timing: float, hits: int) -> bool:
	var t := _enemy_target(target)
	if t.is_empty():
		return false
	var g := grade(timing)
	var base := float(data["party"][me["kind"]]["strike"])
	for i in hits:
		if not t["alive"]:
			break
		_hurt_enemy(t, base * _strike_mult(g), g, me["id"])
	if g == "perfect":
		_gain(int(data["energy"]["perfect_gain"]))
	return true


func _do_skill(me: Dictionary, sid: String, target: String, timing: float) -> bool:
	if not data["skills"].has(sid) or not sid in data["party"][me["kind"]].get("skills", []):
		return false
	var s: Dictionary = data["skills"][sid]
	var need := String(s.get("needs_flag", ""))
	if need != "" and not bool(flags.get(need, false)):
		return false
	var cost := int(s["cost"])
	if energy < cost:
		return false
	match String(s["target"]):
		"enemy":
			var t := _enemy_target(target)
			if t.is_empty():
				return false
			energy -= cost
			if s.has("hits"):
				# دش: دو ضربهٔ پشت‌سرهم با همان زمان‌بندی (سند ۰۹ §۳)
				var g := grade(timing)
				var base := float(data["party"][me["kind"]]["strike"])
				for i in int(s["hits"]):
					if t["alive"]:
						_hurt_enemy(t, base * _strike_mult(g), g, me["id"])
			else:
				_try_interrupt(t, sid)
				_hurt_enemy(t, float(s.get("damage", 0)), "skill", me["id"])
		"all_enemies":
			energy -= cost
			for t in alive("enemy"):
				if int(s.get("stun", 0)) > 0:
					t["stunned"] = maxi(int(t["stunned"]), int(s["stun"]))
					events.append({"type": "stun", "who": t["id"]})
				if float(s.get("damage", 0)) > 0.0:
					_hurt_enemy(t, float(s["damage"]), "skill", me["id"])
		"ally":
			var a := _ally_target(target if target != "" else String(me["id"]),
				s.has("heal"))
			if a.is_empty():
				return false
			energy -= cost
			if s.has("heal"):
				_heal(a, int(s["heal"]))
			if s.has("barrier"):
				a["barrier"] = int(a["barrier"]) + int(s["barrier"])
				events.append({"type": "barrier", "who": a["id"], "amount": int(s["barrier"])})
	events.append({"type": "skill", "skill": sid, "who": me["id"], "fx": s.get("fx", "")})
	return true


## «پیوند دو آسمان»: ۱۰ انرژی، هر دو زنده، ۴۰ به همه + شکننده برای همه.
func _do_link(me: Dictionary, _timing: float) -> bool:
	var s: Dictionary = data["skills"]["link"]
	if energy < int(s["cost"]) or alive("party").size() < 2:
		return false
	energy -= int(s["cost"])
	events.append({"type": "link", "who": me["id"]})
	for t in alive("enemy"):
		_hurt_enemy(t, float(s["damage"]), "link", me["id"])
		if t["alive"] and bool(s.get("fragile", false)):
			t["fragile"] = true
	return true


func _do_item(me: Dictionary, iid: String, target: String) -> bool:
	if int(items.get(iid, 0)) <= 0 or not data["items"].has(iid):
		return false
	var it: Dictionary = data["items"][iid]
	if bool(it.get("flee", false)):
		if not bool(encounter.get("fleeable", true)):
			return false
		items[iid] = int(items[iid]) - 1
		outcome = Outcome.FLED
		events.append({"type": "fled", "item": iid})
		return true
	if it.has("heal"):
		var a := _ally_target(target if target != "" else String(me["id"]), true)
		if a.is_empty():
			return false
		_heal(a, int(it["heal"]))
	if it.has("energy"):
		_gain(int(it["energy"]))
	items[iid] = int(items[iid]) - 1
	events.append({"type": "item", "item": iid, "who": me["id"]})
	return true


## قطع کردن (سند ۰۸ §۴): مهارتی که در فهرست `interrupt` قصد فعلی است،
## قصد را می‌شکند — دشمن نوبت بعدش را از دست می‌دهد و تا آن نوبت شکننده
## (×۱٫۵) است. بر پایهٔ **نوع توانایی** است نه تعداد ضربه.
func _try_interrupt(t: Dictionary, sid: String) -> void:
	if t["intent"] == "":
		return
	var it: Dictionary = _intent_def(t)
	if not sid in it.get("interrupt", []):
		return
	events.append({"type": "interrupt", "who": t["id"], "intent": t["intent"], "by": sid})
	t["stunned"] = maxi(int(t["stunned"]), 1)
	t["fragile"] = true
	_next_intent(t)


func _hurt_enemy(t: Dictionary, amount: float, g: String, by: String) -> void:
	var r: Dictionary = data["rules"]
	var mult := 1.0
	if t["fragile"]:
		mult *= float(r["fragile_mult"])
	if float(t["shield"]) > 0.0:
		mult *= 1.0 - float(t["shield"])
	var dmg := maxi(1, int(round(amount * mult)))
	t["hp"] = maxi(0, int(t["hp"]) - dmg)
	events.append({"type": "damage", "who": t["id"], "amount": dmg, "grade": g, "by": by})
	if int(t["hp"]) == 0:
		_kill(t)
	else:
		_check_phase(t)


func _heal(a: Dictionary, amount: int) -> void:
	var before := int(a["hp"])
	a["hp"] = mini(int(a["max_hp"]), int(a["hp"]) + amount)
	if not a["alive"] and int(a["hp"]) > 0:
		a["alive"] = true
		a["ct"] = _ct_base() / float(a["speed"])
		events.append({"type": "revive", "who": a["id"]})
	events.append({"type": "heal", "who": a["id"], "amount": int(a["hp"]) - before})


func _gain(n: int) -> void:
	var cap := int(data["energy"]["max"])
	energy = mini(cap, energy + n)


func _kill(u: Dictionary) -> void:
	u["alive"] = false
	u["hp"] = 0
	u["intent"] = ""
	events.append({"type": "down" if u["side"] == "party" else "defeat", "who": u["id"]})


# ---------- کنش دشمن ----------

## دشمن فعلی کنش می‌کند. `defense` فاصلهٔ فشار دفاع از لحظهٔ برخورد است
## (سند ۰۸ §۴: «لحظهٔ برخورد را می‌زنی ⇒ −۵۰٪، عالی −۷۰٪»).
func run_enemy(defense: float = NO_PRESS) -> bool:
	if outcome != Outcome.ONGOING or current().get("side", "") != "enemy":
		return false
	var me := current()
	events.clear()
	# نوبت شروع شد: سپر دور قبل تمام است
	me["shield"] = 0.0
	if int(me["stunned"]) > 0:
		me["stunned"] = int(me["stunned"]) - 1
		# نوبتِ ازدست‌رفته شکنندگی را هم تمام می‌کند
		me["fragile"] = false
		events.append({"type": "skip", "who": me["id"]})
		_end_turn(me)
		return true
	me["fragile"] = false
	if int(me["intent_left"]) > 0:
		me["intent_left"] = int(me["intent_left"]) - 1
		events.append({"type": "charge", "who": me["id"], "intent": me["intent"],
			"left": me["intent_left"]})
		_end_turn(me)
		return true
	_execute_intent(me, defense)
	if me["alive"]:
		_next_intent(me)
	_end_turn(me)
	return true


func _execute_intent(me: Dictionary, defense: float) -> void:
	var it: Dictionary = _intent_def(me)
	events.append({"type": "intent", "who": me["id"], "intent": me["intent"],
		"icon": it.get("icon", "")})
	match String(it.get("target", "one")):
		"one":
			var t := _pick_party_target()
			if t.is_empty():
				return
			_apply_to_party(t, it, defense)
		"all":
			for t in alive("party"):
				_apply_to_party(t, it, defense)
		"self":
			if float(it.get("shield", 0.0)) > 0.0:
				me["shield"] = float(it["shield"])
				# سپر «یک دور»: تا نوبت بعد خودش، که `run_enemy` صفرش می‌کند.
				# پس نباید همین‌جا با `_end_turn` پاک شود.
				events.append({"type": "enemy_shield", "who": me["id"]})
			if it.has("summon"):
				_summon(me, it)
	if bool(it.get("self_destruct", false)):
		_kill(me)


## اگر کسی علامت اسکن دارد، هدف اوست (پهپاد: اسکن ← شیرجه)؛ وگرنه تصادفی.
func _pick_party_target() -> Dictionary:
	var list := alive("party")
	if list.is_empty():
		return {}
	for u in list:
		if u["marked"]:
			return u
	return list[_rng.randi_range(0, list.size() - 1)]


func _apply_to_party(t: Dictionary, it: Dictionary, defense: float) -> void:
	if bool(it.get("mark", false)):
		t["marked"] = true
		events.append({"type": "mark", "who": t["id"]})
	if bool(it.get("slow", false)):
		t["slowed"] = true
		t["ct"] = float(t["ct"]) + _ct_base() / float(t["speed"])
		events.append({"type": "slow", "who": t["id"]})
	var dmg := float(it.get("damage", 0)) * _bal("enemy_damage_mult")
	if dmg <= 0.0:
		return
	var r: Dictionary = data["rules"]
	var tm: Dictionary = data["timing"]
	if t["marked"]:
		dmg *= float(r["mark_mult"])
		t["marked"] = false
	# کاهش‌ها ضرب می‌شوند نه جمع، تا هرگز به ۱۰۰٪ نرسند
	var keep := 1.0
	var g := grade(defense)
	if g == "perfect":
		keep *= 1.0 - float(tm["guard_perfect_reduce"])
	elif g == "good":
		keep *= 1.0 - float(tm["guard_good_reduce"])
	if t["guard"]:
		keep *= 1.0 - float(r["command_guard_reduce"])
	var amount := maxi(1, int(round(dmg * keep)))
	var absorbed := mini(int(t["barrier"]), amount)
	t["barrier"] = int(t["barrier"]) - absorbed
	amount -= absorbed
	t["hp"] = maxi(0, int(t["hp"]) - amount)
	events.append({"type": "damage", "who": t["id"], "amount": amount, "grade": g,
		"absorbed": absorbed, "defense": g})
	if int(t["hp"]) == 0:
		_kill(t)


func _summon(me: Dictionary, it: Dictionary) -> void:
	var kind := String(it["summon"])
	var live := 0
	for u in alive("enemy"):
		if u["kind"] == kind:
			live += 1
	if live >= int(it.get("max", 2)) or alive("enemy").size() >= 4:
		events.append({"type": "summon_fail", "who": me["id"]})
		return
	_summoned += 1
	var u := _add_enemy(kind, "%s_s%d" % [kind, _summoned])
	events.append({"type": "summon", "who": me["id"], "new": u["id"]})


func _intent_def(u: Dictionary) -> Dictionary:
	return data["enemies"][u["kind"]]["intents"].get(u["intent"], {})


func _pattern(u: Dictionary) -> Array:
	var e: Dictionary = data["enemies"][u["kind"]]
	if e.has("phases"):
		return (e["phases"][int(u["phase"])] as Dictionary).get("pattern", [])
	return e.get("pattern", [])


func _next_intent(u: Dictionary) -> void:
	var pat := _pattern(u)
	var iid := String(pat[int(u["step"]) % pat.size()])
	u["step"] = int(u["step"]) + 1
	u["intent"] = iid
	u["intent_left"] = int(_intent_def(u).get("windup", 0))


## فاز تازه وقتی جان از آستانه گذشت (سند ۰۹ §۴: «فاز ۲ در ۵۰٪ جان»).
## قصد فعلی عوض می‌شود تا بازیکن همان لحظه تغییر را ببیند.
func _check_phase(u: Dictionary) -> void:
	var e: Dictionary = data["enemies"][u["kind"]]
	if not e.has("phases"):
		return
	var phases: Array = e["phases"]
	var pct := 100.0 * float(u["hp"]) / float(u["max_hp"])
	var want := int(u["phase"])
	for i in phases.size():
		if pct < float((phases[i] as Dictionary).get("below_pct", 100)) and i > want:
			want = i
	if want != int(u["phase"]):
		u["phase"] = want
		u["step"] = 0
		_next_intent(u)
		events.append({"type": "phase", "who": u["id"], "phase": want})


# ---------- گردش نوبت ----------

func _end_turn(me: Dictionary) -> void:
	turn += 1
	if me["side"] == "party":
		# سپرِ فرمان تا نوبت بعد خود یار است، پس اینجا پاک نمی‌شود؛
		# در `_advance` وقتی دوباره نوبتش شد پاک می‌شود.
		pass
	me["ct"] = _ct_base() / float(me["speed"])
	_update_outcome()
	if outcome == Outcome.ONGOING:
		_advance()


func _update_outcome() -> void:
	if outcome != Outcome.ONGOING:
		return
	if alive("enemy").is_empty():
		outcome = Outcome.WIN
		events.append({"type": "win"})
	elif alive("party").is_empty():
		outcome = Outcome.LOSE
		events.append({"type": "lose"})


func _advance() -> void:
	var best := -1
	for i in units.size():
		var u: Dictionary = units[i]
		if not u["alive"]:
			continue
		if best < 0 or float(u["ct"]) < float(units[best]["ct"]) - 0.0001:
			best = i
	if best < 0:
		_current = -1
		return
	var step := float(units[best]["ct"])
	for u in units:
		if u["alive"]:
			u["ct"] = float(u["ct"]) - step
	_current = best
	var u: Dictionary = units[best]
	if u["side"] == "party":
		u["guard"] = false
		u["slowed"] = false


# ---------- ذخیره و برگشت ----------

func _snapshot() -> Dictionary:
	var us: Array = []
	for u in units:
		us.append(u.duplicate(true))
	return {"units": us, "energy": energy, "items": items.duplicate(),
		"turn": turn, "summoned": _summoned, "outcome": outcome}


func _restore(s: Dictionary) -> void:
	units.clear()
	for u in s["units"]:
		units.append((u as Dictionary).duplicate(true))
	energy = int(s["energy"])
	items = (s["items"] as Dictionary).duplicate()
	turn = int(s["turn"])
	_summoned = int(s["summoned"])
	outcome = s["outcome"]


## وضعیت قابل‌مقایسه برای آزمون «شروع دوباره بدون جریمه».
func state_signature() -> String:
	return JSON.stringify(_snapshot())


## پاداش نبرد برده‌شده؛ برای باخت و فرار خالی است.
func reward() -> Dictionary:
	if outcome != Outcome.WIN:
		return {}
	return encounter.get("reward", {})
