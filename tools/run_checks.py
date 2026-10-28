"""Run checks with a waited process and retain each log and exit status."""
import argparse
import json
from pathlib import Path
import subprocess
import time

parser = argparse.ArgumentParser()
parser.add_argument('engine', type=Path)
parser.add_argument('--exported', action='store_true')
parser.add_argument('--report-dir', type=Path)
parser.add_argument('--suite', default='check_model,check_physics,check_interaction,drive_campaign')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
reports = args.report_dir.resolve() if args.report_dir else root/'qa'
reports.mkdir(parents=True, exist_ok=True)
results = []
for suite in args.suite.split(','):
    if (root/'qa/autonomous_run/stop.json').exists():
        raise SystemExit('Autonomous guard requested a saved stop; no further QA started')
    script = root/'ForestRail'/'tests'/f'{suite}.gd'
    command = [str(args.engine.resolve())]
    if suite not in ('check_interaction', 'check_presentation', 'check_instruments', 'check_station_service', 'check_world_geometry', 'check_mechanism_bench', 'check_handcar_input'):
        command.append('--headless')
    if not args.exported:
        command += ['--path', str(root/'ForestRail')]
    command += ['--', '--qa-suite='+suite]
    if suite == 'check_station_service':
        command.append('--station-output='+str(root/'qa'/'v3_p1'))
    if suite.startswith('check_mechanism'):
        command.append('--mechanism-output='+str(root/'qa'/'v3_p3'))
    if suite.startswith('check_handcar_') and suite not in ('check_handcar_revision',):
        command.append('--drive-output='+str(root/'qa'/'v3_p4'))
    log = reports/f'{"export" if args.exported else "source"}_{suite}.log'
    start = time.monotonic()
    with log.open('w', encoding='utf-8') as output:
        process = subprocess.run(command, stdout=output, stderr=subprocess.STDOUT, timeout=180,
                                 cwd=args.engine.resolve().parent, creationflags=subprocess.CREATE_NO_WINDOW)
    content = log.read_text(encoding='utf-8', errors='replace')
    success = process.returncode == 0 and 'SCRIPT ERROR' not in content and 'FAIL:' not in content
    # A script unavailable in an exported build must not be confused with a passed check.
    marker = {'check_model': 'MODEL CHECKS', 'check_physics': 'PHYSICS CHECKS',
              'check_interaction': 'INTERACTION CHECKS', 'drive_campaign': 'DRIVE CAMPAIGN', 'check_handcar_revision': 'HANDCAR CHECKS', 'check_art_v3': 'ART V3 CHECKS', 'check_instruments': 'INSTRUMENT CHECKS', 'check_station_service': 'STATION SERVICE CHECKS', 'check_world_geometry':'WORLD GEOMETRY CHECKS','check_mechanism':'MECHANISM CHECKS','check_mechanism_bench':'MECHANISM BENCH CHECKS','check_handcar_drive':'HANDCAR DRIVE CHECKS','check_handcar_input':'HANDCAR INPUT CHECKS'}
    success &= marker.get(suite, 'PRESENTATION') in content
    result = {'suite': suite, 'exit_code': process.returncode, 'success': success,
              'seconds': round(time.monotonic()-start, 3), 'log': log.name}
    results.append(result)
    print(json.dumps(result), flush=True)
summary = reports/f'{"export" if args.exported else "source"}_checks.json'
previous = {r['suite']: r for r in json.loads(summary.read_text(encoding='utf-8'))} if summary.exists() else {}
for result in results:
    previous[result['suite']] = result
summary.write_text(json.dumps(list(previous.values()), indent=2), encoding='utf-8')
raise SystemExit(0 if all(r['success'] for r in results) else 1)
