# دستور تحویل به Claude Code (هنر فصل ۱)

شاخهٔ `art/style-pipeline` را در شاخهٔ کاری‌ات (`feat/topdown-3q`) merge کن (به `master` پوش نکن)، سپس:

1. **مقیاس (D-ART-02):** ۱۲۸۰×۷۲۰، کاشی ۳۲، `WORLD_SCALE=2`، قد شخصیت ~۸۸ پیکسل، فیلتر Nearest. گام ۱۲ را با همین اعمال کن.
2. **ابزار `tools/import_art.py` (گام ۱۴):** هر پوشهٔ `art_drop/<نام>/asset.json` را به `game/assets/` منتقل کند و Import بسازد. اگر `asset.json` وضعیت `draft` داشت، فقط هشدار بده (خطا نده).
3. **محتوای آمادهٔ استفاده در `art_drop/`:**
   - `env/` ۴ محیط، `parallax/` (coral, cave, plateau؛ بندر نرسیده)، `scenes/` (intro, chapter1_title_bg, end_v1, shop), `title/`, `app_icon/`
   - `props/` ۱۲ شیء شفاف، `terrain/` ۱۸ کاشی (۳۲ و ۶۴ و کامل)
   - `portraits/{kairo,ilara}/` ۶ حالت چهره، `icons/ilara_signals/{stay,come}.png`
   - `kairo/`, `ilara/` اسپرایت idle (۳ جهت)، `ui/`, `icons/`, `hazards/`, `fx/`
4. **هشدارهای محتوا (از `art/ASSET_LIST.md`):** `ui/portrait_frame` فقط قاب استفاده شود (چهرهٔ غریبه حذف)؛ آیکون‌های سگ/روباه کنار نشانه‌های ایلارا جایگزین شوند؛ `skill_*`/`slot_*` فصل ۱ نیست؛ hazards مورب‌اند و باید به کاشی ۳۲×۳۲ برسند.
5. **هنوز نیست (جای‌نگهدار بگذار):** انیمیشن‌های دویدن/دش/هک/مرگ/پرش، لایهٔ پیش‌زمینهٔ برگ شفاف، parallax بندر.
6. همهٔ هنر کدی فقط `art/drafts/` است؛ کامیت «گام N:» و پوش روی شاخهٔ خودت.
