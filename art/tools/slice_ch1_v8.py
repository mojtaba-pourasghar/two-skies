#!/usr/bin/env python3
"""برش دستهٔ ۸: کاشی‌ست‌های نمای کناری (side) — خانه، خیابان، زیرزمین.
  python3 -I art/tools/slice_ch1_v8.py   (اصل‌ها: art/raw/ch1_v8/)
مقیاس یکسان برای همهٔ کاشی‌های یک برگه (S=0.265 ⇒ کاشی بزرگ ≈ ۶۴px؛ نسخهٔ _32 نصف)؛ ترتیب سطری."""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image
import slice_ch1_v1 as v1
v1.RAW = "art/raw/ch1_v8"
S = 0.265
def side_tiles(scene):
    ims, rows = v1.items(f"tileset_side_{scene}", dil=6, minarea=3000, rowgap=110)
    q = v1.quant([v1.scale(i, S) for i in ims], 64); d = f"art_drop/tiles_side_ch1/{scene}"; os.makedirs(d, exist_ok=True); meta = {}
    for i, im in enumerate(q):
        im.save(f"{d}/{scene}_side_{i:02d}.png"); v1.scale(im, 0.5).save(f"{d}/{scene}_side_{i:02d}_32.png"); meta[f"{scene}_side_{i:02d}"] = list(im.size)
    json.dump({"status": "draft-until-user-approval", "camera": "side", "scale": S, "rows": rows, "tiles_64": meta}, open(f"{d}/asset.json", "w"), indent=1, ensure_ascii=False)
    return rows, len(q)
def run():
    print(json.dumps({s: side_tiles(s) for s in ("house", "street", "basement")}))
if __name__ == "__main__": run()
