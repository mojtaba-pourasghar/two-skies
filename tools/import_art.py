#!/usr/bin/env python3
"""ایمپورت هنر: `art_drop/` → `game/assets/` (BUILD_BRIEF §۶ و §۱۱، گام T2).

هر پوشه‌ای که `asset.json` دارد یک **دارایی** است. این ابزار:
  ۱) تصویرها را به `game/assets/<همان مسیر>/` می‌برد (فقط فایل‌های تغییرکرده)،
  ۲) از `names.json` کاشی‌ها `roles.json` می‌سازد تا بازی نقش و نوع برخورد هر
     کاشی را بخواند و هیچ‌جای کد شمارهٔ کاشی دستی نوشته نشود،
  ۳) فریم‌های `<anim>_NN.png` را به `anims.json` گروه می‌کند،
  ۴) `game/assets/manifest.json` را می‌نویسد: چه داریم، چند فایل، چه وضعیتی.

**وضعیت draft فقط هشدار است، نه خطا** (CLAUDE.md: همهٔ هنر پیش‌نویس تا تأیید
کاربر). ابزار هرگز به‌خاطر پیش‌نویس بودن شکست نمی‌خورد.

فایل‌های `.import` را خود Godot می‌سازد (`--import`)؛ دست‌نویس کردنشان شکننده
است چون مسیر مقصد و uid را موتور حساب می‌کند. با `--godot <path>` همین‌جا
صدا زده می‌شود.

    python3 -I tools/import_art.py --list
    python3 -I tools/import_art.py --dry-run
    python3 -I tools/import_art.py --only kairo
    python3 -I tools/import_art.py --godot /path/to/godot
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DROP = ROOT / "art_drop"
DEST = ROOT / "game" / "assets"
MANIFEST = DEST / "manifest.json"

#: وضعیت‌هایی که یعنی کاربر تأیید کرده. بقیه هشدار می‌گیرند.
APPROVED = {"approved-by-user", "approved"}

#: این‌ها هنر بازی نیستند و ایمپورت نمی‌شوند.
SKIP_DIRS = {"anim_concept"}

#: نام فریم انیمیشن: `<anim>_NN.png`. `_strip` ورق چسبیده است، نه فریم.
FRAME_RE = re.compile(r"^(?P<anim>.+?)_(?P<num>\d{2,3})\.png$")

IMAGE_EXT = {".png", ".webp", ".jpg", ".jpeg"}


def sha(path: Path) -> str:
	h = hashlib.sha256()
	with path.open("rb") as fh:
		for chunk in iter(lambda: fh.read(1 << 16), b""):
			h.update(chunk)
	return h.hexdigest()[:16]


def assets() -> list[Path]:
	"""هر پوشه‌ای که `asset.json` دارد، مرتب‌شده."""
	found = sorted(p.parent for p in DROP.rglob("asset.json"))
	out: list[Path] = []
	for d in found:
		rel = d.relative_to(DROP)
		if rel.parts and rel.parts[0] in SKIP_DIRS:
			continue
		out.append(d)
	return out


def owned_images(folder: Path, all_assets: list[Path]) -> list[Path]:
	"""تصویرهای این دارایی.

	دارایی‌ها تودرتو می‌شوند (`kairo/` و `kairo/home/`). هر تصویر به
	**نزدیک‌ترین** `asset.json` بالادستش تعلق دارد، وگرنه دوبار کپی می‌شد و
	manifest شمار اشتباه می‌داد.
	"""
	nested = [a for a in all_assets if a != folder and folder in a.parents]
	out: list[Path] = []
	for p in sorted(folder.rglob("*")):
		if p.suffix.lower() not in IMAGE_EXT or not p.is_file():
			continue
		if any(n in p.parents or n == p.parent for n in nested):
			continue
		out.append(p)
	return out


def tile_roles(folder: Path) -> dict | None:
	"""`names.json` کاشی → نگاشت سادهٔ فایل → نقش و نوع برخورد."""
	src = folder / "names.json"
	if not src.exists():
		return None
	data = json.loads(src.read_text(encoding="utf-8"))
	roles = {}
	for entry in data.get("roles", []):
		roles[str(entry.get("file", ""))] = {
			"index": entry.get("index"),
			"role": entry.get("role", ""),
			"kind": entry.get("kind", "background"),
		}
	return {
		"camera": data.get("camera", ""),
		"scene": data.get("scene", ""),
		"tile_px": data.get("tile_px", 64),
		"count": data.get("count", len(roles)),
		"tiles": roles,
	}


def group_anims(images: list[Path], folder: Path) -> dict:
	"""فریم‌های `<anim>_NN.png` را گروه می‌کند؛ ورق `_strip` کنار گذاشته می‌شود."""
	anims: dict[str, list[str]] = {}
	for p in images:
		if p.parent.name != "anim":
			continue
		m = FRAME_RE.match(p.name)
		if not m:
			continue
		anims.setdefault(m.group("anim"), []).append(str(p.relative_to(folder)))
	for name in anims:
		anims[name].sort()
	return anims


def copy_asset(folder: Path, all_assets: list[Path], *, dry: bool) -> dict:
	rel = folder.relative_to(DROP)
	target = DEST / rel
	meta = json.loads((folder / "asset.json").read_text(encoding="utf-8"))
	status = str(meta.get("status", "unknown"))
	images = owned_images(folder, all_assets)

	copied = 0
	skipped = 0
	total_bytes = 0
	for src in images:
		dst = target / src.relative_to(folder)
		total_bytes += src.stat().st_size
		if dst.exists() and dst.stat().st_size == src.stat().st_size and sha(dst) == sha(src):
			skipped += 1
			continue
		copied += 1
		if dry:
			continue
		dst.parent.mkdir(parents=True, exist_ok=True)
		shutil.copy2(src, dst)

	entry: dict = {
		"path": str(rel).replace("\\", "/"),
		"status": status,
		"approved": status in APPROVED,
		"images": len(images),
		"bytes": total_bytes,
		"copied": copied,
		"unchanged": skipped,
	}
	if "camera" in meta:
		entry["camera"] = meta["camera"]

	roles = tile_roles(folder)
	if roles is not None:
		entry["tiles"] = roles["count"]
		entry["camera"] = roles["camera"] or entry.get("camera", "")
		if not dry:
			target.mkdir(parents=True, exist_ok=True)
			(target / "roles.json").write_text(
				json.dumps(roles, ensure_ascii=False, indent=1), encoding="utf-8")

	anims = group_anims(images, folder)
	if anims:
		entry["anims"] = {k: len(v) for k, v in sorted(anims.items())}
		if not dry:
			target.mkdir(parents=True, exist_ok=True)
			(target / "anims.json").write_text(
				json.dumps(anims, ensure_ascii=False, indent=1), encoding="utf-8")

	return entry


def run_godot_import(godot: str) -> int:
	print("\n— ساخت فایل‌های .import با موتور —")
	proc = subprocess.run(
		[godot, "--headless", "--path", str(ROOT / "game"), "--import"],
		capture_output=True, text=True, timeout=1800,
	)
	bad = [ln for ln in (proc.stdout + proc.stderr).splitlines()
		   if "ERROR" in ln or "Failed" in ln]
	for ln in bad[:10]:
		print("  ! %s" % ln.strip())
	print("  %s" % ("بدون خطا" if not bad else "%d خط خطا" % len(bad)))
	return 1 if bad else 0


def main(argv: list[str] | None = None) -> int:
	ap = argparse.ArgumentParser(description="ایمپورت هنر art_drop به game/assets")
	ap.add_argument("--only", help="فقط دارایی‌هایی که مسیرشان با این شروع می‌شود")
	ap.add_argument("--dry-run", action="store_true", help="فقط گزارش؛ چیزی نوشته نشود")
	ap.add_argument("--list", action="store_true", help="فهرست دارایی‌ها و وضعیتشان")
	ap.add_argument("--godot", help="مسیر موتور، برای ساخت فایل‌های .import")
	args = ap.parse_args(argv)

	if not DROP.exists():
		print("art_drop/ نیست.")
		return 1

	all_assets = assets()
	picked = [a for a in all_assets
			  if not args.only or str(a.relative_to(DROP)).startswith(args.only)]
	if not picked:
		print("هیچ دارایی‌ای با «%s» نخواند." % args.only)
		return 1

	if args.list:
		print("%-46s %-28s %6s" % ("دارایی", "وضعیت", "تصویر"))
		for folder in picked:
			meta = json.loads((folder / "asset.json").read_text(encoding="utf-8"))
			imgs = len(owned_images(folder, all_assets))
			print("%-46s %-28s %6d" % (
				str(folder.relative_to(DROP)), meta.get("status", "-"), imgs))
		return 0

	entries: list[dict] = []
	drafts: list[str] = []
	for folder in picked:
		entry = copy_asset(folder, all_assets, dry=args.dry_run)
		entries.append(entry)
		if not entry["approved"]:
			drafts.append("%s (%s)" % (entry["path"], entry["status"]))
		mark = "✔" if entry["approved"] else "·"
		if entry["copied"] or entry["images"] == 0:
			print("  %s %-44s %4d تصویر، %4d تازه" % (
				mark, entry["path"], entry["images"], entry["copied"]))

	total_images = sum(e["images"] for e in entries)
	total_copied = sum(e["copied"] for e in entries)
	total_bytes = sum(e["bytes"] for e in entries)

	if not args.dry_run:
		DEST.mkdir(parents=True, exist_ok=True)
		MANIFEST.write_text(json.dumps({
			"note": "ساختهٔ tools/import_art.py — دستی ویرایش نکن.",
			"assets": entries,
		}, ensure_ascii=False, indent=1), encoding="utf-8")

	print("\n— خلاصه —")
	print("  %d دارایی، %d تصویر، %d تازه کپی شد، %.1f مگابایت"
		  % (len(entries), total_images, total_copied, total_bytes / 1e6))
	if drafts:
		# هشدار است نه خطا: همهٔ هنر تا تأیید کاربر پیش‌نویس است (CLAUDE.md)
		print("  ⚠ %d دارایی هنوز تأیید کاربر ندارد (پیش‌نویس، مانع ساخت نیست)"
			  % len(drafts))
		for d in drafts[:6]:
			print("      %s" % d)
		if len(drafts) > 6:
			print("      … و %d تای دیگر" % (len(drafts) - 6))
	if args.dry_run:
		print("  (--dry-run: چیزی نوشته نشد)")
		return 0

	if args.godot:
		return run_godot_import(args.godot)
	print("  برای ساخت .import: --godot <مسیر موتور> یا godot --path game --import")
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
