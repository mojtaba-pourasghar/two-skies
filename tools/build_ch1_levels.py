#!/usr/bin/env python3
"""نقشه‌های فصل ۱ را از docs/02_godot_spec.md §۱۱ می‌خواند و فایل‌های JSON مرحله می‌سازد.

نقشه‌ها دستی کپی نمی‌شوند؛ از خود سند خوانده می‌شوند تا خطای رونویسی ممکن نباشد.
هر چیزی که در سند نیست (شناسهٔ گوهر، کلید متن یادداشت، فاز لیزر، مسیر پهپاد،
اتصال اتاق‌ها) در همین فایل صریح نوشته شده و در DECISIONS.md توضیح داده شده است.

اجرا:  python3 tools/build_ch1_levels.py
خروجی: game/levels/data/ch1_l1.json ... ch1_l3.json
"""
from __future__ import annotations
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SPEC = ROOT / "docs" / "02_godot_spec.md"
OUT_DIR = ROOT / "game" / "levels" / "data"

ROOM_W = 30
ROOM_H = 17
COMPACT_ROWS = 12
# قالب فشردهٔ §۱۱ از سطر ۲ شروع می‌شود
COMPACT_OFFSET = 2


def in_ranges(c: int, ranges: list[list[int]]) -> bool:
    return any(len(rng) >= 2 and rng[0] <= c <= rng[1] for rng in ranges)


def expand(rows: list[str], gaps: list[list[int]], crumble: list[list[int]]) -> list[str]:
    """۱۲ سطر §۱۱ → ۱۷ سطر کامل.

    سطر ۰ و ۱ سقف جامد، سطر ۱۴ تا ۱۶ کف جامد، مگر ستون‌هایی که یادداشت اتاق
    «گودال» یا «کف شکننده» اعلام کرده. این همان کاری است که لودر هم می‌کند؛
    اینجا انجام می‌شود تا JSON، اعتبارسنج پایتونی و لودر هر سه یک چیز ببینند.
    """
    out = ["#" * ROOM_W, "#" * ROOM_W]
    out.extend(rows)
    for r in range(14, ROOM_H):
        line = ""
        for c in range(ROOM_W):
            if in_ranges(c, gaps):
                line += "."
            elif in_ranges(c, crumble):
                line += "~" if r == 14 else "."
            else:
                line += "#"
        out.append(line)
    assert len(out) == ROOM_H, len(out)
    return out

# ---------------------------------------------------------------- خواندن سند

def read_rooms() -> dict[str, list[str]]:
    """بلوک‌های ```…``` بخش ۱۱ را به {"L1R1": [۱۲ سطر], ...} تبدیل می‌کند."""
    text = SPEC.read_text(encoding="utf-8")
    start = text.index("## ۱۱.")
    end = text.index("## ۱۲.")
    section = text[start:end]
    rooms: dict[str, list[str]] = {}
    for block in re.findall(r"```\n(.*?)```", section, re.S):
        current = None
        for line in block.split("\n"):
            m = re.match(r"^(L\dR\d)", line)
            if m:
                current = m.group(1)
                rooms[current] = []
                continue
            if current and line.strip():
                # سطر اول L2R1 در سند یک فاصلهٔ اضافی دارد (۳۱ کاراکتر) —
                # DECISIONS.md: D-009
                rooms[current].append(line.rstrip())
    return rooms


def validate_raw(rooms: dict[str, list[str]]) -> list[str]:
    problems = []
    for name, rows in rooms.items():
        if len(rows) != COMPACT_ROWS:
            problems.append(f"{name}: {len(rows)} سطر، انتظار {COMPACT_ROWS}")
        for i, row in enumerate(rows):
            if len(row) != ROOM_W:
                problems.append(f"{name} سطر {i + 2}: {len(row)} کاراکتر، انتظار {ROOM_W}")
    return problems


# ------------------------------------------------- پیکربندی صریح هر مرحله
#
# `digits` می‌گوید هر نماد عددی در هر اتاق چه چیزی است. قاعده (DECISIONS.md D-006):
#   * §۸ می‌گوید «سه گوهر پنهان در هر مرحله»، پس هر مرحله حداکثر ۳ گوهر دارد.
#   * سند ۰۱ می‌گوید صفحهٔ دفتر ۱ در مرحلهٔ ۱ و صفحهٔ ۲ در مرحلهٔ ۲ است
#     (صفحهٔ ۳ در مرحلهٔ ۴ است که در نسخهٔ ۱ نیست).
#   * نمادهای عددی اضافه، سکه می‌شوند — چون §۸ گوهر را به سه تا محدود می‌کند و
#     قانون اقتصاد سند ۰۱ می‌گوید زمرد کمیاب است.
#
# `exits` یک‌طرفه‌ها را صریح می‌گوید. برگشت جایی حذف شده که بازیکن در اتاق مقصد
# داخل سنگ ظاهر می‌شد (DECISIONS.md: D-010).

