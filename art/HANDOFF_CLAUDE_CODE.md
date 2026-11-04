# دستور تحویل به Claude Code (هنر فصل ۱)

شاخهٔ `art/style-pipeline` را در شاخهٔ کاری‌ات (`feat/topdown-3q`) merge کن (به `master` پوش نکن)، سپس:

1. **مقیاس (D-ART-02):** ۱۲۸۰×۷۲۰، کاشی ۳۲، `WORLD_SCALE=2`، قد شخصیت ~۸۸ پیکسل، فیلتر Nearest. گام ۱۲ را با همین اعمال کن.
2. **ابزار `tools/import_art.py` (گام ۱۴):** هر پوشهٔ `art_drop/<نام>/asset.json` را به `game/assets/` منتقل کند و Import بسازد. اگر `asset.json` وضعیت `draft` داشت، فقط هشدار بده (خطا نده).
3. **محتوای آمادهٔ استفاده در `art_drop/`:**
   - `env/` ۴ محیط، `parallax/` (coral, cave, plateau؛ بندر نرسیده)، `scenes/` (intro, chapter1_title_bg, end_v1, shop), `title/`, `app_icon/`
   - `props/` ۱۲ شیء شفاف، `terrain/` ۱۸ کاشی (۳۲ و ۶۴ و کامل)
   - `hazards_topdown/` (۸)، `hackables/` (۸)، `checkpoint_exit/` (۹)، `overlays/leaf_frame_1280x720.png`، `ui/portrait_frame_empty.png`، `scenes/chapter_complete`
   - `portraits/{kairo,ilara}/` ۶ حالت چهره، `icons/ilara_signals/{stay,come}.png`
   - `kairo/`, `ilara/` اسپرایت idle (۳ جهت)، `ui/`, `icons/`, `hazards/`, `fx/`
4. **هشدارهای محتوا (از `art/ASSET_LIST.md`):** `ui/portrait_frame` فقط قاب استفاده شود (چهرهٔ غریبه حذف)؛ آیکون‌های سگ/روباه کنار نشانه‌های ایلارا جایگزین شوند؛ `skill_*`/`slot_*` فصل ۱ نیست؛ `hazards/` قدیمی مورب است و منسوخ؛ از `hazards_topdown/` استفاده شود و اندازهٔ اشیاء روی شبکهٔ ۳۲ تنظیم شود.
5. **هنوز نیست (جای‌نگهدار بگذار):** انیمیشن‌های دویدن/دش/هک/مرگ/پرش، لایهٔ پیش‌زمینهٔ برگ شفاف، parallax بندر.
6. همهٔ هنر کدی فقط `art/drafts/` است؛ کامیت «گام N:» و پوش روی شاخهٔ خودت.
7. **فونت فارسی:** `game/assets/fonts/Vazirmatn-NL-{Regular,Bold,Black}.ttf` (مجوز OFL کنار آن‌هاست). در Godot برای همهٔ متن رابط، `TextServerAdvanced` فعال و `base_direction=RTL` / `language=fa` بگذار. لوگوی فارسی آماده: `art_drop/logo/logo_fa.png`، بنر با لوگو: `art_drop/store/feature_banner_with_logo_1024x500.png`، عنوان با لوگو: `art_drop/title/title_with_logo_1280x720.png`.
8. **صادرات آیکون adaptive:** foreground/background در `art_drop/app_icon/` (۱۰۲۴) → ۴۳۲ پیکسل برای xxxhdpi.

## انیمیشن‌های v2 (`art_drop/{kairo,ilara}/anim/`)
فریم‌ها `<anim>_NN.png` (۱۲۸×۱۲۸ یا ۱۹۲×۱۲۸ طبق `art_drop/anim_v2_asset.json` → `*_frame_w`)، خط پا y=124، fps ~۹. کایرو: walk_down/up، walk_side، run_side، dash، hack، hop، death، respawn. ایلارا: walk_down/up، run_side، signal_stay، signal_come، hop. چپ = آینهٔ راست. پرتره‌های درست ایلارا در `art_drop/portraits/ilara/` (`_obsolete_ilara_v1` را نادیده بگیر). همه draft تا تأیید کاربر.
