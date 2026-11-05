#!/usr/bin/env python3
"""آزمون ایمپورتر هنر (T2).

روی یک `art_drop` ساختگی کار می‌کند، نه روی هنر واقعی، تا سریع باشد و به
محتوای هنر وابسته نماند. چیزی که می‌سنجد همان چیزهایی است که اگر بشکنند
بی‌صدا می‌شکنند: مالکیت تصویر در پوشه‌های تودرتو، گروه‌بندی انیمیشن، نقش
کاشی، و اینکه پیش‌نویس بودن **خطا نیست**.
"""

from __future__ import annotations

import json
import shutil
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import import_art  # noqa: E402

_fails: list[str] = []
_checks = 0


def check(label: str, ok: bool, detail: str = "") -> None:
	global _checks
	_checks += 1
	if ok:
		print("  ✔ %s %s" % (label, detail))
	else:
		_fails.append(label)
		print("  ✘ %s %s" % (label, detail))


def png(path: Path, payload: bytes = b"x") -> None:
	path.parent.mkdir(parents=True, exist_ok=True)
	# محتوای واقعی PNG لازم نیست: ابزار فقط کپی و نام‌گذاری می‌کند
	path.write_bytes(b"\x89PNG\r\n\x1a\n" + payload)


def build_fake(root: Path) -> None:
	drop = root / "art_drop"
	# دارایی تودرتو: kairo و kairo/home
	(drop / "kairo").mkdir(parents=True)
	(drop / "kairo" / "asset.json").write_text(
		json.dumps({"status": "draft-from-approved-sheet"}), encoding="utf-8")
	png(drop / "kairo" / "sheet.png")
	(drop / "kairo" / "home").mkdir()
	(drop / "kairo" / "home" / "asset.json").write_text(
		json.dumps({"status": "draft-until-user-approval", "camera": "topdown"}),
		encoding="utf-8")
	png(drop / "kairo" / "home" / "idle_down.png")
	for i in range(3):
		png(drop / "kairo" / "home" / "anim" / ("walk_down_%02d.png" % i))
	png(drop / "kairo" / "home" / "anim" / "walk_down_strip.png")

	# کاشی با names.json
	tiles = drop / "tiles_ch1_v2" / "street"
	tiles.mkdir(parents=True)
	(tiles / "asset.json").write_text(
		json.dumps({"status": "draft-until-user-approval"}), encoding="utf-8")
	(tiles / "names.json").write_text(json.dumps({
		"camera": "topdown", "scene": "street", "tile_px": 64, "count": 2,
		"roles": [
			{"index": 0, "file": "street_00.png", "role": "asphalt", "kind": "walkable"},
			{"index": 1, "file": "street_01.png", "role": "wall", "kind": "wall"},
		],
	}), encoding="utf-8")
	png(tiles / "street_00.png")
	png(tiles / "street_01.png")

	# دارایی تأییدشده
	env = drop / "env" / "env07"
	env.mkdir(parents=True)
	(env / "asset.json").write_text(
		json.dumps({"status": "approved-by-user"}), encoding="utf-8")
	png(env / "plateau.png")

	# پوشه‌ای که باید نادیده گرفته شود
	skip = drop / "anim_concept"
	skip.mkdir(parents=True)
	(skip / "asset.json").write_text(
		json.dumps({"status": "CONCEPT-NOT-APPROVED"}), encoding="utf-8")
	png(skip / "concept.png")


def main() -> int:
	tmp = Path(tempfile.mkdtemp(prefix="import_art_test_"))
	try:
		build_fake(tmp)
		import_art.ROOT = tmp
		import_art.DROP = tmp / "art_drop"
		import_art.DEST = tmp / "game" / "assets"
		import_art.MANIFEST = import_art.DEST / "manifest.json"

		print("— فهرست دارایی‌ها —")
		found = import_art.assets()
		names = sorted(str(p.relative_to(import_art.DROP)) for p in found)
		check("پوشهٔ anim_concept نادیده گرفته شد", "anim_concept" not in names,
			  "= %s" % names)
		check("۴ دارایی پیدا شد", len(found) == 4, "= %d" % len(found))

		print("— مالکیت تصویر در پوشهٔ تودرتو —")
		kairo = import_art.DROP / "kairo"
		home = import_art.DROP / "kairo" / "home"
		k_imgs = import_art.owned_images(kairo, found)
		h_imgs = import_art.owned_images(home, found)
		check("kairo فقط تصویر خودش را دارد", len(k_imgs) == 1,
			  "= %d (باید ۱ باشد، نه ۶)" % len(k_imgs))
		check("kairo/home پنج تصویر دارد", len(h_imgs) == 5, "= %d" % len(h_imgs))

		print("— گروه‌بندی انیمیشن —")
		anims = import_art.group_anims(h_imgs, home)
		check("یک انیمیشن پیدا شد", list(anims) == ["walk_down"], "= %s" % list(anims))
		check("سه فریم، بدون _strip", len(anims.get("walk_down", [])) == 3,
			  "= %d" % len(anims.get("walk_down", [])))

		print("— نقش کاشی —")
		roles = import_art.tile_roles(import_art.DROP / "tiles_ch1_v2" / "street")
		check("roles خوانده شد", roles is not None)
		check("نوع برخورد کاشی ۱ = wall",
			  roles["tiles"]["street_01.png"]["kind"] == "wall")

		print("— اجرای کامل —")
		code = import_art.main([])
		check("پیش‌نویس بودن خطا نیست", code == 0, "= کد %d" % code)
		dest = import_art.DEST
		check("تصویر کپی شد", (dest / "kairo" / "home" / "idle_down.png").exists())
		check("roles.json نوشته شد", (dest / "tiles_ch1_v2" / "street" / "roles.json").exists())
		check("anims.json نوشته شد", (dest / "kairo" / "home" / "anims.json").exists())
		check("manifest نوشته شد", import_art.MANIFEST.exists())
		man = json.loads(import_art.MANIFEST.read_text(encoding="utf-8"))
		approved = [a for a in man["assets"] if a["approved"]]
		check("یک دارایی تأییدشده", len(approved) == 1, "= %d" % len(approved))

		print("— اجرای دوم: فقط فایل تغییرکرده —")
		import_art.main([])
		man2 = json.loads(import_art.MANIFEST.read_text(encoding="utf-8"))
		recopied = sum(a["copied"] for a in man2["assets"])
		check("هیچ فایلی دوباره کپی نشد", recopied == 0, "= %d" % recopied)

		print("— --dry-run چیزی نمی‌نویسد —")
		shutil.rmtree(dest)
		import_art.main(["--dry-run"])
		check("خروجی ساخته نشد", not dest.exists())

		print("")
		if _fails:
			print("%d از %d سنجه رد شد." % (len(_fails), _checks))
			return 1
		print("همهٔ %d سنجه قبول شد." % _checks)
		return 0
	finally:
		shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
	raise SystemExit(main())
