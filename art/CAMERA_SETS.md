# دو دوربین، دو مجموعهٔ هنر (۱۴۰۵/۰۸/۱۴، درخواست کاربر: «هر دو حالت رو داشته باشیم»)
هنر برای هر دو دوربین تولید و نگه‌داری می‌شود. **تصمیم مکانیک/دوربین بازی هنوز باز است** (D-063 سه‌چهارم؛ سؤال به کاربر ارسال شد). تا آن موقع هیچ هنری کنار گذاشته نمی‌شود.

| مورد | نمای کناری (side) | سه‌چهارم از بالا (topdown) |
|---|---|---|
| حرکت کایرو/ایلارا | `home/anim/walk_side`, `run_side`, `hop`, `dash`, `hack`, `wall_jump` | `home/idle_down/up`، `leap_down`، `climb_up` (جهت‌های دیگر ◐) |
| باس | `art_drop/boss/guardian_sideview` | `art_drop/boss/guardian_topdown` |
| بولت (شکل) | `art_drop/bolt/forms_sideview` | `art_drop/bolt/forms_topdown` |
| بولت (احساس) | `art_drop/bolt/emotions` (جلو؛ برای دیالوگ/HUD) | `art_drop/bolt/emotions_topdown` |
| صحنه‌ها | پارالکس `art_drop/parallax/ch1/*_far|mid|fore` | `art_drop/scenes/ch1/*` + `art_drop/tiles_ch1/*` |
| سکوی شکننده / کف برقی / در | ◐ نسخهٔ کناری در Canva | `art_drop/hazards_ch1_topdown/` |
| دیوارپرش | ✔ (نمای کناری) | حذف؛ جایگزین: `climb` + سکوی شکننده |

## ✅ تصمیم (D-ART-06): بازی هر دو حالت را پشتیبانی می‌کند
هر دو ستون جدول بالا نهایی‌اند. `camera_mode` (`side` | `topdown`) در دادهٔ هر مرحله/صحنه (فرض؛ در انتظار تأیید کاربر).