LOW = [12, 13]
HIGH = [2, 3]

# ----------------------------------------------------------- وصله‌های نقشه
#
# §۱۱ خودش می‌گوید «این ۱۲ اتاق، نقشهٔ اولیهٔ قابل بازی هستند؛ بعد از نخستین
# ۲۰ دقیقه بازی تستی باید موقعیت موانع و سکه‌ها تنظیم شوند»، و §۱۶ شرط پذیرش
# می‌گذارد که «همهٔ گوهرها دسترس‌پذیرند». اعتبارسنج نشان داد سه گوهر نزدیک سقف
# کشیده شده‌اند و هیچ راه رسیدنی ندارند (ارتفاع پرش ۳ کاشی است و اتاق‌ها خالی‌اند).
#
# هر وصله اینجا صریح نوشته شده تا تفاوت با سند در یک جا دیده شود.
# DECISIONS.md: D-017
PATCHES = {
    # L1R2: گوهر در (۲۰,۳) زیر سقف بود. سه سکوی کوچک = «مسیر فرعی» که سند ۰۱
    # برای هر مرحله می‌خواهد. پله‌ها ۳ کاشی فاصله دارند، یعنی اندازهٔ یک پرش.
    "L1R2": [
        (11, 19, "#"), (11, 20, "#"),
        (8, 21, "#"), (8, 22, "#"),
        (5, 19, "#"), (5, 20, "#"),
    ],
    # L2R4: گوهر در (۱۰,۵) دست‌نیافتنی بود. دو سکو، بالای سکوهای شکننده.
    "L2R4": [
        (11, 8, "#"), (11, 9, "#"),
        (8, 9, "#"), (8, 10, "#"),
    ],
    # L3R4: سه گوهر در سطر ۴ بود، ۱۰ کاشی بالای کف. سه سکو ساخته شد و هر گوهر
    # روی پاگرد خودش نشست — یک راه بالاروندهٔ کنار لیزرها، که با توصیف سند ۰۱
    # («انباری پشت یک پهپاد با زمان‌بندی تنگ») هم می‌خواند.
    "L3R4": [
        (4, 9, "."), (4, 16, "."), (4, 23, "."),      # گوهرهای قبلی برداشته شد
        (11, 8, "#"), (11, 9, "#"), (10, 9, "1"),      # پاگرد اول
        (8, 12, "#"), (8, 13, "#"), (7, 13, "2"),      # پاگرد دوم
        (5, 16, "#"), (5, 17, "#"), (4, 17, "3"),      # پاگرد سوم
    ],
}


def apply_patches(name: str, rows: list[str]) -> list[str]:
    """وصله‌ها را روی نقشهٔ خوانده‌شده از سند اعمال می‌کند.

    مختصات **مطلق** است (سطر ۰ تا ۱۶)، ولی نقشهٔ §۱۱ فشرده است و از سطر ۲
    شروع می‌شود، پس قبل از باز شدن قالب، سطر مطلق r به اندیس r-2 نگاشته می‌شود.
    """
    patches = PATCHES.get(name, [])
    if not patches:
        return rows
    grid = [list(r) for r in rows]
    for (abs_row, col, ch) in patches:
        idx = abs_row - COMPACT_OFFSET
        if not (0 <= idx < len(grid)):
            raise ValueError(f"{name}: سطر مطلق {abs_row} بیرون از قالب فشرده است")
        if not (0 <= col < ROOM_W):
            raise ValueError(f"{name}: ستون {col} بیرون از اتاق است")
        grid[idx][col] = ch
    return ["".join(r) for r in grid]

