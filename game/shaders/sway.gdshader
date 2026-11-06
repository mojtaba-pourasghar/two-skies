// تکان برگ و پرده — ریشه ثابت، نوک آزاد (سند ۱۳، جدول تکنیک‌ها)
//
// روی یک **بریده از خود نقاشی** می‌نشیند، نه روی هنر تازه: ناحیهٔ برگ یا
// پرده از تصویر اتاق بریده می‌شود و همان‌جا با وزن تکان می‌خورد.
//
// **نکتهٔ UV:** در Sprite2D با `region_enabled`، مقدار `UV` نه ۰ تا ۱ درون
// بریده، بلکه سهم آن بریده از **کل** بافت است (مثلاً ۰٫۰۵ تا ۰٫۱۴). پس
// مختصات محلی باید از `uv_rect` حساب شود، وگرنه هم وزن غلط درمی‌آید و هم
// جابه‌جایی ده‌ها برابر می‌شود.
shader_type canvas_item;

uniform float amplitude = 2.0;     // بیشینهٔ جابه‌جایی نوک، بر حسب پیکسل
uniform float speed = 1.1;         // هرتز
uniform float phase = 0.0;         // فاز، تا دو بوتهٔ کنار هم هم‌زمان نشوند
uniform float gust = 0.35;         // وزش کند روی تکان تند
uniform vec2 region_px = vec2(64.0, 64.0);
// بریده در مختصات نرمال‌شدهٔ بافت: (x, y, w, h)
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
// 0 = ریشه پایین (برگ، بوته، درخت) ، 1 = ریشه بالا (پرده، بنر، پارچه)
uniform int root_top = 0;
// وزن اضافی از بیرون (عبور بازیکن)، کد آن را موقت بالا می‌برد
uniform float push = 0.0;
// رنگ و شفافیت از کد می‌آید، نه از `modulate` گره: در شیدر canvas_item
// گودو، `COLOR` هنگام ورود به fragment خودش بافت ضرب در رنگ گره است و
// ضرب دوباره یعنی مربع کردن بافت (ناحیهٔ تیره سیاه می‌شود).
uniform vec4 tint = vec4(1.0);

void fragment() {
	vec2 local = (UV - uv_rect.xy) / uv_rect.zw;
	// وزن: صفر در ریشه، یک در نوک، با منحنی درجه دو تا خمش طبیعی باشد
	float w = root_top == 1 ? local.y : (1.0 - local.y);
	w = clamp(w, 0.0, 1.0);
	w = w * w;

	float t = TIME * speed * 6.2831853 + phase;
	float sway = sin(t) + gust * sin(t * 0.31 + 1.7);
	float dx_px = (amplitude + push) * w * sway;
	// پیکسل → سهم محلی → سهم کل بافت
	float dx = (dx_px / max(1.0, region_px.x)) * uv_rect.z;

	vec2 uv = UV + vec2(dx, 0.0);
	// بیرون از بریده چیزی کشیده نشود، وگرنه لبهٔ تکه کش می‌آید و
	// تصویرِ کنارش روی برگ تکرار می‌شود
	if (uv.x < uv_rect.x || uv.x > uv_rect.x + uv_rect.z) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(TEXTURE, uv) * tint;
	}
}
