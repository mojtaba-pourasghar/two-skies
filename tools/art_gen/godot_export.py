"""ساخت فایل‌های Godot از اطلس‌ها: SpriteFrames و TileSet به شکل .tres متنی.

چرا متنی و نه باینری: .tres متن است، پس دیف دارد و بازبینی می‌شود، و اگر
هنرمند بعداً فایل را عوض کند تغییرش در گیت دیده می‌شود.
"""

from __future__ import annotations

from pathlib import Path

HEADER = "[gd_resource type=\"%s\" load_steps=%d format=3]\n\n"


def sprite_frames(
	out: Path,
	texture_res: str,
	*,
	frame_w: int,
	frame_h: int,
	animations: list[dict],
) -> Path:
	"""SpriteFrames از یک اطلس افقی.

	animations: [{"name": "idle", "start": 0, "count": 6, "fps": 12, "loop": true}]
	سند ۰۴: فریم‌ریت انیمیشن شخصیت ۱۲ فریم بر ثانیه.
	"""
	total = sum(int(a["count"]) for a in animations)
	lines = [HEADER % ("SpriteFrames", total + 2)]
	lines.append('[ext_resource type="Texture2D" path="%s" id="1_tex"]\n\n' % texture_res)

	for i in range(total):
		lines.append('[sub_resource type="AtlasTexture" id="f%d"]\n' % i)
		lines.append('atlas = ExtResource("1_tex")\n')
		lines.append('region = Rect2(%d, 0, %d, %d)\n\n' % (i * frame_w, frame_w, frame_h))

	lines.append('[resource]\nanimations = [')
	parts: list[str] = []
	for anim in animations:
		frames = ", ".join(
			'{\n"duration": 1.0,\n"texture": SubResource("f%d")\n}' % (int(anim["start"]) + n)
			for n in range(int(anim["count"]))
		)
		parts.append(
			'{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %.1f\n}'
			% (frames, "true" if anim.get("loop", True) else "false",
			   anim["name"], float(anim.get("fps", 12)))
		)
	lines.append(", ".join(parts))
	lines.append(']\n')

	out.parent.mkdir(parents=True, exist_ok=True)
	out.write_text("".join(lines), encoding="utf-8")
	return out


def tileset(
	out: Path,
	texture_res: str,
	*,
	tile: int,
	columns: int,
	rows: int = 1,
	collision_layer: int = 1,
	solid_tiles: list[int] | None = None,
) -> Path:
	"""TileSet از یک اطلس کاشی.

	solid_tiles: شمارهٔ کاشی‌هایی که برخورد کامل دارند (None یعنی همه).
	هر کاشی جامد همان چندضلعی کامل را می‌گیرد، تا ظاهر روی فیزیک اثر نگذارد.
	"""
	half = tile / 2.0
	box = "PackedVector2Array(%g, %g, %g, %g, %g, %g, %g, %g)" % (
		-half, -half, half, -half, half, half, -half, half
	)
	lines = [HEADER % ("TileSet", 2)]
	lines.append('[ext_resource type="Texture2D" path="%s" id="1_tex"]\n\n' % texture_res)
	lines.append('[sub_resource type="TileSetAtlasSource" id="atlas"]\n')
	lines.append('texture = ExtResource("1_tex")\n')
	lines.append('texture_region_size = Vector2i(%d, %d)\n' % (tile, tile))

	index = 0
	for y in range(rows):
		for x in range(columns):
			lines.append('%d:%d/0 = 0\n' % (x, y))
			if solid_tiles is None or index in solid_tiles:
				lines.append('%d:%d/0/physics_layer_0/polygon_0/points = %s\n' % (x, y, box))
			index += 1

	lines.append('\n[resource]\n')
	lines.append('tile_size = Vector2i(%d, %d)\n' % (tile, tile))
	lines.append('physics_layer_0/collision_layer = %d\n' % collision_layer)
	lines.append('physics_layer_0/collision_mask = 0\n')
	lines.append('sources/0 = SubResource("atlas")\n')

	out.parent.mkdir(parents=True, exist_ok=True)
	out.write_text("".join(lines), encoding="utf-8")
	return out
