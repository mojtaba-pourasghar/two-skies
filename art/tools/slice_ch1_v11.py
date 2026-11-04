#!/usr/bin/env python3
"""برش دستهٔ ۱۰: پارالکس مراحل ۵–۸ (electric=۵، workshop=۶، launch=۷–۸) و کاشی‌ست‌های سه‌چهارم بدون‌درز.
  python3 -I art/tools/slice_ch1_v11.py   (اصل‌ها: art/raw/ch1_v11/)
خروجی کاشی: art_drop/tiles_ch1_v2/<صحنه>/ (جایگزین پیشنهادی tiles_ch1؛ قدیمی دست‌نخورده)."""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from PIL import Image
import slice_ch1_v1 as v1
v1.RAW = "art/raw/ch1_v11"
def parallax():
    os.makedirs("art_drop/parallax/ch1", exist_ok=True)
    for n in ("electric", "workshop", "launch"):
        Image.open(f"{v1.RAW}/parallax_far_{n}_full.png").convert("RGB").resize((1280, 720), Image.LANCZOS).save(f"art_drop/parallax/ch1/{n}_far_1280x720.png")
        for k in ("mid", "fore"):
            Image.fromarray(v1.key(f"{v1.RAW}/parallax_{k}_{n}_full.png"), "RGBA").resize((1280, 720), Image.LANCZOS).save(f"art_drop/parallax/ch1/{n}_{k}_1280x720.png")
def seam(im):
    a = np.array(im).astype(int); m = (a[:, 0, 3] > 0) & (a[:, -1, 3] > 0)
    h = np.abs(a[m, 0, :3] - a[m, -1, :3]).mean() if m.sum() > 8 else -1
    m2 = (a[0, :, 3] > 0) & (a[-1, :, 3] > 0); v = np.abs(a[0, m2, :3] - a[-1, m2, :3]).mean() if m2.sum() > 8 else -1
    return round(float(h), 1), round(float(v), 1)
def tiles(scene, inset=0):
    ims, rows = v1.items(f"tileset_td_{scene}", dil=6, minarea=20000, rowgap=120); assert len(ims) == 18, (scene, rows, len(ims))
    d = f"art_drop/tiles_ch1_v2/{scene}"; os.makedirs(d, exist_ok=True); meta = {}; sc = []
    for i, im in enumerate(ims):
        t = im.convert("RGBA")
        if inset: t = t.crop((inset, inset, t.width - inset, t.height - inset))
        t64 = t.resize((64, round(64 * t.height / t.width)), Image.BOX); t32 = t.resize((32, round(32 * t.height / t.width)), Image.BOX)
        t64.save(f"{d}/{scene}_{i:02d}.png"); t32.save(f"{d}/{scene}_{i:02d}_32.png"); meta[f"{scene}_{i:02d}"] = list(t64.size); sc.append(seam(t64))
    json.dump({"status": "draft-until-user-approval", "camera": "topdown", "inset_px": inset, "tiles_64": meta, "seam_hv": sc}, open(f"{d}/asset.json", "w"), indent=1)
    return rows, [s[0] for s in sc[:12]]
def run():
    parallax(); print(json.dumps({s: tiles(s) for s in ("house", "street", "basement")}))
if __name__ == "__main__": run()