LEVELS = {
    "ch1_l1": {
        "title_key": "ch1_l1_title",
        "par_time": 70,
        "music": "music_home",
        "rooms": ["L1R1", "L1R2", "L1R3", "L1R4"],
        "exits": {
            "L1R1": [("right", "r2", LOW)],
            "L1R2": [("left", "r1", LOW), ("right", "r3", LOW)],
            "L1R3": [("left", "r2", LOW), ("right", "r4", LOW)],
            "L1R4": [("left", "r3", LOW)],
        },
        # یادداشت §۱۱ «گودال در کف ستون‌های ۱۲–۱۴» سه کاشی می‌خواست، ولی برد
        # پرش ایلارا ۶۴٫۱px است و چالهٔ سه کاشی دقیقاً ۶۴px پرش لازم دارد —
        # حاشیهٔ صفر. او هیچ‌وقت کنترل بازیکن نیست و فقط مسیر کایرو را بازپخش
        # می‌کند، پس هیچ ورودی‌ای نجاتش نمی‌دهد و مرگش شکست مرحله است.
        # دو کاشی → ۴۸px لازم از ۶۴٫۱px ظرفیت = ۳۴٪ حاشیه (DECISIONS.md: D-038).
        "floor_gaps": {"L1R3": [[12, 13]]},
        "floor_crumble": {},
        "digits": {
            # L1R2: نماد ۱ بالای اتاق = گوهر پنهان، نماد ۲ روی مسیر اصلی = صفحهٔ دفتر
            "L1R2": {"1": ("gem", "ch1_l1_g1"), "2": ("page", "ch1_p1")},
        },
        "notes": {"L1R1": {"B": "ch1_l1_note1"}},
        "gates": {"L1R1": {"G": {"type": "gate"}}},
    },
    "ch1_l2": {
        "title_key": "ch1_l2_title",
        "par_time": 90,
        "music": "music_street",
        "rooms": ["L2R1", "L2R2", "L2R3", "L2R4"],
        "exits": {
            # خروج L2R1 «سمت راست بالا» است (یادداشت خود سند)
            "L2R1": [("right", "r2", HIGH)],
            "L2R2": [("right", "r3", LOW)],
            "L2R3": [("left", "r2", LOW), ("right", "r4", HIGH)],
            "L2R4": [],
        },
        "floor_gaps": {},
        # یادداشت §۱۱: «کف شکننده بین ستون‌های ۸–۲۱: پلتفرم‌های ~ روی سطر ۱۴»
        "floor_crumble": {"L2R2": [[8, 21]]},
        "digits": {
            "L2R1": {"1": ("gem", "ch1_l2_g1")},
            "L2R3": {"1": ("gem", "ch1_l2_g2"), "2": ("page", "ch1_p2")},
            "L2R4": {"1": ("gem", "ch1_l2_g3")},
        },
        "notes": {"L2R2": {"B": "ch1_l2_note1"}},
        "gates": {"L2R1": {"G": {"type": "gate"}, "T": {"type": "lock"}}},
    },
    "ch1_l3": {
        "title_key": "ch1_l3_title",
        "par_time": 110,
        "music": "music_hall",
        "rooms": ["L3R1", "L3R2", "L3R3", "L3R4"],
        "exits": {
            "L3R1": [("right", "r2", LOW)],
            "L3R2": [("left", "r1", LOW), ("right", "r3", LOW)],
            "L3R3": [("left", "r2", LOW), ("right", "r4", LOW)],
            "L3R4": [("left", "r3", LOW)],
        },
        "floor_gaps": {},
        # یادداشت §۱۱: «کف شکننده در ستون‌های ۷–۱۸»
        "floor_crumble": {"L3R3": [[7, 18]]},
        "digits": {
            # سه گوهر مرحله در اتاق پایانی‌اند که §۱۱ خودش ۱/۲/۳ کشیده؛
            # نمادهای عددی اتاق‌های دیگر سکه می‌شوند (§۸: سه گوهر در هر مرحله)
            "L3R1": {"1": ("coin", "")},
            "L3R2": {"1": ("coin", ""), "2": ("coin", "")},
            "L3R3": {"1": ("coin", "")},
            "L3R4": {
                "1": ("gem", "ch1_l3_g1"),
                "2": ("gem", "ch1_l3_g2"),
                "3": ("gem", "ch1_l3_g3"),
            },
        },
        "notes": {},
        "gates": {"L3R2": {"G": {"type": "gate"}}},
    },
}

# لیزرها: فاز هر لیزر طوری چیده می‌شود که پنجرهٔ امن هم‌زمان برای کایرو و ایلارا
# باز باشد (قاعدهٔ عدالت: پنجرهٔ امن ≥ ۱ ثانیه، هشدار ≥ ۰٫۴ ثانیه).
# ایلارا با ۰٫۸ ثانیه تأخیر می‌آید، پس لیزرهای یک اتاق فاز متفاوت می‌گیرند.
LASER_DIRS = {
    "L2R2": [("down", 0.0)],
    "L3R1": [("down", 0.0)],
    "L3R2": [("down", 0.0), ("down", 1.2)],
    "L3R3": [("down", 0.0)],
    "L3R4": [("down", 0.0), ("down", 0.8), ("down", 1.6)],
}

