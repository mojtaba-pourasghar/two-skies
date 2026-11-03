#!/usr/bin/env python3
"""جدا کردن سه نمای (جلو، پهلو، پشت) از برگهٔ طراحی و ساخت اسپرایت ایستادهٔ بازی.
  python3 -I art/tools/extract_sprites.py art/approved/kairo_sheet_APPROVED.png art_drop/kairo --name kairo --height 44 --colors 24
فایل اصلی دست‌نخورده می‌ماند. خروجی: <name>_idle_{down,side,up}.png روی بوم ۶۴×۶۴ با پای در y=60، و asset.json.
"""
import argparse, json, os
from PIL import Image

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("sheet"); ap.add_argument("outdir")
    ap.add_argument("--name", required=True)
    ap.add_argument("--height", type=int, default=44)
    ap.add_argument("--colors", type=int, default=24)
    ap.add_argument("--tol", type=int, default=34)
    a = ap.parse_args()
    im = Image.open(a.sheet).convert("RGB"); W, H = im.size
    bg = im.getpixel((5, 5)); px = im.load()
    def fg(x, y):
        p = px[x, y]; return max(abs(p[0]-bg[0]), abs(p[1]-bg[1]), abs(p[2]-bg[2])) > a.tol
    cols = [sum(1 for y in range(0, H, 2) if fg(x, y)) for x in range(W)]
    # بخش‌بندی ستونی: فاصلهٔ خالی ≥ ۶۰ پیکسل بین سه نما
    segs, start, gap = [], None, 0
    for x, c in enumerate(cols):
        if c > 3:
            if start is None: start = x
            gap = 0
        elif start is not None:
            gap += 1
            if gap > 60: segs.append((start, x - gap)); start = None; gap = 0
    if start is not None: segs.append((start, W - 1))
    segs = [s for s in segs if s[1] - s[0] > 80][:3]
    assert len(segs) == 3, f"سه نما پیدا نشد: {segs}"
    os.makedirs(a.outdir, exist_ok=True)
    names = ["down", "side", "up"]
    for (x0, x1), nm in zip(segs, names):
        sub = im.crop((max(0, x0-4), 0, min(W, x1+4), H))
        sp = sub.load(); w, h = sub.size
        mask = Image.new("L", (w, h), 0); mp = mask.load()
        for y in range(h):
            for x in range(w):
                p = sp[x, y]
                if max(abs(p[0]-bg[0]), abs(p[1]-bg[1]), abs(p[2]-bg[2])) > a.tol: mp[x, y] = 255
        bbox = mask.getbbox()
        sub = sub.crop(bbox); mask = mask.crop(bbox)
        s = a.height / sub.height
        nw, nh = max(1, round(sub.width*s)), a.height
        sub = sub.resize((nw, nh), Image.BOX); mask = mask.resize((nw, nh), Image.BOX).point(lambda v: 255 if v > 110 else 0)
        rgba = sub.convert("RGB").quantize(colors=a.colors, method=Image.MEDIANCUT, dither=Image.NONE).convert("RGBA")
        rgba.putalpha(mask)
        canvas = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        canvas.alpha_composite(rgba, ((64-nw)//2, 60-nh+1))
        canvas.save(f"{a.outdir}/{a.name}_idle_{nm}.png")
        canvas.resize((512, 512), Image.NEAREST).save(f"{a.outdir}/{a.name}_idle_{nm}_preview.png")
    json.dump({"name": a.name, "status": "draft-from-approved-sheet", "frame_size": [64, 64],
               "feet_baseline_y": 60, "body_height_px": a.height,
               "files": {nm: f"{a.name}_idle_{nm}.png" for nm in names},
               "note": "side_left = mirror of side. فقط ایستاده؛ انیمیشن‌ها با هنرمند/ابزار پیکسل‌آرت از روی برگهٔ تأییدشده."},
              open(f"{a.outdir}/asset.json", "w"), ensure_ascii=False, indent=2)
    print("ok", segs)

if __name__ == "__main__":
    main()
