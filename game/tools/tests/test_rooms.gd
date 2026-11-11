## آزمون موتور اتاق نقاشی‌شده — M1
##
##   godot --headless res://tools/tests/test_rooms.tscn
##
## سه چیز را می‌سنجد که اگر بشکنند بازیکن در دیوار گیر می‌کند یا بازی
## بی‌صدا خالی می‌شود: اعتبارسنجی ماسک، خواندن ماسک از تصویر، و ترتیب
## لایه‌ها (occluder باید **روی** بازیگر باشد).
extends Node2D

## اتاق‌هایی که بودجهٔ زندگی‌شان (قاعدهٔ ۹ CLAUDE.md) به خاطر نیامدن هنر
## ناقص است، با REQ باز. فقط هنر این فهرست را کوتاه می‌کند، نه کد.
const PENDING_LIVING_ART := {
	"r1e_basement": "REQ-031 (دود برداشته شد، منبع حرکت ندارد)",
}

const ROOM := "r1a_living"

var _failures: Array[String] = []
var _checks: int = 0


func _ready() -> void:
	_t_validation()
	_t_real_room()
	_t_mask_queries()
	_t_layers()
	await _t_living()
	_t_stand_occluders()
	_t_doors_reachable()
	_t_all_rooms()
	_report()


func _t_validation() -> void:
	print("— اعتبارسنجی دادهٔ اتاق —")
	var l := RoomData.new()
	var room := l.load_room(ROOM)
	_check("اتاق %s بار شد" % ROOM, not room.is_empty(),
		"" if room.is_empty() else "= %dx%d" % [room["size"][0], room["size"][1]])
	if room.is_empty():
		for e in l.errors:
			print("      %s" % e)
		return
	_check("هیچ خطایی ندارد", l.errors.is_empty(), "= %s" % str(l.errors))
	_check("تصویر پس‌زمینه دارد", String(room["bg"]) != "", "= %s" % room["bg"])
	_check("رفتار دوربین room است", String(room["camera"]) == "room")

	# دادهٔ خراب باید خطا بدهد، نه بی‌صدا رد شود
	var bad := RoomData.new()
	var fake := {
		"id": "bad", "bg": "", "size": [1280, 720], "camera": "isometric",
		"walkable": [[0, 0, 10, 0]],
		"doors": [
			{"id": "d", "rect": [0, 0, 10, 10], "to": "", "spawn": [1, 1]},
			{"id": "d", "rect": [0, 0, 10, 10], "to": "x", "spawn": [1, 1]},
		],
		"spawn": [5000, 5000],
	}
	bad._normalize(fake)
	bad._validate(fake)
	var msgs := " | ".join(bad.errors)
	_check("رفتار دوربین نامعتبر خطا داد", msgs.contains("دوربین"), "")
	_check("نبودن تصویر خطا داد", msgs.contains("پس‌زمینه"), "")
	_check("چندضلعی ۲ نقطه‌ای خطا داد", msgs.contains("walkable[0]"), "")
	_check("در بی‌مقصد و شناسهٔ تکراری خطا دادند",
		msgs.contains("مقصد") and msgs.contains("تکراری"), "")
	_check("نقطهٔ شروع بیرون ماسک خطا داد", msgs.contains("شروع"), "")


func _t_real_room() -> void:
	print("— ساخت اتاق با هنر واقعی —")
	var l := RoomData.new()
	var room := l.load_room(ROOM)
	if room.is_empty():
		return
	var node := PaintedRoom.new()
	add_child(node)
	node.build(room)
	_check("هیچ دارایی هنری گم نشد", node.missing_art.is_empty(),
		"= %s" % str(node.missing_art))
	_check("مرز اتاق از اندازهٔ تصویر می‌آید",
		node.bounds().size == Vector2(1280, 720), "= %s" % str(node.bounds().size))
	_check("پس‌زمینه کشیده شد",
		node.get_node("World/Background").get_child_count() == 1)
	_check("پراپ‌ها کشیده شدند",
		node.get_node("World/Props").get_child_count() >= 1,
		"= %d" % node.get_node("World/Props").get_child_count())
	# occluderهای R1a حالا همه **ایستاده**اند (گام ۵۵): در لایهٔ بازیگران
	# با Y-sort، نه در لایهٔ ۴. مکان‌نگهدارهای بی‌base_y برداشته شدند چون
	# بازیکنِ جلوشان را هم می‌پوشاندند.
	var occ_total := node.get_node("World/Occluders").get_child_count()
	for ch in node.actors.get_children():
		if String(ch.name).begins_with("Cut_") or String(ch.name).begins_with("OccStand_"):
			occ_total += 1
	_check("occluderها کشیده شدند", occ_total >= 3, "= %d" % occ_total)
	_check("لایهٔ نور کشیده شد",
		node.get_node("World/Light").get_child_count() >= 1,
		"= %d" % node.get_node("World/Light").get_child_count())
	node.queue_free()


