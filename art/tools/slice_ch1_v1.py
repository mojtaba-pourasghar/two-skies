#!/usr/bin/env python3
"""برش دستهٔ ۱ گرافیک فصل ۱ (مراحل ۱–۳): لباس خانگی کایرو/ایلارا، پراپ‌ها، دشمن/مانع، افکت، و سه صحنه.
  python3 -I art/tools/slice_ch1_v1.py     (اصل‌ها: art/raw/ch1_v1/*_full.png)"""
import json, os
import numpy as np
from PIL import Image
from scipy import ndimage
RAW = "art/raw/ch1_v1"
def key(path):
    a = np.array(Image.open(path).convert("RGB")).astype(int); r, g, b = a[..., 0], a[..., 1], a[..., 2]
    m = ((r > 170) & (b > 170) & (g < 120)) | ((r > g * 2) & (b > g * 2) & (r > 50) & (b > 50))
    edge = (~m) & (r > g * 1.3) & (b > g * 1.3); a[edge, 0] = np.minimum(r[edge], g[edge] + 12); a[edge, 2] = np.minimum(b[edge], g[edge] + 12)
    return np.dstack([a.astype(np.uint8), np.where(m, 0, 255).astype(np.uint8)])
def items(name, dil=6, minarea=800, rowgap=70):
    """اجزای متصل → فهرست RGBA بریده‌شده به ترتیب سطری (y خوشه‌ای، سپس x)."""
    a = key(f"{RAW}/{name}_full.png"); m = a[..., 3] > 0; lab, k = ndimage.label(ndimage.binary_dilation(m, iterations=dil)); lab = np.where(m, lab, 0)
    ids = [i for i in range(1, k + 1) if (lab == i).sum() >= minarea]; cen = {i: ndimage.center_of_mass(lab == i) for i in ids}
    ids.sort(key=lambda i: cen[i][0]); rows = []; 
    for i in ids:
        if rows and abs(cen[i][0] - np.mean([cen[j][0] for j in rows[-1]])) < rowgap: rows[-1].append(i)
        else: rows.append([i])
    out = []
    for r in rows:
        for i in sorted(r, key=lambda i: cen[i][1]):
            b = a.copy(); b[..., 3] = np.where(lab == i, 255, 0); im = Image.fromarray(b, "RGBA"); out.append(im.crop(im.getbbox()))
    return out, [len(r) for r in rows]
def scale(im, s): return im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.BOX)
def quant(ims, n):
    px = np.concatenate([np.array(i)[np.array(i)[..., 3] > 0][:, :3] for i in ims]); side = int(np.ceil(np.sqrt(len(px))))
    pal = Image.fromarray(np.pad(px, ((0, side * side - len(px)), (0, 0)), mode="edge").reshape(side, side, 3).astype(np.uint8), "RGB").quantize(n, method=Image.MEDIANCUT, dither=Image.NONE)
    out = []
    for i in ims:
        arr = np.array(i); rgb = Image.fromarray(arr[..., :3], "RGB").quantize(palette=pal, dither=Image.NONE).convert("RGB")
        out.append(Image.fromarray(np.dstack([np.array(rgb), np.where(arr[..., 3] > 127, 255, 0)]).astype(np.uint8), "RGBA"))
    return out
def save(ims, names, outd, canvas=None, anchor="bottom"):
    os.makedirs(outd, exist_ok=True); meta = {}
    W = canvas[0] if canvas else None
    for im, n in zip(ims, names):
        if canvas:
            cv = Image.new("RGBA", canvas, (0, 0, 0, 0)); x = (canvas[0] - im.width) // 2; y = canvas[1] - 4 - im.height if anchor == "bottom" else (canvas[1] - im.height) // 2
            cv.paste(im, (x, y), im); im = cv
        im.save(f"{outd}/{n}.png"); meta[n] = list(im.size)
    json.dump({"status": "draft-until-user-approval", "frames": meta}, open(f"{outd}/asset.json", "w"), indent=1, ensure_ascii=False); return meta
