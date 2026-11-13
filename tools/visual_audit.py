"""Pictures for the eye check before a release: every machine by day, at night with the lamp, running, braking, in a skid, and the depot.

  python tools/visual_audit.py            pictures and sheets into qa/visual_audit_latest

Look at the sheets zoomed in: the checks with ticks do not see a wrong lamp or a cut flame.
"""
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import devenv  # noqa: E402

devenv.console_utf8()
out = devenv.ROOT / "qa" / "visual_audit_latest"
out.mkdir(parents=True, exist_ok=True)
for old in out.glob("*.png"):
    old.unlink()   # pictures of the previous run, made by this same script
godot = devenv.godot_path()
devenv.ensure_no_godot()
print(f"Снимаю кадры всех машин и депо в {out} (около минуты)...", flush=True)
try:
    run = subprocess.run([str(godot), "--path", str(devenv.ROOT / "ForestRail"), "--", "--qa-suite=probe_visual_audit", str(out)],
                         capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=600)
except subprocess.TimeoutExpired:
    devenv.kill_godot()
    raise SystemExit("Съёмка не уложилась в 10 минут, Godot остановлен.")
except KeyboardInterrupt:
    devenv.kill_godot()
    raise SystemExit(1)
(out / "godot.log").write_text(run.stdout + run.stderr, encoding="utf-8")
errors = [l for l in (run.stdout + run.stderr).splitlines() if "SCRIPT ERROR" in l or "Parse Error" in l]
frames = sorted(out.glob("*.png"))
if errors or not frames:
    raise SystemExit("Съёмка с ошибками, смотри " + str(out / "godot.log") + ("\n" + "\n".join(errors[:5]) if errors else ""))
subprocess.run([sys.executable, str(devenv.ROOT / "tools" / "visual_audit_sheet.py"), str(out)], capture_output=True)
sheets = sorted(out.glob("sheet_*.png"))
print(f"Готово: {len(frames)} кадров, {len(sheets)} листов по машинам, депо отдельными кадрами depot_*.png")
print(f"Папка: {out}")
