#!/usr/bin/env python3
"""برش دستهٔ ۱۷: میدان گشت، UI انتخاب ارتقا، افکت‌های صفحه، نورپردازی اتاق.
  python3 -I art/tools/slice_ch1_v17.py   (اصل‌ها: art/raw/ch1_v17/)
افکت‌های صفحه با جعبهٔ دستی برش می‌خورند (ترتیب سطری خودکار برای این ورق شکننده بود)."""
import json, os, sys, tempfile
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from PIL import Image
from scipy import ndimage
import slice_ch1_v1 as v1
v1.RAW = "art/raw/ch1_v17"
def meta(d, **kw):
    a = json.load(open(f"{d}/asset.json")); a.update(kw); json.dump(a, open(f"{d}/asset.json", "w"), indent=1, ensure_ascii=False)
def key_img(im):
    with tempfile.TemporaryDirectory() as t:
        p = f"{t}/x.png"; im.convert("RGB").save(p); return v1.key(p)
def crop_keyed(a, box, dil=3, minarea=60, largest=False):
    x0, y0, x1, y1 = box; sub = a[y0:y1, x0:x1].copy(); m = sub[..., 3] > 0
    lab, k = ndimage.label(ndimage.binary_dilation(m, iterations=dil)); lab = np.where(m, lab, 0)
    ids = [i for i in range(1, k + 1) if (lab == i).sum() >= minarea]
    if largest and ids: ids = [max(ids, key=lambda i: (lab == i).sum())]
    keep = np.isin(lab, ids); sub[..., 3] = np.where(keep, 255, 0); im = Image.fromarray(sub, "RGBA"); return im.crop(im.getbbox())
def pano():
    d = "art_drop/rooms/ch1"; os.makedirs(d, exist_ok=True); im = Image.open(f"{v1.RAW}/pano_plaza_patrol_full.png").convert("RGB")
    im.save(f"{d}/s3a_plaza_patrol_{im.width}x{im.height}.png")
def upgrade():
    ims, rows = v1.items("upgrade_ui", dil=2, minarea=3000, rowgap=110); assert rows == [1, 5, 4]
    names = ["upgrade_panel"] + [f"icon_{n}" for n in ("blade", "shield", "leafstaff", "chip", "boot", "battery", "heart", "lens", "amulet")]
    q = v1.quant([v1.scale(ims[0], 0.8)] + [v1.scale(i, 0.4) for i in ims[1:]], 64); d = "art_drop/ui/upgrade_choice"; v1.save(q, names, d)
    meta(d, camera="ui", note="پنل با ۳ جایگاه کارت؛ آیکن‌ها ۰٫۴")
def fx():
    d = "art_drop/effects/screen"; os.makedirs(d, exist_ok=True)
    raw = Image.open(f"{v1.RAW}/screen_fx_full.png").convert("RGB"); a = key_img(raw)
    # ویگنت: آلفا از نسبت صورتی (t=r/255 ⇒ شفافیت)، رنگ سیاه
    sub = np.array(raw.crop((32, 32, 500, 400))).astype(float); t = np.clip(sub[..., 0] / 255.0, 0, 1)
    vig = np.zeros(sub.shape[:2] + (4,), np.uint8); vig[..., 3] = ((1 - t) * 255).astype(np.uint8); Image.fromarray(vig, "RGBA").save(f"{d}/vignette_dark.png")
    boxes = {"flash_0": (570, 60, 700, 190), "flash_1": (740, 55, 890, 200), "flash_2": (920, 40, 1110, 215), "flash_3": (1120, 20, 1340, 220),
             "vortex_0": (565, 215, 775, 410), "vortex_1": (840, 215, 1050, 410), "vortex_2": (1110, 215, 1340, 410),
             "laser_0": (50, 450, 390, 580), "laser_1": (425, 450, 835, 580), "laser_2": (865, 450, 1430, 580),
             "shockwave_0": (35, 620, 260, 780), "shockwave_1": (300, 620, 610, 790), "shockwave_2": (630, 610, 1000, 790), "shockwave_3": (1020, 610, 1420, 790),
             "banner_victory": (915, 815, 1425, 935), "banner_defeat": (915, 945, 1425, 1075)}
    ims, names = [], []
    for n, b in boxes.items(): ims.append(crop_keyed(a, b, largest=True)); names.append(n)
    for r, (nm, y0, y1) in enumerate((("white", 825, 895), ("gold", 910, 980), ("red", 995, 1065))):
        sub = a[y0:y1, 25:880].copy(); m = sub[..., 3] > 0; lab, k = ndimage.label(ndimage.binary_dilation(m, iterations=2)); lab = np.where(m, lab, 0)
        ids = sorted([i for i in range(1, k + 1) if (lab == i).sum() > 150], key=lambda i: ndimage.center_of_mass(lab == i)[1]); assert len(ids) == 10, (nm, len(ids))
        for dgt, i in enumerate(ids):
            b = sub.copy(); b[..., 3] = np.where(lab == i, 255, 0); im = Image.fromarray(b, "RGBA"); ims.append(im.crop(im.getbbox())); names.append(f"digit_{nm}_{dgt}")
    sc = [0.5 if n.startswith(("flash", "vortex", "laser", "shockwave")) else (0.5 if n.startswith("banner") else 0.6) for n in names]
    q = v1.quant([v1.scale(i, s) for i, s in zip(ims, sc)], 64); v1.save(q, names, d)
    meta(d, camera="battle-3q", note="vignette_dark.png: سیاه با آلفا (نمایشی)؛ ارقام ۳ رنگ؛ بنرها بدون متن")
def light():
    ims, rows = v1.items("lighting", dil=14, minarea=300, rowgap=100); assert rows == [4, 3, 3, 2], rows
    names = [f"window_light_{i}" for i in range(4)] + [f"moon_shaft_{i}" for i in range(3)] + [f"lamp_glow_{i}" for i in range(3)] + [f"city_glow_{i}" for i in range(2)]
    d = "art_drop/overlays/rooms"; v1.save(v1.quant([v1.scale(i, 0.6) for i in ims], 64), names, d)
    meta(d, camera="topdown", scale=0.6, todo="ذرات گرد و اخگر (فریم‌ها) کم‌رنگ‌اند و کلید ماجنتا آن‌ها را نگرفت؛ باید روی پس‌زمینهٔ سیاه بازتولید شوند (additive)")
def run(): pano(); upgrade(); fx(); light()
if __name__ == "__main__": run()
