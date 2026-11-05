# دستور ساخت بازی «دو آسمان» — مرجع ورودی برای Claude Code
(۱۴۰۵/۰۸/۱۴، تأیید کاربر. این سند **اول** خوانده شود؛ بقیهٔ اسناد را از اینجا به‌ترتیب باز کن.)

> **تغییر مصوب D-ART-09:** بازی RPG اکتشافی سه‌چهارمی با نبرد نوبتی و نقشهٔ قابل‌راه‌رفتن شد و **اکتشاف/نقشه/نبرد `topdown` و اتاق‌های چالش مانع‌دار `side` (Super Meat Boy، اصلاح ۰۸/۱۵)**؛ جدول §۲ برای حالت `side` (آینده) و هنر باقی می‌ماند. طراحی: `docs/08_rpg_battle_and_overworld.md` (بخش ۱۰ پایین را ببین).

## ۰. وضعیت: چه چیزی قفل است
| موضوع | تصمیم | منبع |
|---|---|---|
| دو حالت دوربین | `side` و `topdown`، **ثابت برای هر مرحله** (نه کلید بازیکن، نه وسط مرحله) | D-ART-06/07 |
| جدول دوربین هر مرحله | **تأیید کاربر** (بخش ۲) | D-ART-08 |
| بخش‌های بی‌کنترل | بازی در لحظه‌های سناریو خودش با انیمیشن جلو می‌رود؛ باید سیستم رسمی داشته باشد (بخش ۴) | D-ART-08 |
| الگوی بازی | بازی‌های سه‌چهارمی نوع «Sea of Stars» فقط به‌عنوان **الگوی ساختاری** (بخش ۵)؛ هیچ محتوایی کپی نمی‌شود | D-ART-08، CLAUDE.md قانون ۵ |
| مقیاس | ۱۲۸۰×۷۲۰، کاشی ۳۲، `WORLD_SCALE=2`، قد شخصیت ~۸۸px، Nearest | D-ART-02 |
| هنر | همه «draft تا تأیید کاربر»؛ import فقط هشدار بدهد | CLAUDE.md |

## ۱. ترتیب خواندن
1. `CLAUDE.md` و `DECISIONS.md` (از D-063 و D-ART-02 تا D-ART-08)
2. **این سند**
3. `docs/01_main_design_and_screenplay_ch1-8.md` — بخش «طراحی مراحل فصل ۱» و جدول «حالت دوربین هر مرحله»
4. `docs/02_godot_spec.md` — فیزیک، ماشین حالت، §۱۸ سیستم فیلم‌نامه، قالب JSON مرحله
5. `game/TOPDOWN_SPEC.md` (مشخصات حالت `topdown`)؛ حالت `side` از شاخهٔ `v0-sideview` + سند ۰۲
6. `docs/05_release_v1_plan.md` — محدودهٔ نسخهٔ ۱ (مراحل ۱–۳)
7. `art/CAMERA_SETS.md`، `art/HANDOFF_CLAUDE_CODE.md`، `art/PRODUCTION_LIST.md` — هنر و مسیرها
8. `docs/04_art_and_sound_bible.md`، `docs/screenplay/` برای صحنه‌ها

## ۲. حالت دوربین هر مرحله (تأیید شد)
| # | مرحله | `camera_mode` | هنر اصلی |
|---|---|---|---|
| ۱ | خانهٔ خالی | `side` | `tiles_side_ch1/house`، پارالکس `house_*`، `hazards_ch1/` |
| ۲ | خیابان سوخته | `topdown` | `tiles_ch1_v2/street`، `scenes/ch1/launch_road*`، `hazards_ch1_topdown/` (سکوی شکننده) |
| ۳ | پهپاد گشتی | `side` | `tiles_side_ch1/street`، پارالکس `street_*`، `hazards_ch1/drone_*`، `enemies/nexa/` |
| ۴ | زیرزمین | `topdown` | `tiles_ch1_v2/basement`، `hazards_ch1_topdown/security_door`، `enemies/nexa_topdown/` |
| ۵ | کف برقی | `side` | `tiles_side_ch1/basement`، پارالکس `electric_*`، `hazards_ch1_sideview/electric_floor` |
| ۶ | بولت | `topdown` | `tiles_ch1_v2/basement`، `scenes/ch1/workshop*`، `bolt/forms_topdown`، `bolt/emotions_topdown` |
| ۷ | جادهٔ پرتاب | `side` | `tiles_side_ch1/street`، پارالکس `launch_*`، `scenes/ch1/launch_platform_side*` |
| ۸ | باس | `side` | `boss/guardian_sideview`، پارالکس `launch_*` |
| — | اتاق ایلارا (مخفی) | `topdown` | `scenes/ch1/ilara_bedroom*`، `tiles_ch1_v2/house` |
نسخهٔ ۱ = مراحل ۱–۳: `side` ← `topdown` ← `side`.

