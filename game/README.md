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

## هنر

هنر **موقت** است ولی دیگر مستطیل رنگی نیست: اسپرایت پیکسلی خوانا با پالت رسمی.
هیچ PNG دستی در مخزن نیست — هر چهارده فایل با یک اسکریپت ساخته می‌شود:

```bash
python3 -I tools/gen_art.py           # ساخت دوباره
python3 -I tools/gen_art.py --check   # بررسی اینکه PNGها با اسکریپت می‌خوانند
```

`--check` در `tools/run_tests.sh` اجرا می‌شود، پس اگر کسی PNG را دستی عوض کند
آزمون رد می‌شود. مجموع هنر **۵۶ کیلوبایت** است (سقف بسته ۱۰۰ مگابایت).

| فایل | کارش |
| --- | --- |
| `tools/pixel.py` | نوشتن PNG با کتابخانهٔ استاندارد، بدون وابستگی |
| `tools/palette.py` | ۳۴ رنگ مجاز و فرمول سایه/هایلایت سند ۰۴ |
| `tools/gen_art.py` | کشیدن کاشی، شخصیت، مانع، قلم، پس‌زمینه |
| `game/art/palette.gd` | **ساخته می‌شود** — دستی ویرایشش نکن |
| `game/art/art.gd` | تنها جایی که مسیر بافت نوشته می‌شود |

هر رنگی در کد باید از `Palette` بیاید؛ هر بافتی از `Art`. وقتی هنر نهایی رسید،
فقط فایل‌های `game/art/` عوض می‌شوند و هیچ اسکریپت دیگری دست نمی‌خورد.

`tools/tests/test_art.gd` نگه می‌دارد که هر بافت وارد شده باشد، اندازه‌اش با
جعبهٔ برخورد بخواند، و هر چهار گونهٔ کاشی **برخورد یکسان** داشته باشند — تا
ظاهر هیچ‌وقت روی فیزیک و حل‌پذیری اثر نگذارد.

## صدا

هنوز مکان‌نگهدار: کلید صدای بدون فایل (سکوت، نه خطا).
فهرست دقیق دارایی‌های لازم در `docs/05_release_v1_plan.md` است.

## ساخت اندروید

پریست `Android` در `export_presets.cfg` آماده و کامیت شده است:
`arm64-v8a` تنها، `min_sdk=24` (§۱۵)، `target_sdk=34`، Gradle build روشن،
جهت صفحه landscape قفل (از `project.godot`)، و نام بستهٔ **جای‌نگهدار**
`ir.twoskies.game`. هیچ کلید یا keystore در مخزن نیست.

**در این محیط APK ساخته نشد** و دلیلش این است:

```
No export template found at the expected path
Invalid Android SDK path in Editor Settings. Missing 'platform-tools' directory!
```

یعنی پریست درست خوانده و اعتبارسنجی شد، ولی قالب اکسپورت و SDK اندروید نصب
نیستند. جاوا ۲۱ و Gradle ۸٫۱۴ هستند. مراحل ساخت روی ماشینی که SDK دارد:

```bash
# ۱) قالب اکسپورت هم‌نسخهٔ موتور (۴٫۵)
#    یا از منوی ویرایشگر: Editor → Manage Export Templates → Download
mkdir -p ~/.local/share/godot/export_templates/4.5.stable
# فایل Godot_v4.5-stable_export_templates.tpz را باز کنید و محتوایش را آنجا بریزید
```

```bash
# ۲) SDK اندروید (command line tools) و بسته‌های لازم
export ANDROID_HOME="$HOME/android-sdk"
sdkmanager --sdk_root="$ANDROID_HOME"   "platform-tools" "build-tools;34.0.0" "platforms;android-34" "cmdline-tools;latest"
```

```bash
# ۳) مسیرها را به ویرایشگر بدهید (یک بار)
godot -e --headless --quit
# سپس در Editor Settings → Export → Android:
#   Android SDK Path = $ANDROID_HOME
#   Java SDK Path    = مسیر JDK ۱۷ یا بالاتر
```

```bash
# ۴) keystore دیباگ (برای بیلد رلیز، keystore خودتان و هرگز در مخزن)
keytool -genkeypair -v -keystore ~/debug.keystore -alias androiddebugkey   -keyalg RSA -keysize 2048 -validity 10000   -storepass android -keypass android -dname "CN=Android Debug,O=Android,C=US"
```

```bash
# ۵) ساخت APK دیباگ
mkdir -p ../build
godot --headless --path . --export-debug "Android" ../build/two-skies.apk
```

سقف حجم بسته در سند ۰۵ صد مگابایت است. با مکان‌نگهدارهای فعلی (مستطیل رنگی و
کلید صدای بدون فایل) حجم بسیار کمتر از آن است؛ عدد واقعی پس از رسیدن هنر و صدای
نهایی سنجیده می‌شود.

### پلاگین‌های اندروید

`android/plugins/AdiveryGodot.gdap` و `Poolakey.gdap` **قرارداد** پلاگین‌اند و
کامیت شده‌اند؛ خود فایل AAR در مخزن نیست و باید ساخته و کنار همان `.gdap`
گذاشته شود (`android/plugins/*.aar` در `.gitignore` است).

کد از قبل آماده است: `autoload/ads.gd` و `autoload/billing.gd` با
`Engine.has_singleton(...)` نگهبانی می‌کنند، پس **بدون AAR هم بازی بدون خطا
ساخته و اجرا می‌شود** — تبلیغ روی `StubProvider` می‌رود و فروشگاه پیام
«بازار در دسترس نیست» نشان می‌دهد.

شناسه‌های واقعی ادیوری در `data/ads_config.json` جای‌نگهدارند
(`REPLACE_WITH_ADIVERY_APP_ID`) و پیش از انتشار از پنل ادیوری پر می‌شوند.
کلید RSA بازار فقط به محصول نهایی وصل می‌شود (§۱۵).

## پیش از انتشار

`data/ads_config.json` و شناسه‌های پولاکی **جای‌نگهدارند**. کلید واقعی و keystore
هرگز در مخزن نمی‌رود. فهرست کامل کارهای پیش از انتشار در `docs/05_release_v1_plan.md`.
