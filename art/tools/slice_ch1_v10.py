#!/usr/bin/env python3
"""برش دستهٔ ۸ (بازتولید): آیکن ابزارها، هیجان‌های ایلارا (سه‌چهارم روبه‌پایین)، کایرو dash/hack/hurt روبه‌بالا.
  python3 -I art/tools/slice_ch1_v10.py   (اصل‌ها: art/raw/ch1_v10/)"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import slice_ch1_v1 as v1, slice_ch1_v4 as v4
RAW = "art/raw/ch1_v10"; v4.RAW = RAW
def icons():
    cells, _ = v4.cut("icons_tools", v4.even(2, 944), [[0, 840, 1680]] * 2); q = v1.quant([v1.scale(c, 0.32) for c in cells], 64)
    d = "art_drop/icons/tools_v2"; os.makedirs(d, exist_ok=True); sizes = {}
    for im, n in zip(q, ["climb", "leap", "dash", "hack"]):
        c = im.crop(im.getbbox()); c.save(f"{d}/{n}.png"); sizes[n] = list(c.size)
    json.dump({"status": "draft-until-user-approval", "sizes": sizes, "scale": 0.32}, open(f"{d}/asset.json", "w"), indent=1)
    return sizes
def run():
    rep = {"icons": icons()}; g = (v4.even(2, 944), [v4.even(3, 1680)] * 2)
    rep["ilara_emotions"] = v4.char128("ilara_home_emotions_down", "ilara", 0.205, v4.even(2, 944), [v4.even(3, 1680), [0, 560, 1070, 1680]], {k: [i] for i, k in enumerate(["hurt", "scared", "happy", "curious", "sad", "signal"])}, sub="emotions_topdown")
    rep["kairo_up"] = v4.char128("kairo_home_dash_hack_hurt_up", "kairo", 0.34, [0, 325, 610, 944], [[0, 640, 1070, 1680]] * 3, {"dash_up": [0, 1, 2], "hack_up": [3, 4, 5], "hurt_up": [6, 7, 8]})
    print(json.dumps(rep))
if __name__ == "__main__": run()
