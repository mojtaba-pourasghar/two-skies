#!/usr/bin/env python3
"""برش دستهٔ ۱۶: اتاق‌های نقاشی‌شده، پانورامای خیابان، پیش‌زمینه‌های occluder، سکوها/موانع side.
  python3 -I art/tools/slice_ch1_v16.py   (اصل‌ها: art/raw/ch1_v16/)"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image
import slice_ch1_v1 as v1
v1.RAW = "art/raw/ch1_v16"
def meta(d, **kw):
    a = json.load(open(f"{d}/asset.json")); a.update(kw); json.dump(a, open(f"{d}/asset.json", "w"), indent=1, ensure_ascii=False)
def rooms():
    d = "art_drop/rooms/ch1"; os.makedirs(d, exist_ok=True)
    for n, nm in (("room_house_corridor", "r1b_corridor"), ("room_house_kitchen", "r1c_kitchen")):
        Image.open(f"{v1.RAW}/{n}_full.png").convert("RGB").resize((1280, 720), Image.BOX).save(f"{d}/{nm}_1280x720.png")
    im = Image.open(f"{v1.RAW}/pano_street_wide_full.png").convert("RGB"); im.save(f"{d}/s2a_street_wide_{im.width}x{im.height}.png")
    json.dump({"status": "draft-until-user-approval", "camera": "topdown", "note": "R1b/R1c: room 1280x720؛ S2a: پانورامای follow", "pano_size": list(im.size)}, open(f"{d}/asset.json", "w"), indent=1, ensure_ascii=False)
def sheets():
    ims, rows = v1.items("occluders", dil=8, minarea=3000, rowgap=110); assert rows == [4, 4, 4]
    names = ["arch_gothic", "doorframe_wood", "column_stone", "curtains_velvet", "chandelier", "branch_leafy", "beam_fallen", "railing_wood", "bookshelf_tall", "window_frame_glow", "cables_hanging", "rubble_pile"]
    d = "art_drop/occluders/ch1"; v1.save(v1.quant([v1.scale(i, 0.5) for i in ims], 64), names, d); meta(d, camera="topdown", scale=0.5, usage="پیش‌زمینه؛ شخصیت از پشتشان رد می‌شود (Y-sort بالاتر)")
    ims, rows = v1.items("side_platforms", dil=8, minarea=3000, rowgap=110); assert rows == [1, 2, 1, 4, 5], rows
    names = ["platform_wood_long", "platform_wood_medium", "platform_stone_ledge", "platform_wood_short", "platform_bookshelf", "platform_crumble_0", "platform_crumble_1", "platform_crumble_2", "ladder", "spikes_floor", "saw_rail", "chain_hanging", "lantern_checkpoint"]
    d = "art_drop/side_ch1/platforms"; v1.save(v1.quant([v1.scale(i, 0.3) for i in ims], 64), names, d); meta(d, camera="side", scale=0.3)
def run(): rooms(); sheets()
if __name__ == "__main__": run()
