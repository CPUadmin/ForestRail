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
parser.add_argument('--partial-first', action='store_true')
parser.add_argument('--manual-run', action='store_true', help='Run on a new human request despite a completed autonomous stop marker')
args = parser.parse_args()
root = Path(__file__).resolve().parents[1]
reports = args.report_dir.resolve() if args.report_dir else root/'qa'
reports.mkdir(parents=True, exist_ok=True)
results = []
for suite in args.suite.split(','):
    if (root/'qa/autonomous_run/stop.json').exists() and not args.manual_run:
        raise SystemExit('Autonomous guard requested a saved stop; no further QA started')
    script = root/'ForestRail'/'tests'/f'{suite}.gd'
    command = [str(args.engine.resolve())]
    if suite not in ('check_interaction', 'check_presentation', 'check_instruments', 'check_station_service', 'check_world_geometry', 'check_mechanism_bench', 'check_handcar_input', 'check_motor_controls', 'check_loading_selection', 'check_layout_p7'):
        command.append('--headless')
    if not args.exported:
        command += ['--path', str(root/'ForestRail')]
    command += ['--', '--qa-suite='+suite]
    if suite == 'drive_campaign' and args.partial_first:
        command.append('--partial-first')
    if suite == 'check_station_service':
        command.append('--station-output='+str(root/'qa'/'v3_p1'))
    if suite.startswith('check_mechanism'):
        command.append('--mechanism-output='+str(root/'qa'/'v3_p3'))
    if suite.startswith('check_handcar_') and suite not in ('check_handcar_revision',):
        command.append('--drive-output='+str(root/'qa'/'v3_p4'))
    if suite == 'check_motor_controls':
        command.append('--motor-output='+str(root/'qa'/'v3_p5'))
    if suite == 'check_loading_selection':
        command.append('--loading-output='+str(root/'qa'/'v3_p6'))
    if suite == 'check_layout_p7':
        command.append('--layout-output='+str(root/'qa'/'v3_p7'))
    log = reports/f'{"export" if args.exported else "source"}_{suite}.log'
    start = time.monotonic()
    exit_code = 124
    with log.open('w', encoding='utf-8') as output:
        try:
            process = subprocess.run(command, stdout=output, stderr=subprocess.STDOUT, timeout=180,
                                     cwd=args.engine.resolve().parent, creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
            exit_code = process.returncode
        except subprocess.TimeoutExpired:
            output.write('\nFAIL: QA process exceeded 180 seconds; terminated by runner\n')
    content = log.read_text(encoding='utf-8', errors='replace')
    success = exit_code == 0 and 'SCRIPT ERROR' not in content and 'FAIL:' not in content
    # A script unavailable in an exported build must not be confused with a passed check.
    marker = {'check_model': 'MODEL CHECKS', 'check_physics': 'PHYSICS CHECKS',
              'check_interaction': 'INTERACTION CHECKS', 'drive_campaign': 'DRIVE CAMPAIGN', 'check_handcar_revision': 'HANDCAR CHECKS', 'check_art_v3': 'ART V3 CHECKS', 'check_instruments': 'INSTRUMENT CHECKS', 'check_station_service': 'STATION SERVICE CHECKS', 'check_world_geometry':'WORLD GEOMETRY CHECKS','check_mechanism':'MECHANISM CHECKS','check_mechanism_bench':'MECHANISM BENCH CHECKS','check_handcar_drive':'HANDCAR DRIVE CHECKS','check_handcar_input':'HANDCAR INPUT CHECKS','check_motor_controls':'MOTOR CONTROL CHECKS','check_loading_selection':'LOADING SELECTION CHECKS','check_layout_p7':'LAYOUT P7 CHECKS','check_steam':'STEAM CHECKS'}
    success &= marker.get(suite, 'PRESENTATION') in content
    result = {'suite': suite, 'exit_code': exit_code, 'success': success,
              'seconds': round(time.monotonic()-start, 3), 'log': log.name}
    results.append(result)
    print(json.dumps(result), flush=True)
summary = reports/f'{"export" if args.exported else "source"}_checks.json'
previous = {r['suite']: r for r in json.loads(summary.read_text(encoding='utf-8'))} if summary.exists() else {}
for result in results:
    previous[result['suite']] = result
summary.write_text(json.dumps(list(previous.values()), indent=2), encoding='utf-8')
raise SystemExit(0 if all(r['success'] for r in results) else 1)
