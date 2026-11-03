#!/usr/bin/env python3
"""برنامهٔ کنش هر اتاق را از BFS اعتبارسنج بیرون می‌کشد و برای روبات می‌نویسد.

خروجی: game/levels/data/solutions/ch1_lN.plan.json

این فایل **دنبالهٔ کنش** است (walk/jump/dash/wall_jump/rise/fall با کاشی مبدأ و
مقصد)، نه رشتهٔ ورودی فریم‌به‌فریم. رشتهٔ ورودی خروجیِ روبات در موتور است، چون BFS
گسسته است و فیزیک پیوسته؛ ترجمهٔ بی‌بازخورد با یک پیکسل خطا در فرود از هم می‌پاشد.

دو برنامه در هر اتاق می‌آید:
  * `direct` — فقط تا خروج (مسیری که روبات پیش‌فرض می‌رود)
  * `full`   — اول گوهر و صفحهٔ دفتر، بعد خروج

جدا از فایل مرحله نگه داشته می‌شود، چون build_ch1_levels.py فایل مرحله را
بازتولید می‌کند و هر چیزی داخلش بنویسیم پاک می‌شود.

اجرا:  python3 tools/export_plans.py
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from validate_ch1 import (  # noqa: E402
    DATA, ROOM_W, TOOLS, Grid, load_constants, plan_room,
)

OUT_DIR = DATA / "solutions"
LEVELS = ["ch1_l1", "ch1_l2", "ch1_l3"]


def annotate_entries(level: dict) -> None:
    """برای هر اتاق ثبت می‌کند از کدام سمت و کدام سطر وارد می‌شوند."""
    rooms = {r["id"]: r for r in level["rooms"]}
    for r in level["rooms"]:
        r["_entered_by"] = []
    for r in level["rooms"]:
        for d in r.get("exits", []):
            dest = rooms.get(d.get("to"))
            if dest is not None:
                dest["_entered_by"].append((d.get("side"), d.get("rows", [])))


def forward_entry(level: dict, idx: int, grid) -> list:
    """نقطهٔ ورود **جلورو** اتاق.

    `entry_points` اعتبارسنج همهٔ ورودی‌های ممکن را می‌دهد، و در مرحلهٔ ۱ که
    درگاه‌ها دوطرفه‌اند یعنی اتاق میانی از هر دو سمت ورودی دارد. BFS آن وقت از
    هر چهار خانه هم‌زمان شروع می‌کند و کوتاه‌ترین مسیر را از خانه‌ای می‌سازد که
    عملاً هیچ‌وقت از آن وارد نمی‌شویم — برای r3 مرحلهٔ ۱ نقشه شد «یک قدم به راست»
    از ستون ۲۸، در حالی که بازیکن از ستون ۱ وارد می‌شود و سر راهش چاله است
    (DECISIONS.md: D-034).

    ورود واقعی: اتاق اول از نماد `I`؛ بقیه از درگاهی که اتاق قبلی به آن‌ها دارد.
    خروج از سمت راست یعنی ظاهر شدن در ستون ۱، و از چپ در ستون ۲۸ (D-011).
    """
    if idx == 0:
        return grid.find(lambda ch: ch == "I")
    prev = level["rooms"][idx - 1]
    me = level["rooms"][idx]["id"]
    for d in prev.get("exits", []):
        if d.get("to") != me:
            continue
        col = 1 if d.get("side") == "right" else ROOM_W - 2
        return [(col, int(v)) for v in d.get("rows", [])]
    return grid.find(lambda ch: ch == "I")


def forward_targets(room: dict, grid, order: dict) -> list:
    """هدف اتاق: نماد X، وگرنه **درگاه جلورو**.

    `exit_targets` اعتبارسنج هر درگاهی را برمی‌گرداند و برای سنجش دسترس‌پذیری
    همان بس است. ولی روبات باید جلو برود: اتاق‌های میانی هم درگاه چپ (برگشت) و
    هم راست (جلو) دارند، و اگر درگاه برگشت هدف شود روبات بین دو اتاق رفت و
    برگشت می‌کند (DECISIONS.md: D-030).
    """
    xs = grid.find(lambda ch: ch == "X")
    if xs:
        return xs
    best = None
    best_rank = -1
    for d in room.get("exits", []):
        rank = order.get(d.get("to"), -1)
        if rank > best_rank:
            best_rank = rank
            best = d
    if best is None:
        return []
    side = best.get("side", "right")
    col = 0 if side == "left" else ROOM_W - 1
    return [(col, int(v)) for v in best.get("rows", [])]


def main() -> int:
    K = load_constants()
    total_legs = 0
    unreachable: list[str] = []
    OUT_DIR.mkdir(parents=True, exist_ok=True)

    for level_id in LEVELS:
        level = json.loads((DATA / f"{level_id}.json").read_text(encoding="utf-8"))
        tools = TOOLS.get(level_id, set())
        annotate_entries(level)
        # ترتیب اتاق‌ها، تا «جلو» معنی داشته باشد
        order = {r["id"]: i for i, r in enumerate(level["rooms"])}

        out = {
            "level_id": level_id,
            "tools": sorted(tools),
            "_generated_by": "tools/export_plans.py از BFS اعتبارسنج",
            "rooms": [],
        }

        for idx, room in enumerate(level["rooms"]):
            grid = Grid(room["tiles"], room.get("objects", {}), room.get("exits", []))
            starts = forward_entry(level, idx, grid)
            targets = forward_targets(room, grid, order)

            collectibles = []
            for sym, spec in room.get("objects", {}).items():
                if spec.get("type") in ("gem", "page"):
                    for pos in grid.find(lambda s, _s=sym: s == _s):
                        collectibles.append((spec.get("type"), spec.get("id", sym), pos))

            direct = plan_room(grid, starts, targets, [], K, tools)
            full = plan_room(grid, starts, targets, collectibles, K, tools)
            for kind, plan in (("direct", direct), ("full", full)):
                for leg in plan["legs"]:
                    total_legs += 1
                    if not leg["reachable"]:
                        unreachable.append(
                            f"{level_id}/{room['id']} {kind} هدف {leg['goal']}")

            # ستون‌هایی که سکوی شکننده دارند: روبات برای این بازه «بمان/بیا» می‌زند،
            # چون سکو ۰٫۸ ثانیه پس از تماس می‌افتد و ایلارا ۰٫۸ ثانیه عقب‌تر است.
            crumble_cols = sorted({
                c for r in range(len(room["tiles"]))
                for c in range(ROOM_W)
                if room["tiles"][r][c] == "~"
            })

            out["rooms"].append({
                "id": room["id"],
                "starts": [list(p) for p in starts],
                "exits": [list(p) for p in targets],
                "collectibles": [
                    {"kind": k, "id": i, "cell": list(p)} for (k, i, p) in collectibles
                ],
                "crumble_cols": crumble_cols,
                "direct": direct["legs"],
                "full": full["legs"],
            })

        path = OUT_DIR / f"{level_id}.plan.json"
        path.write_text(json.dumps(out, ensure_ascii=False, indent=1) + "\n",
                        encoding="utf-8")
        n_direct = sum(len(l["steps"]) for r in out["rooms"] for l in r["direct"])
        n_full = sum(len(l["steps"]) for r in out["rooms"] for l in r["full"])
        n_crumble = sum(1 for r in out["rooms"] if r["crumble_cols"])
        print(f"{path.name}: {len(out['rooms'])} اتاق، {n_direct} کنش مستقیم، "
              f"{n_full} کنش کامل، {n_crumble} اتاق با سکوی شکننده")

    print(f"\n{total_legs} پا بررسی شد.")
    if unreachable:
        print(f"{len(unreachable)} پای غیرقابل‌دسترس:")
        for u in unreachable:
            print("  -", u)
        return 1
    print("همهٔ پاها قابل دسترس‌اند.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
