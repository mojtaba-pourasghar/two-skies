#!/usr/bin/env python3
"""برش دستهٔ ۴: پارالکس جلو، مرگ کایرو (ذرهٔ نارنجی)، علامت‌های ایلارا، دش/هک/دیوارپرش کایرو، باس، ربات‌ها، بولت.
  python3 -I art/tools/slice_ch1_v4.py   (اصل‌ها: art/raw/ch1_v4/)"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from PIL import Image
import slice_ch1_v1 as v1
RAW = "art/raw/ch1_v4"
def cut(sheet, rcuts, ccuts):
    a = v1.key(f"{RAW}/{sheet}_full.png"); out = []; rowof = []
    for r in range(len(rcuts) - 1):
        for c in range(len(ccuts[r]) - 1):
            out.append(Image.fromarray(np.ascontiguousarray(a[rcuts[r]:rcuts[r + 1], ccuts[r][c]:ccuts[r][c + 1]]), "RGBA")); rowof.append(r)
    return out, rowof
def even(n, total): return [round(i * total / n) for i in range(n + 1)]
def char128(sheet, who, s, rcuts, ccuts, splits):
    cells, rowof = cut(sheet, rcuts, ccuts); q = v1.quant([v1.scale(c, s) for c in cells], 64); bb = [x.getbbox() for x in q]; assert all(bb), sheet
    ground = {r: max(b[3] for b, rr in zip(bb, rowof) if rr == r) for r in set(rowof)}
    out = f"art_drop/{who}/home/anim"; os.makedirs(out, exist_ok=True); rep = {}
    for name, idx in splits.items():
        fr = []
        for i in idx:
            ci = q[i].crop(bb[i]); arr = np.array(ci)[..., 3] > 0; cx = int(np.average(np.nonzero(arr)[1]))
            cv = Image.new("RGBA", (128, 128), (0, 0, 0, 0)); cv.paste(ci, (64 - cx, 124 - ground[rowof[i]] + bb[i][1]), ci); fr.append(cv)
            if ci.width > 120 or ci.height > 124: rep.setdefault(name + "_oversize", []).append(list(ci.size))
        for k, f in enumerate(fr): f.save(f"{out}/{name}_{k:02d}.png")
        st = Image.new("RGBA", (128 * len(fr), 128)); [st.paste(f, (128 * k, 0)) for k, f in enumerate(fr)]; st.save(f"{out}/{name}_strip.png"); rep[name] = len(fr)
    return rep
def sheet_out(sheet, names, s, outd, rows, cols):
    """کادر مشترک: همهٔ فریم‌ها به یک پنجرهٔ ثابت (اجتماع محدودهٔ محتوا نسبت به سلول) بریده می‌شوند."""
    cells, _ = cut(sheet, even(rows, 944), [even(cols, 1680)] * rows); q = v1.quant([v1.scale(c, s) for c in cells], 64)
    bbs = [x.getbbox() for x in q]; assert all(bbs), sheet
    x0 = min(b[0] for b in bbs); y0 = min(b[1] for b in bbs); x1 = max(b[2] for b in bbs); y1 = max(b[3] for b in bbs)
    os.makedirs(outd, exist_ok=True); meta = {}
    for im, n in zip(q, names): im.crop((x0, y0, x1, y1)).save(f"{outd}/{n}.png")
    json.dump({"status": "draft-until-user-approval", "frame_size": [x1 - x0, y1 - y0], "scale": s, "frames": names}, open(f"{outd}/asset.json", "w"), indent=1, ensure_ascii=False)
    return [x1 - x0, y1 - y0]
def run():
    rep = {}
    os.makedirs("art_drop/parallax/ch1", exist_ok=True)
    for n in ("house", "street", "basement"):
        Image.fromarray(v1.key(f"{RAW}/parallax_fore_{n}_full.png"), "RGBA").resize((1280, 720), Image.LANCZOS).save(f"art_drop/parallax/ch1/{n}_fore_1280x720.png")
    rep["kairo_death"] = char128("kairo_home_death_respawn2", "kairo", 0.1972, even(2, 944), [even(3, 1680)] * 2, {"death": list(range(6))})
    rep["ilara_signals"] = char128("ilara_home_signals", "ilara", 0.2115, even(2, 944), [even(3, 1680)] * 2, {"signal_stay": [0, 1, 2], "signal_come": [3, 4, 5]})
    rep["kairo_3x3"] = char128("kairo_home_dash_hack_walljump", "kairo", 0.1972 * 1.42, [0, 325, 603, 944], [[0, 620, 1120, 1680], [0, 660, 1030, 1680], [0, 620, 1040, 1680]], {"dash": [0, 1, 2], "hack": [3, 4, 5], "wall_jump": [6, 7, 8]})
    rep["boss"] = sheet_out("boss_guardian", [f"phase_{i + 1}" for i in range(4)], 0.34, "art_drop/boss/guardian", 2, 2)
    rep["robots"] = sheet_out("robots_nexa", ["guard_idle", "guard_step", "guard_scan", "crawler_0", "crawler_1", "suicide_explode"], 0.25, "art_drop/enemies/nexa", 2, 3)
    rep["bolt_forms"] = sheet_out("bolt_forms", ["hover", "wheel", "spider", "bird", "transform_0", "transform_1"], 0.2, "art_drop/bolt/forms", 2, 3)
    rep["bolt_emotions"] = sheet_out("bolt_emotions", ["happy", "curious", "scared", "sad", "angry", "hover_glow"], 0.2, "art_drop/bolt/emotions", 2, 3)
    print(json.dumps(rep))
if __name__ == "__main__": run()
