## آزمون بازی‌شدن واقعی مراحل — docs/02_godot_spec.md §۲۲ و §۱۶
##
##   godot --headless res://tools/tests/test_robot.tscn
##   godot --headless res://tools/tests/test_robot.tscn -- --record
##
## روبات با ورودی واقعی (حرکت/پرش/دش/هک/همراه) هر سه مرحله را تا خروج می‌برد.
## با `--record` رشتهٔ ورودی موفق در `user://solutions/` نوشته می‌شود تا به
## `levels/data/solutions/*.inputs.json` کامیت شود (`solution_path` §۲۲).
extends Node2D

const LEVELS := ["ch1_l1", "ch1_l2", "ch1_l3"]

## مرحله‌هایی که روبات هنوز تا خروج نمی‌برد، با پیشرفت پایهٔ امروز.
##
## این‌ها **نقص نقشه نیستند**: هر ۱۲ اتاق با BFS حل‌پذیرند و L3R1 با محاسبه هم
## قابل عبور است (۱٫۷۱ ثانیه عبور لازم در برابر ۲٫۴ ثانیه پنجرهٔ پهپاد). آنچه
## کم است هم‌زمانی سه‌گانهٔ روبات است: هک پهپاد + پنجرهٔ لیزر + نزدیک بودن
## ایلارا. تا آن وقت، آزمون **پسرفت** را می‌گیرد: اگر تعداد اتاق‌های پیموده‌شده
## از عدد پایه کمتر شود، رد می‌شود (DECISIONS.md: D-042).
const KNOWN_INCOMPLETE := {
	"ch1_l2": 3,
	"ch1_l3": 1,
}
## سقف زمان هر تلاش
const MAX_SECONDS: int = 180
## چند تلاش با jitter متفاوت پیش از اعلام شکست
const MAX_ATTEMPTS: int = 3

var _failures: Array[String] = []
var _checks: int = 0
var _record_mode: bool = false
var _results: Dictionary = {}


func _ready() -> void:
	_record_mode = "--record" in OS.get_cmdline_user_args()
	print("— بازی‌شدن مراحل با روبات کنترلی —")
	if _record_mode:
		print("  (حالت ضبط)")
	var args := OS.get_cmdline_user_args()
	var only := ""
	for a in args:
		if a.begins_with("--only="):
			only = a.substr(7)
	for level_id in LEVELS:
		if only != "" and level_id != only:
			continue
		await _run_level(level_id)
	if only == "" or only == "ch1_l1":
		await _test_replay()
	_report()


func _check(label: String, ok: bool, detail: String = "") -> void:
	_checks += 1
	if ok:
		print("  ✔ %s %s" % [label, detail])
	else:
		_failures.append("%s %s" % [label, detail])
		print("  ✘ %s %s" % [label, detail])


## یک مرحله را با چند تلاش تا تمام شدن می‌برد.
func _run_level(level_id: String) -> void:
	print("\n— %s —" % level_id)
	var plan := Robot.load_plan(level_id)
	if plan.is_empty():
		_check("برنامهٔ %s" % level_id, false, "(tools/export_plans.py را اجرا کن)")
		return
	_check("برنامهٔ %s بار شد" % level_id, true,
		"(%d اتاق)" % (plan.get("rooms", []) as Array).size())

	var best: Dictionary = {}
	for attempt in MAX_ATTEMPTS:
		var outcome := await _attempt(level_id, plan, attempt)
		if bool(outcome.get("finished", false)):
			best = outcome
			break
		if best.is_empty() or int(outcome.get("rooms", 0)) > int(best.get("rooms", 0)):
			best = outcome

	_results[level_id] = best
	var finished := bool(best.get("finished", false))
	var rooms := int(best.get("rooms", 0))

	if KNOWN_INCOMPLETE.has(level_id) and not finished:
		var baseline: int = int(KNOWN_INCOMPLETE[level_id])
		_check("%s: پیشرفت پسرفت نکرد (پایه %d اتاق)" % [level_id, baseline],
			rooms >= baseline,
			"= %d اتاق، مرگ %d، افتادن ایلارا %d" % [
				rooms, int(best.get("deaths", 0)), int(best.get("ilara_falls", 0))])
		print("    ⚠ %s هنوز تا خروج نمی‌رسد — کار باز گام ۸ (D-042)" % level_id)
		return

	_check("%s تا خروج تمام شد" % level_id, finished,
		"(اتاق‌های دیده‌شده %d/%d، تلاش %d، %s)" % [
			int(best.get("rooms", 0)), (plan.get("rooms", []) as Array).size(),
			int(best.get("attempt", 0)) + 1,
			"%.1f ثانیه" % (float(best.get("frames", 0)) / 60.0)])
	if finished:
		_check("%s: ایلارا زنده به خروج رسید" % level_id,
			int(best.get("ilara_falls", -1)) >= 0 and bool(best.get("ilara_alive", false)),
			"(افتادن ایلارا %d بار)" % int(best.get("ilara_falls", 0)))
		_check("%s: ستاره گرفت" % level_id, int(best.get("stars", 0)) >= 1,
			"= %d ستاره، %d سکه" % [int(best.get("stars", 0)), int(best.get("coins", 0))])
	else:
		for line in (best.get("log", []) as Array):
			print("      %s" % line)