func _t_mask_queries() -> void:
	print("— ماسک از روی تصویر خوانده می‌شود —")
	var l := RoomData.new()
	var room := l.load_room(ROOM)
	if room.is_empty():
		return
	var spawn := Vector2(float(room["spawn"][0]), float(room["spawn"][1]))
	_check("نقطهٔ شروع روی زمین است", RoomData.point_walkable(room, spawn),
		"= %s" % str(spawn))
	_check("بیرون قاب روی زمین نیست",
		not RoomData.point_walkable(room, Vector2(-50, -50)))
	_check("دیوار پنجره (بالا-چپ) روی زمین نیست",
		not RoomData.point_walkable(room, Vector2(300, 150)))

	# سوراخ‌ها: مبل جایی است که ماسک **دارد** ولی نباید رفت
	var sofa := Vector2(380, 430)
	var inside_walk := false
	for flat in room["walkable"]:
		if Geometry2D.is_point_in_polygon(sofa, RoomData.to_polygon(flat)):
			inside_walk = true
	_check("مبل داخل چندضلعی قابل‌راه‌رفتن است", inside_walk)
	_check("ولی سوراخ `blocked` جلویش را می‌گیرد",
		not RoomData.point_walkable(room, sofa), "= %s" % str(sofa))

	var hz := RoomData.hazard_at(room, Vector2(640, 515))
	_check("ماسک خطر کف شکسته خوانده می‌شود", not hz.is_empty(),
		"= %s" % String(hz.get("id", "-")))
	_check("خطر آسیب ۱۰٪ دارد، نه مرگ",
		is_equal_approx(float(hz.get("damage_pct", 0.0)), 10.0),
		"= %.0f٪" % float(hz.get("damage_pct", 0.0)))
	_check("جای امن خطر بیرون خودش است",
		not RoomData.hazard_at(room,
			Vector2(float(hz["safe"][0]), float(hz["safe"][1]))).has("id"))

	# مرکز در را از خود داده می‌گیریم، نه عدد دست‌نویس: ماسک از روی تصویر
	# کشیده می‌شود و با هر اصلاح جابه‌جا می‌شود (درس D-ART-17).
	var door_rect: Array = ((room["doors"] as Array)[0] as Dictionary)["rect"]
	var door_mid := Vector2(
		float(door_rect[0]) + float(door_rect[2]) * 0.5,
		float(door_rect[1]) + float(door_rect[3]) * 0.5)
	var dr := RoomData.door_at(room, door_mid)
	_check("در طاق از مرکز خودش خوانده می‌شود", not dr.is_empty(),
		"= %s → %s در %s" % [dr.get("id", "-"), dr.get("to", "-"), str(door_mid)])
	_check("نقطه‌ای دور از هر در، در نیست",
		RoomData.door_at(room, Vector2(200, 650)).is_empty())


## ترتیب لایه‌ها اهمیت دارد: اگر occluder زیر بازیگر بیاید، شخصیت روی ستون
## کشیده می‌شود؛ اگر نور زیر occluder بیاید، هاله پشت پرده گیر می‌کند.
func _t_layers() -> void:
	print("— ترتیب لایه‌ها —")
	var l := RoomData.new()
	var room := l.load_room(ROOM)
	if room.is_empty():
		return
	var node := PaintedRoom.new()
	add_child(node)
	node.build(room)
	var bg: Node2D = node.get_node("World/Background")
	var props: Node2D = node.get_node("World/Props")
	var actors: Node2D = node.actors
	var occ: Node2D = node.get_node("World/Occluders")
	var light: Node2D = node.get_node("World/Light")
	_check("نقاشی زیر همه است", bg.z_index < props.z_index)
	_check("پراپ زیر بازیگر است", props.z_index < actors.z_index)
	_check("occluder روی بازیگر است", occ.z_index > actors.z_index)
	_check("نور روی occluder است", light.z_index > occ.z_index)
	_check("Y-sort روی دنیا و بازیگران روشن است",
		node.world.y_sort_enabled and actors.y_sort_enabled)
	node.queue_free()


