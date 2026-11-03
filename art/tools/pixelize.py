#!/usr/bin/env python3
"""تبدیل تصویر نقاشی‌وار (Canva/Cloudflare) به پیکسل‌آرت قابل‌استفاده در بازی.

استفاده:
  python3 -I art/tools/pixelize.py IN.png OUT.png --size 640x360 --colors 64 [--sat 1.35 --bright 1.2 --contrast 1.15]
  برای اسپرایت/آیکون: --size 32x48 --colors 16 --transparent  (پس‌زمینهٔ تخت را شفاف می‌کند)
هیچ کلید یا شبکه‌ای لازم نیست. فیلتر Nearest را در Godot روشن کن.
"""
import argparse
from PIL import Image, ImageEnhance, ImageFilter

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src"); ap.add_argument("dst")
    ap.add_argument("--size", default="640x360")
    ap.add_argument("--colors", type=int, default=64)
    ap.add_argument("--sat", type=float, default=1.35)
    ap.add_argument("--bright", type=float, default=1.2)
    ap.add_argument("--contrast", type=float, default=1.15)
    ap.add_argument("--transparent", action="store_true")
    ap.add_argument("--preview", type=int, default=3, help="ضریب پیش‌نمایش Nearest (0 = بدون)")
    a = ap.parse_args()
    w, h = (int(v) for v in a.size.lower().split("x"))
    im = Image.open(a.src).convert("RGB")
    # کاهش با فیلتر جعبه‌ای (BOX) برای پیکسل‌های تمیز، سپس تیزکردن و نگاشت پالت
    im = im.resize((w, h), Image.BOX if im.width >= w else Image.LANCZOS)
    im = im.filter(ImageFilter.UnsharpMask(radius=1.0, percent=120, threshold=2))
    im = ImageEnhance.Color(im).enhance(a.sat)
    im = ImageEnhance.Brightness(im).enhance(a.bright)
    im = ImageEnhance.Contrast(im).enhance(a.contrast)
    im = im.filter(ImageFilter.MedianFilter(3))
    q = im.quantize(colors=a.colors, method=Image.MEDIANCUT, dither=Image.NONE).convert("RGBA")
    if a.transparent:
        bg = q.getpixel((0, 0))
        px = q.load()
        for y in range(h):
            for x in range(w):
                if px[x, y][:3] == bg[:3]:
                    px[x, y] = (0, 0, 0, 0)
    q.save(a.dst)
    if a.preview:
        q.resize((w * a.preview, h * a.preview), Image.NEAREST).save(a.dst.replace(".png", "_preview.png"))
    print(f"{a.dst}: {w}x{h}, {a.colors} رنگ")

if __name__ == "__main__":
    main()
