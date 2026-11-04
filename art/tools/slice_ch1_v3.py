#!/usr/bin/env python3
"""برش دستهٔ ۳ فصل ۱: دویدن/پرش/مرگ و برگشت (لباس خانگی)، صحنهٔ مقدمه، پارالکس میانی.
  python3 -I art/tools/slice_ch1_v3.py     (اصل‌ها: art/raw/ch1_v3/*_full.png)
هر برگه ۳×۲ سلول؛ مبنای زمین هر ردیف = پایین‌ترین نقطهٔ فریم‌های همان ردیف (برای حفظ ارتفاع پرش)."""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from PIL import Image
import slice_ch1_v1 as v1
RAW = "art/raw/ch1_v3"
def cells(sheet):
    a = v1.key(f"{RAW}/{sheet}_full.png"); H, W = a.shape[:2]; out = []
    for i in range(6):
        c, r = i % 3, i // 3; cell = a[r * H // 2:(r + 1) * H // 2, c * W // 3:(c + 1) * W // 3].copy()
        al = cell[..., 3] > 0
        # حذف لکه‌های ریز پراکنده نزدیک مرز سلول: فقط pixel‌های درون ۳٪ حاشیه نگه داشته می‌شوند
        out.append(Image.fromarray(cell, "RGBA"))
    return out
def anim(sheet, who, s, name, n=6):
    cs = cells(sheet); bbs = [c.getbbox() for c in cs]; assert all(bbs), sheet
    sc = [v1.scale(c, s) for c in cs]
    q = v1.quant(sc, 64)
    bb = [x.getbbox() for x in q]; ground = [max(bb[r * 3 + j][3] for j in range(3)) for r in range(2)]
    out = f"art_drop/{who}/home/anim"; os.makedirs(out, exist_ok=True); frames = []; sizes = []
    for i, im in enumerate(q):
        b = bb[i]; arr = np.array(im)[..., 3] > 0; xs = np.nonzero(arr.any(0))[0]; cx = int(np.average(np.nonzero(arr)[1]))
        cv = Image.new("RGBA", (128, 128), (0, 0, 0, 0)); x = 64 - cx; y = 124 - ground[i // 3]
        # برش در صورت بیرون‌زدگی از بوم
        cv.alpha_composite(im, (max(x, 0) if x >= 0 else 0, 0)) if False else cv.paste(im, (x, y), im)
        cv.save(f"{out}/{name}_{i:02d}.png"); frames.append(cv); sizes.append(list(b[2:]) )
    strip = Image.new("RGBA", (128 * n, 128)); [strip.paste(c, (128 * i, 0)) for i, c in enumerate(frames)]; strip.save(f"{out}/{name}_strip.png")
    return sizes
def mid(n):
    a = v1.key(f"{RAW}/parallax_mid_{n}_full.png"); Image.fromarray(a, "RGBA").resize((1280, 720), Image.LANCZOS).save(f"art_drop/parallax/ch1/{n}_mid_1280x720.png")
def run():
    os.makedirs("art_drop/parallax/ch1", exist_ok=True); rep = {}
    for who, s in (("kairo", 0.1972), ("ilara", 0.2115)):
        for sh, nm in (("run_side", "run_side"), ("hop", "hop"), ("death_respawn", "death")):
            rep[f"{who}_{nm}"] = anim(f"{who}_home_{sh}", who, s, nm)
    for n in ("house", "street", "basement"): mid(n)
    os.makedirs("art_drop/scenes/ch1", exist_ok=True)
    Image.open(f"{RAW}/scene_intro_full.png").convert("RGB").resize((1280, 720), Image.LANCZOS).save("art_drop/scenes/ch1/intro_1280x720.png")
    print(json.dumps(rep))
if __name__ == "__main__": run()
