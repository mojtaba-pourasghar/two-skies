#!/usr/bin/env python3
"""اعتبارسنج حل‌پذیری ۱۲ اتاق فصل ۱ — بدون نیاز به موتور.

روی هر اتاق یک BFS روی حالت هوایی اجرا می‌شود و این‌ها را تضمین می‌کند:
  ۱) از نقطهٔ ورود به نقطهٔ خروج راه هست
  ۲) همهٔ گوهرها و صفحه‌های دفتر دسترس‌پذیرند
  ۳) هیچ شکاف بی‌ابزاری بیشتر از ۴٫۵ کاشی نیست (قاعدهٔ §۳)
  ۴) پنجرهٔ امن هر مانع زمان‌بندی‌دار ≥ ۱ ثانیه و هشدارش ≥ ۰٫۴ ثانیه (قاعدهٔ عدالت)

اعداد پرش از `game/data/tuning.json` و ثابت‌های §۳ گرفته می‌شوند، نه از فرض مولّد
`tools/generate_rooms.py` که ۴ کاشی بالا و ۶ کاشی افقی می‌گیرد. برای مقایسه، همان
فرض سخاوتمندانه هم جداگانه گزارش می‌شود (DECISIONS.md: D-008).

اجرا:  python3 tools/validate_ch1.py
"""
from __future__ import annotations

import json
import math
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "game" / "levels" / "data"
TUNING = ROOT / "game" / "data" / "tuning.json"

TILE = 16
ROOM_W = 30
ROOM_H = 17

# کاشی‌هایی که می‌توان رویشان ایستاد
SOLID = set("#~")
# کشنده در تماس
DEADLY = set("^")
# جامد تا وقتی هک نشده
HACKABLE_SOLID = set("GTD")

# ابزار باز شدهٔ هر مرحله (§۶ و DECISIONS.md: D-003)
TOOLS = {
    "ch1_l1": set(),
    "ch1_l2": {"wall_jump", "hack"},
    "ch1_l3": {"wall_jump", "hack", "dash"},
}


