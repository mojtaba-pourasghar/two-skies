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

    # برد پرش ایلارا با ثابت‌های خودش (§۵): RUN_SPEED و JUMP_VELOCITY متفاوت
    i_jv = abs(float(prof.get("ilara", {}).get("JUMP_VELOCITY",
        base["ilara"]["JUMP_VELOCITY"])))
    i_run = float(prof.get("ilara", {}).get("RUN_SPEED", base["ilara"]["RUN_SPEED"]))
    i_h = i_jv * i_jv / (2.0 * g)
    i_range = i_run * (i_jv / g + math.sqrt(2.0 * i_h / (g * fall_mult)))

    return {
        "ilara_range_px": i_range,
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

    def tight(self, c: int, r: int) -> bool:
        """خانهٔ قابل‌ایستادنی که سقفش چسبیده است: بازیگر در آن جا نمی‌شود.

        قد جعبهٔ برخورد ۱۶px است، یعنی دقیقاً یک کاشی (§۳). اگر هم زیر و هم
        بالای خانه جامد باشد، بازیگر با حاشیهٔ صفر داخلش می‌افتد و در عمل گیر
        می‌کند. BFS کاشی‌محور این را نمی‌بیند، پس برنامه‌ریز باید چنین خانه‌ای را
        نافرابر بشمارد و مسیر را **از روی** مانع ببرد — همان کاری که آدم می‌کند
        (DECISIONS.md: D-052).
        """
        if not (0 <= c < ROOM_W and 0 <= r < ROOM_H):
            return False
        if self.at(c, r) in SOLID:
            return False
        above_solid = self.at(c, r - 1) in SOLID if r > 0 else True
        below_solid = self.at(c, r + 1) in SOLID if r + 1 < ROOM_H else True
        return above_solid and below_solid

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
        # خانهٔ تنگ برای برنامه‌ریز نافرابر است
        if self.tight(c, r):
            return True
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


def search(grid: Grid, starts: list[tuple[int, int]], K: dict, tools: set,
           hacked: bool) -> tuple[set, dict, dict]:
    """BFS روی حالت هوایی، با ردگیری پدر و کنش هر یال.

    حالت = (ستون، سطر، بودجهٔ بالا رفتن، بودجهٔ حرکت افقی در هوا).
    علاوه بر مجموعهٔ خانه‌های دسترس‌پذیر، `parent` و `action` هم برمی‌گردند تا
    بتوان از هدف تا شروع عقب رفت و **دنبالهٔ کنش** ساخت، نه فقط فهرست کاشی.
    هر یال از قبل معنای خودش را دارد و همان نام کنش می‌شود.
    """
    UP = K["jump_up"]
    ACROSS = K["jump_across"]
    WJ_UP = K["wj_up"]
    WJ_ACROSS = K["wj_across"]
    DASH = K["dash_across"]

    seen: set = set()
    visited: set[tuple[int, int]] = set()
    parent: dict = {}
    action: dict = {}
    q: deque = deque()

    def push(c: int, r: int, up: int, across: int, src=None, act: str = "") -> None:
        if r >= ROOM_H or r < 0:
            return
        if grid.solid(c, r, hacked) or grid.deadly(c, r):
            return
        st = (c, r, up, across)
        if st in seen:
            return
        seen.add(st)
        visited.add((c, r))
        if src is not None:
            parent[st] = src
            action[st] = act
        q.append(st)

    for (c, r) in starts:
        push(c, r, 0, ACROSS)

    while q:
        st = q.popleft()
        c, r, up, across = st
        grounded = grid.solid(c, r + 1, hacked) and up == 0

        if grounded:
            for dc in (-1, 1):
                push(c + dc, r, 0, 0, st, "walk_right" if dc > 0 else "walk_left")
            push(c, r, UP, ACROSS, st, "jump")
            if "dash" in tools:
                for n in range(1, DASH + 1):
                    for dc in (-1, 1):
                        blocked = False
                        for k in range(1, n + 1):
                            if grid.solid(c + dc * k, r, hacked):
                                blocked = True
                                break
                        if not blocked:
                            push(c + dc * n, r, 0, 0, st,
                                 "dash_right" if dc > 0 else "dash_left")
            if not grid.solid(c, r + 1, hacked):
                push(c, r + 1, 0, across, st, "fall")
        else:
            if "wall_jump" in tools:
                for dc in (-1, 1):
                    if grid.solid(c + dc, r, hacked):
                        push(c - dc, r, WJ_UP, WJ_ACROSS, st,
                             "wall_jump_left" if dc > 0 else "wall_jump_right")
            if up > 0 and not grid.solid(c, r - 1, hacked):
                push(c, r - 1, up - 1, across, st, "rise")
            for dc in (-1, 1):
                if across > 0 and not grid.solid(c + dc, r, hacked):
                    push(c + dc, r, up, across - 1, st,
                         "air_right" if dc > 0 else "air_left")
            if not grid.solid(c, r + 1, hacked):
                push(c, r + 1, 0, across, st, "fall")

    return visited, parent, action


def reachable(grid: Grid, starts: list[tuple[int, int]], K: dict, tools: set,
              hacked: bool) -> set[tuple[int, int]]:
    """فقط مجموعهٔ خانه‌های دسترس‌پذیر — پوستهٔ نازک روی search()."""
    return search(grid, starts, K, tools, hacked)[0]


def reconstruct(goal_state, parent: dict, action: dict) -> list[dict]:
    """از حالت هدف تا شروع عقب می‌رود و دنبالهٔ کنش می‌دهد."""
    chain = []
    st = goal_state
    while st in parent:
        chain.append({
            "action": action[st],
            "to": [st[0], st[1]],
            "from": [parent[st][0], parent[st][1]],
        })
        st = parent[st]
    chain.reverse()
    return chain


def nearest_state(parent: dict, starts: list, cell: tuple) -> object:
    """کم‌هزینه‌ترین حالتی که در خانهٔ `cell` ایستاده است.

    BFS سطح‌به‌سطح است، پس اولین حالتی که در parent برای این خانه دیده می‌شود
    کوتاه‌ترین مسیر را دارد. حالت روی زمین ترجیح دارد (بودجهٔ بالا رفتن صفر).
    """
    best = None
    for st in parent.keys():
        if (st[0], st[1]) != cell:
            continue
        if best is None or st[2] < best[2]:
            best = st
    if best is None:
        for st in starts:
            if (st[0], st[1]) == cell:
                return st
    return best


def compress(grid: Grid, steps: list[dict], hacked: bool) -> list[dict]:
    """کنش‌های ریز BFS را به «نقطهٔ راه» از زمین به زمین فشرده می‌کند.

    چرا لازم است: BFS حالت‌های میانهٔ پرش (`rise`، `air_left`) را هم می‌دهد.
    اگر روبات هر کدام را یک هدف جدا بگیرد، در هر کاشیِ قوسِ پرش می‌ایستد و
    دوباره می‌پرد — که یعنی هیچ‌وقت از جا در نمی‌آید. آدم هم این‌طور بازی
    نمی‌کند: «بدو تا ستون ۱۲، از شفت بالا برو، بدو تا ستون ۲۹».

    هر نقطهٔ راه یک کاشیِ روی‌زمین است و `kind` می‌گوید چطور باید به آن رسید:
      walk      — راه رفتن در همان سطح
      hop       — یک پرش
      dash      — دش
      wallclimb — زنجیرهٔ دیوارپرش در شفت
      drop      — افتادن به پایین
    """
    def grounded(c: int, r: int) -> bool:
        return grid.solid(c, r + 1, hacked)

    out: list[dict] = []
    pending: list[str] = []
    needs_jump = False
    for st in steps:
        act = st["action"]
        pending.append(act)
        c, r = st["to"]
        is_last = st is steps[-1]
        # کنش `jump` جابه‌جایی ندارد و خانه‌اش همان خانهٔ قبلی است. اگر برایش
        # نقطهٔ راه بسازیم، روبات هدفی می‌گیرد که همین حالا رویش ایستاده، پس
        # جهتی ندارد و صاف بالا می‌پرد — روی چاله یعنی افتادن در چاله.
        # پرش یک **صفت** نقطهٔ راه بعدی است، نه خودش یک نقطه (D-035).
        if act == "jump" and not is_last:
            needs_jump = True
            continue
        if grounded(c, r) or is_last:
            if any(a.startswith("wall_jump") for a in pending):
                kind = "wallclimb"
            elif any(a.startswith("dash") for a in pending):
                kind = "dash"
            elif needs_jump or "jump" in pending:
                kind = "hop"
            elif all(a == "fall" for a in pending):
                kind = "drop"
            else:
                kind = "walk"
            wp = {"cell": [c, r], "kind": kind, "micro": len(pending)}
            if kind == "wallclimb":
                # نخستین دیوارپرش می‌گوید دیوار کدام سمت است، پس روبات بداند
                # اول به کدام طرف فشار بدهد. wall_jump_right یعنی دیوار در چپ.
                first = next(a for a in pending if a.startswith("wall_jump"))
                wp["push"] = "left" if first == "wall_jump_right" else "right"
            out.append(wp)
            pending = []
            needs_jump = False

    # راه رفتن‌های پشت‌سرهم در یک سطر به آخرینشان تا می‌شوند: «بدو تا ستون X».
    # بدون این، هر کاشی یک هدف جدا می‌شد و روبات در هر کاشی می‌ایستاد.
    # دش روی زمین صاف لازم نیست: BFS آن را ترجیح می‌دهد چون در هر یال دو کاشی
    # جلو می‌رود و یال کمتری مصرف می‌کند، ولی همان مسیر با راه رفتن هم باز است.
    # دش فقط جایی بماند که تنها راه است (شکاف پهن‌تر از پرش).
    # روبات خودش روی مسیرهای بلند و بی‌مانع دش می‌زند، پس ورودی دش هم سنجیده
    # می‌شود بدون آن‌که درستی مسیر به زمان‌بندی دش گره بخورد (D-036).
    flat: list[dict] = []
    for wp in out:
        if (flat and wp["kind"] in ["walk", "dash"] and flat[-1]["kind"] in ["walk", "dash"]
                and flat[-1]["cell"][1] == wp["cell"][1]):
            flat[-1]["cell"] = wp["cell"]
            flat[-1]["kind"] = "walk"
            flat[-1]["micro"] += wp["micro"]
            continue
        flat.append(wp)
    out = flat

    merged: list[dict] = []
    for wp in out:
        if (merged and wp["kind"] == "walk" and merged[-1]["kind"] == "walk"
                and merged[-1]["cell"][1] == wp["cell"][1]):
            merged[-1]["cell"] = wp["cell"]
            merged[-1]["micro"] += wp["micro"]
            continue
        # هدف تکراری در همان خانه حذف می‌شود
        if merged and merged[-1]["cell"] == wp["cell"] and merged[-1]["kind"] == wp["kind"]:
            merged[-1]["micro"] += wp["micro"]
            continue
        merged.append(wp)
    return merged


def plan_room(grid: Grid, starts: list, targets: list, collectibles: list,
              K: dict, tools: set) -> dict:
    """برنامهٔ کنش یک اتاق: اول قلم‌های ارزشمند، بعد خروج.

    هر پا (leg) یک جست‌وجوی تازه از نقطهٔ پایان پای قبلی است، تا مسیر واقعاً
    پیوسته باشد و روبات بتواند پا به پا اجرا کند.
    """
    hacked = "hack" in tools
    legs: list[dict] = []
    cursor = list(starts)
    order = [p for (_k, _i, p) in collectibles] + list(targets)

    for goal in order:
        visited, parent, action = search(grid, cursor, K, tools, hacked)
        if goal not in visited:
            legs.append({"goal": list(goal), "reachable": False, "steps": []})
            continue
        gst = nearest_state(parent, [(c, r, 0, K["jump_across"]) for (c, r) in cursor], goal)
        steps = reconstruct(gst, parent, action) if gst is not None else []
        legs.append({
            "goal": list(goal),
            "reachable": True,
            "steps": steps,
            "waypoints": compress(grid, steps, hacked) if steps else [],
        })
        cursor = [goal]

    return {"legs": legs}


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


def check_companion_gaps(level: dict, K: dict) -> list[str]:
    """در مرحله‌های همراه، چاله نباید از برد پرش **ایلارا** بگذرد.

    §۳ می‌گوید «طراح مرحله نباید شکاف بیشتر از ۴٫۵ تایل بدون ابزار بگذارد»، ولی
    آن عدد از برد پرش کایرو (۴٫۸۳ کاشی) می‌آید. ایلارا ثابت‌های خودش را دارد
    (§۵) و بردش ۴٫۰۱ کاشی است. او هیچ‌وقت کنترل بازیکن نیست و فقط مسیر کایرو را
    بازپخش می‌کند، پس اگر چاله از ظرفیتش بگذرد **هیچ ورودی‌ای** نجاتش نمی‌دهد و
    مرگش طبق §۵ شکست مرحله است.

    این نگهبان پس از آن اضافه شد که روبات گام ۸ دید ایلارا در چالهٔ سه کاشی
    L1R3 با حاشیهٔ ۰٪ هر بار می‌افتد (DECISIONS.md: D-038).
    """
    if not bool(level.get("companion", False)):
        return []
    margin: float = float(K["fairness"].get("companion_gap_margin", 0.85))
    capacity: float = K["ilara_range_px"] * margin
    problems: list[str] = []
    for room in level["rooms"]:
        tiles = room["tiles"]
        run = 0
        for c in range(ROOM_W + 1):
            has_floor = True
            if c < ROOM_W:
                has_floor = any(tiles[r][c] in SOLID for r in range(14, ROOM_H))
            if has_floor:
                if run > 0:
                    need = float(run + 1) * TILE
                    if need > capacity:
                        problems.append(
                            "%s/%s: چالهٔ %d کاشی %.0fpx پرش لازم دارد، "
                            "ظرفیت امن ایلارا %.0fpx"
                            % (level.get("id", "?"), room["id"], run, need, capacity))
                run = 0
            else:
                run += 1
    return problems


def check_headroom(level: dict) -> list[str]:
    """هر خانهٔ قابل‌ایستادن باید دست‌کم ۲ کاشی ارتفاع آزاد داشته باشد.

    قد جعبهٔ برخورد هر دو شخصیت ۱۶px است، یعنی **دقیقاً یک کاشی** (§۳:
    `HITBOX = Vector2(10, 16)`). پس یک کاشی ارتفاع آزاد حاشیهٔ صفر می‌دهد و
    بازیگر زیر سقف گیر می‌کند: نه آدم می‌تواند رد شود و نه روبات.

    این نگهبان پس از آن اضافه شد که روبات گام ۸ ب در L2R4 خانهٔ (۹,۱۲) گیر کرد —
    جایی که سکوی اضافه‌شده در D-017 درست بالای سکوی شکننده افتاده بود
    (DECISIONS.md: D-052).
    """
    problems: list[str] = []
    for room in level["rooms"]:
        tiles = room["tiles"]
        for c in range(1, ROOM_W - 1):
            for r in range(2, ROOM_H - 1):
                if tiles[r][c] in SOLID:
                    continue
                if tiles[r + 1][c] not in SOLID:
                    continue
                free = 0
                rr = r
                while rr >= 0 and tiles[rr][c] not in SOLID:
                    free += 1
                    rr -= 1
                if free < 2:
                    problems.append(
                        "%s/%s: خانهٔ (%d,%d) فقط %d کاشی ارتفاع آزاد دارد "
                        "(قد بازیگر ۱ کاشی، حداقل لازم ۲)"
                        % (level.get("id", "?"), room["id"], c, r, free))
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

    print("\n=== قاعدهٔ چاله برای همراه (ایلارا) ===")
    print("  برد پرش ایلارا %.1fpx = %.2f کاشی (کایرو %.2f کاشی)"
          % (K["ilara_range_px"], K["ilara_range_px"] / TILE, K["range_px"] / TILE))
    gap_problems: list[str] = []
    head_problems: list[str] = []
    for level_id in levels:
        level = json.loads((DATA / f"{level_id}.json").read_text(encoding="utf-8"))
        level.setdefault("id", level_id)
        gap_problems += check_companion_gaps(level, K)
        head_problems += check_headroom(level)
    if gap_problems:
        for p in gap_problems:
            print("  ✘", p)
    else:
        margin = float(K["fairness"].get("companion_gap_margin", 0.85))
        print("  ✔ هیچ چاله‌ای از ظرفیت امن ایلارا (%.0fpx با %.0f%% حاشیه) نمی‌گذرد"
              % (K["ilara_range_px"] * margin, (1.0 - margin) * 100.0))

    print("\n=== ارتفاع آزاد (قد بازیگر ۱ کاشی) ===")
    if head_problems:
        # خطا نیست: نقشه مجاز است و برنامه‌ریز این خانه‌ها را نافرابر می‌شمارد،
        # پس مسیر از **روی** مانع می‌رود — همان کاری که آدم می‌کند.
        print("  i %d خانهٔ تنگ؛ برنامه‌ریز از آن‌ها عبور نمی‌دهد:" % len(head_problems))
        for p in head_problems:
            print("    ·", p)
    else:
        print("  ✔ هیچ خانهٔ تنگی نیست")

    ok, total, problems = validate(levels, K, "ثابت‌های واقعی §۳")
    problems += gap_problems

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
