#!/usr/bin/env python3
"""برش دستهٔ دوم v2: Kairo run_side/dash/hack/hop/death/respawn، Ilara stay/come/hop، و پرتره‌های اصلاح‌شدهٔ Ilara.
  python3 -I art/tools/slice_anim_v2b.py
مقیاس همان مقیاس slice_anim_v2 (art_drop/anim_v2_asset.json). فریم‌ها ۱۲۸ یا ۱۹۲ پهن، خط پای y=124 (hop: ارتفاع نسبی حفظ می‌شود)."""
import json, os
import numpy as np
from PIL import Image
from scipy import ndimage
RAW = "art/raw/anim_v2"
# فایل -> (شخصیت، ستون×ردیف، {انیمیشن: [اندیس سلول‌ها]})
SHEETS = {
 "kairo_run_side": ("kairo", (3, 2), {"run_side": [0, 1, 2, 3, 4, 5]}),
 "kairo_death_respawn": ("kairo", (3, 2), {"death": [0, 1, 2], "respawn": [3, 4, 5]}),
 "kairo_dash_hack_hop": ("kairo", (3, 3), {"dash": [0, 1, 2], "hack": [3, 4, 5], "hop": [6, 7, 8]}),
 "ilara_stay_come_hop": ("ilara", (3, 3), {"signal_stay": [0, 1, 2], "signal_come": [3, 4, 5], "hop": [6, 7, 8]})}
# شیت‌هایی که فریم‌هایشان کنار هم می‌چسبند: برش دستی (ycuts، و xcuts برای هر ردیف)
CUTS = {"kairo_dash_hack_hop": ([300, 622], [[605, 1005], [650, 1025], [640, 1010]]),
        "ilara_stay_come_hop": ([340, 645], [[668, 1042]] * 3)}
AIR = {"hop"}
# شیت‌های ۳×۳ شخصیت‌ها را کوچک‌تر کشیده‌اند؛ ضریب برای رسیدن به قد ~۸۴–۸۸px (اندازه‌گیری‌شده از فریم ایستاده)
MULT = {"kairo_dash_hack_hop": 1.42, "ilara_stay_come_hop": 1.31}
def key(im):
    a = np.array(im.convert("RGB")).astype(int); r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = ((r > 170) & (b > 170) & (g < 120)) | ((r > g * 2) & (b > g * 2) & (r > 50) & (b > 50))  # شامل سایهٔ بنفش تیره
    edge = (~m) & (r > g * 1.3) & (b > g * 1.3)
    a[edge, 0] = np.minimum(r[edge], g[edge] + 12); a[edge, 2] = np.minimum(b[edge], g[edge] + 12)
    return np.dstack([a.astype(np.uint8), np.where(m, 0, 255).astype(np.uint8)])
def cut_cells(a, yc, xcs):
    H, W = a.shape[:2]; ys = [0] + yc + [H]; out = []
    for r in range(len(ys) - 1):
        xs = [0] + xcs[r] + [W]
        for c in range(len(xs) - 1):
            cell = a[ys[r]:ys[r + 1], xs[c]:xs[c + 1]].copy(); m = cell[..., 3] > 0
            lab, k = ndimage.label(ndimage.binary_dilation(m, iterations=10)); lab = np.where(m, lab, 0)
            sizes = ndimage.sum(m, lab, range(1, k + 1)); keep = np.isin(lab, [i + 1 for i, v in enumerate(sizes) if v >= 0.1 * sizes.max()])
            cell[..., 3] = np.where(keep, 255, 0); img = Image.fromarray(cell, "RGBA"); bb = img.getbbox(); out.append((img.crop(bb), ys[r] + bb[3]))
    return out
def cells(name, grid):
    """جزء‌های متصل کل شیت؛ بدنه‌ها (جزء بزرگ) + اجزای کوچک نزدیک (حلقه، خطوط سرعت، جرقه) به نزدیک‌ترین بدنه؛ مرتب‌سازی ردیف/ستون."""
    a = key(Image.open(f"{RAW}/{name}_full.png")); cols, rows = grid; m = a[..., 3] > 0
    if name in CUTS: return cut_cells(a, *CUTS[name])
    lab, k = ndimage.label(ndimage.binary_dilation(m, iterations=3)); lab = np.where(m, lab, 0)
    idx = list(range(1, k + 1)); area = np.array(ndimage.sum(m, lab, idx)); cen = np.array(ndimage.center_of_mass(m, lab, idx))
    order = np.argsort(-area); mains = [int(i) for i in order[:cols * rows]]
    assert area[mains[-1]] > 0.2 * area[mains[0]], f"{name}: تعداد بدنه کمتر از انتظار {area[order[:cols*rows+2]]}"
    groups = {i: [i] for i in mains}
    for i in range(k):
        if i in mains or area[i] < 0.002 * area[mains[0]]: continue
        d = [np.hypot(*(cen[i] - cen[j])) for j in mains]; jn = int(np.argmin(d))
        if d[jn] < 300: groups[mains[jn]].append(i)
    srt = sorted(mains, key=lambda i: cen[i][0]); ordered = []  # y سپس x
    for r, chunk in enumerate([srt[x:x + cols] for x in range(0, len(srt), cols)]): ordered += sorted(chunk, key=lambda i: cen[i][1])
    out = []
    for gi in ordered:
        keep = np.isin(lab, [i + 1 for i in groups[gi]]); b = a.copy(); b[..., 3] = np.where(keep, 255, 0); img = Image.fromarray(b, "RGBA"); bb = img.getbbox(); out.append((img.crop(bb), bb[3]))
    return out
