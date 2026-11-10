## یافتن دارایی بدون وابستگی به پسوند — D-ART-56
##
## داده‌ها (اتاق، نقشهٔ افکت، anims.json) مسیر را با `.png` می‌نویسند، ولی
## ایمپورتر پس‌زمینه‌های بزرگ را به **WebP** تبدیل می‌کند تا بسته زیر سقف
## ۱۰۰ مگابایت بماند. اگر هر جا مسیر خام استفاده شود، تبدیل یعنی شکستن
## همهٔ ارجاع‌ها.
##
## پس همه‌جا از اینجا می‌گذرد: اول خود مسیر، بعد همان نام با پسوند دیگر.
class_name AssetPath
extends RefCounted

const ASSETS := "res://assets/"
## ترتیب مهم است: اگر هر دو باشند، همان که داده خواسته برنده است.
const EXTS := [".png", ".webp"]


## مسیر کامل دارایی، یا رشتهٔ خالی اگر هیچ نسخه‌ای نباشد.
static func find(rel: String) -> String:
	if rel == "":
		return ""
	var p := rel if rel.begins_with("res://") else ASSETS + rel
	if ResourceLoader.exists(p):
		return p
	var base := p.get_basename()
	for e in EXTS:
		var alt: String = base + e
		if alt != p and ResourceLoader.exists(alt):
			return alt
	return ""


static func exists(rel: String) -> bool:
	return find(rel) != ""


## بافت، یا نول. صدا زننده خودش تصمیم می‌گیرد نبودش خطاست یا هشدار.
static func texture(rel: String) -> Texture2D:
	var p := find(rel)
	return load(p) if p != "" else null
