"""A trial build for the owner, the way a release is built, but WITHOUT the release itself.

  python tools/build_trial.py

Steps (the quality gates of docs/PLAN_RAZRABOTKI_RU.md): a clean copy of the last commit, the export template in place,
the import twice, the Windows export into release/trial/<version>/ForestRail.exe, short checks of the exported exe,
and a search for lost pictures in its logs. No tag, no install, no shortcut, no GitHub: those wait for the owner's word.
"""
import shutil
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import devenv  # noqa: E402

devenv.console_utf8()
ROOT = devenv.ROOT
TEMPLATE = ROOT / "tools" / "templates" / "windows_release_x86_64.exe"
EXPORT_CHECKS = "check_model,check_art_v3,check_presentation"
LOST = ("No loader found", "Failed loading")


def step(text: str) -> None:
    print(f"\n== {text}", flush=True)


def git(*args, cwd=ROOT) -> str:
    return subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, encoding="utf-8", errors="replace").stdout


if not TEMPLATE.is_file():
    raise SystemExit(f"Нет шаблона экспорта {TEMPLATE}.\nСкачай его: python tools/fetch_windows_template.py")
godot = devenv.godot_path()
devenv.ensure_no_godot()
version = devenv.project_version()
changed = [l for l in git("status", "--short").splitlines() if not l.startswith("??")]
if changed:
    print(f"Внимание: {len(changed)} файлов изменено и не закоммичено. Сборка берёт ПОСЛЕДНИЙ КОММИТ, этих правок в ней не будет.")
out_dir = ROOT / "release" / "trial" / version
exe = out_dir / "ForestRail.exe"
worktree = ROOT / "release" / "_trial_worktree"

try:
    step(f"Чистая копия последнего коммита ({git('log', '--oneline', '-1').strip()})")
    if worktree.exists():
        git("worktree", "remove", "--force", str(worktree))
        shutil.rmtree(worktree, ignore_errors=True)
    git("worktree", "add", "--detach", str(worktree), "HEAD")
    (worktree / "tools" / "templates").mkdir(parents=True, exist_ok=True)
    shutil.copy2(TEMPLATE, worktree / "tools" / "templates" / TEMPLATE.name)

    step("Импорт картинок и звуков (дважды: первый раз Godot иногда падает, это нормально)")
    for attempt in (1, 2):
        run = subprocess.run([str(godot), "--headless", "--path", str(worktree / "ForestRail"), "--import"],
                             capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=1800)
        print(f"  импорт {attempt}: код {run.returncode}")

    step(f"Экспорт в {exe}")
    out_dir.mkdir(parents=True, exist_ok=True)
    if exe.exists():
        exe.unlink()
    run = subprocess.run([str(godot), "--headless", "--path", str(worktree / "ForestRail"), "--export-release", "Windows Desktop", str(exe)],
                         capture_output=True, text=True, encoding="utf-8", errors="replace", timeout=1800)
    (out_dir / "export.log").write_text(run.stdout + run.stderr, encoding="utf-8")
    if not exe.is_file():
        raise SystemExit(f"Экспорт не дал exe, смотри {out_dir / 'export.log'}")
    print(f"  exe: {exe.stat().st_size / 1e6:.0f} МБ")

    step(f"Проверка готового exe: {EXPORT_CHECKS}")
    checks = out_dir / "checks"
    run = subprocess.run([sys.executable, str(ROOT / "tools" / "run_checks.py"), str(exe), "--exported", "--manual-run",
                          "--report-dir", str(checks), "--suite", EXPORT_CHECKS],
                         capture_output=True, text=True, encoding="utf-8", errors="replace")
    print("  " + (run.stdout.strip().splitlines() or ["(нет вывода)"])[-1][:200])
    green = run.returncode == 0

    step("Поиск потерянных картинок в логах готового exe")
    lost = []
    for log in checks.glob("*.log"):
        for line in log.read_text(encoding="utf-8", errors="replace").splitlines():
            if any(word in line for word in LOST):
                lost.append(f"{log.name}: {line.strip()}")
    for line in lost[:10]:
        print("  " + line)
    print("  потерянных нет" if not lost else f"  НАЙДЕНО {len(lost)}")
finally:
    git("worktree", "remove", "--force", str(worktree))
    shutil.rmtree(worktree, ignore_errors=True)

if green and not lost:
    print(f"\nГОТОВО: пробная сборка {version} лежит в {exe}\nУстановка, ярлык и выпуск только по слову владельца.")
else:
    raise SystemExit(f"\nСБОРКА С ОШИБКАМИ: проверки {'прошли' if green else 'НЕ прошли'}, потерянных картинок {len(lost)}. Логи: {out_dir}")
