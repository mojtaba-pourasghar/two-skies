#!/usr/bin/env python3
"""برش دستهٔ ۱۱/۱۵: افکت‌های نبرد، رابط نبرد، پس‌زمینهٔ نبرد خیابان.
  python3 -I art/tools/slice_ch1_v15.py   (اصل‌ها: art/raw/ch1_v15/)"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from PIL import Image
import slice_ch1_v1 as v1
v1.RAW = "art/raw/ch1_v15"
def meta(d, **kw):
    a = json.load(open(f"{d}/asset.json")); a.update(kw); json.dump(a, open(f"{d}/asset.json", "w"), indent=1, ensure_ascii=False)
def fx():
    ims, rows = v1.items("battle_fx1", dil=10, minarea=1500, rowgap=100); assert rows == [3, 3, 3]
    names = [f"hit_{k}_{i}" for k in ("normal", "good", "perfect") for i in range(3)]
    d = "art_drop/battle_fx/hits"; v1.save(v1.quant([v1.scale(i, 0.4) for i in ims], 64), names, d); meta(d, camera="battle-3q", scale=0.4)
    ims, rows = v1.items("battle_fx2", dil=6, minarea=1500, rowgap=80); assert rows == [5, 3, 3, 3, 4]
    names = [f"timing_ring_{i}" for i in range(4)] + ["timing_success_flash"] + [f"shield_block_{i}" for i in range(3)] + [f"hack_{i}" for i in range(3)] + [f"light_leaf_{i}" for i in range(3)] + ["fragile_overlay", "intent_badge", "interrupt_shatter_0", "interrupt_shatter_1"]
    d = "art_drop/battle_fx/skills"; v1.save(v1.quant([v1.scale(i, 0.35) for i in ims], 64), names, d); meta(d, camera="battle-3q", scale=0.35)
def ui():
    ims, rows = v1.items("battle_ui", dil=6, minarea=3000, rowgap=80); assert rows == [4, 4, 2, 1], rows
    bars = ims[9]; h = bars.height // 2; health, energy = bars.crop((0, 0, bars.width, h)), bars.crop((0, h, bars.width, bars.height))
    health = health.crop(health.getbbox()); energy = energy.crop(energy.getbbox())
    icons = [v1.scale(i, 0.3) for i in ims[:8]]; others = [v1.scale(i, 0.4) for i in (ims[8], health, energy, ims[10])]
    q = v1.quant(icons + others, 64)
    names = ["intent_strike", "intent_explosion", "intent_antihack", "intent_scan", "intent_heal", "intent_summon", "intent_charge", "intent_stun", "menu_frame", "bar_health", "bar_energy", "turn_order_strip"]
    d = "art_drop/battle_ui"; v1.save(q, names, d); meta(d, camera="ui", scale="icons 0.3 / others 0.4")
def bg():
    d = "art_drop/battle_bg"; os.makedirs(d, exist_ok=True)
    Image.open(f"{v1.RAW}/battle_bg_street_full.png").convert("RGB").resize((1280, 720), Image.BOX).save(f"{d}/battle_bg_street_1280x720.png")
def run(): fx(); ui(); bg()
if __name__ == "__main__": run()
