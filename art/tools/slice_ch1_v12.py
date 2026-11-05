#!/usr/bin/env python3
"""برش دستهٔ ۱۲ (اکتشاف سه‌چهارمی): قطعات نقشهٔ جهان، جمع‌شدنی‌ها/نشانگرها، اشیای تعاملی.
  python3 -I art/tools/slice_ch1_v12.py   (اصل‌ها: art/raw/ch1_v12/)"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import slice_ch1_v1 as v1
v1.RAW = "art/raw/ch1_v12"
SETS = {
 "overworld_pieces": ("art_drop/overworld/ch1", 0.3, dict(dil=6, minarea=3000, rowgap=110), [4,3,5,3],
   ["node_house","node_street","node_drone_tower","node_basement","node_electric_floor","node_workshop","node_launch_pad",
    "path_straight","path_curve","path_junction","gate_locked_fog","gate_open","marker_treasure","marker_player","icon_guardian_boss"]),
 "explore_pickups": ("art_drop/explore/pickups", 0.4, dict(dil=4, minarea=300, rowgap=70), [12,5,5,6],
   ["coin_0","coin_1","coin_2","coin_3","gem_0","gem_1","gem_2","gem_3","chip_0","chip_1","chip_2","chip_3",
    "part_battery","part_drone","note_scroll","pickup_heart","prompt_bubble",
    "alert_enemy","vision_cone_s","vision_cone_m","vision_cone_l","backhit_flash",
    "dust_0","dust_1","dust_2","splash_0","splash_1","splash_2"]),
 "explore_props": ("art_drop/explore/props", 0.3, dict(dil=6, minarea=3000, rowgap=110), [4,4,5],
   ["save_statue","chest_wood","chest_metal","lever","plate_up","plate_pressed","push_block","crate_breakable",
    "door_security","camera_zone_marker","climb_marker","leap_pad","wall_cracked"]),
}
def run():
    rep = {}
    for n, (outd, s, kw, rows_exp, names) in SETS.items():
        ims, rows = v1.items(n, **kw); assert rows == rows_exp and len(ims) == len(names), (n, rows)
        q = v1.quant([v1.scale(i, s) for i in ims], 64)
        meta = v1.save(q, names, outd); rep[n] = len(q)
        a = json.load(open(f"{outd}/asset.json")); a.update({"camera": "topdown", "scale": s, "source": f"art/raw/ch1_v12/{n}_full.png"})
        json.dump(a, open(f"{outd}/asset.json", "w"), indent=1, ensure_ascii=False)
    print(json.dumps(rep))
if __name__ == "__main__": run()
