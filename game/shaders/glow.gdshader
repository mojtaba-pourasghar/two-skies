// هالهٔ نور نقطه‌ای — سند ۱۴ بند ۱ و ۲
//
// نور از **منبع دیدنی** می‌آید: مرکز و شعاعش در نقشهٔ افکت اتاق است.
// افت شعاعی نرم (smoothstep روی مربع فاصله) تا لبهٔ دایره دیده نشود.
//
// `clip_rect` ناحیهٔ مجاز را در مختصات اتاق محدود می‌کند: مثلاً نور شهر
// فقط پشت پنجره، نه روی دیوار کنارش. سند ۱۴ بند ۶ صریح می‌گوید نور
// نباید روی ناحیهٔ سایه‌دار نقاشی بیفتد.
shader_type canvas_item;
render_mode blend_add;

uniform vec4 tint = vec4(1.0);
// ناحیهٔ خود گره در مختصات اتاق: (x, y, w, h)
uniform vec4 node_rect = vec4(0.0, 0.0, 1.0, 1.0);
// ناحیهٔ مجاز در مختصات اتاق؛ w یا h صفر یعنی بی‌حد
uniform vec4 clip_rect = vec4(0.0);
uniform float feather = 40.0;
// ماسک تصویری در مختصات اتاق (REQ-029، `clip_mask` نقشهٔ افکت): نور فقط
// جایی که ماسک روشن است. برای نوری که باید فقط روی پنل‌ها بیفتد، نه کف
// تاریک بینشان — کاری که یک مستطیل نمی‌تواند.
uniform bool use_clip_tex = false;
uniform sampler2D clip_tex : filter_linear, repeat_disable;
uniform vec2 space = vec2(1280.0, 720.0);
// توان افت: ۲ یعنی شبیه افت فیزیکی نور، ۱ یعنی خطی و مصنوعی
uniform float falloff = 2.2;

void fragment() {
	vec2 d = UV - vec2(0.5);
	float r = length(d) * 2.0;
	float a = pow(clamp(1.0 - r, 0.0, 1.0), falloff);

	if (clip_rect.z > 0.0 && clip_rect.w > 0.0) {
		vec2 room = node_rect.xy + UV * node_rect.zw;
		vec2 lo = clip_rect.xy;
		vec2 hi = clip_rect.xy + clip_rect.zw;
		float f = max(1.0, feather);
		float mx = smoothstep(lo.x - f, lo.x + f, room.x)
			* (1.0 - smoothstep(hi.x - f, hi.x + f, room.x));
		float my = smoothstep(lo.y - f, lo.y + f, room.y)
			* (1.0 - smoothstep(hi.y - f, hi.y + f, room.y));
		a *= mx * my;
	}
	if (use_clip_tex) {
		vec2 room = node_rect.xy + UV * node_rect.zw;
		a *= texture(clip_tex, room / space).r;
	}
	COLOR = vec4(tint.rgb, 1.0) * a * tint.a;
}