def run():
    rep = {}
    # شخصیت‌ها: مقیاس هم‌تراز با idle تأییدشده (کایرو 0.1972، ایلارا 0.2115)، بوم ۱۲۸، خط پا y=124
    for who, f, s, names in (("kairo", "kairo_home", 0.1972, ["idle_down", "idle_side", "idle_up", "run_side", "wall_jump", "hurt"]),
                             ("ilara", "ilara_home", 0.2115, ["idle_down", "idle_side", "idle_up", "scared", "reach", "reach_glow"])):
        ims, rows = items(f, dil=8, minarea=3000); assert len(ims) == 6, (f, rows)
        q = quant([scale(i, s) for i in ims], 64); rep[f] = save(q, names, f"art_drop/{who}/home", (128, 128))
    # پراپ‌ها: مقیاس ۰٫۲۵ (مبل ~۹۶px)، بدون بوم ثابت
    ims, rows = items("props", dil=6, minarea=3000); names = ["family_photo", "wall_clock", "sofa", "armchair", "bookshelf", "lamp", "curtains", "door", "server_rack", "steam_pipe", "power_pole", "neon_sign"]
    assert len(ims) == 12, rows; rep["props"] = save(quant([scale(i, 0.25) for i in ims], 64), names, "art_drop/props_ch1")
    # دشمن/مانع: مقیاس ۰٫۲؛ بوم مشترک برای فریم‌های هر شیء
    ims, rows = items("hazards_enemies", dil=14, minarea=2500); assert len(ims) == 12, rows
    names = ["drone_hover", "drone_scan", "drone_explode", "saw_0", "saw_1", "saw_2", "vent_idle", "vent_warn", "vent_burst", "ceiling_warn", "ceiling_fall", "ceiling_hit"]
    q = quant([scale(i, 0.2) for i in ims], 64); W = max(i.width for i in q) + 8; H = max(i.height for i in q) + 8; rep["hazards"] = save(q, names, "art_drop/hazards_ch1", (W, H), "center")
    # افکت‌ها: مقیاس ۰٫۲۵
    ims, rows = items("fx", dil=10, minarea=200, rowgap=60); rep["fx_rows"] = rows
    # ردیف ۲: ۴ جرقه + قطعات خاکستر پراکنده → خاکستر با برش ثابت ۴ خوشه از ردیف
    a = key(f"{RAW}/fx_full.png"); ash = []
    for x0, x1 in ((820, 1000), (1000, 1200), (1200, 1400), (1400, 1600)):
        c = a[215:330, x0:x1].copy(); im = Image.fromarray(c, "RGBA"); bb = im.getbbox(); ash.append(im.crop(bb) if bb else im)
    keep = ims[:5] + ims[5 - 1 + 1:5] if False else None
    row1 = ims[:4]; spark = ims[4:8]; rest = ims[4 + 4 + 6:]   # 4 + (4 جرقه + 6 قطعهٔ خاکستر) + بقیه
    names = ["dash_ref"] + [f"dash_trail_{i}" for i in range(3)] + [f"spark_{i}" for i in range(4)] + [f"wire_{i}" for i in range(3)] + [f"blast_{i}" for i in range(5)] + [f"rain_{i}" for i in range(3)] + ["warning"]
    allf = row1 + spark + rest; assert len(allf) == len(names), (len(allf), len(names), rows)
    rep["fx"] = save([scale(i, 0.25) for i in allf], names, "art_drop/fx_ch1")
    save([scale(i, 0.25) for i in ash], [f"ash_{i}" for i in range(4)], "art_drop/fx_ch1_ash")
    # صحنه‌ها ۱۲۸۰×۷۲۰
    os.makedirs("art_drop/scenes/ch1", exist_ok=True)
    for n in ("house", "street", "basement"):
        Image.open(f"{RAW}/scene_{n}_full.png").convert("RGB").resize((1280, 720), Image.LANCZOS).save(f"art_drop/scenes/ch1/{n}_1280x720.png")
    print(json.dumps({k: (list(v)[:3] if isinstance(v, dict) else v) for k, v in rep.items()}, ensure_ascii=False))
if __name__ == "__main__": run()
