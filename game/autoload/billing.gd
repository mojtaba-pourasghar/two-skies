## Billing — پرداخت درون‌برنامه‌ای کافه بازار با پولاکی (docs/02_godot_spec.md §۱۵)
##
## پلاگین godot-poolakey. در محیط توسعه پلاگین موجود نیست و همهٔ متدها بی‌اثرند،
## پس منوی فروشگاه بدون خطا کار می‌کند و دکمه‌ها غیرفعال می‌شوند.
extends Node

signal connected(ok: bool)
signal purchase_succeeded(sku: String, token: String)
signal purchase_failed(sku: String, reason: String)
signal products_queried(products: Array)

const SHOP_PATH := "res://data/shop.json"

var _plugin: Object = null
var _products: Array = []
var is_connected_to_market: bool = false


func _ready() -> void:
	if OS.get_name() == "Android" and Engine.has_singleton("Poolakey"):
		_plugin = Engine.get_singleton("Poolakey")
	_load_catalog()


func _load_catalog() -> void:
	if not FileAccess.file_exists(SHOP_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(SHOP_PATH))
	if parsed is Dictionary:
		_products = parsed.get("products", [])


func available() -> bool:
	return _plugin != null


func catalog() -> Array:
	return _products.duplicate(true)


func connect_to_market() -> void:
	if _plugin == null:
		is_connected_to_market = false
		connected.emit(false)
		return
	_plugin.call("connect")


func purchase(sku: String) -> void:
	if _plugin == null:
		purchase_failed.emit(sku, "market_unavailable")
		return
	_plugin.call("purchase", sku)


func consume(token: String) -> void:
	if _plugin != null:
		_plugin.call("consume", token)


func restore() -> void:
	if _plugin != null:
		_plugin.call("restore")
