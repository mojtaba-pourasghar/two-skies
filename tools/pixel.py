"""نوشتن PNG با کتابخانهٔ استاندارد پایتون — بدون وابستگی بیرونی.

هنر موقت باید بازتولیدپذیر باشد: هیچ فایل دودویی دستی در مخزن نیست، هر PNG از
همین اسکریپت‌ها ساخته می‌شود. (DECISIONS.md: D-058)
"""

from __future__ import annotations

import struct
import zlib

RGBA = tuple[int, int, int, int]


def hex_rgba(code: str, alpha: int = 255) -> RGBA:
    """«#RRGGBB» یا «#RRGGBBAA» را به چهارتایی می‌برد."""
    s = code.lstrip("#")
    if len(s) == 8:
        return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), int(s[6:8], 16))
    if len(s) != 6:
        raise ValueError("کد رنگ نامعتبر: %s" % code)
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16), alpha)


def mix(a: RGBA, b: RGBA, t: float) -> RGBA:
    """a را به اندازهٔ t به سمت b می‌برد (آلفا از a می‌ماند)."""
    return (
        round(a[0] + (b[0] - a[0]) * t),
        round(a[1] + (b[1] - a[1]) * t),
        round(a[2] + (b[2] - a[2]) * t),
        a[3],
    )


CLEAR: RGBA = (0, 0, 0, 0)


class Canvas:
    """بوم RGBA ساده با مبدأ گوشهٔ بالا-چپ."""

    def __init__(self, w: int, h: int, fill: RGBA = CLEAR) -> None:
        self.w = w
        self.h = h
        self.px: list[list[RGBA]] = [[fill for _ in range(w)] for _ in range(h)]

    def set(self, x: int, y: int, c: RGBA) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = c

    def get(self, x: int, y: int) -> RGBA:
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return CLEAR

    def rect(self, x: int, y: int, w: int, h: int, c: RGBA) -> None:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.set(xx, yy, c)

    def hline(self, x: int, y: int, w: int, c: RGBA) -> None:
        self.rect(x, y, w, 1, c)

    def vline(self, x: int, y: int, h: int, c: RGBA) -> None:
        self.rect(x, y, 1, h, c)

    def blit(self, other: "Canvas", x: int, y: int) -> None:
        for yy in range(other.h):
            for xx in range(other.w):
                c = other.px[yy][xx]
                if c[3] != 0:
                    self.set(x + xx, y + yy, c)

    def outline(self, c: RGBA) -> None:
        """خط دور یک‌پیکسلی دور هر پیکسل مات (§۴: «نه مشکی خالص»)."""
        edges: list[tuple[int, int]] = []
        for y in range(self.h):
            for x in range(self.w):
                if self.px[y][x][3] != 0:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    if self.get(x + dx, y + dy)[3] != 0:
                        edges.append((x, y))
                        break
        for x, y in edges:
            self.set(x, y, c)

    def from_art(self, art: list[str], key: dict[str, RGBA], x: int = 0, y: int = 0) -> None:
        """نقشهٔ نویسه‌ای را می‌کشد؛ نویسهٔ «.» شفاف است."""
        for r, line in enumerate(art):
            for c, ch in enumerate(line):
                if ch == ".":
                    continue
                if ch not in key:
                    raise KeyError("نویسهٔ بی‌رنگ «%s» در سطر %d" % (ch, r))
                self.set(x + c, y + r, key[ch])

    def to_png(self) -> bytes:
        raw = bytearray()
        for row in self.px:
            raw.append(0)  # نوع فیلتر: هیچ
            for c in row:
                raw += bytes(c)
        return _png(self.w, self.h, bytes(raw))

    def save(self, path: str) -> None:
        with open(path, "wb") as fh:
            fh.write(self.to_png())


def _chunk(tag: bytes, data: bytes) -> bytes:
    return (
        struct.pack(">I", len(data))
        + tag
        + data
        + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)
    )


def _png(w: int, h: int, raw: bytes) -> bytes:
    header = struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0)  # ۸ بیت، RGBA
    return (
        b"\x89PNG\r\n\x1a\n"
        + _chunk(b"IHDR", header)
        + _chunk(b"IDAT", zlib.compress(raw, 9))
        + _chunk(b"IEND", b"")
    )
