// تکان گیاه و پرده و پیچک و لوستر — سند ۱۴ بند ۳
//
// **لولا در ریشه است.** نقطهٔ لولا (`pivot`) از نقشهٔ افکت اتاق می‌آید:
// برای گیاه پایین، برای پرده و لوستر بالا. وزن با فاصله از لولا زیاد
// می‌شود، پس ریشه نمی‌جنبد و نوک آزاد است.
//
// دامنه ≤۲ پیکسل و دورهٔ ۳ تا ۶ ثانیه. تندتر یا بزرگ‌تر از این، «تکان»
// دیده می‌شود نه باد.
//
// **نکتهٔ UV:** در Sprite2D با `region_enabled` مقدار `UV` سهم بریده از
// کل بافت است، نه ۰ تا ۱ درون بریده؛ پس `uv_rect` لازم است.
shader_type canvas_item;

uniform float amp_px = 2.0;
uniform float period_s = 4.5;
uniform float phase = 0.0;
// وزش: موج کند روی تکان اصلی. دامنه‌اش نسبی است.
uniform float gust = 0.0;
uniform vec2 region_px = vec2(64.0, 64.0);
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);
// لولا در مختصات محلی بریده، ۰ تا ۱
uniform vec2 pivot_local = vec2(0.5, 1.0);
// فشار بیرونی (عبور بازیکن)
uniform float push = 0.0;
uniform vec4 tint = vec4(1.0);

void fragment() {
	vec2 local = (UV - uv_rect.xy) / uv_rect.zw;
	// فاصله از لولا، نرمال‌شده به دورترین لبه
	float reach = max(pivot_local.y, 1.0 - pivot_local.y);
	float w = clamp(abs(local.y - pivot_local.y) / max(reach, 0.001), 0.0, 1.0);
	w = w * w;

	float t = TIME * 6.2831853 / max(period_s, 0.001) + phase;
	// دو فرکانس ناهم‌اندازه: الگوی تکرار آشکار نمی‌دهد
	float s = sin(t) + gust * sin(t * 0.37 + 1.1);
	float dx_px = (amp_px + push) * w * s;
	float dx = (dx_px / max(1.0, region_px.x)) * uv_rect.z;

	vec2 uv = UV + vec2(dx, 0.0);
	if (uv.x < uv_rect.x || uv.x > uv_rect.x + uv_rect.z) {
		COLOR = vec4(0.0);
	} else {
		COLOR = texture(TEXTURE, uv) * tint;
	}
}
