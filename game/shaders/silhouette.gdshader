// سیلوئت کم‌رنگ بازیگرِ پنهان پشت occluder — تصمیم کاربر ۱۴۰۵/۰۸/۲۱
//
// وقتی بیش از ~۶۰٪ بازیگر زیر یک `cut` می‌رود، همان بازیگر دوباره روی
// مبل کشیده می‌شود: خط دور پررنگ‌تر و داخلِ کم‌رنگ، با رنگ سرد.
//
// چرا خط دور جدا از پرکردن: فقط پرکردنِ کم‌رنگ روی مبلِ تیره گم می‌شود،
// و فقط خط دور بی‌جان است. ترکیبشان جای بازیکن را می‌گوید بی‌آنکه
// وانمود کند او دیده می‌شود.
shader_type canvas_item;

uniform vec4 tint : source_color = vec4(0.55, 0.78, 1.0, 1.0);
uniform float fill_alpha = 0.28;
uniform float line_alpha = 0.55;
//: ضخامت خط دور بر حسب پیکسلِ بافت
uniform float outline_px = 1.5;
uniform vec2 tex_size = vec2(128.0, 128.0);
//: ۰ تا ۱ — کد نرم بالا و پایینش می‌برد تا ظاهر و ناپدید شدن پرشی نباشد
uniform float amount = 0.0;
uniform float cut_threshold = 0.35;

void fragment() {
	if (amount <= 0.001) {
		COLOR = vec4(0.0);
	} else {
		vec2 px = outline_px / tex_size;
		float a = texture(TEXTURE, UV).a;
		// بیشینهٔ آلفای همسایه‌ها: اگر خودش تهی است و همسایه پر، لبه است
		float n = 0.0;
		n = max(n, texture(TEXTURE, UV + vec2(px.x, 0.0)).a);
		n = max(n, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
		n = max(n, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
		n = max(n, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
		n = max(n, texture(TEXTURE, UV + px).a);
		n = max(n, texture(TEXTURE, UV - px).a);
		n = max(n, texture(TEXTURE, UV + vec2(px.x, -px.y)).a);
		n = max(n, texture(TEXTURE, UV + vec2(-px.x, px.y)).a);

		float inside = step(cut_threshold, a);
		float edge = step(cut_threshold, n) * (1.0 - inside);
		float al = inside * fill_alpha + edge * line_alpha;
		COLOR = vec4(tint.rgb, al * amount);
	}
}
