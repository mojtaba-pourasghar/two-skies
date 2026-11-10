## جارو کردن ضریب آسیب فرمانده — گام ۵۴ بند ۱
##
##   godot --headless res://tools/tests/sim_balance.tscn
##
## معیار مدیر: بازیکن دقیق ۲۵ تا ۴۰٪ جان از دست بدهد و نبرد ۱۲۰ تا ۱۸۰
## ثانیه باشد؛ ناشی و فقط‌سپر ببازند. فقط **ضریب آسیب فرمانده** تنظیم
## می‌شود، چون لیزر قطع‌نشدنی و هزینهٔ ۳ تصمیم مدیر است نه عدد قابل‌تنظیم.
extends Node

const RUNS := 60
const SWEEP := [1.0, 1.25, 1.5, 1.75, 2.0, 2.5]


func _ready() -> void:
	print("— جارو کردن ضریب آسیب فرمانده (%d اجرا) —" % RUNS)
	print("ضریب | دقیق می‌برد | آسیب دقیق | زمان | ناشی می‌بازد | فقط‌سپر می‌بازد")
	for m in SWEEP:
		# **override کل بلوک را جای می‌گذارد**، پس `enemy_hp_mult` هم
		# باید همراهش برود؛ وگرنه فرمانده جان سند را می‌گیرد و نبرد
		# ۶۸ ثانیه می‌شود — در اولین جارو همین شد و هر شش ردیف یک عدد داد.
		var bal := {"enemy_hp_mult": 5.0, "enemy_damage_mult": m}
		var k := BattleSim.summary("ch1_a3_commander", "skilled", RUNS, bal)
		var c := BattleSim.summary("ch1_a3_commander", "clumsy", RUNS, bal)
		var g := BattleSim.summary("ch1_a3_commander", "guard_only", RUNS, bal)
		var ok_taken: bool = k["median_taken"] >= 0.25 and k["median_taken"] <= 0.40
		var ok_time: bool = k["median_s"] >= 120.0 and k["median_s"] <= 180.0
		print("%.2f | %3.0f٪ | %3.0f٪ %s | %3.0fث %s | %3.0f٪ | %3.0f٪   %s"
			% [m, k["win_rate"] * 100.0, k["median_taken"] * 100.0,
				"✔" if ok_taken else " ", k["median_s"], "✔" if ok_time else " ",
				c["lose_rate"] * 100.0, g["lose_rate"] * 100.0,
				"◄ هر دو شرط" if (ok_taken and ok_time) else ""])
	get_tree().quit(0)