مکانیک‌ها بر اساس حالت: دیوارپرش فقط `side`؛ جهش (کمان ثابت+سایه)، `climb` و سکوی شکننده فقط `topdown`؛ دش و هک در هر دو. تعویض حالت **فقط بین مرحله‌ها/صحنه‌ها** با dissolve ۰٫۴ ثانیه.

## ۳. دوربین در هر حالت
- `side`: دنبال‌کنندهٔ نرم با کمی جلوتر-نگری (look-ahead) و محدودهٔ مرحله؛ مرز اتاق/مرحله را از JSON بخوان.
- `topdown`: **دنبال‌کنندهٔ نرم** با مرز نقشه + Y-sort (مبنای مرتب‌سازی y پای هر جسم). این **جایگزین قفل‌بودن دوربین روی یک اتاق** در `TOPDOWN_SPEC §۶` است (D-ART-08)؛ اتاق‌های کوچک می‌توانند با `camera_follow: "room"` در JSON همان رفتار قفل را نگه دارند. پیش‌فرض `follow`.
- هر دو: لرزش دوربین طبق سند ۰۴؛ زوم صحنه‌ها طبق `SHOT_ZOOM` در `cutscene.gd`.

## ۴. بخش‌های بی‌کنترل (سناریو بازی را جلو می‌برد)
مثال‌ها در سناریو: مقدمهٔ داستان، لحظهٔ افتادن ایلارا در مرحلهٔ ۷ (مرگ حساب نمی‌شود؛ کایرو ۳ ثانیه بدون کنترل برمی‌گردد)، ورود به صحنهٔ سکوی پرتاب، رام‌کردن بولت، باز شدن پنل باس.
سه لایه بساز (روی `Cutscene` موجود سوار شو، از نو ننویس):
1. **`GameMode`** (autoload یا بخشی از `game_state`): `PLAY` / `SCRIPTED` / `CUTSCENE`. در غیر `PLAY` ورودی بازیکن قطع، بافر ورودی پاک، HUD پنهان یا کم‌رنگ.
2. **`ScriptedSequence`** (Resource/JSON در `data/sequences/`): فهرست گام‌ها: `move_to(actor, marker, speed)`، `play_anim`، `camera_to / zoom / shake`، `wait`، `dialogue(key)`، `set_flag`، `checkpoint`، `fade`، `spawn/despawn`، `give_control`. بازیگر در حین اجرا **آسیب‌ناپذیر** است و مرگ حساب نمی‌شود مگر گام بگوید.
3. **ماشهٔ مرحله**: در JSON مرحله `triggers: [{area, sequence, once}]`. پایان توالی = ذخیرهٔ چک‌پوینت + `give_control`.
قواعد: دکمهٔ «رد کردن» برای توالی‌های طولانی (>۵ ثانیه)؛ توالی‌های کوتاه (<۳ ثانیه) رد نمی‌شوند؛ تایم‌اوت ایمنی تا بازی گیر نکند؛ هر توالی باید در هر دو `camera_mode` بیاید (دوربین با گام `camera_to` عوض می‌شود، نه حالت). فیلم‌نامه (سند ۰۱ و `docs/screenplay/`) مرجع محتواست.

