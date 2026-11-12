#!/usr/bin/env python3
"""دستهٔ ۲۵: کیت رابط (پنل‌ها/کنترل‌ها/آیکون‌ها/نشان) + هنر منوی اصلی و شکست. اصل‌ها: art/raw/ch1_v25/*_full.png
  python3 -I art/tools/slice_ch1_v25.py"""
import json, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
from PIL import Image
from scipy import ndimage
import slice_ch1_v1 as v1
v1.RAW = "art/raw/ch1_v25"
def comps(name, dil=3, minarea=300):
    a = v1.key(f"{v1.RAW}/{name}_full.png"); m = a[..., 3] > 0
    lab, k = ndimage.label(ndimage.binary_dilation(m, iterations=dil)); lab = np.where(m, lab, 0); out = []
    for i, s in enumerate(ndimage.find_objects(lab), 1):
        if (lab == i).sum() < minarea: continue
        b = a.copy(); b[..., 3] = np.where(lab == i, 255, 0); im = Image.fromarray(b, "RGBA"); out.append(((s[0].start, s[1].start), im.crop(im.getbbox())))
    return out
def pick(cs, table, outd, canvas=None):
    os.makedirs(outd, exist_ok=True); meta = {}; used = set()
    for (y, x, nm) in table:
        j = min((i for i in range(len(cs)) if i not in used), key=lambda i: abs(cs[i][0][0] - y) + abs(cs[i][0][1] - x)); used.add(j); im = cs[j][1]
        if abs(cs[j][0][0] - y) + abs(cs[j][0][1] - x) > 60: print("WARN far", nm, cs[j][0])
        if canvas:
            cv = Image.new("RGBA", canvas, (0, 0, 0, 0)); cv.paste(im, ((canvas[0] - im.width) // 2, (canvas[1] - im.height) // 2), im); im = cv
        im.save(f"{outd}/{nm}.png"); meta[nm] = list(im.size)
    if len(used) != len(cs): print("WARN unused", len(cs) - len(used), outd)
    return meta
def ninepatch_safe(im, band=70):
    """گوهر وسط لبه‌ها را با ستون‌های بدون گوهر جایگزین می‌کند تا کشیدن NinePatch آن را کش ندهد."""
    a = np.array(im); h, w = a.shape[:2]; r, g, b, al = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int), a[..., 3]
    cy = (g > 170) & (b > 170) & (r < 140) & (al > 0)
    out = a.copy()
    for side in ("top", "bottom"):
        sl = slice(0, band) if side == "top" else slice(h - band, h)
        cols = np.where(cy[sl].any(axis=0))[0]; cols = cols[(cols > w * 0.3) & (cols < w * 0.7)]
        if not len(cols): continue
        x0, x1 = cols.min() - 14, cols.max() + 14; gw = x1 - x0; donor = x1 + 10
        if donor + gw >= w - 60: donor = x0 - 10 - gw
        if donor < 20 or x0 < 0 or donor + gw > w: continue
        out[sl, x0:x1] = a[sl, donor:donor + gw]
    for side in ("left", "right"):
        sl = slice(0, band) if side == "left" else slice(w - band, w)
        rows = np.where(cy[:, sl].any(axis=1))[0]; rows = rows[(rows > h * 0.3) & (rows < h * 0.7)]
        if not len(rows): continue
        y0, y1 = rows.min() - 14, rows.max() + 14; gh = y1 - y0; donor = y1 + 10
        if donor + gh >= h - 60: donor = y0 - 10 - gh
        if donor < 20 or y0 < 0 or donor + gh > h: continue
        out[y0:y1, sl] = a[donor:donor + gh, sl]
    return Image.fromarray(out, "RGBA")
def kit():
    d = "art_drop/ui/kit"; meta = {}
    meta["panels"] = pick(comps("kit_a"), [(7, 23, "panel_xl"), (53, 804, "panel_l"), (115, 1255, "panel_m"), (428, 1074, "panel_sq"), (429, 22, "panel_wide"), (495, 1352, "panel_s"),
        (715, 32, "banner_ribbon"), (740, 603, "divider_vine"), (714, 1146, "corner_ornament"), (739, 1322, "slot_normal"), (735, 1455, "slot_selected")], d + "/panels")
    for n in ("panel_xl", "panel_l", "panel_m", "panel_sq", "panel_wide", "panel_s"):
        ninepatch_safe(Image.open(f"{d}/panels/{n}.png")).save(f"{d}/panels/{n}_np.png")
    meta["controls"] = pick(comps("kit_b"), [(25, 24, "btn_normal"), (24, 418, "btn_hover"), (25, 819, "btn_pressed"), (25, 1213, "btn_disabled"),
        (150, 54, "btn_sq_normal"), (150, 213, "btn_sq_hover"), (150, 377, "btn_sq_pressed"), (150, 538, "btn_sq_disabled"), (275, 34, "tab_active"), (275, 422, "tab_inactive"),
        (412, 35, "toggle_off"), (412, 262, "toggle_on"), (407, 533, "checkbox_off"), (406, 668, "checkbox_on"), (403, 861, "radio_off"), (403, 999, "radio_on"),
        (514, 24, "slider_track"), (514, 541, "slider_fill"), (506, 1046, "slider_with_knob"), (599, 32, "bar_empty"), (599, 827, "bar_fill"),
        (678, 67, "divider_vertical"), (703, 1038, "ability_slot_fire"), (718, 782, "cursor_hand"), (730, 203, "btn_highlight_gold")], d + "/controls")
    json.dump({"status": "draft-until-user-approval", "design_space": [1600, 899], "note": "اندازهٔ اصلی Canva؛ برای پایهٔ ۱۲۸۰×۷۲۰ حدود ×۰٫۸ کوچک شود. *_np.png = گوهر وسط لبه حذف‌شده برای NinePatch؛ گوهر را جدا روی لبه بگذار.", **meta}, open(f"{d}/asset.json", "w"), indent=1, ensure_ascii=False)
def icons():
    d = "art_drop/ui/icons"; names = ["settings", "sound_on", "sound_off", "music", "save", "load", "back", "close", "pause", "play", "home", "language",
        "backpack", "companions", "compass", "map", "quest_scroll", "journal", "chip", "lantern", "shield", "sword", "heart", "energy",
        "toolbox", "medkit", "battery", "circuit_board", "key", "paper_note", "scrap_metal", "glow_herb", "water_bottle", "food_can", "wire_coil", "drone_core"]
    cs = comps("icons", dil=1)
    rows = {141: 0, 358: 1, 586: 2}; items = []
    for (y, x), im in cs:
        r = min(rows, key=lambda k: abs(k - y)); items.append((rows[r], x, im))
    items.sort(key=lambda t: (t[0], t[1])); print("icons", len(items))
    os.makedirs(d, exist_ok=True); meta = {}
    for (r, x, im), nm in zip(items, names):
        cv = Image.new("RGBA", (128, 128), (0, 0, 0, 0)); cv.paste(im, ((128 - im.width) // 2, (128 - im.height) // 2), im); cv.save(f"{d}/{nm}.png"); meta[nm] = [128, 128]
    json.dump({"status": "draft-until-user-approval", "size": [128, 128], "frames": meta, "note": "ردیف۱ گرد (سیستم)، ردیف۲ مربع (منو/مهارت)، ردیف۳ گرد (آیتم)"}, open(f"{d}/asset.json", "w"), indent=1, ensure_ascii=False)
def emblem():
    d = "art_drop/ui/ornaments"; cs = comps("emblem")
    meta = pick(cs, [(24, 55, "emblem_large"), (38, 574, "emblem_small"), (254, 509, "divider_ornate"), (398, 585, "wreath_arc"), (578, 32, "corner_tl"), (578, 188, "corner_tr"), (736, 32, "corner_bl"), (736, 188, "corner_br"),
        (646, 341, "sparkle_star"), (633, 532, "heart_gem"), (626, 767, "lock_closed"), (627, 932, "lock_open"), (707, 1137, "ring_0"), (707, 1249, "ring_1"), (707, 1361, "ring_2"), (707, 1473, "ring_3")], d)
    json.dump({"status": "draft-until-user-approval", "frames": meta, "note": "ring_0..3 = چهار فریم قاب انتخاب (۴ fps حلقه)"}, open(f"{d}/asset.json", "w"), indent=1, ensure_ascii=False)
def backdrops():
    d = "art_drop/ui/menu"; os.makedirs(d, exist_ok=True)
    for n, o in (("menu_two_skies", "menu_two_skies"), ("defeat_bg", "defeat_bg")):
        Image.open(f"{v1.RAW}/{n}_full.png").convert("RGB").resize((1920, 1080), Image.LANCZOS).save(f"{d}/{o}.png")
    json.dump({"status": "draft-until-user-approval", "size": [1920, 1080], "menu_two_skies": "دو آسمان؛ ناحیهٔ خالی تیره بالا-چپ/وسط برای عنوان؛ سیلوئت دو نفر پایین وسط",
               "defeat_bg": "تراس ویران تیره؛ وسط خالی برای متن شکست/مکث؛ فانوس فیروزه‌ای بالا-چپ", "note": "WebP lossy 90 طبق سیاست پس‌زمینه‌ها"}, open(f"{d}/asset.json", "w"), indent=1, ensure_ascii=False)
if __name__ == "__main__": kit(); icons(); emblem(); backdrops()
