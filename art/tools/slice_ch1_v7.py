#!/usr/bin/env python3
"""برش دستهٔ ۷ (دو دوربین): راه رفتن روبه‌پایین/بالا (سه‌چهارم)، کایرو dash/hack/hurt روبه‌پایین،
خطرها و ۳ صحنهٔ نمای کناری.
  python3 -I art/tools/slice_ch1_v7.py   (اصل‌ها: art/raw/ch1_v7/)"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image
import slice_ch1_v1 as v1, slice_ch1_v4 as v4
RAW = "art/raw/ch1_v7"; v4.RAW = RAW
def row_out(sheet, names, s, outd, r0, r1, cuts):
    """یک ردیف از برگه؛ کادر مشترک برای همان ردیف."""
    cells, _ = v4.cut(sheet, [r0, r1], [cuts]); q = v1.quant([v1.scale(c, s) for c in cells], 64)
    bbs = [x.getbbox() for x in q]; assert all(bbs), (sheet, r0)
    x0 = min(b[0] for b in bbs); y0 = min(b[1] for b in bbs); x1 = max(b[2] for b in bbs); y1 = max(b[3] for b in bbs)
    os.makedirs(outd, exist_ok=True)
    for im, n in zip(q, names): im.crop((x0, y0, x1, y1)).save(f"{outd}/{n}.png")
    json.dump({"status": "draft-until-user-approval", "camera": "side", "frame_size": [x1 - x0, y1 - y0], "scale": s, "frames": names}, open(f"{outd}/asset.json", "w"), indent=1, ensure_ascii=False)
    return [x1 - x0, y1 - y0]
def run():
    rep = {}
    os.makedirs("art_drop/scenes/ch1", exist_ok=True)
    for n in ("ilara_bedroom", "launch_platform", "workshop"):
        Image.open(f"{RAW}/scene_{n}_side_full.png").convert("RGB").resize((1280, 720), Image.LANCZOS).save(f"art_drop/scenes/ch1/{n}_side_1280x720.png")
    g = (v4.even(2, 944), [v4.even(3, 1680)] * 2)
    rep["kairo_walk_down"] = v4.char128("kairo_home_walk_down", "kairo", 0.21, *g, {"walk_down": list(range(6))})
    rep["kairo_walk_up"] = v4.char128("kairo_home_walk_up", "kairo", 0.21, *g, {"walk_up": list(range(6))})
    rep["ilara_walk_down"] = v4.char128("ilara_home_walk_down", "ilara", 0.205, *g, {"walk_down": list(range(6))})
    rep["ilara_walk_up"] = v4.char128("ilara_home_walk_up", "ilara", 0.205, *g, {"walk_up": list(range(6))})
    cc = [0, 620, 1050, 1680]
    rep["kairo_3x3_down"] = v4.char128("kairo_home_dash_hack_hurt_down", "kairo", 0.34, [0, 325, 610, 944], [cc] * 3, {"dash_down": [0, 1, 2], "hack_down": [3, 4, 5], "hurt_down": [6, 7, 8]})
    hc = [0, 560, 1095, 1680]; H = "art_drop/hazards_ch1_sideview"
    rep["h_fragile"] = row_out("hazards_side", [f"fragile_platform_{i}" for i in range(3)], 0.2, f"{H}/fragile_platform", 0, 422, hc)
    rep["h_electric"] = row_out("hazards_side", [f"electric_floor_{i}" for i in range(3)], 0.2, f"{H}/electric_floor", 422, 635, hc)
    rep["h_door"] = row_out("hazards_side", [f"security_door_{i}" for i in range(3)], 0.2, f"{H}/security_door", 635, 944, hc)
    print(json.dumps(rep))
if __name__ == "__main__": run()