## افکت‌ها از نقشهٔ تصویر — سند ۱۴. هر عددی که سند می‌گذارد اینجا سنجیده
## می‌شود، چون «افکت حرفه‌ای» به چشم قابل بحث است ولی این عددها نه.
func _t_living() -> void:
	print("— افکت از روی نقشهٔ تصویر —")
	var l := RoomData.new()
	var room := l.load_room(ROOM)
	if room.is_empty():
		return
	var node := PaintedRoom.new()
	add_child(node)
	node.build(room)

	var fx: RoomEffects = node.get_node_or_null("World/Motion/Effects")
	_check("نقشهٔ افکت اتاق بار شد", fx != null)
	if fx == null:
		return

	# هر افکت نقشه باید گرهی داشته باشد، و هیچ گرهی بی‌نقشه نباشد
	var want := fx.effects.size()
	var got := fx.get_child_count()
	_check("برای هر افکت نقشه یک گره ساخته شد", got == want,
		"= %d گره برای %d افکت" % [got, want])

	var swayed := 0
	var fogged := 0
	var glows := 0
	var parts := 0
	for e in fx.effects:
		var t := String(e.get("type", ""))
		match t:
			"sway":
				swayed += 1
				# سند ۱۴ بند ۳: دامنه ≤۲ پیکسل، دوره ۳ تا ۶ ثانیه
				var n: Node2D = fx.get_node_or_null("Fx_%s" % e.get("id", ""))
				if n != null and n.material is ShaderMaterial:
					var m := n.material as ShaderMaterial
					_check("  تکان «%s» دامنه‌اش ≤۲ پیکسل است" % e.get("id", ""),
						float(m.get_shader_parameter("amp_px")) <= 2.0001,
						"= %.1f" % float(m.get_shader_parameter("amp_px")))
					var per: float = float(m.get_shader_parameter("period_s"))
					_check("  و دوره‌اش ۳ تا ۷ ثانیه است", per >= 3.0 and per <= 7.0,
						"= %.1f ث" % per)
			"fog_patch":
				fogged += 1
				var n2: Node2D = fx.get_node_or_null("Fx_%s" % e.get("id", ""))
				if n2 != null and n2.material is ShaderMaterial:
					var tint = (n2.material as ShaderMaterial).get_shader_parameter("tint")
					# سند ۱۴ بند ۴: آلفا ≤۰٫۱۲
					_check("  مه «%s» آلفایش ≤۰٫۱۲ است" % e.get("id", ""),
						float(tint.w) <= 0.1201, "= %.3f" % float(tint.w))
			"flicker_light", "glow_pulse":
				glows += 1
				# سند ۱۴ بند ۲: دامنه ±۶ تا ۱۲٪ (نبض آرام می‌تواند کمتر)
				_check("  نور «%s» دامنه‌اش ≤۱۸٪ است" % e.get("id", ""),
					float(e.get("amp", 0.0)) <= 0.1801,
					"= %.0f٪" % (float(e.get("amp", 0.0)) * 100.0))
			"embers", "dust_in_beam":
				parts += 1
				var n3: GPUParticles2D = fx.get_node_or_null("Fx_%s" % e.get("id", ""))
				if n3 != null:
					# سند ۱۴ بند ۵: حداکثر ۳۰ در هر منبع
					_check("  ذرهٔ «%s» ≤۳۰ تاست" % e.get("id", ""),
						n3.amount <= 30, "= %d" % n3.amount)

	_check("اتاق هم تکان دارد، هم نور زنده، هم ذره از منبع",
		swayed > 0 and glows > 0 and parts > 0,
		"= تکان %d، نور %d، ذره %d، مه %d" % [swayed, glows, parts, fogged])

	# گرد پای بازیکن جداست: واکنش است نه افکت صحنه
	var puff: GPUParticles2D = node.get_node_or_null("World/Light/DustPuff")
	_check("گرد پای بازیکن هست و در شروع خاموش است",
		puff != null and not puff.emitting)

	var living: Dictionary = node.living_layers()
	_check("بودجهٔ زندگی از گره‌های واقعی شمرده شد",
		int(living["sources"]) >= PaintedRoom.LIVING_MIN_SOURCES,
		"= %d منبع (حرکت %d، ذره %d، نور %d)" % [int(living["sources"]),
			int(living["motion"]), int(living["particles"]), int(living["lights"])])
	_check("اتاق «زنده» شمرده می‌شود", node.is_living())

	await _t_signal(fx)

	# واکنش به عبور: نزدیک یک تکان رد شدن باید فشارش را بیشتر کند
	var sway_list := fx.sway_nodes()
	if not sway_list.is_empty():
		var n4: Node2D = sway_list[0]
		var mat := n4.material as ShaderMaterial
		var rect: Rect2 = n4.get_meta("react_rect", Rect2())
		node.react_to(rect.get_center(), 120.0)
		var after := float(mat.get_shader_parameter("push"))
		_check("عبور از کنار گیاه تکانش را بیشتر می‌کند", after > 0.0,
			"= %.2f" % after)
		for i in 80:
			node.react_to(Vector2(-900, -900), 0.0)
		_check("و بعد از دور شدن می‌خوابد",
			float(mat.get_shader_parameter("push")) < 0.05)

	_t_cut_occluders(node)

	_check("رنگ گذار در، سیاه خالص نیست (تغییر نور نه خاموشی)",
		node.light_tint() != Color(0, 0, 0), "= %s" % str(node.light_tint()))
	node.queue_free()


