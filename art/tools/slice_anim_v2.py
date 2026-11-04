#!/usr/bin/env python3
"""برش شیت‌های انیمیشن v2 (مرجع = برگهٔ تأییدشده در Canva) به فریم‌های ۱۲۸×۱۲۸ در تراکم اصلی (بدن ~۸۸px)، با پالت مشترک ۶۴ رنگ برای هر شخصیت.
  python3 -I art/tools/slice_anim_v2.py
مقیاس: از نسبت قد اسپرایت idle موجود (art_drop/<who>/<who>_idle_down.png) به قد فریم‌های walk_front."""
import json, os
import numpy as np
from PIL import Image
from scipy import ndimage
SHEETS = {
 "kairo": {"walk_down": "kairo_walk_front", "walk_up": "kairo_walk_back"},
 "ilara": {"walk_down": "ilara_walk_front", "walk_up": "ilara_walk_back", "run_side": "ilara_run_side"}}
def key(path):
    im = np.array(Image.open(path).convert("RGB")).astype(int); r, g, b = im[..., 0], im[..., 1], im[..., 2]
    m = (r > 170) & (b > 170) & (g < 120)
    edge = (~m) & (r > g * 1.3) & (b > g * 1.3)
    im[edge, 0] = np.minimum(r[edge], g[edge] + 12); im[edge, 2] = np.minimum(b[edge], g[edge] + 12)
    return np.dstack([im.astype(np.uint8), np.where(m, 0, 255).astype(np.uint8)])
def frames(path, n=6):
    """شبکهٔ ثابت ۳×۲؛ در هر سلول بزرگ‌ترین جزء متصل (به‌اضافهٔ اجزای نزدیک) نگه داشته می‌شود."""
    a = key(path); H, W = a.shape[:2]; out = []
    for r in range(2):
        for c in range(3):
            cell = a[r * H // 2:(r + 1) * H // 2, c * W // 3:(c + 1) * W // 3].copy()
            lab, k = ndimage.label(ndimage.binary_dilation(cell[..., 3] > 0, iterations=6))
            if k == 0: continue
            sizes = ndimage.sum(cell[..., 3] > 0, lab, range(1, k + 1)); keep = np.isin(lab, [i + 1 for i, v in enumerate(sizes) if v >= 0.05 * sizes.max()])
            cell[..., 3] = np.where(keep & (cell[..., 3] > 0), 255, 0); img = Image.fromarray(cell, "RGBA"); out.append(img.crop(img.getbbox()))
    return out
def run():
    meta = {}
    for who, anims in SHEETS.items():
        raw = {k: frames(f"art/raw/anim_v2/{v}_full.png") for k, v in anims.items()}
        idle = Image.open(f"art_drop/{who}/{who}_idle_down.png").convert("RGBA"); ih = idle.getbbox()[3] - idle.getbbox()[1]
        fh = np.mean([f.height for f in raw["walk_down"]]); s = ih / fh
        scaled = {k: [f.resize((max(1, round(f.width * s)), max(1, round(f.height * s))), Image.BOX) for f in v] for k, v in raw.items()}
        allpx = np.concatenate([np.array(f)[np.array(f)[..., 3] > 0][:, :3] for v in scaled.values() for f in v])
        side = int(np.ceil(np.sqrt(len(allpx)))); pal_src = Image.fromarray(np.pad(allpx, ((0, side * side - len(allpx)), (0, 0)), mode="edge").reshape(side, side, 3).astype(np.uint8), "RGB")
        pal = pal_src.quantize(64, method=Image.MEDIANCUT, dither=Image.NONE)
        meta[who] = {"scale": round(float(s), 4), "idle_h": int(ih)}
        for k, fs in scaled.items():
            outd = f"art_drop/{who}/anim"; os.makedirs(outd, exist_ok=True); strip = Image.new("RGBA", (128 * len(fs), 128), (0, 0, 0, 0))
            for i, f in enumerate(fs):
                arr = np.array(f); rgb = Image.fromarray(arr[..., :3], "RGB").quantize(palette=pal, dither=Image.NONE).convert("RGB"); q = np.dstack([np.array(rgb), arr[..., 3]])
                q[..., 3] = np.where(q[..., 3] > 127, 255, 0); g = Image.fromarray(q.astype(np.uint8), "RGBA")
                cx = int(np.average(np.nonzero(q[..., 3])[1])); cv = Image.new("RGBA", (128, 128), (0, 0, 0, 0))
                cv.paste(g, (64 - cx, 124 - g.height), g); cv.save(f"{outd}/{k}_{i:02d}.png"); strip.paste(cv, (i * 128, 0))
            strip.save(f"{outd}/{k}_strip.png")
            bg = [Image.alpha_composite(Image.new("RGBA", (128, 128), (30, 50, 60, 255)), strip.crop((i * 128, 0, i * 128 + 128, 128))).convert("RGB") for i in range(len(fs))]
            bg[0].save(f"{outd}/{k}.gif", save_all=True, append_images=bg[1:], duration=110, loop=0)
            meta[who][k] = len(fs)
    json.dump({"status": "v2-from-approved-sheet-reference", "frame_size": [128, 128], "feet_baseline_y": 124, "palette": 64, "fps": 9, "anims": meta,
               "note": "side_left = mirror. تراکم و قد مطابق idle تأییدشده؛ هنوز draft تا تأیید کاربر."}, open("art_drop/anim_v2_asset.json", "w"), indent=1, ensure_ascii=False)
    print(json.dumps(meta, ensure_ascii=False))
if __name__ == "__main__": run()
