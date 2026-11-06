#!/usr/bin/env python3
"""دستهٔ ۲۰/۲۱: حلقه‌های انیمیشنی صحنهٔ زنده (D-ART-39). ردیف = یک انیمیشن ۶ فریمی؛ فریم‌ها روی بوم مشترک (پایین-وسط) تا نلرزند."""
import json, os, sys, tempfile
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from PIL import Image
import slice_ch1_v1 as v1
v1.RAW = "art/raw/ch1_v20"
def keyed(name):
    with tempfile.TemporaryDirectory() as t:
        p = f"{t}/x.png"; Image.open(f"{v1.RAW}/{name}_full.png").convert("RGB").save(p); return v1.key(p)
def segments(m, mingap=18, minw=14):
    col = m.any(axis=0); segs = []; s = None; gap = 0
    for x, v in enumerate(col):
        if v:
            if s is None: s = x
            gap = 0; e = x
        elif s is not None:
            gap += 1
            if gap >= mingap: segs.append([s, e]); s = None
    if s is not None: segs.append([s, e])
    return [g for g in segs if g[1] - g[0] >= minw]
SHEETS = {
 "anim20": [("candle", 20, 190), ("lantern", 185, 365), ("curtain", 370, 525), ("smoke", 535, 665), ("drip", 685, 795), ],
 "anim21": [("plant", 20, 210), ("vines", 215, 400), ("moth", 420, 560), ("drone", 570, 705), ("neon", 715, 790), ("water", 815, 910)],
}
def run(scale=0.5):
    out = {}
    for sheet, rows in SHEETS.items():
        a = keyed(sheet)
        for nm, y0, y1 in rows:
            sub = a[y0:y1]; m = sub[..., 3] > 0; segs = segments(m, mingap=6 if nm in ('curtain', 'water') else 18)
            if len(segs) != 6: print("WARN", sheet, nm, len(segs), segs); continue
            fr = []
            for x0, x1 in segs:
                s = sub[:, x0:x1 + 1].copy(); im = Image.fromarray(s, "RGBA"); bb = im.getbbox(); fr.append(im.crop(bb) if bb else im)
            W = max(f.width for f in fr); H = max(f.height for f in fr); d = f"art_drop/ambient/ch1/{nm}"; os.makedirs(d, exist_ok=True); sizes = []
            for i, f in enumerate(fr):
                c = Image.new("RGBA", (W, H), (0, 0, 0, 0)); c.paste(f, ((W - f.width) // 2, H - f.height), f)
                c = c.resize((max(1, int(W * scale)), max(1, int(H * scale))), Image.BOX); c.save(f"{d}/{nm}_{i}.png"); sizes = list(c.size)
            json.dump({"status": "draft-until-user-approval", "frames": 6, "size": sizes, "fps": 8, "loop": True, "anchor": "bottom-center", "camera": "topdown"}, open(f"{d}/asset.json", "w"), indent=1)
            out[nm] = sizes
    print(out)
if __name__ == "__main__": run()
