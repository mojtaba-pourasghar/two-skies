"""کش فراخوانی‌ها با کلید hash.

چرا: هر بار اجرای دوبارهٔ اسکریپت نباید دوباره پول خرج کند. کلید از خود
درخواست (مدل + پرامپت + پارامترها) ساخته می‌شود، پس تغییر پرامپت یعنی کلید
تازه و تولید تازه، و نبود تغییر یعنی هزینهٔ صفر.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

from . import config


def key(payload: dict) -> str:
	blob = json.dumps(payload, ensure_ascii=False, sort_keys=True).encode("utf-8")
	return hashlib.sha256(blob).hexdigest()[:32]


def _p(k: str, ext: str) -> Path:
	return config.CACHE / ("%s.%s" % (k, ext))


def get_bytes(k: str, ext: str = "bin") -> bytes | None:
	p = _p(k, ext)
	return p.read_bytes() if p.exists() else None


def put_bytes(k: str, data: bytes, ext: str = "bin") -> Path:
	config.ensure_dirs()
	p = _p(k, ext)
	p.write_bytes(data)
	return p


def get_json(k: str) -> dict | None:
	raw = get_bytes(k, "json")
	return json.loads(raw.decode("utf-8")) if raw else None


def put_json(k: str, data: dict) -> Path:
	return put_bytes(k, json.dumps(data, ensure_ascii=False, indent=2).encode("utf-8"), "json")
