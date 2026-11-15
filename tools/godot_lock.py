"""One Godot at a time, for every copy of the project on this computer (the owner's rule: tests never run in parallel).

  python tools/godot_lock.py -- "<path to godot>" --headless --path ForestRail --import
  python tools/godot_lock.py -- python tools/run_all_checks.py --only check_yard

The command waits for its turn (a lock file in the temp folder, shared by all work folders), runs, and frees the turn.
run_all_checks.py takes the same lock by itself; wrap only the direct Godot runs (imports, probes) in this script.
"""
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import devenv  # noqa: E402

if __name__ == "__main__":
    devenv.console_utf8()
    args = sys.argv[1:]
    if args and args[0] == "--":
        args = args[1:]
    if not args:
        raise SystemExit(__doc__)
    with devenv.godot_turn():
        raise SystemExit(subprocess.run(args).returncode)