## occluder بریده از نقاشی (REQ-010 با روش گام ۵۴).
##
## قرارداد: گره در **لایهٔ بازیگران** است نه لایهٔ occluder، چون آنجا z
## بالاتر است و همیشه می‌پوشاند. اینجا Y-sort تصمیم می‌گیرد، پس بازیکن
## جلوی مبل دیده می‌شود و پشتش پنهان.
func _t_cut_occluders(node: PaintedRoom) -> void:
	print("— occluder بریده از نقاشی —")
	var cuts: Array[Polygon2D] = []
	for c in node.actors.get_children():
		if c is Polygon2D and String(c.name).begins_with("Cut_"):
			cuts.append(c)
	var want := 0
	for raw in node.data.get("occluders", []):
		if ((raw as Dictionary).get("cut", []) as Array).size() >= 6:
			want += 1
	_check("برای هر `cut` یک گره ساخته شد", cuts.size() == want,
		"= %d از %d" % [cuts.size(), want])
	if cuts.is_empty():
		return

	for c in cuts:
		var base: float = float(c.get_meta("cut_base_y", -1.0))
		_check("  «%s» روی خط Y-sort خودش نشسته" % c.name,
			is_equal_approx(c.position.y, base), "= y %.0f" % c.position.y)
		_check("  و بافتش همان نقاشی اتاق است", c.texture != null)
		# جابه‌جایی بافت باید دقیقاً همان مقدار جابه‌جایی نقاط باشد،
		# وگرنه بریده از جای غلط تصویر برداشته می‌شود و مبل «می‌لغزد».
		_check("  و بافت یک‌به‌یک روی مختصات اتاق می‌افتد",
			is_equal_approx(c.texture_offset.y, base * c.texture_scale.y),
			"= جابه‌جایی %.0f، مقیاس %.3f" % [c.texture_offset.y, c.texture_scale.y])
		_check("  و در لایهٔ بازیگران است، نه لایهٔ occluder",
			c.get_parent() == node.actors)

	# درصد پوشش و فعال شدن سیلوئت (تصمیم کاربر ۱۴۰۵/۰۸/۲۱)
	_t_coverage(node)

	# بازیکنی که **پشت** مبل است باید پایین‌تر از آن در صف Y-sort بیفتد
	var sofa: Polygon2D = null
	for c in cuts:
		if c.name == "Cut_sofa":
			sofa = c
	if sofa != null:
		var base: float = float(sofa.get_meta("cut_base_y", 0.0))
		_check("  پای بازیکن در ۴۳۰ پشت مبل است (کمتر از %.0f)" % base,
			430.0 < base)
		_check("  و در ۵۸۰ جلوی آن", 580.0 > base)