## ۵. «الگوی Sea of Stars» — چه چیزی اجازه دارد و چه چیزی نه
**الگوی ساختاری مجاز (به زبان خودمان):** اکتشاف سه‌چهارمی با شخصیت دنبال‌شونده، لحظه‌های پیمایش اسکریپتی (بالا رفتن/پریدن خودکار روی نقطه‌های مشخص)، دوربین نرم با نماهای سینمایی در لحظه‌های داستانی، جعبهٔ گفت‌وگوی کوتاه با پرتره، اعلان تعامل کنار شیء، پان دوربین برای نشان‌دادن هدف.
**ممنوع (CLAUDE.md قانون ۵):** هر شخصیت، اسپرایت، نقشه، رابط، متن، موسیقی یا صحنه از آن بازی؛ و **هرگز تصویر آن بازی به هیچ مدل یا ابزار تصویر داده نشود**. نام بازی در هیچ فایل/شناسه/متن بازی نیاید. فقط ساختار؛ همه‌چیز دیگر از هنر و سناریوی خودمان.

## ۶. نقشهٔ هنر → بازی (`tools/import_art.py`)
- هر `art_drop/<نام>/asset.json` → `game/assets/<نام>/` + فایل Import؛ `draft-until-user-approval` فقط هشدار.
- انیمیشن‌های شخصیت در `art_drop/{kairo,ilara}/home/anim/`، نام‌گذاری `<anim>_NN.png` (۱۲۸×۱۲۸؛ `climb_up` ۱۹۲×۱۹۲)، خط پا y=124، ~۹fps. `side`: `walk_side run_side hop dash hack wall_jump death`. `topdown`: `walk_{down,up,left}` (راست=آینه)، `leap_down climb_up`، `{dash,hack,hurt}_{down,up,left}`، `emotions_topdown` (ایلارا).
- کاشی سه‌چهارم: **`tiles_ch1_v2`** (نه `tiles_ch1` قدیمی)؛ کاشی نمای کناری: `tiles_side_ch1`. هر دو ۶۴px + `_32`؛ ۱۸–۲۰ کاشی به ترتیب سطری ؛ نقش و نوع برخورد هر کاشی در `names.json` کنار آن و جدول `art/TILE_ROLES.md`.
- پارالکس: `art_drop/parallax/ch1/<صحنه>_{far,mid,fore}_1280x720.png` برای `house street basement electric workshop launch`؛ `fore`/`mid` شفاف.
- UI/آیکن‌ها: `art_drop/icons/tools_v2/{climb,leap,dash,hack}.png`؛ فونت `Erfan-Pixel-Regular.ttf` (مضرب ۱۶، Nearest)؛ متن‌های فارسی RTL.

## ۷. گام‌های کار (به ترتیب؛ هر گام کامیت «گام N:» و پوش روی شاخهٔ کاری)
- **T1** merge `origin/art/style-pipeline` به شاخهٔ کاری (`feat/topdown-3q`)؛ هرگز `master`.
- **T2** `tools/import_art.py` طبق بخش ۶ + آزمون.
- **T3** فیلد `camera_mode` (`side|topdown`) و `camera_follow` در قالب JSON مرحله و `level_loader`؛ پروفایل tuning از روی `camera_mode` انتخاب شود (نه دستی).
- **T4** `game/SIDEVIEW_SPEC.md` (مشخصات حالت `side` از `v0-sideview` و سند ۰۲) کنار `TOPDOWN_SPEC.md`.
- **T5** `GameMode` + `ScriptedSequence` + ماشهٔ مرحله (بخش ۴) روی `Cutscene`.
- **T6** دوربین نرم هر دو حالت (بخش ۳) + تعویض حالت بین مرحله‌ها.
- **T7** مرحلهٔ ۱ (`side`)، سپس مرحلهٔ ۲ (`topdown`)، سپس مرحلهٔ ۳ (`side`) با نقشه‌های سند ۰۲ §۱۱ و توالی‌های ورودی/خروجی هر مرحله.
- **T8** اعتبارسنج حل‌پذیری برای هر دو حالت (`test_solvable.gd`)؛ `topdown` طبق `TOPDOWN_SPEC §۸`.
- **T9** بازی‌تست دستی + گزارش؛ سپس عکس‌های فروشگاه از بازی در حال اجرا.
معیار پذیرش هر گام: آزمون‌ها سبز، بدون کلید/توکن در مخزن، `git diff` قبل از کامیت بررسی شود.

## ۸. قواعد ثابت
شاخه‌ها: `feat/topdown-3q` یا شاخهٔ هنر؛ پوش مستقیم به `master` ممنوع. تصمیم تازه در `DECISIONS.md`. اگر مشخصات تناقض داشت **بایست و بپرس**. هنر ساخته‌شده با کد فقط `art/drafts/` است.

