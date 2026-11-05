#!/usr/bin/env python3
"""برش دستهٔ ۱۳: پس‌زمینهٔ نبرد (زیرزمین/کارگاه)، اسپرایت نبرد دشمن‌ها، بازماندگان NPC.
  python3 -I art/tools/slice_ch1_v13.py   (اصل‌ها: art/raw/ch1_v13/)"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
from PIL import Image
import slice_ch1_v1 as v1
v1.RAW = "art/raw/ch1_v13"
def bgs():
    d = "art_drop/battle_bg"; os.makedirs(d, exist_ok=True)
    for n in ("basement", "workshop"):
        Image.open(f"{v1.RAW}/battle_bg_{n}_full.png").convert("RGB").resize((1280, 720), Image.BOX).save(f"{d}/battle_bg_{n}_1280x720.png")
    json.dump({"status": "draft-until-user-approval", "camera": "battle-3q", "size": [1280, 720], "note": "کف مرکزی خالی برای صف‌آرایی؛ HUD روی آن"}, open(f"{d}/asset.json", "w"), indent=1, ensure_ascii=False)
def sheet(name, outd, s, rows_exp, names, extra):
    ims, rows = v1.items(name, dil=8, minarea=3000, rowgap=110); assert rows == rows_exp and len(ims) == len(names), (name, rows)
    q = v1.quant([v1.scale(i, s) for i in ims], 64); v1.save(q, names, outd)
    a = json.load(open(f"{outd}/asset.json")); a.update(extra); a["scale"] = s; a["source"] = f"{v1.RAW}/{name}_full.png"
    json.dump(a, open(f"{outd}/asset.json", "w"), indent=1, ensure_ascii=False)
def run():
    bgs()
    en = [f"{e}_{a}" for e in ("crawler", "guard", "drone", "kamikaze") for a in ("idle", "attack", "hurt")]
    en[-3:] = ["kamikaze_idle", "kamikaze_charge", "kamikaze_explode"]
    sheet("battle_enemies", "art_drop/enemies/battle_nexa", 0.4, [3,3,3,3], en, {"camera": "battle-3q"})
    sheet("npc_survivors", "art_drop/npc/survivors", 0.19, [4,4], ["mechanic","scavenger","nurse","merchant","child","watchman","scholar","soldier_wounded"], {"camera": "topdown", "height_px_approx": 88})
if __name__ == "__main__": run()
