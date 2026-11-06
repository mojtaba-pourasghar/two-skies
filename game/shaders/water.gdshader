// آب — جابه‌جایی UV دو لایه (سند ۱۳)
//
// دو موج با سرعت و طول‌موج متفاوت روی هم: یک لایه تنها الگوی تکرارشوندهٔ
// آشکاری می‌سازد که چشم فوراً می‌گیردش.
shader_type canvas_item;

uniform float amp_px = 1.6;
uniform float speed = 0.6;
uniform float wave_len = 28.0;
uniform vec2 region_px = vec2(64.0, 64.0);
uniform float shimmer = 0.06;   // نوسان روشنایی، نه فقط جابه‌جایی
uniform vec4 tint = vec4(1.0);
// بریده در مختصات نرمال‌شدهٔ بافت (توضیح در sway.gdshader)
uniform vec4 uv_rect = vec4(0.0, 0.0, 1.0, 1.0);

void fragment() {
	float t = TIME * speed * 6.2831853;
	vec2 local = (UV - uv_rect.xy) / uv_rect.zw;
	float y = local.y * region_px.y;
	float x = local.x * region_px.x;
	float dx = sin(y / wave_len + t) * amp_px
		+ sin(y / (wave_len * 0.41) - t * 1.7) * amp_px * 0.45;
	float dy = cos(x / (wave_len * 1.3) + t * 0.8) * amp_px * 0.25;
	vec2 uv = clamp(UV + vec2(dx / region_px.x * uv_rect.z,
		dy / region_px.y * uv_rect.w),
		uv_rect.xy, uv_rect.xy + uv_rect.zw);
	vec4 c = texture(TEXTURE, uv) * tint;
	c.rgb *= 1.0 + shimmer * sin(y / (wave_len * 0.7) + t * 1.3);
	COLOR = c;
}