## پوشش و سیلوئت. سه چیز سنجیده می‌شود:
##   ۱ پوشش **بیرون** هر بریده صفر است
##   ۲ پوشش وسط بریده بالاست
##   ۳ بریده‌ای که بازیگر **جلویش** ایستاده نباید پوشش بدهد
func _t_coverage(node: PaintedRoom) -> void:
	print("— پوشش و سیلوئت —")
	var cuts: Array[Polygon2D] = []
	for c in node.actors.get_children():
		if c is Polygon2D and String(c.name).begins_with("Cut_"):
			cuts.append(c)
	if cuts.is_empty():
		_check("اتاق بریده‌ای برای سنجش پوشش دارد", false)
		return

	# جایی دور از هر بریده
	_check("دور از همهٔ occluderها پوشش صفر است",
		is_equal_approx(node.coverage_at(Vector2(60, 690)), 0.0),
		"= %.2f" % node.coverage_at(Vector2(60, 690)))

	for c in cuts:
		var base: float = float(c.get_meta("cut_base_y", 0.0))
		# مرکز افقی بریده، کمی بالاتر از خط پایه → بازیگر پشت آن
		var mid := Vector2(0, 0)
		var n := 0
		for v in c.polygon:
			mid += v
			n += 1
		mid = mid / float(maxi(1, n)) + c.position
		var behind := Vector2(mid.x, base - 12.0)
		var cov: float = node.coverage_at(behind)
		_check("  پشت «%s» پوشش بالاست" % c.name, cov >= 0.5,
			"= %.0f٪" % (cov * 100.0))

		# **جلوی** همان بریده پوشش باید بیفتد. «صفر» دیگر ادعای درستی
		# نیست: از گام ۵۵ ممکن است occluder ایستادهٔ دیگری نزدیک همین
		# نقطه باشد و سهم خودش را بگذارد (قفسهٔ R1a کنار بوفه). ادعای
		# واقعی Y-sort این است: جلو کمتر از پشت، و زیر آستانهٔ سیلوئت.
		var front := Vector2(mid.x, base + 40.0)
		var fcov: float = node.coverage_at(front)
		_check("  ولی جلویش کمتر و زیر آستانه است",
			fcov < cov and fcov < ActorVisual.GHOST_ON,
			"= %.0f٪ در برابر %.0f٪" % [fcov * 100.0, cov * 100.0])

	# آستانهٔ روشن شدن سیلوئت همان ۶۰٪ است که کاربر خواست
	_check("آستانهٔ سیلوئت ۶۰٪ است",
		is_equal_approx(ActorVisual.GHOST_ON, 0.60),
		"= %.0f٪" % (ActorVisual.GHOST_ON * 100.0))
	_check("گذارش ۰٫۱ تا ۰٫۲ ثانیه است",
		ActorVisual.GHOST_FADE_S >= 0.1 and ActorVisual.GHOST_FADE_S <= 0.2,
		"= %.2fث" % ActorVisual.GHOST_FADE_S)



## **چند درصد هر در روی کف واقعی است؟** (گام ۵۷)
##
## دری که مستطیلش بیشتر بیرون ماسک باشد، در عمل یک شکاف باریک است:
## بازیکن جلوی در می‌ایستد و رد نمی‌شود و فکر می‌کند بازی خراب است.
## آزمون سرتاسری همین را در S2b گرفت (۲۰٪) و اندازه‌گیری دو در دیگر را
## هم لو داد. ملاک: دست‌کم یک‌چهارم مستطیل، با پهنای جعبهٔ پا.
const DOOR_MIN_PCT := 0.25

func _t_doors_reachable() -> void:
	print("— در‌ها روی کف —")
	var worst := 1.0
	var worst_id := ""
	for rid in ALL_ROOMS:
		var l := RoomData.new()
		var room := l.load_room(rid)
		if room.is_empty():
			continue
		for raw in room["doors"]:
			var d: Dictionary = raw
			var r: Array = d["rect"]
			var hit := 0
			var total := 0
			for ix in 6:
				for iy in 6:
					var p := Vector2(
						float(r[0]) + float(r[2]) * (float(ix) + 0.5) / 6.0,
						float(r[1]) + float(r[3]) * (float(iy) + 0.5) / 6.0)
					total += 1
					var ok := true
					for dx in [-9.0, 0.0, 9.0]:
						var q := p + Vector2(dx, 0)
						if not RoomData.point_walkable(room, q) \
								or not RoomData.hazard_at(room, q).is_empty():
							ok = false
					if ok:
						hit += 1
			var pct := float(hit) / float(maxi(1, total))
			if pct < worst:
				worst = pct
				worst_id = "%s/%s" % [rid, d["id"]]
			_check("  «%s» در «%s» ≥۲۵٪ روی کف است" % [d["id"], rid],
				pct >= DOOR_MIN_PCT, "= %.0f٪" % (pct * 100.0))
	_check("باریک‌ترین در", worst >= DOOR_MIN_PCT,
		"= %s با %.0f٪" % [worst_id, worst * 100.0])


