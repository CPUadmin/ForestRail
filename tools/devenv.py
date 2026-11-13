"""Common helpers of the work environment (docs/superpowers/specs/2026-11-14-work-environment-design.md).

The root of the project, the path to Godot (from tools/local_settings.json, which is not in git),
the list of test suites and the guard against a Godot left running by an earlier run.
"""
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SETTINGS = ROOT / "tools" / "local_settings.json"
TESTS = ROOT / "ForestRail" / "tests"
# not in the usual run: the save check needs an old save, the soak runs for minutes, check_perf measures the screen rate
SKIPPED = {"check_save_p8", "check_soak_p8", "check_perf"}

EXAMPLE = '{\n  "godot": "C:/путь/к/Godot_v4.7.2-stable_win64.exe"\n}'


def console_utf8() -> None:
    """Russian text in the Windows console."""
    for stream in (sys.stdout, sys.stderr):
        try:
            stream.reconfigure(encoding="utf-8", errors="replace")
        except (AttributeError, ValueError):
            pass


def godot_path(settings: Path = SETTINGS) -> Path:
    if not settings.is_file():
        raise SystemExit(
            f"Нет файла настроек {settings}.\n"
            f"Создай его (образец: tools/local_settings.example.json) с путём к Godot, например:\n{EXAMPLE}")
    try:
        data = json.loads(settings.read_text(encoding="utf-8"))
        exe = Path(data["godot"])
    except (ValueError, KeyError, TypeError):
        raise SystemExit(f"В {settings} нужен ключ \"godot\" с путём к Godot, например:\n{EXAMPLE}")
    if not exe.is_file():
        raise SystemExit(f"Godot не найден по пути {data['godot']} (файл {settings}). Поправь путь.")
    return exe


def godot_running() -> list:
    """Lines 'name PID' of the running Godot processes."""
    try:
        out = subprocess.run(["tasklist", "/FO", "CSV", "/NH"], capture_output=True, text=True,
                             encoding="cp866", errors="replace").stdout
    except OSError:
        return []
    found = []
    for line in out.splitlines():
        parts = [p.strip('"') for p in line.split('","')]
        if len(parts) >= 2 and parts[0].lower().startswith("godot"):
            found.append(f"{parts[0]} PID {parts[1]}")
    return found


def ensure_no_godot() -> None:
    running = godot_running()
    if running:
        raise SystemExit("Уже запущен Godot (возможно, висит прошлый прогон), тесты нельзя гонять параллельно:\n  "
                         + "\n  ".join(running) + "\nЗакрой игру или заверши эти процессы и запусти снова.")


def kill_godot() -> None:
    subprocess.run(["taskkill", "/F", "/IM", "Godot*"], capture_output=True)


def list_suites() -> list:
    names = sorted(p.stem for p in TESTS.glob("check_*.gd"))
    names = [n for n in names if n not in SKIPPED]
    if (TESTS / "drive_campaign.gd").is_file():
        names.append("drive_campaign")
    return names


def unknown_suites(names) -> list:
    return [n for n in names if not (TESTS / f"{n}.gd").is_file()]


def project_version() -> str:
    for line in (ROOT / "ForestRail" / "project.godot").read_text(encoding="utf-8").splitlines():
        if line.startswith("config/version="):
            return line.split("=", 1)[1].strip().strip('"')
    return "unknown"
