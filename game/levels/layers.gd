## شماره‌های لایهٔ فیزیک — docs/02_godot_spec.md §۱
##
## §۱ لایه‌ها را با شماره می‌دهد (۱ زمین، ۲ کایرو، …) و مقدار بیتی هر لایه 1 << (n-1) است.
## همه‌جا از این ثابت‌ها استفاده می‌شود تا عدد بیتی وسط کد نیفتد.
class_name Layers
extends RefCounted

const GROUND: int   = 1 << 0   # ۱
const KAIRO: int    = 1 << 1   # ۲
const ILARA: int    = 1 << 2   # ۳
const ENEMY: int    = 1 << 3   # ۴
const HAZARD: int   = 1 << 4   # ۵
const ITEM: int     = 1 << 5   # ۶
const TRIGGER: int  = 1 << 6   # ۷
const TOOL: int     = 1 << 7   # ۸

## هر دو شخصیت — ماسک مشترک خطرها، اقلام و ماشه‌ها
const ACTORS: int = KAIRO | ILARA