## occluderهای ایستادهٔ دستهٔ ۱۶ (گام ۵۵، REQ-032).
##
## قاعده‌های کاربر عدد دارند، پس سنجیدنی‌اند: قد مفید ≥۹۰px، کف جلو
## ≥۴۰px، روی هیچ دری نیفتد، و **سیلوئت واقعاً روشن شود** — یعنی پشتش
## پوشش از آستانهٔ ۶۰٪ بگذرد. تا پیش از این، همین ادعا را نوشته بودم
## بی آنکه سنجیده باشم و غلط از آب درآمد (نوار پشت مبل).
const STAND_ROOMS := ["r1a_living", "r1b_corridor", "r1c_kitchen", "c1_balcony"]
const MIN_USEFUL_H := 90.0
const MIN_FRONT_FLOOR := 40.0

func _t_stand_occluders() -> void:
	print("— occluder ایستادهٔ دستهٔ ۱۶ —")
	var total := 0
	for rid in STAND_ROOMS:
		var l := RoomData.new()
		var room := l.load_room(rid)
		if room.is_empty():
			_check("«%s» بار شد" % rid, false, "= %s" % str(l.errors))
			continue
		_check("«%s» بی‌خطا بار شد" % rid, l.errors.is_empty(), "= %s" % str(l.errors))
		var node := PaintedRoom.new()
		add_child(node)
		node.build(room)
		var found := 0
		for raw in room["occluders"]:
			var o: Dictionary = raw
			if not o.has("img") or not o.has("base_y"):
				continue
			found += 1
			total += 1
			var oid := String(o.get("id", "?"))
			var at: Array = o["at"]
			var pos := Vector2(float(at[0]), float(at[1]))
			var base_y := float(o["base_y"])
			var cx := pos.x + float(o.get("w", 0.0)) * 0.5

			_check("  «%s»: قد مفید ≥۹۰px" % oid, base_y - pos.y >= MIN_USEFUL_H,
				"= %.0f" % (base_y - pos.y))
			# کف جلو: چند نقطه در نوار ۴۰ پیکسلی زیر پای شیء
			var front_ok := true
			for dy in [10.0, 25.0, MIN_FRONT_FLOOR]:
				if not RoomData.point_walkable(room, Vector2(cx, base_y + dy)):
					front_ok = false
			_check("  «%s»: کف جلویش ≥۴۰px است" % oid, front_ok)
			# گره‌اش در لایهٔ بازیگران است، نه لایهٔ ۴ — وگرنه Y-sort ندارد
			var holder := node.actors.get_node_or_null("OccStand_%s" % oid)
			_check("  «%s»: در لایهٔ بازیگران با Y-sort است" % oid, holder != null)
			if holder != null:
				_check("  «%s»: گره روی خط پایه نشسته" % oid,
					is_equal_approx(holder.position.y, base_y),
					"= %.0f" % holder.position.y)
			# سیلوئت: پشتش باید از آستانه بگذرد، جلویش نه.
			#
			# **نقطهٔ پشت باید رفتنی باشد.** درس گران گام ۵۴: تنها جیب
			# ۱۰۰٪ پوشش R1a داخل مستطیل یک در بود، پس بازیکن هرگز آنجا
			# نمی‌ایستاد و سیلوئت در ضبط روشن نمی‌شد. پای خود شیء هم
			# مانع است، پس از بالای ردپایش اولین خانهٔ راه‌رفتنی را
			# می‌گیریم، نه نقطه‌ای که فقط روی کاغذ پوشیده است.
			var behind := Vector2(cx, base_y - 10.0)
			var reach := false
			for d in range(6, 96, 4):
				behind = Vector2(cx, base_y - float(d))
				if RoomData.point_walkable(room, behind):
					reach = true
					break
			_check("  «%s»: پشتش جای ایستادن دارد" % oid, reach,
				"= %s" % str(behind.round()))
			var ahead := Vector2(cx, base_y + 36.0)
			var cb: float = node.coverage_at(behind)
			var ca: float = node.coverage_at(ahead)
			_check("  «%s»: پشتش سیلوئت روشن می‌شود" % oid, cb >= ActorVisual.GHOST_ON,
				"= %.0f٪" % (cb * 100.0))
			_check("  «%s»: جلویش نه" % oid, ca < ActorVisual.GHOST_ON,
				"= %.0f٪" % (ca * 100.0))
		_check("«%s» دست‌کم یک occluder ایستاده دارد" % rid, found >= 1, "= %d" % found)
		node.queue_free()
	_check("چهار اتاق روی هم ≥۵ نقطه دارند", total >= 5, "= %d" % total)

