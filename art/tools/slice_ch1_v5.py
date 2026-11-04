#!/usr/bin/env python3
"""برش دستهٔ ۵ (سه‌چهارم از بالا): کاشی زیرزمین، سه صحنه، کف برقی/در امنیتی، شکل‌های بولت، باس.
  python3 -I art/tools/slice_ch1_v5.py   (اصل‌ها: art/raw/ch1_v5/)"""
import json, os, sys, shutil
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image
import slice_ch1_v1 as v1, slice_ch1_v2 as v2, slice_ch1_v4 as v4
RAW = "art/raw/ch1_v5"; v1.RAW = RAW; v4.RAW = RAW
def run():
    rep = {}
    rep["tiles_basement"] = v2.tiles("tileset_basement", "basement")
    os.makedirs("art_drop/scenes/ch1", exist_ok=True)
    for n in ("ilara_bedroom", "launch_road", "workshop"):
        Image.open(f"{RAW}/scene_{n}_full.png").convert("RGB").resize((1280, 720), Image.LANCZOS).save(f"art_drop/scenes/ch1/{n}_1280x720.png")
    rep["hazards"] = v4.sheet_out("hazards_electric_door", ["electric_floor_0", "electric_floor_1", "electric_floor_2", "security_door_0", "security_door_1", "security_door_2"], 0.2, "art_drop/hazards_ch1_topdown", 2, 3)
    rep["bolt_forms"] = v4.sheet_out("bolt_forms_topdown", ["hover", "wheel", "spider", "bird", "transform_0", "transform_1"], 0.2, "art_drop/bolt/forms_topdown", 2, 3)
    rep["boss"] = v4.sheet_out("boss_guardian_topdown", [f"phase_{i + 1}" for i in range(4)], 0.34, "art_drop/boss/guardian_topdown", 2, 2)
    print(json.dumps(rep))
if __name__ == "__main__": run()
