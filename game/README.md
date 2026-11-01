# دو آسمان — پروژهٔ Godot (نسخهٔ ۱)

پلتفرمر معمایی دو شخصیتی. این پوشه ریشهٔ پروژهٔ Godot است، یعنی `res://` همین `game/` است.

**دامنهٔ نسخهٔ ۱:** فصل ۱، مرحله‌های ۱ تا ۳ (۱۲ اتاق). بقیهٔ فصل‌ها و بازی‌های فرعی
ساخته نشده‌اند، ولی قالب داده و کلاس‌های پایه طوری نوشته شده‌اند که بعداً بازنویسی لازم نشود.

## اجرا

```bash
godot --path game
```

منوی اصلی → نقشهٔ فصل → مرحله. کلیدهای توسعه: `A`/`D` حرکت، `Space` پرش،
`K` عمل (هک یا دش)، `L` همراه (ضربه = بیا، نگه‌داشتن = بمان)، `Esc` توقف.
روی موبایل همین‌ها دکمهٔ لمسی مجازی دارند.

## آزمون‌ها

```bash
GODOT=/path/to/godot ./tools/run_tests.sh
```

از ریشهٔ مخزن اجرا می‌شود و این‌ها را پشت سر هم می‌سنجد:

| آزمون | چه می‌سنجد |
| --- | --- |
| `tools/check_sources.py` | کاراکتر نامرئی کنترل جهت و تو رفتگی قاطی |
| `tools/validate_ch1.py` | حل‌پذیری ۱۲ اتاق با BFS روی ثابت‌های واقعی §۳ |
| `test_compile` | کامپایل شدن همهٔ اسکریپت‌ها |
| `test_physics` | ثابت‌های §۳، coyote، بافر پرش، دیوارپرش، مرگ، تکرارپذیری |
| `test_levels` | قالب §۱۰، باز شدن قالب فشردهٔ §۱۱، مُهر شدن لبه |
| `test_companion` | قانون همراهی، تأخیر ۴۸ فریمی، بمان/بیا، teleport |
| `test_solvable` | موانع در موتور، برد پرش اندازه‌گیری‌شده، قاعدهٔ عدالت |
| `test_save_ui` | ذخیره، امضا، پشتیبان، مهاجرت، اقتصاد، ده صفحهٔ UI |
| `test_cutscene_audio` | قالب §۱۸، باکس گفت‌وگو، ۱۱۷ کلید صدا |
| `test_acceptance` | بندهای §۱۶ و معیار پذیرش سند ۰۵ |

## ساخت دوبارهٔ مرحله‌ها

نقشه‌های فصل ۱ از `docs/02_godot_spec.md` §۱۱ خوانده می‌شوند، نه دستی کپی:

```bash
python3 tools/build_ch1_levels.py
```

جدول `digits`، `exits` و `PATCHES` در همان فایل است. پس از هر تغییر، اعتبارسنج را اجرا کن.

## ساختار

```
res://
  autoload/   GameState, Settings, Audio, Ads, Billing, NetService, SceneRouter, EventBus, Cutscene
  actors/     kairo/ (ماشین حالت §۴)، ilara/ (قانون همراهی §۵)، enemies/
  tools/      کلاس پایهٔ Tool §۱۷-۱، hack_module، dash، tests/
  hazards/    spike، crumble، laser
  items/      pickup، note، exit_point، gate
  levels/     level_loader (قالب §۱۰ و §۱۱)، room، data/ch1_l1..l3.json
  ui/         common/ (fa، ui_kit، screen) و ده صفحهٔ §۱۳
  data/       tuning، strings_fa، sfx، shop، ads_config، cutscenes/
```

## اعداد بازی

`actors/kairo/constants.gd` ثابت‌های §۳ را دارد و هیچ عددی وسط کد نیست.
`data/tuning.json` **هر دو** مجموعهٔ اعداد (سند ۰۲ و سند ۰۱) را نگه می‌دارد؛
عوض کردن `active_profile` کل حس بازی را جابه‌جا می‌کند بدون دست زدن به کد.

## هنر و صدا

همه مکان‌نگهدار است: مستطیل رنگی و کلید صدای بدون فایل (سکوت، نه خطا).
`LevelLoader.make_placeholder_tileset()` تنها جایی است که باید با رسیدن کاشی واقعی
عوض شود. فهرست دقیق دارایی‌های لازم در `docs/05_release_v1_plan.md` است.

## پیش از انتشار

`data/ads_config.json` و شناسه‌های پولاکی **جای‌نگهدارند**. کلید واقعی و keystore
هرگز در مخزن نمی‌رود. فهرست کامل کارهای پیش از انتشار در `docs/05_release_v1_plan.md`.