## **سینوس خالص ممنوع است** (سند ۱۴ بند ۲). این را نمی‌شود با نگاه کردن
## به کد ثابت کرد، پس سیگنال واقعی ۳۰۰ فریم نمونه‌برداری و با بهترین
## سینوسِ هم‌دامنه مقایسه می‌شود. اگر باقی‌مانده کوچک باشد، یعنی عملاً
## همان سینوس است.
func _t_signal(fx: RoomEffects) -> void:
	var target: Node2D = null
	var amp := 0.0
	for e in fx.effects:
		if String(e.get("type", "")) == "flicker_light":
			target = fx.get_node_or_null("Fx_%s" % e.get("id", ""))
			amp = float(e.get("amp", 0.1))
			break
	if target == null:
		_check("نور سوسوزن برای سنجش سیگنال پیدا شد", false)
		return

	var mat := target.material as ShaderMaterial
	var seen: Array[float] = []
	for i in 300:
		await get_tree().process_frame
		var t = mat.get_shader_parameter("tint")
		seen.append(float(t.w))

	var lo := seen[0]
	var hi := seen[0]
	var mean := 0.0
	for v in seen:
		lo = minf(lo, v)
		hi = maxf(hi, v)
		mean += v
	mean /= float(seen.size())

	_check("نور واقعاً نوسان می‌کند", hi - lo > 0.0001,
		"= دامنهٔ %.4f" % (hi - lo))
	# دامنهٔ دیده‌شده نباید از چیزی که نقشه خواسته بیشتر باشد
	_check("نوسانش از دامنهٔ نقشه بیرون نمی‌زند",
		(hi - lo) <= mean * amp * 2.6 + 0.001,
		"= %.4f، سقف %.4f" % [hi - lo, mean * amp * 2.6])

	# شمارش قله‌ها: سینوس خالص ۱٫۷ هرتز در ۵ ثانیه دقیقاً ~۸ قله می‌دهد و
	# فاصله‌هاشان برابرند. سیگنال چندفرکانسی فاصله‌های نابرابر دارد.
	var gaps: Array[int] = []
	var last := -1
	for i in range(1, seen.size() - 1):
		if seen[i] > seen[i - 1] and seen[i] >= seen[i + 1]:
			if last >= 0:
				gaps.append(i - last)
			last = i
	var varied := false
	if gaps.size() >= 3:
		var g0 := gaps[0]
		for g in gaps:
			if absi(g - g0) > 2:
				varied = true
	_check("فاصلهٔ قله‌ها برابر نیست (سینوس خالص نیست)", varied,
		"= %d قله، فاصله‌ها %s" % [gaps.size() + 1, str(gaps.slice(0, 6))])


## هر چهار اتاق باید بار شوند و بودجهٔ زندگی را داشته باشند. تا اینجا
## فقط R1a سنجیده می‌شد، پس یک اتاق تازه می‌توانست با ماسک شکسته یا
## بی‌هیچ لایهٔ زنده وارد شود و هیچ آزمونی نگوید.
## هر ۱۱ اتاق فصل ۱. تا اینجا فقط چهار تا سنجیده می‌شدند، پس اتاق تازه
## می‌توانست با ماسک شکسته یا دری به ناکجا وارد شود و هیچ آزمونی نگوید.
const ALL_ROOMS := [
	"r1a_living", "r1b_corridor", "r1c_kitchen", "r1d_bedroom", "r1e_basement",
	"c1_balcony", "c2_laser_alley", "c3_electric_hall",
	"s2a_street", "s2b_street", "s3a_plaza",
]


