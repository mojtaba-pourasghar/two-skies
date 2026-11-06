// لکهٔ مه — سند ۱۴ بند ۴
//
// ورقهٔ tileable سفید+آلفا (`overlays/fog/sheet_*`) که **دو لایه** با
// جهت و سرعت متفاوت روی هم می‌لغزند. یک لایه، نواری می‌شود که رد می‌شود.
//
// لبه‌ها پَر داده می‌شوند (`edge_feather`) وگرنه مستطیل مه دیده می‌شود —
// که همان «افکت دیدن به‌جای فضا دیدن» است که سند ۱۴ بند ۷ رد می‌کند.
shader_type canvas_item;

uniform sampler2D sheet : repeat_enable, filter_linear;
uniform vec4 tint = vec4(1.0);
uniform vec2 rect_px = vec2(256.0, 256.0);
// جابه‌جایی هر لایه بر حسب **پیکسل اتاق**؛ کد هر فریم به‌روزش می‌کند
uniform vec2 offset_a = vec2(0.0);
uniform vec2 offset_b = vec2(0.0);
uniform float tile_px = 420.0;    // یک دور ورقه چند پیکسل اتاق است
uniform float scale_b = 1.6;
uniform float feather_px = 80.0;

void fragment() {
	vec2 room = UV * rect_px;
	float a = texture(sheet, (room + offset_a) / tile_px).a;
	float b = texture(sheet, (room * scale_b + offset_b) / tile_px).a;
	// ضرب، نه جمع: دو لایه که روی هم می‌افتند نباید مه را دو برابر کنند
	float m = 1.0 - (1.0 - a) * (1.0 - b * 0.85);

	float f = max(1.0, feather_px);
	float ex = smoothstep(0.0, f, room.x)
		* (1.0 - smoothstep(rect_px.x - f, rect_px.x, room.x));
	float ey = smoothstep(0.0, f, room.y)
		* (1.0 - smoothstep(rect_px.y - f, rect_px.y, room.y));

	COLOR = vec4(tint.rgb, m * ex * ey * tint.a);
}
