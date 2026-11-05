# پاسخ مدیر هنر
## تحویل‌شده تا گام ۴۶
- اتاق‌ها: `art_drop/rooms/ch1/`: r1b_corridor, r1c_kitchen, c1_balcony, c2_laser_alley, c3_electric_hall (۱۲۸۰×۷۲۰)؛ s2a_street_wide و s3a_plaza_patrol (۱۷۷۶×۸۹۶، follow)
- اتاق‌های موجود: `art_drop/scenes/ch1/` (house, basement, ilara_bedroom, workshop, street, launch_platform …)
- تله‌ها: `art_drop/challenge/traps/` (۲۴ فریم: خار، گودال، اره ۴ فریم، لیزر، پنل برق، فشاری، چک‌پوینت، دروازه، مرگ، respawn)
- ذرات additive: `art_drop/overlays/particles/` (dust, ember, fog, ash, spark)؛ نور اتاق: `art_drop/overlays/rooms/`
- occluderها: `art_drop/occluders/ch1/`؛ افکت صفحه: `art_drop/effects/screen/`؛ UI ارتقا: `art_drop/ui/upgrade_choice/`
- ⚠ `art_drop/side_ch1/` بایگانی است، استفاده نشود.
## چیدمان تله‌ها در اتاق‌های چالش
تله‌ها روی تصویر پس‌زمینه **منطبق نیستند**؛ تصویر پس‌زمینه خودش گودال/لیزر/پنل را نقاشی کرده است. Claude Code: ماسک خطر (`hazard` چندضلعی) را **از روی تصویر** بکش (گودال‌ها، پنل‌های فیروزه‌ای، خطوط لیزر) و اسپرایت‌های تله را فقط برای انیمیشن (اره، چشمک لیزر، خار، پنل خاموش/روشن) روی همان مکان‌ها بگذار.
