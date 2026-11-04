#!/usr/bin/env python3
"""برش شیت‌های انیمیشن Canva (پس‌زمینهٔ magenta) به فریم‌های جدا روی بوم ثابت، با مقیاس یکسان برای هر شیت.
  python3 -I art/tools/slice_anim_sheets.py
خروجی: art_drop/anim_concept/<who>/<anim>_<NN>.png + نوار + asset.json (وضعیت: concept — جایگزین اسپرایت تأییدشده نیست)"""
import json, os
import numpy as np
from PIL import Image
from scipy import ndimage
SHEETS = {  # نام: (فایل، [(anim، تعداد فریم)] به ترتیب ردیف)
 "kairo": [("art/raw/anim/kairo_run_full.png", [("run", 7)]),
           ("art/raw/anim/kairo_dash_hack_hop_full.png", [("dash", 4), ("hack", 4), ("hop", 4)]),
           ("art/raw/anim/kairo_death_respawn_full.png", [("death", 6)])],
 "ilara": [("art/raw/anim/ilara_run_full.png", [("run", 8)]),
           ("art/raw/anim/ilara_stay_come_hop_full.png", [("stay", 4), ("come", 4), ("hop", 4)])]}
def key(path):
    im = np.array(Image.open(path).convert("RGB")).astype(int); r, g, b = im[..., 0], im[..., 1], im[..., 2]
    m = (r > 170) & (b > 170) & (g < 120)
    a = np.where(m, 0, 255).astype(np.uint8)
    edge = (~m) & (r > g * 1.3) & (b > g * 1.3)
    im[edge, 0] = np.minimum(r[edge], g[edge] + 12); im[edge, 2] = np.minimum(b[edge], g[edge] + 12)
    return Image.fromarray(np.dstack([im.astype(np.uint8), a]), "RGBA")
def components(rgba, rows_spec):
    a = np.array(rgba)[..., 3] > 0
    lab, n = ndimage.label(ndimage.binary_dilation(a, iterations=7))
    objs = ndimage.find_objects(lab); items = []
    for i, sl in enumerate(objs):
        area = (lab[sl] == i + 1).sum()
        if area > 2500:
            sub = a[sl] & (lab[sl] == i + 1)
            if sub.sum() > 1500: items.append((sl, i + 1))
    ys = sorted(items, key=lambda t: (t[0][0].start + t[0][0].stop) / 2)
    out, idx = [], 0
    for name, cnt in rows_spec:
        row = sorted(ys[idx:idx + cnt], key=lambda t: t[0][1].start); idx += cnt; out.append((name, row, lab))
    return out, len(items)
def run():
    meta = {}
    for who, sheets in SHEETS.items():
        meta[who] = {}
        for path, spec in sheets:
            rgba = key(path); a = np.array(rgba)
            # فریم‌های هر ردیف: برای ردیف‌های چندتایی، مرکز y را برای گروه‌بندی بگیر
            allc, n = components(rgba, [(nm, 0) for nm, _ in spec]) if False else (None, 0)
            lab, nlab = ndimage.label(ndimage.binary_dilation(a[..., 3] > 0, iterations=7))
            objs = ndimage.find_objects(lab); items = []
            for i, sl in enumerate(objs):
                m = (lab[sl] == i + 1) & (a[sl][..., 3] > 0)
                if m.sum() > 1500: items.append((sl, i + 1))
            items.sort(key=lambda t: (t[0][0].start + t[0][0].stop) / 2)
            idx = 0
            for name, cnt in spec:
                row = sorted(items[idx:idx + cnt], key=lambda t: t[0][1].start); idx += cnt
                frames = []
                for sl, lid in row:
                    f = np.zeros_like(a); m = lab == lid; m[:] = m
                    f[sl] = np.where((lab[sl] == lid)[..., None], a[sl], 0); frames.append(Image.fromarray(f[sl]))
                hmax = max(f.height for f in frames); s = min(1.0, 104 / hmax)
                W = 192 if name in ("dash",) else 128; H = 128
                out = f"art_drop/anim_concept/{who}"; os.makedirs(out, exist_ok=True); strip = Image.new("RGBA", (W * len(frames), H), (0, 0, 0, 0))
                for i, f in enumerate(frames):
                    g = f.resize((max(1, round(f.width * s)), max(1, round(f.height * s))), Image.LANCZOS)
                    if g.width > W: g = g.resize((W, round(g.height * W / g.width)), Image.LANCZOS)
                    cv = Image.new("RGBA", (W, H), (0, 0, 0, 0)); cv.paste(g, ((W - g.width) // 2, H - 4 - g.height), g)
                    cv.save(f"{out}/{name}_{i:02d}.png"); strip.paste(cv, (i * W, 0))
                strip.save(f"{out}/{name}_strip.png"); meta[who][name] = {"frames": len(frames), "frame_size": [W, H], "scale": round(s, 3)}
    json.dump({"status": "CONCEPT-NOT-APPROVED", "note": "Canva با مرجع پرتره؛ سبک chibi/ساده‌تر از برگهٔ تأییدشده. جایگزین اسپرایت تأییدشده نیست.", "anims": meta},
              open("art_drop/anim_concept/asset.json", "w"), indent=1, ensure_ascii=False)
    print(json.dumps(meta, ensure_ascii=False))
if __name__ == "__main__": run()
