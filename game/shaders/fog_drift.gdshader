// مه و دود رانشی — پیمایش UV دو لایه با سرعت متفاوت (سند ۱۳ بند ۳)
//
// دو لایه لازم است، نه یکی: یک لایه با هر سرعتی «نواری که رد می‌شود»
// دیده می‌شود. دو لایه با سرعت ناهم‌خوان، ابرِ بی‌الگو می‌سازد.
shader_type canvas_item;

uniform float speed_a = 0.012;
uniform float speed_b = -0.007;
uniform float scale_b = 1.7;
uniform float strength = 0.55;   // سهم لایهٔ دوم
// رنگ و شفافیت از کد می‌آید، نه از `modulate` گره.
//
// در شیدر canvas_item گودو، `COLOR` هنگام ورود به fragment **خودش
// بافت ضرب در رنگ گره** است. ضرب دوبارهٔ آن در COLOR یعنی مربع کردن
// بافت: ناحیه‌های تیره سیاه می‌شوند. اولین رفع من همین بود و در R1a
// پنج مستطیل سیاه روی نقاشی گذاشت. پس tint صریح است.
uniform vec4 tint = vec4(1.0);

void fragment() {
	vec2 ua = UV + vec2(TIME * speed_a, sin(TIME * 0.07) * 0.02);
	vec2 ub = UV * scale_b + vec2(TIME * speed_b, cos(TIME * 0.05) * 0.015);
	vec4 a = texture(TEXTURE, fract(ua));
	vec4 b = texture(TEXTURE, fract(ub));
	// **رنگ و آلفای گره در خودِ COLOR می‌آید.** نوشتن مستقیم روی COLOR
	// آن را دور می‌ریزد، و مه با رنگ خام بافت (فیروزه‌ای) و آلفای ۱
	// کشیده می‌شود. در اولین ضبط R1a همین شد: کل اتاق گرم، سبزآبی.
	COLOR = mix(a, b, strength) * tint;
}
