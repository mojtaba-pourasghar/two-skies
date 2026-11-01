#!/usr/bin/env python3
"""نگهبان منبع: کاراکترهای نامرئی کنترل جهت، تب/فاصلهٔ قاطی، و سطر بیش از حد بلند.

کاراکتر کنترل جهت (مثل U+200E) در رشتهٔ فارسی وسط کد GDScript باعث
«Parse Error: Invisible text direction control character» می‌شود و اسکریپت
اصلاً بار نمی‌شود — که در حالت headless به‌شکل یک هنگِ بی‌پیام ظاهر می‌شود.

اجرا:  python3 tools/check_sources.py
"""
from __future__ import annotations
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
EXTS = {".gd", ".tscn", ".tres", ".json", ".godot", ".py", ".md"}

# جدول از نقطه‌کد ساخته می‌شود، نه از خود کاراکتر — وگرنه این فایل خودش
# حاوی همان کاراکترهایی می‌شد که دنبالشان است و همیشه خودش را رد می‌کرد.
BAD_CHARS = {
    chr(cp): name
    for cp, name in [
        (0x200E, "LEFT-TO-RIGHT MARK (U+200E)"),
        (0x200F, "RIGHT-TO-LEFT MARK (U+200F)"),
        (0x202A, "LEFT-TO-RIGHT EMBEDDING (U+202A)"),
        (0x202B, "RIGHT-TO-LEFT EMBEDDING (U+202B)"),
        (0x202C, "POP DIRECTIONAL FORMATTING (U+202C)"),
        (0x202D, "LEFT-TO-RIGHT OVERRIDE (U+202D)"),
        (0x202E, "RIGHT-TO-LEFT OVERRIDE (U+202E)"),
        (0x2066, "LEFT-TO-RIGHT ISOLATE (U+2066)"),
        (0x2067, "RIGHT-TO-LEFT ISOLATE (U+2067)"),
        (0x2068, "FIRST STRONG ISOLATE (U+2068)"),
        (0x2069, "POP DIRECTIONAL ISOLATE (U+2069)"),
        (0x200B, "ZERO WIDTH SPACE (U+200B)"),
    ]
}


def main() -> int:
    problems: list[str] = []
    checked = 0
    for path in sorted(ROOT.rglob("*")):
        if path.is_dir() or path.suffix not in EXTS:
            continue
        rel = path.relative_to(ROOT)
        if ".git" in rel.parts or ".godot" in rel.parts:
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        checked += 1
        for lineno, line in enumerate(text.splitlines(), 1):
            for ch, name in BAD_CHARS.items():
                if ch in line:
                    problems.append(f"{rel}:{lineno}: {name}")
        # GDScript با تب تو رفتگی می‌دهد؛ قاطی شدن تب و فاصله خطای خاموش می‌سازد
        if path.suffix == ".gd":
            for lineno, line in enumerate(text.splitlines(), 1):
                indent = line[: len(line) - len(line.lstrip())]
                if " " in indent and "\t" in indent:
                    problems.append(f"{rel}:{lineno}: تو رفتگی تب و فاصله قاطی است")

    if problems:
        print(f"{len(problems)} مشکل در {checked} فایل:")
        for p in problems:
            print("  -", p)
        return 1
    print(f"{checked} فایل بررسی شد؛ مشکلی نیست.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