# پهپادها: مسیر افقی، برد بر حسب کاشی از محل خودش (§۷: مسیر بین دو نقطه)
DRONE_RANGE = 6


def build_level(level_id: str, cfg: dict, rooms: dict[str, list[str]]) -> dict:
    out_rooms = []
    laser_seen: dict[str, int] = {}

    for idx, src_name in enumerate(cfg["rooms"]):
        rows = apply_patches(src_name, rooms[src_name])
        rid = f"r{idx + 1}"
        objects: dict[str, dict] = {}

        # کدام نمادهای غیرپایه در این اتاق هست؟
        present = {ch for row in rows for ch in row if ch not in "#."}

        # نمادهای عددی
        for sym, (kind, ident) in cfg["digits"].get(src_name, {}).items():
            if sym not in present:
                continue
            if kind == "coin":
                objects[sym] = {"type": "coin"}
            else:
                objects[sym] = {"type": kind, "id": ident}

        # یادداشت
        for sym, key in cfg["notes"].get(src_name, {}).items():
            if sym in present:
                objects[sym] = {"type": "note", "text_key": key}

        # در و قفل
        for sym, spec in cfg["gates"].get(src_name, {}).items():
            if sym in present:
                objects[sym] = dict(spec)

        # لیزر — همهٔ L های یک اتاق یک نماد مشترک دارند، پس فاز اتاق یکی است.
        if "L" in present:
            dirs = LASER_DIRS.get(src_name, [("down", 0.0)])
            d, phase = dirs[laser_seen.get(src_name, 0) % len(dirs)]
            laser_seen[src_name] = laser_seen.get(src_name, 0) + 1
            objects["L"] = {"type": "laser", "dir": d, "phase": phase}

        # پهپاد
        if "n" in present:
            objects["n"] = {"type": "drone", "axis": "h", "range": DRONE_RANGE}

        # خروج
        if "X" in present:
            # مرحله‌های ۱ تا ۳ همراه دارند، پس هر دو شخصیت باید برسند (§۸)
            objects["X"] = {"type": "exit", "needs_both": True}

        gaps = cfg["floor_gaps"].get(src_name, [])
        crumble = cfg["floor_crumble"].get(src_name, [])
        room = {
            "id": rid,
            "source": src_name,
            "tiles": expand(rows, gaps, crumble),
            "exits": [
                {"side": side, "to": to, "rows": list(r)}
                for (side, to, r) in cfg["exits"].get(src_name, [])
            ],
            "objects": objects,
        }
        if src_name in cfg["floor_gaps"]:
            room["floor_gaps"] = cfg["floor_gaps"][src_name]
        if src_name in cfg["floor_crumble"]:
            room["floor_crumble"] = cfg["floor_crumble"][src_name]
        out_rooms.append(room)

    return {
        "id": level_id,
        "title_key": cfg["title_key"],
        "par_time": cfg["par_time"],
        "view": "side",
        "companion": True,
        "music": cfg["music"],
        "start_room": "r1",
        "_generated_by": "tools/build_ch1_levels.py از docs/02_godot_spec.md §۱۱",
        "rooms": out_rooms,
    }


def main() -> int:
    rooms = read_rooms()
    problems = validate_raw(rooms)
    if problems:
        print("نقشه‌های سند مشکل دارند:")
        for p in problems:
            print("  -", p)
        return 1

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for level_id, cfg in LEVELS.items():
        level = build_level(level_id, cfg, rooms)
        path = OUT_DIR / f"{level_id}.json"
        path.write_text(
            json.dumps(level, ensure_ascii=False, indent=2) + "\n", encoding="utf-8"
        )
        n_coins = sum(
            "".join(r["tiles"]).count("o")
            + sum(
                "".join(r["tiles"]).count(s)
                for s, d in r["objects"].items()
                if d.get("type") == "coin"
            )
            for r in level["rooms"]
        )
        n_gems = sum(
            sum(
                "".join(r["tiles"]).count(s)
                for s, d in r["objects"].items()
                if d.get("type") == "gem"
            )
            for r in level["rooms"]
        )
        n_pages = sum(
            sum(
                "".join(r["tiles"]).count(s)
                for s, d in r["objects"].items()
                if d.get("type") == "page"
            )
            for r in level["rooms"]
        )
        print(
            f"{path.relative_to(ROOT)}: {len(level['rooms'])} اتاق، "
            f"{n_coins} سکه، {n_gems} گوهر، {n_pages} صفحه، زمان هدف {cfg['par_time']}s"
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
