"""Run the test suites of the game one by one and print one summary.

  python tools/run_all_checks.py                      all suites (about 40 minutes)
  python tools/run_all_checks.py --only check_model,check_cab
  python tools/run_all_checks.py --skip drive_campaign

Never in parallel: the script refuses to start while any Godot is running, and on Ctrl+C it stops the Godot it started.
The logs of every suite go to the report folder (qa/last_run by default), the summary to summary.txt there.
"""
import argparse
import json
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import devenv  # noqa: E402

devenv.console_utf8()
parser = argparse.ArgumentParser(description="Все наборы тестов по одному")
parser.add_argument("--only", default="", help="наборы через запятую")
parser.add_argument("--skip", default="", help="наборы через запятую, которые пропустить")
parser.add_argument("--report-dir", type=Path, default=devenv.ROOT / "qa" / "last_run")
args = parser.parse_args()

suites = [s for s in args.only.split(",") if s] or devenv.list_suites()
bad = devenv.unknown_suites(suites + [s for s in args.skip.split(",") if s])
if bad:
    raise SystemExit("Таких наборов нет в ForestRail/tests: " + ", ".join(bad))
skip = set(s for s in args.skip.split(",") if s)
suites = [s for s in suites if s not in skip]
godot = devenv.godot_path()
devenv.ensure_no_godot()
report = args.report_dir.resolve()
report.mkdir(parents=True, exist_ok=True)

print(f"Запускаю {len(suites)} наборов по одному. Логи: {report}")
rows = []
started_all = time.time()
try:
    for index, suite in enumerate(suites, 1):
        started = time.time()
        process = subprocess.Popen([sys.executable, str(devenv.ROOT / "tools" / "run_checks.py"), str(godot), "--manual-run",
                                    "--report-dir", str(report), "--suite", suite],
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace")
        out, _ = process.communicate()
        last = out.strip().splitlines()[-1] if out.strip() else ""
        try:
            ok = bool(json.loads(last).get("success"))
        except ValueError:
            ok = False
        seconds = time.time() - started
        rows.append((suite, ok, seconds))
        print(f"[{index}/{len(suites)}] {'OK ' if ok else 'КРАСНЫЙ'} {suite} ({seconds:.0f} с)", flush=True)
except KeyboardInterrupt:
    print("\nОстановлено. Завершаю Godot, который запустил этот прогон.")
    try:
        process.kill()
    except Exception:
        pass
    devenv.kill_godot()
    raise SystemExit(1)

green = sum(1 for r in rows if r[1])
lines = [f"{'OK ' if ok else 'КРАСНЫЙ'} {suite} {seconds:.0f} с" for suite, ok, seconds in rows]
summary = f"{green} из {len(rows)} зелёные, {(time.time() - started_all) / 60:.1f} мин"
(report / "summary.txt").write_text(summary + "\n" + "\n".join(lines) + "\n", encoding="utf-8")
print("\n" + summary)
for suite, ok, _ in rows:
    if not ok:
        print(f"  красный: {suite}, лог {report / ('source_' + suite + '.log')}")
sys.exit(0 if green == len(rows) else 1)