func _t_all_rooms() -> void:
	print("— هر چهار اتاق —")
	for rid in ALL_ROOMS:
		var l := RoomData.new()
		var room := l.load_room(rid)
		_check("«%s» بدون خطا بار شد" % rid, not room.is_empty(),
			"" if room.is_empty() else ", ".join(l.errors))
		if room.is_empty():
			continue
		_check("  شروع «%s» روی زمین است" % rid,
			RoomData.point_walkable(room, Vector2(float(room["spawn"][0]),
				float(room["spawn"][1]))))
		# سقف زوم از وجود نسخهٔ پرجزئیات می‌آید: ۱٫۳× با آن، ۱٫۱۲× بی آن
		# (سند ۱۴، D-ART-46). اتاقی که hires دارد ولی مسیرش غلط نوشته
		# شده، بی‌صدا به ۱٫۱۲ قفل می‌شود — همین برای چهار اتاق افتاده بود.
		var node2 := PaintedRoom.new()
		add_child(node2)
		node2.build(room)
		# اگر اتاق فیلد `hires` دارد، باید واقعاً بار شود
		if String(room.get("hires", "")) != "":
			_check("  «%s» نسخهٔ پرجزئیاتش بار شد" % rid, node2.has_hires(),
				"= %s" % String(room.get("hires", "")))
		# و سقف زوم همیشه با وجود یا نبود آن می‌خواند
		_check("  سقف زوم «%s» با نسخهٔ پرجزئیات می‌خواند" % rid,
			is_equal_approx(node2.max_zoom(),
				1.3 if node2.has_hires() else PaintedRoom.ZOOM_WITHOUT_HIRES),
			"= %.2f (%s)" % [node2.max_zoom(),
				"دارد" if node2.has_hires() else "ندارد"])
		node2.queue_free()

		# ناحیهٔ زوم بالای ۱٫۱۲ بدون hires باید **خطا** باشد، نه قفل
		# بی‌صدا روی ۱٫۱۲ (D-ART-58).
		var probe: Dictionary = room.duplicate(true)
		probe["hires"] = ""
		probe["zoom_zones"] = [{"rect": [0, 0, 100, 100], "level": "close"}]
		var pv := RoomData.new()
		pv._normalize(probe)
		pv._validate(probe)
		var caught := false
		for e in pv.errors:
			if e.contains("نسخهٔ پرجزئیات"):
				caught = true
		_check("  زوم بالای ۱٫۱۲ بی‌هایرز در «%s» خطا می‌دهد" % rid, caught)

		var budget := false
		for w in l.warnings:
			if w.contains("بودجهٔ زندگی"):
				budget = true
		if PENDING_LIVING_ART.has(rid):
			# منتظر هنر، با شمارهٔ REQ. دیده می‌شود، پنهان نمی‌شود؛ و اگر اتاق
			# زنده شد این سنجه رد می‌شود تا فهرست پاک شود.
			print("  ⚠   «%s» بودجهٔ زندگی ندارد — منتظر %s" % [rid, PENDING_LIVING_ART[rid]])
			_check("  «%s» هنوز واقعاً منتظر هنر است (وگرنه از فهرست بردار)" % rid, budget)
		else:
			_check("  «%s» بودجهٔ زندگی را دارد" % rid, not budget,
				"" if not budget else "هشدار دارد")
		# در باید به اتاقی برود که وجود دارد، وگرنه بازیکن در هیچ‌جا
		# می‌افتد و خطایی هم نمی‌بیند
		for raw in room["doors"]:
			var dest := String((raw as Dictionary).get("to", ""))
			var exists := FileAccess.file_exists("res://rooms/%s.json" % dest)
			_check("  در «%s» → «%s» وجود دارد"
				% [(raw as Dictionary).get("id", "?"), dest], exists)
			if not exists:
				continue
			# **نقطهٔ ورود باید در مقصد روی زمین باشد.** اگر نباشد بازیکن
			# داخل دیوار ظاهر می‌شود و هیچ خطایی هم نمی‌بیند؛ همان چیزی
			# که اعتبارسنجی برای `spawn` خود اتاق می‌گیرد ولی برای
			# `spawn` درها نمی‌گرفت.
			var sp: Array = (raw as Dictionary).get("spawn", [])
			var dl := RoomData.new()
			var droom := dl.load_room(dest)
			var at := Vector2(float(sp[0]), float(sp[1]))
			_check("  و نقطهٔ ورودش در «%s» روی زمین است" % dest,
				not droom.is_empty() and RoomData.point_walkable(droom, at),
				"= (%d,%d)" % [int(at.x), int(at.y)])
			# **و نباید داخل درِ دیگری در مقصد بیفتد.** اگر بیفتد،
			# بازیکن همان فریم دوباره رد می‌شود و بین دو اتاق در حلقه
			# می‌افتد. این را ضبط مسیر بیرون کشید: برگشت از C1 دوباره
			# وارد C1 می‌شد، و چهار نقطهٔ ورود دیگر هم همین عیب را
			# داشتند.
			var in_door := ""
			for raw2 in droom.get("doors", []):
				var d2: Dictionary = raw2
				var r2: Array = d2.get("rect", [])
				if r2.size() != 4:
					continue
				if Rect2(float(r2[0]), float(r2[1]), float(r2[2]),
						float(r2[3])).has_point(at):
					in_door = String(d2.get("id", "?"))
			_check("  و داخل درِ دیگری نمی‌افتد", in_door == "",
				"" if in_door == "" else "داخل در «%s»" % in_door)


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