## ۱۰. RPG: نبرد نوبتی، افکت نبرد، نقشهٔ قابل‌راه‌رفتن (D-ART-09)
مرجع هویت/سناریو: `docs/09_screenplay_rpg_ch1-8.md`؛ مرجع طراحی: `docs/08_rpg_battle_and_overworld.md`. گام‌های تازه (بعد از T6؛ ترتیب):
- **T10** بازنویسی اسناد: ۰۱ (هویت)، ۰۲ (ماشین حالت `OVERWORLD/BATTLE`، JSON مرحله با `encounters`)، ۰۴ (دارایی‌های نبرد/نقشه)، ۰۵ (محدودهٔ v1)؛ به‌روزرسانی `TOPDOWN_SPEC`. **اگر چیزی تناقض داشت بایست و بپرس.**
- **T11** `Overworld` (نقشهٔ قابل‌راه‌رفتن فصل ۱، ۳ گره باز + قفل نمایشی، دروازه ← مرحله، دشمن دیدنی ← نبرد).
- **T12** `Battle` (نوبتی، ضربهٔ هم‌زمان، دفاع، انرژی رشته، قصد دشمن و قطع‌کردن، پیوند، فرار) با `tuning.json` پروفایل `battle`؛ آزمون واحد برای پنجره‌های زمان و ترتیب نوبت.
- **T13** افکت و رابط نبرد از `art_drop/battle_fx/*` و `art_drop/battle_ui/*` (وقتی رسید؛ تا آن موقع جای‌نگهدار).
- **T14** سه نبرد v1 و آموزش آن‌ها (جدول §۵ سند ۰۸) + شکست = شروع دوبارهٔ نبرد < ۲ ثانیه.
- **T15** نواحی ۱–۳: اکتشاف `topdown` + **اتاق‌های چالش `side`** (`camera_zone` با تغییر خودکار و نرم دوربین ۰٫۶ث وسط ناحیه، بدون لمس، مرگ بی‌نهایت، ریستارت <۰٫۳ث، شمارندهٔ مرگ؛ سند ۰۹ §۲ب) + توالی‌های اسکریپتی. T7/T8 (سطح‌ها و اعتبارسنج حل‌پذیری هر دو حالت) دوباره معتبرند.
- **T16** بازی‌تست و گزارش.
محدودیت: هیچ محتوایی از بازی مرجع (شخصیت/نقشه/رابط/نام/متن/افکت) کپی نشود.

## ۹. باز مانده (از کاربر)
ابطال توکن‌های Cloudflare؛ لباس سبز ایلارا در خانه؛ تأیید نهایی هنر (همه draft).

> **D-ART-09d:** دوربین وسط ناحیه خودکار عوض می‌شود (`camera_zone` در JSON مرحله؛ تغییر `camera_mode` پویا به‌جای ثابت‌بودن در کل مرحله). T3 را بر همین اساس پیاده کن.

## ۱۱. مسیر هنر تازه برای RPG (برای tools/import_art.py)
`art_drop/overworld/ch1/*` (گره‌ها/مسیر/دروازه/نشانگر)، `art_drop/explore/props/*` (اشیای تعاملی)، `art_drop/explore/pickups/*` (جمع‌شدنی/نشانگر/افکت اکتشاف)، بعداً `art_drop/battle_fx|battle_ui|battle_bg|npc|enemies_battle`. هر پوشه `asset.json` دارد؛ نام فایل = شناسهٔ دارایی. همه پیش‌نویس تا تأیید کاربرند.

### مسیرهای هنر RPG (به‌روز، دستهٔ ۱۲–۱۴)
`art_drop/battle_bg/` (basement, workshop, house, launch)، `art_drop/enemies/battle_nexa/`، `art_drop/boss/guardian_battle/`، `art_drop/effects/bond_two_skies/`، `art_drop/ui/explore_hud/`، `art_drop/npc/survivors/`، `art_drop/explore/{props,pickups}/`، `art_drop/overworld/ch1/`. در انتظار: `battle_fx`, `battle_ui`, پس‌زمینهٔ نبرد خیابان (دستهٔ ۱۱).
