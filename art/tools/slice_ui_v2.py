#!/usr/bin/env python3
"""برش شیت‌های UI v2 (کلید magenta + despill) به art_drop/ui/v2/<گروه>/<نام>.png
  python3 -I art/tools/slice_ui_v2.py
شمارهٔ جزء = ترتیب برچسب scipy (اسکن سطری از بالا-چپ)، با dilation=8 برای چسباندن اجزای یک شیء."""
import json, os
import numpy as np
from PIL import Image
from scipy import ndimage
RAW = "art/raw/ui_v2"; OUT = "art_drop/ui/v2"
MAP = {
 "level_nodes": {2: "node_unlocked", 3: "node_locked", 4: "node_done", 1: "node_selected", 5: "node_locked_alt", 6: "stars_0", 7: "stars_1", 8: "stars_2", 9: "stars_3"},
 "shop_cards": {1: "card", 2: "card_selected", 3: "price_tag", 4: "ribbon_new", 5: "btn_buy", 6: "btn_soldout"},
 "profile_parts": {2: "panel", 1: "avatar_frame", 3: "level_star", 4: "btn_edit", 5: "stat_row_1", 9: "stat_row_2", 10: "stat_row_3", 6: "medal_gold", 8: "medal_silver", 7: "medal_locked"},
 "pause_menu": {1: "panel", 3: "btn_resume", 4: "btn_restart", 5: "btn_home"},
 "settings_controls": {1: "panel", 2: "slider_empty", 3: "slider_half", 4: "toggle_on", 5: "toggle_off", 6: "check_on", 7: "check_off", 8: "arrow_left", 9: "arrow_right"},
 "menu_buttons": {1: "btn_normal", 2: "btn_pressed", 3: "btn_disabled", 4: "btn_highlight"}}
def key(path):
    a = np.array(Image.open(path).convert("RGB")).astype(int); r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = ((r > 170) & (b > 170) & (g < 120)) | ((r > g * 2) & (b > g * 2) & (r > 50) & (b > 50))
    edge = (~m) & (r > g * 1.3) & (b > g * 1.3); a[edge, 0] = np.minimum(r[edge], g[edge] + 12); a[edge, 2] = np.minimum(b[edge], g[edge] + 12)
    return np.dstack([a.astype(np.uint8), np.where(m, 0, 255).astype(np.uint8)])
def run():
    meta = {}
    for sheet, names in MAP.items():
        a = key(f"{RAW}/{sheet}_full.png"); m = a[..., 3] > 0; lab, k = ndimage.label(ndimage.binary_dilation(m, iterations=8)); lab = np.where(m, lab, 0)
        big = [i for i in range(1, k + 1) if (lab == i).sum() > 1500]; os.makedirs(f"{OUT}/{sheet}", exist_ok=True); meta[sheet] = {}
        for idx, name in names.items():
            c = big[idx - 1]; b = a.copy(); b[..., 3] = np.where(lab == c, 255, 0); im = Image.fromarray(b, "RGBA"); im = im.crop(im.getbbox())
            im.save(f"{OUT}/{sheet}/{name}.png"); meta[sheet][name] = list(im.size)
    json.dump({"status": "draft-until-user-approval", "source": "Canva UI v2 (no text; text uses Erfan pixel font D-ART-03)",
               "note": "اندازه‌ها در رزولوشن اصلی شیت (۱۶۸۰×۹۴۴)؛ برای بازی ۱۲۸۰×۷۲۰ حدود ×0.76 و برای 9-slice پنل‌ها/دکمه‌ها لبه‌ها حفظ شود.", "items": meta}, open(f"{OUT}/asset.json", "w"), indent=1, ensure_ascii=False)
    print(json.dumps(meta, ensure_ascii=False))
if __name__ == "__main__": run()
