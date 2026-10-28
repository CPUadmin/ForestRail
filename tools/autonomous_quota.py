"""Read-only Codex quota monitor; never starts a model turn or reads credentials.

Protocol: https://learn.chatgpt.com/docs/app-server
"""
import argparse
import datetime as dt
import json
from pathlib import Path
import queue
import shutil
import subprocess
import threading
import time

ROOT = Path(__file__).resolve().parents[1]
RUNTIME = ROOT / 'qa/autonomous_run'


def write_json(name, value):
    target = RUNTIME / name
    temporary = target.with_suffix('.quota.tmp')
    temporary.write_text(json.dumps(value, indent=2), encoding='utf-8')
    temporary.replace(target)


def remaining(result):
    buckets = result.get('rateLimitsByLimitId')
    if not buckets:
        buckets = {'codex': result.get('rateLimits')}
    values = [max(0, 100 - float(bucket[window]['usedPercent']))
              for bucket in buckets.values() if bucket
              for window in ('primary', 'secondary')
              if bucket.get(window) and bucket[window].get('usedPercent') is not None]
    if not values:
        raise ValueError('No active quota windows returned')
    return min(values)


def monitor(once=False):
    executable = shutil.which('codex')
    if not executable:
        raise RuntimeError('Installed Codex executable unavailable')
    process = subprocess.Popen([executable, 'app-server', '--listen', 'stdio://'],
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                               stderr=subprocess.DEVNULL, text=True, encoding='utf-8',
                               creationflags=subprocess.CREATE_NO_WINDOW, cwd=ROOT)
    inbox = queue.Queue()
    def read():
        for line in process.stdout:
            try:
                inbox.put(json.loads(line))
            except ValueError:
                pass
        inbox.put({'closed': True})
    threading.Thread(target=read, daemon=True).start()
    def send(method, params=None, identifier=None):
        message = {'method': method, 'params': params or {}}
        if identifier is not None:
            message['id'] = identifier
        process.stdin.write(json.dumps(message) + '\n')
        process.stdin.flush()
    def response(identifier):
        end = time.monotonic() + 40
        while time.monotonic() < end:
            message = inbox.get(timeout=max(.01, end - time.monotonic()))
            if message.get('closed'):
                raise RuntimeError('Quota service closed')
            if message.get('id') == identifier:
                if 'error' in message:
                    raise RuntimeError('Quota service rejected request')
                return message['result']
        raise TimeoutError('Quota service timed out')
    try:
        send('initialize', {'clientInfo': {'name': 'forest_rail_quota_guard', 'version': '1.0'}}, 1)
        response(1)
        send('initialized')
        identifier = 2
        while not (RUNTIME / 'stop.json').exists():
            send('account/rateLimits/read', identifier=identifier)
            value = remaining(response(identifier))
            state = {'checked_at_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
                     'remaining_percent': value, 'used_percent': 100-value,
                     'source': 'Codex app-server account/rateLimits/read'}
            write_json('limits.json', state)
            if once:
                print(json.dumps(state))
                return
            if value < 10:
                return  # Native guard sees this value within ten seconds.
            identifier += 1
            for _ in range(60):
                if (RUNTIME / 'stop.json').exists():
                    return
                time.sleep(1)
    finally:
        process.terminate()
        try:
            process.wait(timeout=5)
        except subprocess.TimeoutExpired:
            process.kill()


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--once', action='store_true')
    args = parser.parse_args()
    try:
        monitor(args.once)
    except Exception as error:
        # Preserve last confirmed quota; native guard safely stops on stale data.
        write_json('quota_error.json', {'at_utc': dt.datetime.now(dt.timezone.utc).isoformat(),
                                       'error_type': type(error).__name__})
        raise SystemExit('Quota monitor unavailable; native stale-data stop remains active')
