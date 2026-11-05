#!/usr/bin/env python3
"""برش دستهٔ ۱۴: پس‌زمینهٔ نبرد (خانه/جادهٔ پرتاب)، باس غول نگهبان (نبرد)، پیوند دو آسمان + HUD اکتشاف.
  python3 -I art/tools/slice_ch1_v14.py   (اصل‌ها: art/raw/ch1_v14/)"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from PIL import Image
from scipy import ndimage
import slice_ch1_v1 as v1
v1.RAW = "art/raw/ch1_v14"
def meta(d, **kw):
    json.dump({"status": "draft-until-user-approval", **kw}, open(f"{d}/asset.json", "w"), indent=1, ensure_ascii=False)
def bgs():
    d = "art_drop/battle_bg"; os.makedirs(d, exist_ok=True)
    for n in ("house", "launch"):
        Image.open(f"{v1.RAW}/battle_bg_{n}_full.png").convert("RGB").resize((1280, 720), Image.BOX).save(f"{d}/battle_bg_{n}_1280x720.png")
def comps(a, dil, minarea):
    m = a[..., 3] > 0; lab, k = ndimage.label(ndimage.binary_dilation(m, iterations=dil)); lab = np.where(m, lab, 0)
    return lab, [i for i in range(1, k + 1) if (lab == i).sum() >= minarea]
def crop(a, mask):
    b = a.copy(); b[..., 3] = np.where(mask, 255, 0); im = Image.fromarray(b, "RGBA"); return im.crop(im.getbbox())
def boss():
    a = v1.key(f"{v1.RAW}/boss_guardian_battle_full.png"); lab, ids = comps(a, 8, 1500)
    boxes = {i: ndimage.find_objects((lab == i).astype(int))[0] for i in ids}
    def at(x, y):  # مؤلفه‌ای که این نقطه (مرکز تقریبی) داخل bbox آن است
        for i, (sy, sx) in boxes.items():
            if sx.start <= x <= sx.stop and sy.start <= y <= sy.stop and (sy.stop - sy.start) > 200: return i
    spec = {"idle": (200, 300), "laser_charge": (700, 300), "ground_slam": (1180, 350), "summon_drones": (250, 800), "phase3_exposed": (720, 800), "hurt": (1200, 820)}
    out, names = [], []
    for n, (x, y) in spec.items():
        i = at(x, y); assert i, n; mask = lab == i
        if n == "summon_drones": mask |= np.isin(lab, [j for j in ids if j not in (i,) and boxes[j][1].start > 300 and boxes[j][1].stop < 520 and boxes[j][0].start > 800])
        out.append(crop(a, mask)); names.append(n)
    q = v1.quant([v1.scale(i, 0.6) for i in out], 64); d = "art_drop/boss/guardian_battle"; v1.save(q, names, d)
    meta(d, camera="battle-3q", scale=0.6, source=f"{v1.RAW}/boss_guardian_battle_full.png", phases="ف۱ لیزر، ف۲ ضربهٔ کف، ف۳ پهپادها + پنل پشتی")
def hud():
    a = v1.key(f"{v1.RAW}/bond_hud_full.png")
    for r in ((800, 0, 915, 118), (1170, 0, 1300, 118), (750, 455, 960, 558), (1125, 455, 1345, 558), (396, 445, 595, 556), (84, 448, 245, 545), (435, 8, 556, 124), (100, 8, 220, 118)): a[r[1]:r[3], r[0]:r[2], 3] = 0
    cols = [(0, 330), (330, 665), (665, 1020), (1020, 1456)]; ims = []
    for x0, x1 in cols:
        sub = a[0:456, x0:x1].copy(); im = Image.fromarray(sub, "RGBA"); ims.append(im.crop(im.getbbox()))
    d = "art_drop/effects/bond_two_skies"; v1.save(v1.quant(ims, 64), [f"bond_stage_{i}" for i in range(4)], d); meta(d, camera="battle-3q", scale=1.0, note="۴ مرحلهٔ پیوند دو آسمان؛ مرحلهٔ ۴ فلاش نهایی")
    lab, ids = comps(a[:, :, :], 5, 1500); sel = {"hud_health_orb": (180, 680), "hud_energy_bar": (600, 650), "hud_coin_counter": (470, 780), "hud_emerald_counter": (750, 790), "hud_tool_wheel": (955, 790), "hud_minimap_frame": (340, 960), "hud_objective_arrow": (830, 980)}
    out, names = [], []
    for n, (x, y) in sel.items():
        i = lab[y, x]
        if i == 0:  # نزدیک‌ترین پیکسل غیرصفر
            yy, xx = np.nonzero(lab[max(0, y - 40):y + 40, max(0, x - 40):x + 40]); assert len(yy), n; i = lab[max(0, y - 40) + yy[0], max(0, x - 40) + xx[0]]
        out.append(crop(a, lab == i)); names.append(n)
    d = "art_drop/ui/explore_hud"; v1.save(v1.quant([v1.scale(i, 0.45) for i in out], 64), names, d); meta(d, camera="ui", scale=0.45)
def run():
    bgs(); boss(); hud()
if __name__ == "__main__": run()
