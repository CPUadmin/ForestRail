"""Watch the exchange folder of GPT and stop (print what changed) as soon as GPT delivers something.

  python tools/watch_gpt.py [--every 120]

Watches tools/art_sources/ART_QUEUE.md, FEEDBACK_FOR_GPT.md and every file under tools/art_sources/inbox/.
Claude runs it in the background: when it ends, Claude is woken up and a cheap helper checks the delivery.
"""
import argparse
import hashlib
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1] / "tools" / "art_sources"


def snapshot() -> dict:
    files = [ROOT / "ART_QUEUE.md", ROOT / "FEEDBACK_FOR_GPT.md"] + [p for p in (ROOT / "inbox").rglob("*") if p.is_file()]
    state = {}
    for p in files:
        try:
            st = p.stat()
            state[str(p.relative_to(ROOT))] = (st.st_size, int(st.st_mtime))
        except OSError:
            pass
    return state


parser = argparse.ArgumentParser()
parser.add_argument("--every", type=int, default=120, help="seconds between looks")
args = parser.parse_args()
for stream in (sys.stdout,):
    try:
        stream.reconfigure(encoding="utf-8")
    except Exception:
        pass
before = snapshot()
print("watching", len(before), "files", flush=True)
while True:
    time.sleep(args.every)
    now = snapshot()
    added = sorted(set(now) - set(before))
    changed = sorted(k for k in now if k in before and now[k] != before[k])
    if added or changed:
        print("GPT CHANGED")
        for k in added: print("  new:", k)
        for k in changed: print("  changed:", k)
        break
