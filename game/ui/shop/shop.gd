## فروشگاه — docs/02_godot_spec.md §۱۵، قیمت‌های سند ۰۵
##
## در محیط توسعه پلاگین پولاکی نیست، پس دکمه‌های خرید پولی خاکستری‌اند و
## پیام «بازار در دسترس نیست» دیده می‌شود. هیچ خرید تصادفی وجود ندارد.
extends Screen

func build() -> VBoxContainer:
	var box := UIKit.make_root("ui_shop")
	box.add_child(UIKit.make_currency_bar())
	box.add_child(UIKit.make_spacer(4))

	var market := Billing.available()
	if not market:
		box.add_child(UIKit.make_label(Fa.t("ui_market_unavailable"), 9, UIKit.MUTED))

	for product in Billing.catalog():
		var sku := String(product.get("sku", ""))
		var owned: bool = GameState.owns(sku)
		var price := int(product.get("price_toman", 0))
		var suffix: String = ""
		if owned:
			suffix = "  " + Fa.t("ui_owned")
		else:
			suffix = "  %s %s" % [Fa.num(price), Fa.t("ui_toman")]
		var b := UIKit.make_button("ui_buy", market and not owned, suffix)
		var name_label := UIKit.make_label(String(product.get("name", sku)), 10)
		var row := UIKit.make_row()
		row.add_child(name_label)
		row.add_child(b)
		if market and not owned:
			b.pressed.connect(func(): Billing.purchase(sku))
		box.add_child(row)

	# کالاهای درون‌بازی که با سکه یا زمرد خریدنی‌اند (سند ۰۵)
	box.add_child(UIKit.make_spacer(6))
	box.add_child(UIKit.make_label(Fa.t("ui_shop_skins"), 11, UIKit.ACCENT))
	for item in _in_game_items():
		var owned: bool = GameState.owns(String(item["sku"]))
		var coin_cost: int = int(item["coins"])
		var gem_cost: int = int(item["gems"])
		var affordable: bool = (
			int(GameState.data.get("coins", 0)) >= coin_cost
			if coin_cost > 0
			else int(GameState.data.get("gems", 0)) >= gem_cost
		)
		var cost: String = ""
		if coin_cost > 0:
			cost = "  %s %s" % [Fa.num(coin_cost), Fa.t("ui_coins")]
		else:
			cost = "  %s %s" % [Fa.num(gem_cost), Fa.t("ui_gems")]
		var b := UIKit.make_button("ui_buy", not owned and affordable,
			("  " + Fa.t("ui_owned")) if owned else cost)
		var row := UIKit.make_row()
		row.add_child(UIKit.make_label(item["name"], 10))
		row.add_child(b)
		if not owned and affordable:
			b.pressed.connect(func(): _buy_in_game(item))
		box.add_child(row)

	add_back_button(box)
	return box

func _in_game_items() -> Array:
	return [
		{"sku": "skin_kairo_blue", "name": "کایرو — روسری آبی", "coins": 60, "gems": 0},
		{"sku": "skin_ilara_green", "name": "ایلارا — روسری سبز", "coins": 60, "gems": 0},
		{"sku": "skin_kairo_special", "name": "کایرو — ظاهر ویژه", "coins": 0, "gems": 80},
	]

func _buy_in_game(item: Dictionary) -> void:
	var coin_cost: int = int(item["coins"])
	var ok: bool = false
	if coin_cost > 0:
		ok = GameState.spend_coins(coin_cost)
	else:
		ok = GameState.spend_gems(int(item["gems"]))
	if ok:
		GameState.grant_purchase(String(item["sku"]))
		Audio.play_sfx("ui_click")
		SceneRouter.reload_current()
