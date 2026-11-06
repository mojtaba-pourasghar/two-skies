#!/usr/bin/env python3
"""دستهٔ ۲۲/۲۳: مه tileable، شعلهٔ اجاق/نئون/در، و نسخهٔ پرجزئیات ۱۶۸۰×۹۴۴ اتاق‌ها. اصل‌ها: art/raw/ch1_v22/ و راوهای اتاق"""
import glob, json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from PIL import Image
import slice_ch1_v1 as v1
import slice_ch1_v20 as v20
v1.RAW = "art/raw/ch1_v22"; v20.v1.RAW = "art/raw/ch1_v22"
def tileable(a):
    h, w = a.shape[:2]; r = np.roll(np.roll(a, h // 2, 0), w // 2, 1)
    y = np.minimum(np.arange(h), h - 1 - np.arange(h)) / (h / 2.0); x = np.minimum(np.arange(w), w - 1 - np.arange(w)) / (w / 2.0)
    m = np.clip(np.minimum.outer(y, x) * 2.0, 0, 1)  # 1 وسط، 0 لبه
    m = m * m * (3 - 2 * m)
    return a * m + r * (1 - m)
def fog():
    d = "art_drop/overlays/fog"; os.makedirs(d, exist_ok=True); info = {}
    for n, (lo, hi) in {"thin": (2, 99.5), "thick": (5, 98), "smoke": (5, 99)}.items():
        g = np.array(Image.open(f"{v1.RAW}/fog_{n}_full.png").convert("L")).astype(float)
        g = tileable(g); a, b = np.percentile(g, lo), np.percentile(g, hi); al = np.clip((g - a) / max(b - a, 1), 0, 1)
        o = Image.fromarray(np.dstack([np.full(g.shape, 255, np.uint8)] * 3 + [(al * 255).astype(np.uint8)]), "RGBA").resize((1024, 1024), Image.LANCZOS)
        o.save(f"{d}/sheet_{n}.png"); info[n] = [1024, 1024]
    json.dump({"status": "draft-until-user-approval", "tileable": True, "color": "white-alpha (رنگ را کد بزند)", "sheets": info, "note": "آلفا=روشنایی نرمال‌شده؛ مصرف: UV scroll دو لایه با سرعت‌های متفاوت، آلفای کل ۰٫۰۴–۰٫۲"}, open(f"{d}/asset.json", "w"), indent=1, ensure_ascii=False)
def ambient():
    a = v20.keyed("anim23"); out = {}
    for nm, y0, y1 in (("stove_fire", 40, 230), ("neon_bar", 270, 440), ("neon_arrow", 490, 610), ("door_open", 630, 900)):
        sub = a[y0:y1]; m = sub[..., 3] > 0; segs = v20.segments(m, mingap=10)
        if len(segs) != 6: print("WARN", nm, len(segs), segs); continue
        fr = []
        for x0, x1 in segs:
            im = Image.fromarray(sub[:, x0:x1 + 1].copy(), "RGBA"); fr.append(im.crop(im.getbbox()))
        W = max(f.width for f in fr); H = max(f.height for f in fr); d = f"art_drop/ambient/ch1/{nm}"; os.makedirs(d, exist_ok=True)
        for i, f in enumerate(fr):
            c = Image.new("RGBA", (W, H), (0, 0, 0, 0)); c.paste(f, ((W - f.width) // 2, H - f.height), f)
            c = c.resize((max(1, W // 2), max(1, H // 2)), Image.BOX); c.save(f"{d}/{nm}_{i}.png"); out[nm] = list(c.size)
        json.dump({"status": "draft-until-user-approval", "frames": 6, "size": out[nm], "fps": 8, "loop": nm != "door_open", "anchor": "bottom-center", "camera": "topdown"}, open(f"{d}/asset.json", "w"), indent=1)
    print(out)
def hires():
    d = "art_drop/rooms/ch1/hires"; os.makedirs(d, exist_ok=True); done = {}
    srcs = {"r1b_corridor": "room_house_corridor_full.png", "r1c_kitchen": "room_house_kitchen_full.png", "c1_balcony": "c1_balcony_full.png", "c2_laser_alley": "c2_laser_full.png", "c3_electric_hall": "c3_electric_full.png",
            "r1a_house": "scene_house_full.png", "r1d_ilara_bedroom": "scene_ilara_bedroom_full.png", "r1e_basement": "scene_basement_full.png", "s2b_street": "scene_street_full.png"}
    for n, f in srcs.items():
        p = (glob.glob(f"art/raw/**/{f}", recursive=True) or [None])[0]
        if p and "side" not in p:
            im = Image.open(p).convert("RGB"); im.save(f"{d}/{n}_{im.width}x{im.height}.png"); done[n] = im.size
    json.dump({"status": "draft-until-user-approval", "note": "اصل Canva بدون کاهش به ۱۲۸۰؛ برای زوم تا ۱٫۳× شفاف. مختصات ۱۲۸۰×۷۲۰ با ضرب ۱٫۳۱۲۵ (X و Y) به آن‌ها می‌رسد", "rooms": {k: list(v) for k, v in done.items()}}, open(f"{d}/asset.json", "w"), indent=1, ensure_ascii=False); print(done)
if __name__ == "__main__": fog(); ambient(); hires()
