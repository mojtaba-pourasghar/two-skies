#!/usr/bin/env python3
"""برش چهار برگهٔ Canva (رابط، آیکون، موانع، افکت) به عناصر جدا با پس‌زمینهٔ شفاف.
  python3 -I art/tools/slice_sheets.py
ورودی: art/raw/sheet_{ui,icons,hazards,fx}.png ؛ خروجی: art_drop/{ui,icons,hazards,fx}/*.png + asset.json
کادرها (x0,y0,x1,y1) روی تصویر ۱۶۰۰×۸۹۹ است. پس‌زمینه با floodfill از لبه‌ها حذف می‌شود (داخل پنل‌های تیره حفظ می‌شود).
"""
import json, os
from PIL import Image, ImageDraw

SHEETS = {
 "ui": ("art/raw/sheet_ui.png", {
   "portrait_frame": (15,15,225,295), "bar_health": (232,68,556,126), "bar_energy": (232,148,556,208), "bar_stamina": (232,232,540,284),
   "dialog_frame": (588,45,1168,292), "btn_pause": (1228,32,1334,132), "btn_settings": (1362,32,1468,132),
   "counter_coin": (1212,158,1512,222), "counter_gem": (1212,238,1512,298), "panel_square": (38,328,438,692),
   "slot_a": (472,342,590,488), "slot_b": (608,342,724,488), "slot_c": (744,342,860,488), "slot_empty": (878,342,998,488),
   "btn_jump": (1042,332,1224,508), "btn_dash": (1252,332,1432,508), "cursor": (1470,415,1585,540),
   "skill_fire": (470,538,596,680), "skill_ice": (604,538,730,680), "skill_nature": (740,538,866,680), "skill_aura": (874,538,1000,680),
   "btn_action": (1042,522,1224,698), "btn_companion": (1252,522,1432,698),
   "badge_gem": (45,715,165,830), "banner_red": (185,725,280,830), "banner_green": (305,725,405,830), "banner_purple": (425,725,525,830),
   "divider": (40,835,1545,880)}),
 "icons": ("art/raw/sheet_icons.png", {
   "dash": (60,70,390,310), "hack": (430,30,720,330), "hop": (740,40,1100,330), "companion_stay": (1115,110,1300,310), "companion_come": (1300,110,1560,310),
   "coin": (90,330,380,580), "gem": (440,350,700,590), "notebook": (790,340,1040,570), "keycard": (1150,340,1410,580),
   "shield": (90,600,350,860), "checkpoint_flag": (440,600,720,870), "heart": (770,610,1070,850), "crystals": (1130,600,1440,850)}),
 "hazards": ("art/raw/sheet_hazards.png", {
   "spikes": (35,20,450,310), "laser_emitter": (525,55,940,285),
   "drone_a1": (965,30,1100,190), "drone_a2": (1110,30,1250,190), "drone_a3": (1255,30,1395,190), "drone_a4": (1400,30,1545,190),
   "drone_hacked1": (965,195,1100,355), "drone_hacked2": (1110,195,1250,355), "drone_hacked3": (1255,195,1395,355), "drone_hacked4": (1400,195,1545,355),
   "platform_intact": (40,360,435,590), "platform_shaking": (465,355,840,645), "platform_falling": (875,385,1255,815),
   "door_security": (170,610,490,875), "checkpoint_flag": (580,650,775,875)}),
}
FX_ROWS = {"dash_trail": (35,35,135), "hack_ring": (150,285), "dust": (290,380), "death_burst": (405,535), "respawn_ring": (540,645), "coin_sparkle": (680,765), "leaves": (790,865)}

def cut(im, box, name, outdir):
    sub = im.crop(box).convert("RGB")
    w, h = sub.size
    marker = sub.copy()
    seeds = [(x, 0) for x in range(0, w, 8)] + [(x, h-1) for x in range(0, w, 8)] + [(0, y) for y in range(0, h, 8)] + [(w-1, y) for y in range(0, h, 8)]
    for s in seeds:
        if marker.getpixel(s) != (255, 0, 255):
            ImageDraw.floodfill(marker, s, (255, 0, 255), thresh=26)
    out = sub.convert("RGBA"); op = out.load(); mp = marker.load()
    for y in range(h):
        for x in range(w):
            if mp[x, y] == (255, 0, 255): op[x, y] = (0, 0, 0, 0)
    bb = out.getchannel("A").getbbox()
    if bb: out = out.crop(bb)
    out.save(f"{outdir}/{name}.png")
    return out.size

def main():
    index = {}
    for key, (path, boxes) in SHEETS.items():
        im = Image.open(path).convert("RGB"); d = f"art_drop/{key}"; os.makedirs(d, exist_ok=True)
        index[key] = {n: list(cut(im, b, n, d)) for n, b in boxes.items()}
        json.dump({"name": key, "status": "sliced-from-canva-sheet", "source": path, "files": index[key],
                   "note": "اندازه‌ها در تراکم اصلی برگه؛ Godot در زمان واردکردن به اندازهٔ نمایش (مقیاس ۱۲۸۰×۷۲۰) کوچک می‌کند. فیلتر Nearest."},
                  open(f"{d}/asset.json", "w"), ensure_ascii=False, indent=2)
    # افکت‌ها: ۹ فریم در هر ردیف، آلفا از روشنایی (ترکیب add یا عادی)
    fx = Image.open("art/raw/sheet_fx.png").convert("RGB"); os.makedirs("art_drop/fx", exist_ok=True)
    meta = {}
    for name, rows in FX_ROWS.items():
        y0, y1 = (rows[0], rows[-1]) if len(rows) == 2 else (rows[0], rows[2]+rows[0]) 
        if name == "dash_trail": y0, y1 = 35, 135
        frames = []
        for k in range(9):
            x0 = 38 + k*172; fr = fx.crop((x0, y0, x0+172, y1)).convert("RGBA"); p = fr.load()
            for yy in range(fr.height):
                for xx in range(fr.width):
                    r, g, b, _ = p[xx, yy]; lum = max(r, g, b)
                    p[xx, yy] = (r, g, b, 0 if lum < 22 else min(255, int(lum*1.6)))
            frames.append(fr)
        W = max(f.width for f in frames); H = max(f.height for f in frames)
        strip = Image.new("RGBA", (W*9, H), (0,0,0,0))
        for k, f in enumerate(frames): strip.alpha_composite(f, (k*W, 0))
        strip.save(f"art_drop/fx/{name}_strip.png"); meta[name] = {"frames": 9, "frame_size": [W, H]}
    json.dump({"name": "fx", "status": "sliced-from-canva-sheet", "strips": meta, "note": "هر نوار ۹ فریم افقی؛ آلفا از روشنایی؛ پیشنهاد: blend add"}, open("art_drop/fx/asset.json", "w"), ensure_ascii=False, indent=2)
    print({k: len(v) for k, v in index.items()}, list(meta))

if __name__ == "__main__":
    main()
