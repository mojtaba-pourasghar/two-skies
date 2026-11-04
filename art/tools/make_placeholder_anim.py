#!/usr/bin/env python3
"""انیمیشن‌های «جای‌نگهدار» از روی اسپرایت‌های تأییدشده، فقط با جابه‌جایی اعداد صحیح پیکسل (بدون بازنقاشی/درون‌یابی).
فقط پیش‌نویس موقت است تا هنرمند فریم‌های اصلی را بدهد. خروجی: art/drafts/anim_placeholder/<who>/<anim>_<dir>.png (نوار افقی ۱۲۸×۱۲۸) + gif
  python3 -I art/tools/make_placeholder_anim.py"""
import json, os
from PIL import Image
import numpy as np
S = 128
def shift(im, dx, dy):
    out = Image.new("RGBA", im.size, (0,0,0,0)); out.paste(im, (dx, dy), im); return out
def lean(im, px, split=0.55):
    """بالاتنه را px پیکسل جابه‌جا می‌کند (خم‌شدن)، ردیف به ردیف، بدون درون‌یابی."""
    a = np.array(im); h = a.shape[0]; out = np.zeros_like(a); bb = im.getbbox(); top, bot = bb[1], bb[3]
    for y in range(h):
        t = 0 if y >= bot else max(0, (bot - y) / max(1, (bot - top)))
        d = int(round(px * max(0, t - (1 - split)) / split)) if t > (1 - split) else 0
        row = np.roll(a[y], d, axis=0)
        if d > 0: row[:d] = 0
        elif d < 0: row[d:] = 0
        out[y] = row
    return Image.fromarray(out)
def squash(im, sy):
    """کشیدن/فشردن عمودی با نزدیک‌ترین همسایه (Nearest) حول خط پا."""
    bb = im.getbbox(); h = bb[3]-bb[1]; nh = max(1, int(round(h*sy)))
    crop = im.crop(bb).resize((bb[2]-bb[0], nh), Image.NEAREST)
    out = Image.new("RGBA", im.size, (0,0,0,0)); out.paste(crop, (bb[0], bb[3]-nh), crop); return out
def tint(im, rgb, k):
    a = np.array(im).astype(float); m = a[...,3] > 0
    for i in range(3): a[...,i] = np.where(m, a[...,i]*(1-k) + rgb[i]*k, a[...,i])
    return Image.fromarray(a.astype(np.uint8))
def dissolve(im, p, seed):
    a = np.array(im); rng = np.random.default_rng(seed); mask = rng.random(a.shape[:2]) < p
    a[mask, 3] = 0; return Image.fromarray(a)
def strip(frames, path):
    sh = Image.new("RGBA", (S*len(frames), S), (0,0,0,0))
    for i, f in enumerate(frames): sh.paste(f, (i*S, 0))
    sh.save(path)
    bg = []
    for f in frames:
        b = Image.new("RGBA", f.size, (30,50,60,255)); b.alpha_composite(f); bg.append(b.convert("RGB"))
    bg[0].save(path.replace(".png", ".gif"), save_all=True, append_images=bg[1:], duration=110, loop=0)
def run():
    meta = {}
    for who in ("kairo", "ilara"):
        out = f"art/drafts/anim_placeholder/{who}"; os.makedirs(out, exist_ok=True); meta[who] = {}
        for d in ("down", "side", "up"):
            base = Image.open(f"art_drop/{who}/{who}_idle_{d}.png").convert("RGBA")
            idle = [shift(base, 0, y) for y in (0, 0, -1, -1)]
            walk = [shift(lean(base, l), 0, y) for l, y in ((0,0),(1,-2),(2,-3),(1,-2),(0,0),(-1,-2),(-2,-3),(-1,-2))] if d == "side" else \
                   [shift(squash(base, s), x, y) for s, x, y in ((1,0,0),(0.97,-1,0),(1,0,-3),(0.97,1,0),(1,0,0),(0.97,-1,0),(1,0,-3),(0.97,1,0))]
            strip(idle, f"{out}/idle_{d}.png"); strip(walk, f"{out}/walk_{d}.png")
            meta[who][d] = {"idle": len(idle), "walk": len(walk)}
        side = Image.open(f"art_drop/{who}/{who}_idle_side.png").convert("RGBA")
        strip([squash(side,0.92), shift(lean(side,4),6,0), shift(lean(side,5),10,-1), shift(lean(side,3),4,0)], f"{out}/dash_side.png")
        strip([shift(squash(side,s),0,0) for s in (1,0.9,0.8,1.05,1)] + [shift(side,0,-14),shift(side,0,-20),shift(side,0,-14),shift(side,0,0)], f"{out}/hop_side.png")
        down = Image.open(f"art_drop/{who}/{who}_idle_down.png").convert("RGBA")
        strip([tint(down,(80,230,255),k) for k in (0,0.25,0.5,0.25)], f"{out}/hack_down.png")
        strip([dissolve(tint(down,(255,255,255),0.3*(i<2)), p, i) for i, p in enumerate((0,0.15,0.35,0.6,0.85,1.0))], f"{out}/death_down.png")
    json.dump({"status": "PLACEHOLDER-NOT-FINAL", "frame_size": [S,S], "fps": 9, "note": "جابه‌جایی صحیح پیکسل از روی اسپرایت تأییدشده؛ جایگزین با فریم‌های هنرمند. side_left = آینه.", "anims": meta},
              open("art/drafts/anim_placeholder/asset.json","w"), indent=1, ensure_ascii=False)
if __name__ == "__main__": run()
