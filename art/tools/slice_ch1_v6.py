#!/usr/bin/env python3
"""برش دستهٔ ۶ (سه‌چهارم از بالا): جهش رو به پایین، بالا رفتن، سکوی شکننده، احساس بولت، سکوی پرتاب.
  python3 -I art/tools/slice_ch1_v6.py   (اصل‌ها: art/raw/ch1_v6/)
مقیاس‌ها از اندازهٔ سر/قد در برگه‌ها نرمال شده (قد ایستاده ~۸۴ px)."""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image
import slice_ch1_v1 as v1, slice_ch1_v4 as v4
RAW = "art/raw/ch1_v6"; v4.RAW = RAW
def run():
    rep = {}
    os.makedirs("art_drop/scenes/ch1", exist_ok=True)
    Image.open(f"{RAW}/scene_launch_platform_full.png").convert("RGB").resize((1280, 720), Image.LANCZOS).save("art_drop/scenes/ch1/launch_platform_1280x720.png")
    g = (v4.even(2, 944), [v4.even(3, 1680)] * 2)
    rep["kairo_leap"] = v4.char128("kairo_home_leap_down", "kairo", 0.23, *g, {"leap_down": list(range(6))})
    rep["ilara_leap"] = v4.char128("ilara_home_leap_down", "ilara", 0.25, *g, {"leap_down": list(range(6))})
    rep["kairo_climb"] = v4.char128("kairo_home_climb_up", "kairo", 0.27, *g, {"climb_up": list(range(6))}, size=192)
    rep["ilara_climb"] = v4.char128("ilara_home_climb_up", "ilara", 0.29, *g, {"climb_up": list(range(6))}, size=192)
    rep["fragile"] = v4.sheet_out("fragile_platform", [f"fragile_platform_{i}" for i in range(6)], 0.2, "art_drop/hazards_ch1_topdown/fragile_platform", 2, 3)
    rep["bolt_emotions_td"] = v4.sheet_out("bolt_emotions_topdown", ["happy", "curious", "scared", "sad", "angry", "hover_glow"], 0.2, "art_drop/bolt/emotions_topdown", 2, 3)
    print(json.dumps(rep))
if __name__ == "__main__": run()
