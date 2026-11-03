#!/usr/bin/env bash
# همهٔ آزمون‌های خودکار را اجرا می‌کند و یک خلاصه می‌دهد.
#
#   GODOT=/path/to/godot ./tools/run_tests.sh
#
# هر آزمون با timeout اجرا می‌شود و خروجی‌اش در فایل می‌رود، نه در لوله:
# اگر اسکریپت GDScript بار نشود صحنه هرگز quit نمی‌کند و خروجی لوله‌شده
# هنگام kill از دست می‌رود.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GAME="$ROOT/game"
GODOT="${GODOT:-godot}"
TIMEOUT="${TIMEOUT:-400}"
LOGDIR="${LOGDIR:-$(mktemp -d)}"

TESTS=(
  "res://tools/tests/test_compile.tscn"
  "res://tools/tests/test_physics.tscn"
  "res://tools/tests/test_levels.tscn"
  "res://tools/tests/test_companion.tscn"
  "res://tools/tests/test_solvable.tscn"
  "res://tools/tests/test_save_ui.tscn"
  "res://tools/tests/test_cutscene_audio.tscn"
  "res://tools/tests/test_robot.tscn"
  "res://tools/tests/test_acceptance.tscn"
)

fail=0

echo "=== نگهبان منبع ==="
if ! python3 -I "$ROOT/tools/check_sources.py"; then
  fail=1
fi

echo
echo "=== اعتبارسنج نقشهٔ فصل ۱ (بدون موتور) ==="
if ! python3 -I "$ROOT/tools/validate_ch1.py"; then
  fail=1
fi

echo
echo "=== برنامهٔ کنش روبات از BFS ==="
if ! python3 -I "$ROOT/tools/export_plans.py"; then
  fail=1
fi

if ! command -v "$GODOT" >/dev/null 2>&1 && [ ! -x "$GODOT" ]; then
  echo
  echo "موتور Godot پیدا نشد ($GODOT) — آزمون‌های درون‌موتور اجرا نشدند."
  echo "GODOT=/path/to/godot را بده تا اجرا شوند."
  exit $fail
fi

echo
echo "=== وارد کردن پروژه ==="
( cd "$GAME" && timeout "$TIMEOUT" "$GODOT" --headless --import >"$LOGDIR/import.log" 2>&1 )
if grep -qE "^(SCRIPT )?ERROR" "$LOGDIR/import.log"; then
  echo "وارد کردن پروژه خطا داد:"
  grep -E "^(SCRIPT )?ERROR" "$LOGDIR/import.log" | head -20
  fail=1
else
  echo "بدون خطا."
fi

for t in "${TESTS[@]}"; do
  name="$(basename "$t" .tscn)"
  if [ ! -f "$GAME/${t#res://}" ]; then
    echo
    echo "=== $name — هنوز ساخته نشده، رد شد ==="
    continue
  fi
  echo
  echo "=== $name ==="
  log="$LOGDIR/$name.log"
  # --fixed-fps حلقه را از ساعت دیوار جدا می‌کند. بدون آن آزمون روبات
  # دقیقه‌ها طول می‌کشد؛ با آن همان کار در چند ثانیه تمام می‌شود.
  ( cd "$GAME" && timeout "$TIMEOUT" "$GODOT" --headless --fixed-fps 60 "$t" >"$log" 2>&1 )
  code=$?
  grep -vE "^\s*$|کلید صدا بدون فایل|^Godot Engine" "$log"
  if grep -q "ObjectDB instances leaked" "$log"; then
    echo "  ← $name: نشت ObjectDB (گره‌ای آزاد نشده)"
    fail=1
  fi
  if grep -q "Failed to load script" "$log"; then
    # اسکریپت کامپایل نشده: صحنه هرگز quit نمی‌کند و آزمون با timeout می‌ایستد.
    # بدون این پیام، علت به‌شکل یک هنگِ بی‌دلیل دیده می‌شد.
    echo "  ← $name: اسکریپت کامپایل نشد (خطای Parse بالا را ببین)"
    fail=1
  elif [ $code -eq 124 ]; then
    echo "  ← $name: با timeout ($TIMEOUT ثانیه) ایستاد"
    fail=1
  elif [ $code -ne 0 ]; then
    echo "  ← $name با کد $code تمام شد"
    fail=1
  fi
done

# اجرای واقعی بازی: --import خطای کامپایل اسکریپت صحنه‌ها را نشان نمی‌دهد،
# ولی اجرای واقعی نشان می‌دهد. پس بوت تا منوی اصلی هم سنجیده می‌شود.
echo
echo "=== بوت تا منوی اصلی ==="
boot="$LOGDIR/boot.log"
( cd "$GAME" && timeout 60 "$GODOT" --headless --quit-after 400 >"$boot" 2>&1 )
if grep -qE "SCRIPT ERROR|^ERROR" "$boot"; then
  echo "بوت خطا داد:"
  grep -E "SCRIPT ERROR|^ERROR" "$boot" | head -20
  fail=1
else
  echo "بدون خطا."
fi

echo
if [ $fail -eq 0 ]; then
  echo "همهٔ آزمون‌ها قبول شد."
else
  echo "دست‌کم یک آزمون رد شد. گزارش‌ها: $LOGDIR"
fi
exit $fail
