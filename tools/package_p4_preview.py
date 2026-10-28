"""Package P4 only after inspecting all required native results."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import zipfile

root = Path(__file__).resolve().parents[1]
folder = root / 'qa/v3_p4'
native = json.loads((folder/'native/export_checks.json').read_text(encoding='utf-8'))
drive = json.loads((folder/'drive_results.json').read_text(encoding='utf-8'))
gui = json.loads((folder/'input_results.json').read_text(encoding='utf-8'))
assets = json.loads((root/'qa/supplied_assets_audit.json').read_text(encoding='utf-8'))
required = {'check_model','check_physics','check_handcar_drive','check_handcar_input',
            'check_handcar_revision','check_mechanism','check_mechanism_bench',
            'check_station_service','check_world_geometry','check_art_v3','check_instruments','drive_campaign'}
if {r['suite'] for r in native} != required or not all(r['success'] for r in native):
    raise RuntimeError('Native P4 checks incomplete or failed')
if drive['failures'] or gui['failures'] or assets['originals_without_exact_copy']:
    raise RuntimeError('Drive/input/assets acceptance failed')
exe = folder/'build/ForestRail_P4.exe'
report = {'version':'1.2.0-preview.4','stage':'P4',
          'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
          'exe_sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),
          'drive':drive,'gui':gui,'native_checks':native,
          'original_pngs_preserved':len(assets['original_pngs']),
          'human_novice_trial':'not performed','remaining':'P5-P8, human first-trip acceptance'}
report_path=root/'qa/handcar_drive_p4.json'
report_path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
images=['empty_drive','loaded_drive','empty_coast','loaded_coast','dead_point_push']
for name in images:
    shutil.copyfile(folder/f'{name}.png',root/'docs/screenshots'/f'p4_{name}.png')
play=folder/'Play_P4.cmd'
play.write_bytes(b'@echo off\r\nstart "" "%~dp0ForestRail_P4.exe" -- "--profile-dir=%~dp0profile"\r\nexit /b 0\r\n')
bench=folder/'Handcar_Drive_Bench.cmd'
bench.write_bytes(b'@echo off\r\nstart "" "%~dp0ForestRail_P4.exe" -- --handcar-drive-bench\r\nexit /b 0\r\n')
archive=folder/'ForestRail_P4_preview.zip'
files=[exe,play,bench,report_path,root/'docs/P4_DRIVE_RU.md',root/'docs/SUPPLIED_ASSETS_RU.md',
       *[root/'docs/screenshots'/f'p4_{name}.png' for name in images]]
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as output:
    for path in files: output.write(path,Path('ForestRail_P4')/path.name)
with zipfile.ZipFile(archive) as output:
    if output.testzip(): raise RuntimeError('Corrupt P4 archive')
print(json.dumps({'archive':str(archive),'bytes':archive.stat().st_size,'native_suites':len(native)}))
