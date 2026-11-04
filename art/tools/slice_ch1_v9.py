#!/usr/bin/env python3
"""برش دستهٔ ۹ (سه‌چهارم از بالا): راه رفتن به چپ، کایرو dash/hack/hurt به چپ، ربات‌های Nexa.
  python3 -I art/tools/slice_ch1_v9.py   (اصل‌ها: art/raw/ch1_v9/)  — راست = آینهٔ چپ در بازی."""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import slice_ch1_v1 as v1, slice_ch1_v4 as v4
RAW = "art/raw/ch1_v9"; v4.RAW = RAW
def nexa():
    """برش دستی (پرتو اسکن و خرده‌های انفجار از مرز سلول‌های مساوی می‌گذرند)؛ کادر مشترک برای هر ۶ فریم."""
    names = ["guard_idle", "guard_step", "guard_scan", "crawler_0", "crawler_1", "suicide_explode"]
    cells, _ = v4.cut("nexa_topdown", [0, 515, 944], [[0, 560, 1010, 1680], [0, 540, 985, 1680]]); q = v1.quant([v1.scale(c, 0.2) for c in cells], 64)
    bbs = [x.getbbox() for x in q]; x0 = min(b[0] for b in bbs); y0 = min(b[1] for b in bbs); x1 = max(b[2] for b in bbs); y1 = max(b[3] for b in bbs)
    d = "art_drop/enemies/nexa_topdown"; os.makedirs(d, exist_ok=True)
    for im, n in zip(q, names): im.crop((x0, y0, x1, y1)).save(f"{d}/{n}.png")
    json.dump({"status": "draft-until-user-approval", "camera": "topdown", "frame_size": [x1 - x0, y1 - y0], "scale": 0.2, "frames": names}, open(f"{d}/asset.json", "w"), indent=1, ensure_ascii=False)
    return [x1 - x0, y1 - y0]
def run():
    rep = {}; g = (v4.even(2, 944), [v4.even(3, 1680)] * 2)
    rep["kairo_walk_left"] = v4.char128("kairo_home_walk_left", "kairo", 0.21, *g, {"walk_left": list(range(6))})
    rep["ilara_walk_left"] = v4.char128("ilara_home_walk_left", "ilara", 0.205, *g, {"walk_left": list(range(6))})
    cc = [0, 640, 1080, 1680]
    rep["kairo_3x3_left"] = v4.char128("kairo_home_dash_hack_hurt_left", "kairo", 0.34, [0, 325, 610, 944], [cc] * 3, {"dash_left": [0, 1, 2], "hack_left": [3, 4, 5], "hurt_left": [6, 7, 8]})
    rep["nexa_topdown"] = nexa()
    print(json.dumps(rep))
if __name__ == "__main__": run()