def run():
    meta = json.load(open("art_drop/anim_v2_asset.json")); scale = {w: meta["anims"][w]["scale"] for w in ("kairo", "ilara")}
    todo = {}
    for name, (who, grid, anims) in SHEETS.items():
        cs = cells(name, grid)
        for an, idx in anims.items(): todo.setdefault(who, {})[an] = [(cs[i][0], cs[i][1], MULT.get(name, 1.0)) for i in idx]
    for who, anims in todo.items():
        s = scale[who]; sc = {}
        for an, fs in anims.items():
            base = max(b for _, b, _ in fs)
            sc[an] = [(f.resize((max(1, round(f.width * s * m)), max(1, round(f.height * s * m))), Image.BOX), round((base - b) * s * m) if an in AIR else 0) for f, b, m in fs]
        px = np.concatenate([np.array(f)[np.array(f)[..., 3] > 0][:, :3] for v in sc.values() for f, _ in v]); side = int(np.ceil(np.sqrt(len(px))))
        src = Image.fromarray(np.pad(px, ((0, side * side - len(px)), (0, 0)), mode="edge").reshape(side, side, 3).astype(np.uint8), "RGB")
        pal = src.quantize(96 if who == "kairo" else 64, method=Image.MEDIANCUT, dither=Image.NONE)
        meta["anims"].setdefault(who, {}); outd = f"art_drop/{who}/anim"; os.makedirs(outd, exist_ok=True)
        for an, fs in sc.items():
            w = 128 if max(f.width for f, _ in fs) <= 120 else 192; strip = Image.new("RGBA", (w * len(fs), 128), (0, 0, 0, 0))
            for i, (f, lift) in enumerate(fs):
                arr = np.array(f); rgb = Image.fromarray(arr[..., :3], "RGB").quantize(palette=pal, dither=Image.NONE).convert("RGB")
                q = np.dstack([np.array(rgb), np.where(arr[..., 3] > 127, 255, 0)]).astype(np.uint8); g = Image.fromarray(q, "RGBA")
                cv = Image.new("RGBA", (w, 128), (0, 0, 0, 0)); cv.paste(g, ((w - g.width) // 2, 124 - lift - g.height), g)
                cv.save(f"{outd}/{an}_{i:02d}.png"); strip.paste(cv, (i * w, 0))
            strip.save(f"{outd}/{an}_strip.png")
            bg = [Image.alpha_composite(Image.new("RGBA", (w, 128), (30, 50, 60, 255)), strip.crop((i * w, 0, i * w + w, 128))).convert("RGB") for i in range(len(fs))]
            bg[0].save(f"{outd}/{an}.gif", save_all=True, append_images=bg[1:], duration=110, loop=0)
            meta["anims"][who][an] = len(fs); meta["anims"][who][an + "_frame_w"] = w
            print(who, an, len(fs), [f.size for f, _ in fs])
    json.dump(meta, open("art_drop/anim_v2_asset.json", "w"), indent=1, ensure_ascii=False)
    # پرتره‌های Ilara (پس‌زمینهٔ سبز تیره -> شفاف با floodfill)
    im = Image.open(f"{RAW}/ilara_portraits_v2_full.png").convert("RGB"); W, H = im.size; names = ["neutral", "angry", "shocked", "sad", "happy", "crying"]
    os.makedirs("art_drop/portraits/ilara", exist_ok=True)
    for i, n in enumerate(names):
        c, r = i % 3, i // 3; cell = im.crop((c * W // 3, r * H // 2, (c + 1) * W // 3, (r + 1) * H // 2)); cell.save(f"art_drop/portraits/ilara/{n}.png")
        a = np.array(cell).astype(int); bgc = np.median(np.concatenate([a[:6, :6].reshape(-1, 3), a[:6, -6:].reshape(-1, 3)]), axis=0)
        near = (np.abs(a - bgc).sum(-1) < 40); lab, k = ndimage.label(near); border = set(lab[0]) | set(lab[-1]) | set(lab[:, 0]) | set(lab[:, -1]); border.discard(0)
        m = np.isin(lab, list(border)); Image.fromarray(np.dstack([a.astype(np.uint8), np.where(m, 0, 255).astype(np.uint8)]), "RGBA").save(f"art_drop/portraits/ilara/{n}_alpha.png")
if __name__ == "__main__": run()