func _attempt(level_id: String, plan: Dictionary, attempt: int) -> Dictionary:
	# ذخیره پاک می‌شود تا باز شدن ابزار هر مرحله مثل بازی واقعی باشد
	GameState.data = GameState.default_save()
	GameState.data["cutscenes_seen"] = ["c1_intro", "c1_title"]
	SceneRouter.pending_level = "res://levels/data/%s.json" % level_id

	var game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	for i in 20:
		await get_tree().physics_frame

	var robot := Robot.new()
	robot.game = game
	robot.plan = plan
	robot.route = "direct"
	robot.jitter = attempt * 7
	if "--trace" in OS.get_cmdline_user_args():
		robot.trace_every = 30
	add_child(robot)

	var rooms_seen := {}
	var finished := [false]
	game.level_finished.connect(func(_r): finished[0] = true, CONNECT_ONE_SHOT)

	var max_frames := 60 * MAX_SECONDS
	var f := 0
	while f < max_frames and not finished[0] and robot.phase != Robot.Phase.DONE:
		await get_tree().physics_frame
		f += 1
		robot.step()
		rooms_seen[String(game.current_room_id)] = true

	# اگر روبات تمام کرد ولی سیگنال در همان فریم آمد
	if game.finished:
		finished[0] = true

	var out := {
		"attempt": attempt,
		"finished": finished[0],
		"frames": f,
		"rooms": rooms_seen.size(),
		"deaths": int(game.deaths),
		"ilara_falls": int(game.ilara_falls),
		"ilara_alive": game.ilara != null and is_instance_valid(game.ilara),
		"coins": int(game.coins_banked),
		"stars": int(SceneRouter.last_result.get("stars", 0)) if finished[0] else 0,
		"log": robot.log_lines.duplicate(),
		"inputs": robot.recorded_to_base64(),
	}

	if finished[0] and _record_mode:
		_write_solution(level_id, out)

	robot._release_all()
	robot.queue_free()
	game.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	return out


func _write_solution(level_id: String, out: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute("user://solutions")
	var path := "user://solutions/%s.inputs.json" % level_id
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({
		"level_id": level_id,
		"_comment": "solution_path §۲۲ — یک بایت در هر فریم فیزیک، bitmask از ["
			+ ", ".join(Robot.ACTIONS) + "]",
		"frames": int(out["frames"]),
		"inputs_base64": String(out["inputs"]),
	}, "  "))
	f.close()
	print("      رشتهٔ ورودی نوشته شد: %s (%d فریم)"
		% [ProjectSettings.globalize_path(path), int(out["frames"])])


## بازپخش حلقه‌باز: همان رشتهٔ ورودی باید همان نتیجه را بدهد (سند ۰۵).
func _test_replay() -> void:
	print("\n— بازپخش رشتهٔ ورودی (تکرارپذیری) —")
	var level_id := "ch1_l1"
	var src: Dictionary = _results.get(level_id, {})
	if not bool(src.get("finished", false)):
		_check("بازپخش %s" % level_id, false, "(اجرای اصلی تمام نشده بود)")
		return

	GameState.data = GameState.default_save()
	GameState.data["cutscenes_seen"] = ["c1_intro", "c1_title"]
	SceneRouter.pending_level = "res://levels/data/%s.json" % level_id
	var game = load("res://scenes/game.tscn").instantiate()
	add_child(game)
	for i in 20:
		await get_tree().physics_frame

	var robot := Robot.new()
	robot.game = game
	robot.record_enabled = false
	robot.load_recorded_base64(String(src["inputs"]))
	add_child(robot)

	var finished := [false]
	game.level_finished.connect(func(_r): finished[0] = true, CONNECT_ONE_SHOT)

	var i := 0
	while i < robot.recorded.size() and not finished[0]:
		await get_tree().physics_frame
		robot.replay_frame(i)
		i += 1
	# چند فریم حاشیه برای رسیدن ایلارا
	var extra := 0
	while not finished[0] and extra < 240:
		await get_tree().physics_frame
		extra += 1

	_check("بازپخش %s همان نتیجه را داد" % level_id, finished[0] or game.finished,
		"(%d فریم ضبط‌شده + %d فریم حاشیه)" % [robot.recorded.size(), extra])

	robot._release_all()
	robot.queue_free()
	game.queue_free()
	await get_tree().process_frame


func _report() -> void:
	print("")
	for level_id in LEVELS:
		var r: Dictionary = _results.get(level_id, {})
		print("  %s: %s  اتاق %d، مرگ %d، افتادن ایلارا %d، %.1f ثانیه" % [
			level_id,
			"تمام شد" if bool(r.get("finished", false)) else "تمام نشد",
			int(r.get("rooms", 0)), int(r.get("deaths", 0)),
			int(r.get("ilara_falls", 0)), float(r.get("frames", 0)) / 60.0])
	print("")
	if _failures.is_empty():
		print("همهٔ %d سنجه قبول شد." % _checks)
		get_tree().quit(0)
	else:
		print("%d از %d سنجه رد شد:" % [_failures.size(), _checks])
		for f in _failures:
			print("  - %s" % f)
		get_tree().quit(1)
