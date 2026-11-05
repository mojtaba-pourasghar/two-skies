#!/usr/bin/env python3
"""دستهٔ ۱۸: اتاق‌های چالش سه‌چهارم، تله‌ها، ذرات additive. اصل‌ها: art/raw/ch1_v18/"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from PIL import Image
import slice_ch1_v1 as v1
v1.RAW = "art/raw/ch1_v18"
def meta(d, **kw):
    a = json.load(open(f"{d}/asset.json")); a.update(kw); json.dump(a, open(f"{d}/asset.json", "w"), indent=1, ensure_ascii=False)
def rooms():
    d = "art_drop/rooms/ch1"
    for n, o in (("c1_balcony", "c1_balcony"), ("c2_laser", "c2_laser_alley"), ("c3_electric", "c3_electric_hall")):
        Image.open(f"{v1.RAW}/{n}_full.png").convert("RGB").resize((1280, 720), Image.LANCZOS).save(f"{d}/{o}_1280x720.png")
def traps():
    ims, rows = v1.items("traps", dil=4, minarea=300, rowgap=60); assert rows == [5, 4, 7, 8], rows
    names = ["spike_off", "spike_on", "pit_ember", "floor_cracked", "floor_fallen"] + [f"saw_{i}" for i in range(4)] + \
            ["laser_emitter_l", "laser_emitter_r", "laser_beam_h", "laser_beam_v", "elec_panel_off", "elec_panel_on", "gas_vent"] + \
            ["plate_up", "plate_down", "checkpoint_off", "checkpoint_on", "gate_locked", "gate_open", "death_mark", "respawn_ring"]
    d = "art_drop/challenge/traps"; v1.save(v1.quant([v1.scale(i, 0.5) for i in ims], 64), names, d)
    meta(d, camera="topdown", scale=0.5, note="خار/گودال/کاشی/دروازه/چک‌پوینت 3/4؛ لیزر h/v برای کشیدن")
def particles():
    im = np.array(Image.open(f"{v1.RAW}/particles_full.png").convert("RGB")).astype(float)
    boxes = {"dust_0": (80, 30, 490, 230), "dust_1": (610, 30, 970, 230), "dust_2": (1070, 30, 1480, 230),
             "ember_0": (80, 270, 490, 470), "ember_1": (610, 260, 970, 470), "ember_2": (1070, 270, 1480, 470),
             "fog_0": (90, 520, 480, 690), "fog_1": (620, 520, 960, 690), "fog_2": (1080, 520, 1430, 690),
             "ash_0": (80, 720, 290, 900), "ash_1": (350, 720, 570, 900),
             "spark_0": (630, 740, 800, 890), "spark_1": (870, 730, 1050, 900), "spark_2": (1100, 720, 1310, 910), "spark_3": (1370, 700, 1620, 920)}
    d = "art_drop/overlays/particles"; os.makedirs(d, exist_ok=True); fr = {}
    for n, (x0, y0, x1, y1) in boxes.items():
        s = im[y0:y1, x0:x1]; al = s.max(axis=2); al = np.clip((al - 6) / 249.0, 0, 1)
        rgb = np.where(al[..., None] > 0, np.clip(s / np.maximum(al[..., None], 1e-3), 0, 255), 0)
        o = np.dstack([rgb, al * 255]).astype(np.uint8); o = Image.fromarray(o, "RGBA"); o = o.crop(o.getbbox())
        o = o.resize((max(1, o.width // 2), max(1, o.height // 2)), Image.BOX); o.save(f"{d}/{n}.png"); fr[n] = list(o.size)
    json.dump({"status": "draft-until-user-approval", "frames": fr, "camera": "any", "blend": "additive/alpha",
               "note": "آلفا از روشنایی؛ رنگ unpremultiplied"}, open(f"{d}/asset.json", "w"), indent=1, ensure_ascii=False)
def run(): rooms(); traps(); particles()
if __name__ == "__main__": run()
