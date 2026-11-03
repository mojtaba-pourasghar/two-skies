#!/usr/bin/env python3
"""هنر موقت «دو آسمان» را می‌سازد — همه از روی لوحهٔ رنگ یکپارچهٔ سند ۰۴.

چرا اسکریپت و نه فایل دستی: هنر موقت است و بارها عوض می‌شود؛ تا وقتی از اسکریپت
بیرون می‌آید، هر تغییر پالت یک‌جا اعمال می‌شود، هیچ رنگ سرگردانی در مخزن نمی‌ماند
و بازبینی تغییر هنر به جای دیف دودویی، دیف متنی است.

قواعد ثابتی که سند می‌گذارد و اینجا رعایت می‌شود:
  * پس‌زمینهٔ دور همیشه #14161F
  * پلتفرم قابل‌ایستادن خط بالایی روشن‌تر دارد: ۱ پیکسل #C9CCD6
  * خطر همیشه #FF4D4D (چشمکش کار کد است، نه بافت)
  * چیزی که لمس‌پذیر است لبهٔ سفید ۱ پیکسلی دارد
  * خط دور یک پیکسل با رنگ تیرهٔ هم‌خانواده، نه مشکی خالص
  * سایه/هایلایت فقط با فرمول سند (palette.shade / palette.light)

اجرا:  python3 -I tools/gen_art.py
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import palette as P  # noqa: E402
from pixel import CLEAR, RGBA, Canvas, hex_rgba, mix  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
ART = ROOT / "game" / "art"
TILE = 16

# ----- رنگ‌های آماده -----
C = {
    "ash": P.rgba(P.NIGHT_ASH),
    "steel": P.rgba(P.BURNT_STEEL),
    "steel_d": P.shade(P.BURNT_STEEL),
    "steel_l": P.light(P.BURNT_STEEL),
    "rust": P.rgba(P.RUST_RED),
    "rust_d": P.shade(P.RUST_RED),
    "fire": P.rgba(P.FIRE_ORANGE),
    "fire_d": P.shade(P.FIRE_ORANGE),
    "fire_l": P.light(P.FIRE_ORANGE),
    "warn": P.rgba(P.WARN_YELLOW),
    "warn_d": P.shade(P.WARN_YELLOW),
    "dust": P.rgba(P.LIGHT_DUST),
    "dust_d": P.shade(P.LIGHT_DUST),
    "far": P.rgba(P.UI_PANEL),
    "white": P.rgba(P.WHITE),
    "cyan": P.rgba(P.DIGITAL_CYAN),
    "cyan_d": P.shade(P.DIGITAL_CYAN),
    "danger": P.rgba(P.DANGER),
    "danger_d": P.shade(P.DANGER),
    "coin": P.rgba(P.COIN),
    "coin_d": P.shade(P.COIN),
    "emerald": P.rgba(P.EMERALD),
    "emerald_d": P.shade(P.EMERALD),
    "success": P.rgba(P.SUCCESS),
    "soil": P.rgba(P.AURA_SOIL),
    "soil_d": P.shade(P.AURA_SOIL),
    "teal": P.rgba(P.WATER_TEAL),
    "bolt": P.rgba(P.BOLT_BODY),
    "bolt_d": P.shade(P.BOLT_BODY),
    "panel": P.rgba(P.UI_PANEL),
    "text": P.rgba(P.UI_TEXT),
    "server": P.rgba(P.SERVER_BLUE),
}


#: در حالت بررسی چیزی نوشته نمی‌شود؛ فقط با آنچه روی دیسک است مقایسه می‌شود.
CHECK = False
MISMATCH: list[str] = []


def _emit(data: bytes, rel: str) -> Path:
    path = ART / rel
    if CHECK:
        if not path.exists() or path.read_bytes() != data:
            MISMATCH.append(rel)
        return path
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(data)
    return path


def save(canvas: Canvas, rel: str) -> Path:
    return _emit(canvas.to_png(), rel)


# ===================== کاشی‌ها =====================

def ground_tile(top_lit: bool, left_edge: bool, right_edge: bool) -> Canvas:
    """یک کاشی جامد ۱۶×۱۶ با سه پلهٔ سایه (§۴: سایه، میانه، روشن)."""
    t = Canvas(TILE, TILE, C["steel"])
    # بافت آجری ریز با پلهٔ تیره، تا سطح یکدست نباشد
    for y in range(TILE):
        for x in range(TILE):
            band = (y // 4) % 2
            if (x + band * 4) % 8 == 0:
                t.set(x, y, C["steel_d"])
    # کف کاشی تیره‌تر: نور جهت‌دار از بالا (§۴)
    t.hline(0, TILE - 1, TILE, C["steel_d"])
    if top_lit:
        # «پلتفرم قابل‌ایستادن با خط بالایی روشن‌تر، ۱ پیکسل، #C9CCD6»
        t.hline(0, 0, TILE, C["dust"])
        t.hline(0, 1, TILE, C["steel_l"])
    if left_edge:
        t.vline(0, 1, TILE - 1, C["steel_d"])
    if right_edge:
        t.vline(TILE - 1, 1, TILE - 1, C["steel_d"])
    return t


def gen_tileset() -> Path:
    """اطلس ۴ کاشی در یک ردیف: درون، سطح، سکوی تک، ستون."""
    atlas = Canvas(TILE * 4, TILE)
    atlas.blit(ground_tile(False, False, False), 0, 0)          # ۰ درون توده
    atlas.blit(ground_tile(True, False, False), TILE, 0)        # ۱ سطح
    atlas.blit(ground_tile(True, True, True), TILE * 2, 0)      # ۲ سکوی تک
    atlas.blit(ground_tile(False, True, True), TILE * 3, 0)     # ۳ ستون
    return save(atlas, "tilesets/ch1_ground.png")


# ===================== شخصیت‌ها =====================
# بوم ۱۲×۱۶، دقیقاً هم‌اندازهٔ ناحیهٔ برخورد (۱۰×۱۶) به‌علاوهٔ خط دور،
# تا شخصیت روی زمین شناور یا فرورفته دیده نشود.

_CHAR_ART = [
    "..hhhhhh..",
    ".hhhhhhhh.",
    ".hssssssh.",
    ".ssessess.",
    ".ssssssss.",
    "..cccccc..",
    ".jjjjjjjj.",
    "jjjjggjjjj",
    "jjjjjjjjjj",
    "jjjjjjjjjj",
    ".jjjjjjjj.",
    "..jj..jj..",
    "..jj..jj..",
    "..jj..jj..",
    "..dd..dd..",
    "..dd..dd..",
]


def character(scarf: str, jacket: str, skin: str, hair: str, glow: str | None) -> Canvas:
    key = {
        "h": P.rgba(hair),
        "s": P.rgba(skin),
        "e": P.rgba(P.UI_PANEL),            # چشم
        "c": P.rgba(scarf),
        "j": P.rgba(jacket),
        "d": P.shade(jacket),               # شلوار: سایهٔ فرمولی ژاکت
        "g": P.rgba(glow) if glow else P.rgba(jacket),
    }
    body = Canvas(10, 16)
    body.from_art(_CHAR_ART, key)
    out = Canvas(12, 16)
    out.blit(body, 1, 0)
    # خط دور تیرهٔ هم‌خانواده (سایهٔ ژاکت)، نه مشکی خالص
    out.outline(P.shade(jacket, 0.75))
    # نور لبه (§۴): «روی شخصیت‌ها در صحنه‌های شب، یک خط ۱ پیکسلی از رنگ نور
    # اصلی». فصل ۱ شب است و کایرو ژاکت تیره دارد؛ بدون این خط روی کاشی تیره
    # گم می‌شود و قاعدهٔ تضاد ۳۰٪ §۴ می‌شکند. نور از بالا-چپ می‌تابد.
    _rim_light(out, P.rgba(P.CH1["accent"]))
    return out


def _rim_light(c: Canvas, color: RGBA) -> None:
    """پیکسل‌های لبهٔ چپ و بالای هر توده را به رنگ نور اصلی می‌برد."""
    hits: list[tuple[int, int]] = []
    for y in range(c.h):
        for x in range(c.w):
            if c.get(x, y)[3] == 0:
                continue
            if c.get(x - 1, y)[3] == 0 or c.get(x, y - 1)[3] == 0:
                hits.append((x, y))
    for x, y in hits:
        c.set(x, y, mix(c.get(x, y), color, 0.55))


def gen_characters() -> list[Path]:
    kairo = character(P.KAIRO_SCARF, P.KAIRO_JACKET, P.KAIRO_SKIN, P.KAIRO_HAIR, P.DIGITAL_CYAN)
    ilara = character(P.ILARA_SCARF, P.ILARA_JACKET, P.ILARA_SKIN, P.ILARA_HAIR, None)
    return [save(kairo, "sprites/kairo.png"), save(ilara, "sprites/ilara.png")]


# ===================== موانع =====================

def gen_spike() -> Path:
    """تیغه ۱۶×۸. §۴: «هر خطر علاوه بر رنگ، شکل یا الگو هم دارد» — دندانه."""
    s = Canvas(TILE, 8)
    for i in range(4):
        base_x = i * 4
        for row in range(8):
            half = max(0, (row + 1) // 2)
            for x in range(base_x + 2 - half, base_x + 2 + half):
                s.set(x, row, C["danger"])
    # راه‌راه هشدار زرد-تیره در پایه (خوانایی برای نابینایی رنگ)
    s.hline(0, 7, TILE, C["danger_d"])
    for x in range(0, TILE, 4):
        s.set(x, 7, C["warn"])
    s.outline(P.shade(P.DANGER, 0.7))
    return save(s, "sprites/spike.png")


def gen_crumble() -> Path:
    """سکوی شکننده ۱۶×۸ — خاک اورا با ترک، تا با زمین ثابت اشتباه نشود."""
    s = Canvas(TILE, 8, C["soil"])
    s.hline(0, 0, TILE, C["dust"])          # قاعدهٔ خط بالایی سکو
    s.hline(0, 7, TILE, C["soil_d"])
    for x, y in ((4, 2), (5, 3), (5, 4), (10, 2), (11, 3), (11, 4), (11, 5), (3, 5)):
        s.set(x, y, C["soil_d"])
    return save(s, "sprites/crumble.png")


def gen_laser() -> Path:
    """فرستندهٔ لیزر ۶×۱۶ — فولاد با چشم قرمز."""
    s = Canvas(6, TILE, C["steel"])
    s.hline(0, 0, 6, C["steel_l"])
    s.hline(0, TILE - 1, 6, C["steel_d"])
    s.rect(1, 6, 4, 4, C["danger"])
    s.rect(2, 7, 2, 2, P.light(P.DANGER))
    s.outline(P.shade(P.BURNT_STEEL, 0.75))
    return save(s, "sprites/laser_emitter.png")


def gen_drone() -> Path:
    """پهپاد ۱۶×۱۰ در دو حالت: فعال و هک‌شده. اطلس ۳۲×۱۰."""
    def body(active: bool) -> Canvas:
        shell = C["bolt"] if active else C["steel"]
        shell_d = C["bolt_d"] if active else C["steel_d"]
        eye = C["danger"] if active else C["cyan"]
        d = Canvas(TILE, 10)
        d.rect(2, 2, 12, 6, shell)
        d.hline(2, 2, 12, P.light(P.BOLT_BODY) if active else C["steel_l"])
        d.hline(2, 7, 12, shell_d)
        d.rect(6, 3, 4, 4, C["white"])
        d.rect(7, 4, 2, 2, eye)
        # پروانه‌ها
        d.hline(0, 1, 4, shell_d)
        d.hline(12, 1, 4, shell_d)
        d.set(1, 0, shell)
        d.set(14, 0, shell)
        # چراغ کوچک #F2C94C (سند: بولت)
        d.set(3, 5, C["warn"] if active else C["steel_d"])
        d.outline(P.shade(P.BOLT_BODY if active else P.BURNT_STEEL, 0.75))
        return d

    atlas = Canvas(TILE * 2, 10)
    atlas.blit(body(True), 0, 0)
    atlas.blit(body(False), TILE, 0)
    return save(atlas, "sprites/drone.png")


# ===================== اقلام =====================

def _touchable_edge(c: Canvas) -> None:
    """«چیزی که لمس‌پذیر است لبهٔ سفید ۱ پیکسل دارد»."""
    c.outline(C["white"])


def _diamond(size: int, fill, dark, lit) -> Canvas:
    c = Canvas(size, size)
    mid = (size - 1) / 2.0
    for y in range(size):
        for x in range(size):
            if abs(x - mid) + abs(y - mid) <= mid:
                c.set(x, y, fill if y <= mid else dark)
    c.set(int(mid) - 1, int(mid) - 1, lit)
    return c


def gen_pickups() -> Path:
    """اطلس ۳۶×۱۲: سکه، زمرد، تراشه."""
    atlas = Canvas(36, 12)

    coin = Canvas(12, 12)
    for y in range(12):
        for x in range(12):
            dx, dy = x - 5.5, y - 5.5
            if dx * dx + dy * dy <= 20:
                coin.set(x, y, C["coin"] if dy <= 0 else C["coin_d"])
    coin.rect(4, 4, 2, 2, P.light(P.COIN))
    _touchable_edge(coin)
    atlas.blit(coin, 0, 0)

    em = _diamond(12, C["emerald"], C["emerald_d"], P.light(P.EMERALD))
    _touchable_edge(em)
    atlas.blit(em, 12, 0)

    chip = Canvas(12, 12)
    chip.rect(2, 3, 8, 6, C["server"])
    chip.rect(4, 5, 4, 2, C["cyan"])
    for x in (1, 10):
        for y in (4, 6, 8):
            chip.set(x, y, C["dust"])
    _touchable_edge(chip)
    atlas.blit(chip, 24, 0)
    return save(atlas, "sprites/pickups.png")


def gen_note() -> Path:
    """یادداشت ۱۲×۱۲ — کاغذ روشن با خطوط متن."""
    n = Canvas(12, 12)
    n.rect(2, 1, 8, 10, C["text"])
    n.hline(2, 1, 8, C["white"])
    for y in (3, 5, 7, 9):
        n.hline(4, y, 5, C["steel"])
    n.outline(C["warn"])
    return save(n, "sprites/note.png")


def gen_gate() -> Path:
    """اطلس ۳۲×۱۶: دروازهٔ هک‌شدنی (فیروزه) و در کلیددار (کهربا)."""
    def panel(accent) -> Canvas:
        g = Canvas(TILE, TILE, C["steel"])
        g.hline(0, 0, TILE, C["steel_l"])
        g.hline(0, TILE - 1, TILE, C["steel_d"])
        g.vline(0, 0, TILE, C["steel_d"])
        g.vline(TILE - 1, 0, TILE, C["steel_d"])
        for y in range(3, TILE - 2, 4):
            g.hline(3, y, 10, accent)
        g.rect(6, 6, 4, 4, accent)
        g.rect(7, 7, 2, 2, C["white"])
        return g

    atlas = Canvas(TILE * 2, TILE)
    atlas.blit(panel(C["cyan"]), 0, 0)
    atlas.blit(panel(P.rgba(P.AMBER_SUN)), TILE, 0)
    return save(atlas, "sprites/gate.png")


def gen_exit() -> Path:
    """اطلس ۳۲×۲۴: خروج (سبز موفقیت) و نقطهٔ ذخیره (فیروزهٔ نکسا)."""
    def arch(accent) -> Canvas:
        e = Canvas(TILE, 24)
        for y in range(24):
            e.vline(1, 2, 22, accent)
            e.vline(TILE - 2, 2, 22, accent)
        e.hline(1, 1, TILE - 2, accent)
        e.rect(3, 3, 10, 20, mix(accent, hex_rgba(P.NIGHT_ASH), 0.65))
        # پیکان رو به بالا: خوانایی با شکل، نه فقط با رنگ (§۴، نابینایی رنگ)
        for i in range(5):
            e.hline(7 - i, 6 + i, 2 + i * 2, accent)
        e.rect(7, 11, 2, 8, accent)
        _touchable_edge(e)
        return e

    atlas = Canvas(TILE * 2, 24)
    atlas.blit(arch(C["success"]), 0, 0)
    atlas.blit(arch(C["cyan"]), TILE, 0)
    return save(atlas, "sprites/exit.png")


# ===================== پس‌زمینهٔ لایه‌ای فصل ۱ =====================

W, H = 480, 270


class Rng:
    """مولّد خطی ساده با بذر ثابت — هنر باید بین اجراها یکسان باشد."""

    def __init__(self, seed: int) -> None:
        self.s = seed & 0xFFFFFFFF

    def next(self, n: int) -> int:
        self.s = (1103515245 * self.s + 12345) & 0x7FFFFFFF
        return self.s % n


def gen_sky() -> Path:
    """لایهٔ ۰: گرادیان ۴ پله‌ای #B8452F → #1F2230 (ردیف فصل ۱)."""
    top = P.rgba(P.RUST_RED)
    bot = P.rgba(P.NIGHT_ASH)
    sky = Canvas(W, H)
    steps = 4
    for y in range(H):
        step = min(steps - 1, y * steps // H)
        sky.hline(0, y, W, mix(top, bot, step / (steps - 1)))
    return save(sky, "fx/ch1_sky.png")


def gen_far() -> Path:
    """لایهٔ ۱ (پارالاکس ۱۰٪): خط افق شهر. «پس‌زمینهٔ دور همیشه #14161F»."""
    far = Canvas(W, H)
    rng = Rng(20260411)
    x = 0
    while x < W:
        w = 14 + rng.next(26)
        h = 40 + rng.next(80)
        far.rect(x, H - h, min(w, W - x), h,
                 mix(hex_rgba(P.UI_PANEL), hex_rgba(P.RUST_RED), 0.12))
        x += w + rng.next(6)
    return save(far, "fx/ch1_far.png")


def gen_mid() -> Path:
    """لایهٔ ۲ (پارالاکس ۳۵٪): ساختمان‌ها با پنجرهٔ روشن.

    سند رنگ این لایه را «رنگ دوم» (#F2C94C) می‌گوید. یک دیوار یکدست زرد
    صفحه را می‌سوزاند و قانون «رنگ تاکیدی بیشتر از ۱۵٪ سطح نگیرد» را می‌شکند،
    پس تودهٔ ساختمان سایهٔ فولاد است و رنگ دوم فقط در پنجره‌ها می‌آید —
    همان «شب سوزان» ردیف فصل ۱. (DECISIONS.md: D-059)
    """
    mid = Canvas(W, H)
    rng = Rng(777)
    # تودهٔ ساختمان باید از کاشی‌های زمین (#3A3F52) دست‌کم ۳۰٪ تیره‌تر باشد،
    # وگرنه بازیکن پس‌زمینه را با سکو اشتباه می‌گیرد — قاعدهٔ تضاد §۴.
    body = mix(hex_rgba(P.UI_PANEL), hex_rgba(P.NIGHT_ASH), 0.35)
    ledge = mix(body, hex_rgba(P.BURNT_STEEL), 0.35)
    window = mix(hex_rgba(P.WARN_YELLOW), body, 0.35)
    x = 0
    while x < W:
        w = 22 + rng.next(30)
        h = 60 + rng.next(110)
        w = min(w, W - x)
        mid.rect(x, H - h, w, h, body)
        mid.hline(x, H - h, w, ledge)
        for wy in range(H - h + 5, H - 4, 9):
            for wx in range(x + 3, x + w - 3, 7):
                if rng.next(10) < 3:
                    mid.rect(wx, wy, 2, 2, window)
        x += w + 2 + rng.next(10)
    return save(mid, "fx/ch1_mid.png")


# ===================== خروجی GDScript =====================

GD_HEADER = """## لوحهٔ رنگ یکپارچهٔ «دو آسمان».
##
## این فایل با tools/gen_art.py از tools/palette.py ساخته می‌شود — دستی ویرایشش
## نکن. سند ۰۴ می‌گوید «هیچ رنگی خارج از این جدول‌ها در بازی استفاده نمی‌شود»،
## پس هر رنگی در کد باید از اینجا بیاید.
class_name Palette
extends RefCounted

"""


def gen_gdscript() -> Path:
    lines = [GD_HEADER]
    for name, value in sorted(P.ALL.items()):
        lines.append('const %s := Color("%s")\n' % (name, value))
    lines.append("""
## سایه = رنگ پایه روی #1F2230 با ۴۰٪ (فرمول سند ۰۴).
static func shade(base: Color, amount: float = 0.40) -> Color:
\treturn base.lerp(NIGHT_ASH, amount)


## هایلایت = رنگ پایه روی #FFFFFF با ۳۰٪ (فرمول سند ۰۴).
static func light(base: Color, amount: float = 0.30) -> Color:
\treturn base.lerp(WHITE, amount)
""")
    return _emit("".join(lines).encode("utf-8"), "palette.gd")


def main(argv: list[str]) -> int:
    global CHECK
    CHECK = "--check" in argv
    made: list[Path] = []
    made.append(gen_tileset())
    made += gen_characters()
    made.append(gen_spike())
    made.append(gen_crumble())
    made.append(gen_laser())
    made.append(gen_drone())
    made.append(gen_pickups())
    made.append(gen_note())
    made.append(gen_gate())
    made.append(gen_exit())
    made.append(gen_sky())
    made.append(gen_far())
    made.append(gen_mid())
    made.append(gen_gdscript())
    if CHECK:
        if MISMATCH:
            print("هنر با اسکریپت نمی‌خواند — دوباره بساز (python3 -I tools/gen_art.py):")
            for rel in MISMATCH:
                print("  ✘ art/%s" % rel)
            return 1
        print("هنر موقت: هر %d فایل با tools/gen_art.py یکی است." % len(made))
        return 0
    for p in made:
        print("  ساخته شد: %s (%d بایت)" % (p.relative_to(ROOT), p.stat().st_size))
    print("هنر موقت: %d فایل." % len(made))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
