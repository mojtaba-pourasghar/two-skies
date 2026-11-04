#!/usr/bin/env python3
"""برش دستهٔ ۲ فصل ۱: راه رفتن لباس خانگی، پرتره‌ها، کاشی‌ها، پارالکس دور.
  python3 -I art/tools/slice_ch1_v2.py     (اصل‌ها: art/raw/ch1_v2/*_full.png)"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from PIL import Image
from scipy import ndimage
import slice_ch1_v1 as v1
v1.RAW = "art/raw/ch1_v2"
def anims(sheet, who, s, anim, n):
    ims, rows = v1.items(sheet, dil=8, minarea=3000); assert len(ims) == n, (sheet, rows)
    q = v1.quant([v1.scale(i, s) for i in ims], 64)
    out = f"art_drop/{who}/home/anim"; os.makedirs(out, exist_ok=True)
    cv = []
    for i, im in enumerate(q):
        c = Image.new("RGBA", (128, 128), (0, 0, 0, 0)); c.paste(im, ((128 - im.width) // 2, 124 - im.height), im); c.save(f"{out}/{anim}_{i:02d}.png"); cv.append(c)
    strip = Image.new("RGBA", (128 * n, 128)); [strip.paste(c, (128 * i, 0)) for i, c in enumerate(cv)]; strip.save(f"{out}/{anim}_strip.png")
    return [im.size for im in q]
def portraits(sheet, who):
    im = Image.open(f"{v1.RAW}/{sheet}_full.png").convert("RGB"); W, H = im.size; names = ["neutral", "angry", "shocked", "sad", "happy", "crying"]
    d = f"art_drop/portraits/{who}_home"; os.makedirs(d, exist_ok=True)
    for i, n in enumerate(names):
        c, r = i % 3, i // 3; cell = im.crop((c * W // 3, r * H // 2, (c + 1) * W // 3, (r + 1) * H // 2)); cell.save(f"{d}/{n}.png")
        a = np.array(cell).astype(int); bgc = np.median(np.concatenate([a[:6, :6].reshape(-1, 3), a[:6, -6:].reshape(-1, 3)]), axis=0)
        near = np.abs(a - bgc).sum(-1) < 40; lab, k = ndimage.label(near); border = set(lab[0]) | set(lab[-1]) | set(lab[:, 0]) | set(lab[:, -1]); border.discard(0)
        m = np.isin(lab, list(border)); Image.fromarray(np.dstack([a.astype(np.uint8), np.where(m, 0, 255).astype(np.uint8)]), "RGBA").save(f"{d}/{n}_alpha.png")
def tiles(sheet, scene):
    ims, rows = v1.items(sheet, dil=6, minarea=20000, rowgap=120); assert len(ims) == 18, (sheet, rows)
    d = f"art_drop/tiles_ch1/{scene}"; os.makedirs(d, exist_ok=True); meta = {}
    for i, im in enumerate(ims):
        t = im.convert("RGBA"); t64 = t.resize((64, round(64 * t.height / t.width)), Image.BOX)
        t32 = t.resize((32, round(32 * t.height / t.width)), Image.BOX)
        t64.save(f"{d}/{scene}_{i:02d}.png"); t32.save(f"{d}/{scene}_{i:02d}_32.png"); meta[f"{scene}_{i:02d}"] = list(t64.size)
    json.dump({"status": "draft-until-user-approval", "note": "فقط برش اولیه؛ ترتیب سطری ۶×۳؛ لبهٔ بنفش جایگزین نشده", "tiles_64": meta}, open(f"{d}/asset.json", "w"), indent=1, ensure_ascii=False)
    return rows
def run():
    rep = {}
    rep["kairo_walk"] = anims("kairo_home_walk_side", "kairo", 0.1972, "walk_side", 6)
    rep["ilara_walk"] = anims("ilara_home_walk_side", "ilara", 0.2115, "walk_side", 6)
    portraits("kairo_home_portraits", "kairo"); portraits("ilara_home_portraits", "ilara")
    rep["tiles_house"] = tiles("tileset_house", "house"); rep["tiles_street"] = tiles("tileset_street", "street")
    os.makedirs("art_drop/parallax/ch1", exist_ok=True)
    for n in ("house", "street", "basement"):
        Image.open(f"{v1.RAW}/parallax_far_{n}_full.png").convert("RGB").resize((1280, 720), Image.LANCZOS).save(f"art_drop/parallax/ch1/{n}_far_1280x720.png")
    print(json.dumps(rep, ensure_ascii=False))
if __name__ == "__main__": run()