def load_constants() -> dict:
    t = json.loads(TUNING.read_text(encoding="utf-8"))
    prof = t["profiles"][t["active_profile"]]
    base = t["profiles"]["spec02"]

    def k(name: str) -> float:
        return float(prof.get("kairo", {}).get(name, base["kairo"][name]))

    g = k("GRAVITY")
    jv = abs(k("JUMP_VELOCITY"))
    run = k("RUN_SPEED")
    fall_mult = k("FALL_GRAVITY_MULT")
    wj_x = k("WALL_JUMP_VEL_X")
    wj_y = abs(k("WALL_JUMP_VEL_Y"))
    dash_px = k("DASH_SPEED") * k("DASH_TIME")

    height_px = jv * jv / (2.0 * g)
    t_up = jv / g
    t_down = math.sqrt(2.0 * height_px / (g * fall_mult))
    range_px = run * (t_up + t_down)

    wj_h = wj_y * wj_y / (2.0 * g)
    wj_t_up = wj_y / g
    wj_range = wj_x * wj_t_up

    return {
        "jump_up": int(height_px // TILE),
        "jump_across": int(range_px // TILE),
        "wj_up": int(wj_h // TILE),
        "wj_across": int(wj_range // TILE),
        "dash_across": int(dash_px // TILE),
        "height_px": height_px,
        "range_px": range_px,
        "fairness": t.get("fairness_rules", {}),
        "hazards": {**base.get("hazards", {}), **prof.get("hazards", {})},
    }


class Grid:
    def __init__(self, rows: list[str], objects: dict, doors: list[dict]):
        self.rows = rows
        self.objects = objects
        # خانه‌هایی که درگاه اعلام‌شده‌اند و لودر بازشان می‌گذارد
        self.door_cells: set[tuple[int, int]] = set()
        for d in doors:
            side = d.get("side", "")
            for v in d.get("rows", []):
                if side == "left":
                    self.door_cells.add((0, int(v)))
                elif side == "right":
                    self.door_cells.add((ROOM_W - 1, int(v)))
        # لودر هر سوراخ بی‌درگاه لبه و سقف را مُهر می‌کند؛ اینجا هم همان کار
        self.sealed: set[tuple[int, int]] = set()
        for r in range(0, 14):
            for c in (0, ROOM_W - 1):
                if (c, r) in self.door_cells:
                    continue
                if self.at(c, r) not in SOLID:
                    self.sealed.add((c, r))
        for c in range(ROOM_W):
            for r in (0, 1):
                if (c, r) in self.door_cells:
                    continue
                if self.at(c, r) not in SOLID:
                    self.sealed.add((c, r))

    def at(self, c: int, r: int) -> str:
        if not (0 <= c < ROOM_W and 0 <= r < len(self.rows)):
            return "#"
        return self.rows[r][c]

    def kind(self, c: int, r: int) -> str:
        sym = self.at(c, r)
        if sym in self.objects:
            return self.objects[sym].get("type", "")
        return ""

    def solid(self, c: int, r: int, hacked: bool) -> bool:
        if (c, r) in self.sealed:
            return True
        if not (0 <= c < ROOM_W):
            return True
        if r < 0:
            return True
        if r >= ROOM_H:
            return False  # افتادن از پایین اتاق = مرگ، نه دیوار
        sym = self.at(c, r)
        if sym in SOLID:
            return True
        if sym in HACKABLE_SOLID:
            return not hacked
        return False

    def deadly(self, c: int, r: int) -> bool:
        return self.at(c, r) in DEADLY

    def find(self, pred) -> list[tuple[int, int]]:
        out = []
        for r in range(len(self.rows)):
            for c in range(ROOM_W):
                if pred(self.at(c, r)):
                    out.append((c, r))
        return out


def reachable(grid: Grid, starts: list[tuple[int, int]], K: dict, tools: set,
              hacked: bool) -> set[tuple[int, int]]:
    """خانه‌هایی که کایرو می‌تواند در آن‌ها روی زمین بایستد یا از آن‌ها بگذرد."""
    UP = K["jump_up"]
    ACROSS = K["jump_across"]
    WJ_UP = K["wj_up"]
    WJ_ACROSS = K["wj_across"]
    DASH = K["dash_across"]

    seen: set[tuple[int, int, int, int]] = set()
    visited: set[tuple[int, int]] = set()
    q: deque = deque()

    def push(c: int, r: int, up: int, across: int) -> None:
        if r >= ROOM_H or r < 0:
            return
        if grid.solid(c, r, hacked) or grid.deadly(c, r):
            return
        st = (c, r, up, across)
        if st in seen:
            return
        seen.add(st)
        visited.add((c, r))
        q.append(st)

    for (c, r) in starts:
        push(c, r, 0, ACROSS)

    while q:
        c, r, up, across = q.popleft()
        grounded = grid.solid(c, r + 1, hacked) and up == 0

        if grounded:
            for dc in (-1, 1):
                push(c + dc, r, 0, 0)
            push(c, r, UP, ACROSS)
            if "dash" in tools:
                for n in range(1, DASH + 1):
                    for dc in (-1, 1):
                        blocked = False
                        for k in range(1, n + 1):
                            if grid.solid(c + dc * k, r, hacked):
                                blocked = True
                                break
                        if not blocked:
                            push(c + dc * n, r, 0, 0)
            if not grid.solid(c, r + 1, hacked):
                push(c, r + 1, 0, across)
        else:
            if "wall_jump" in tools:
                for dc in (-1, 1):
                    if grid.solid(c + dc, r, hacked):
                        push(c - dc, r, WJ_UP, WJ_ACROSS)
            if up > 0 and not grid.solid(c, r - 1, hacked):
                push(c, r - 1, up - 1, across)
            for dc in (-1, 1):
                if across > 0 and not grid.solid(c + dc, r, hacked):
                    push(c + dc, r, up, across - 1)
            if not grid.solid(c, r + 1, hacked):
                push(c, r + 1, 0, across)

    return visited


def entry_points(room: dict, is_first: bool, grid: Grid) -> list[tuple[int, int]]:
    """ورود: اتاق اول از نماد I، بقیه از ستون ۱ یا ۲۸ در سطر درگاه (D-011)."""
    if is_first:
        return grid.find(lambda s: s == "I")
    pts = []
    for d in room.get("_entered_by", []):
        side, rows = d
        col = 1 if side == "right" else ROOM_W - 2
        for v in rows:
            pts.append((col, int(v)))
    return pts


def exit_targets(room: dict, grid: Grid) -> list[tuple[int, int]]:
    """هدف: نماد X، یا خانهٔ درگاه خروج جلورو."""
    xs = grid.find(lambda s: s == "X")
    if xs:
        return xs
    out = []
    for d in room.get("exits", []):
        side = d.get("side", "")
        col = 0 if side == "left" else ROOM_W - 1
        for v in d.get("rows", []):
            out.append((col, int(v)))
    return out


def max_gap(grid: Grid) -> int:
    """بزرگ‌ترین سوراخ پیوستهٔ کف: ستون‌هایی که در سطر ۱۴ تا ۱۶ هیچ کاشی جامدی ندارند.

    این همان «شکاف» §۳ است که نباید بیش از ۴٫۵ کاشی باشد. فاصلهٔ بین سکوهای
    میانی اتاق اینجا شمرده نمی‌شود، چون افتادن از آن‌ها مرگ نیست.
    """
    worst = 0
    run = 0
    for c in range(ROOM_W):
        has_floor = any(grid.at(c, r) in SOLID for r in range(14, ROOM_H))
        if has_floor:
            worst = max(worst, run)
            run = 0
        else:
            run += 1
    return max(worst, run)


def check_fairness(K: dict) -> list[str]:
    problems = []
    h = K["hazards"]
    f = K["fairness"]
    min_window = float(f.get("min_safe_window", 1.0))
    min_warn = float(f.get("min_warning_before_lethal", 0.4))
    laser_off = float(h.get("laser_off", 1.2))
    laser_warn = float(h.get("laser_warn", 0.4))
    # §۷: «۰٫۴ ثانیه هشدار چشمک‌زن **پیش از روشن‌شدن**» — در مدت هشدار پرتو هنوز
    # خاموش و بی‌خطر است، پس پنجرهٔ امن کل زمان خاموشی است (DECISIONS.md: D-016).
    window = laser_off
    if window < min_window:
        problems.append(
            f"پنجرهٔ امن لیزر {window:.2f}s است، کمتر از حداقل {min_window:.2f}s"
        )
    if laser_warn < min_warn:
        problems.append(
            f"هشدار لیزر {laser_warn:.2f}s است، کمتر از حداقل {min_warn:.2f}s"
        )
    return problems


def validate(levels: list[str], K: dict, label: str) -> tuple[int, int, list[str]]:
    ok = 0
    total = 0
    problems: list[str] = []
    print(f"\n=== {label} (پرش {K['jump_up']} کاشی بالا / {K['jump_across']} کاشی افقی, "
          f"دیوارپرش {K['wj_up']}/{K['wj_across']}, دش {K['dash_across']}) ===")

    for level_id in levels:
        path = DATA / f"{level_id}.json"
        level = json.loads(path.read_text(encoding="utf-8"))
        tools = TOOLS.get(level_id, set())
        rooms = {r["id"]: r for r in level["rooms"]}
        # چه کسی از کجا وارد این اتاق می‌شود
        for r in level["rooms"]:
            r["_entered_by"] = []
        for r in level["rooms"]:
            for d in r.get("exits", []):
                dest = rooms.get(d.get("to"))
                if dest is not None:
                    dest["_entered_by"].append((d.get("side"), d.get("rows", [])))

        print(f"\n  {level_id}  (ابزار: {', '.join(sorted(tools)) or 'بدون ابزار'})")
        for idx, room in enumerate(level["rooms"]):
            total += 1
            grid = Grid(room["tiles"], room.get("objects", {}), room.get("exits", []))
            starts = entry_points(room, idx == 0, grid)
            targets = exit_targets(room, grid)

            if not starts:
                problems.append(f"{level_id}/{room['id']}: نقطهٔ ورود پیدا نشد")
                print(f"    ✘ {room['id']}: نقطهٔ ورود پیدا نشد")
                continue

            cells = reachable(grid, starts, K, tools, hacked=False)
            cells_hacked = reachable(grid, starts, K, tools, hacked=("hack" in tools))
            all_cells = cells | cells_hacked

            reached = [t for t in targets if t in all_cells]
            # گوهر و صفحه
            collectibles = []
            for sym, spec in room.get("objects", {}).items():
                if spec.get("type") in ("gem", "page"):
                    for pos in grid.find(lambda s, _sym=sym: s == _sym):
                        collectibles.append((spec.get("type"), spec.get("id", sym), pos))
            missed = [(k, i, p) for (k, i, p) in collectibles if p not in all_cells]

            gap = max_gap(grid)
            gap_limit = float(K["fairness"].get("max_gap_tiles_without_tool", 4.5))

            room_ok = bool(reached) and not missed
            if room_ok:
                ok += 1
            status = "✔" if room_ok else "✘"
            detail = f"{len(all_cells)} خانهٔ دسترس‌پذیر"
            if targets:
                detail += f"، خروج {'رسید' if reached else 'نرسید'}"
            if collectibles:
                detail += f"، {len(collectibles) - len(missed)}/{len(collectibles)} قلم ارزشمند"
            if gap > gap_limit and not tools:
                detail += f"، شکاف {gap} کاشی (حد {gap_limit})"
            print(f"    {status} {room['id']}: {detail}")

            if not reached and targets:
                problems.append(f"{level_id}/{room['id']}: خروج دسترس‌پذیر نیست")
            for (k, i, p) in missed:
                problems.append(f"{level_id}/{room['id']}: {k} «{i}» در {p} دسترس‌پذیر نیست")

    return ok, total, problems


def main() -> int:
    K = load_constants()
    levels = ["ch1_l1", "ch1_l2", "ch1_l3"]

    print("ثابت‌های §۳ (پروفایل فعال):")
    print(f"  ارتفاع پرش {K['height_px']:.1f}px = {K['height_px'] / TILE:.2f} کاشی")
    print(f"  برد افقی پرش {K['range_px']:.1f}px = {K['range_px'] / TILE:.2f} کاشی")

    fair = check_fairness(K)
    print("\n=== قاعدهٔ عدالت ===")
    if fair:
        for p in fair:
            print("  ✘", p)
    else:
        h = K["hazards"]
        print(f"  ✔ پنجرهٔ امن لیزر {h.get('laser_off', 1.2):.2f}s ≥ 1.00s "
              f"(شامل {h.get('laser_warn', 0.4):.2f}s هشدار که در آن پرتو خاموش است)")
        print(f"  ✔ هشدار پیش از کشنده شدن {h.get('laser_warn', 0.4):.2f}s ≥ 0.40s")

    ok, total, problems = validate(levels, K, "ثابت‌های واقعی §۳")

    # همان سنجه با فرض سخاوتمندانهٔ مولّد فصل ۲ تا ۸، فقط برای مقایسه
    K_gen = dict(K)
    K_gen.update({"jump_up": 4, "jump_across": 6, "wj_up": 4, "wj_across": 6})
    ok_gen, total_gen, _ = validate(levels, K_gen, "فرض مولّد: ۴ بالا / ۶ افقی")

    print("\n=== خلاصه ===")
    print(f"  با ثابت‌های واقعی §۳:        {ok}/{total} اتاق حل‌پذیر")
    print(f"  با فرض ۴ بالا / ۶ افقی:     {ok_gen}/{total_gen} اتاق حل‌پذیر")
    if problems:
        print(f"\n{len(problems)} مشکل:")
        for p in problems:
            print("  -", p)
        return 1
    if fair:
        return 1
    print("\nهمهٔ اتاق‌ها با ثابت‌های واقعی حل‌پذیرند.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
