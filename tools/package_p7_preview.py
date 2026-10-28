"""Package P7 with genuine native UI/scene evidence and original asset audit."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import zipfile

root=Path(__file__).resolve().parents[1]
folder=root/'qa/v3_p7'
native=json.loads((folder/'native/export_checks.json').read_text(encoding='utf-8'))
layout=json.loads((folder/'layout_results.json').read_text(encoding='utf-8'))
assets=json.loads((root/'qa/supplied_assets_audit.json').read_text(encoding='utf-8'))
required={'check_layout_p7','check_loading_selection','check_motor_controls','check_station_service','check_world_geometry',
          'check_instruments','check_model','check_physics','check_art_v3','check_handcar_revision','check_handcar_drive',
          'check_handcar_input','check_mechanism','check_mechanism_bench','drive_campaign'}
if {r['suite'] for r in native}!=required or not all(r['success'] for r in native) or layout['failures'] or assets['originals_without_exact_copy']:
    raise RuntimeError('P7 native acceptance or original asset audit failed')
exe=folder/'build/ForestRail_P7.exe'
report={'version':'1.2.0-preview.7','stage':'P7',
        'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
        'exe_sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),
        'layout':layout,'native_checks':native,'original_pngs_preserved':len(assets['original_pngs']),
        'human_trial':'not performed','remaining':'P8 compatibility, 20-minute soak, human first-trip acceptance'}
report_path=root/'qa/presentation_p7.json'
report_path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
images=['menu','depot_1280_150','route_locomotive_1280_150','route_handcar_1600_100','map_1280_150',*[f'station_{i}' for i in range(6)]]
for name in images: shutil.copyfile(folder/(name+'.png'),root/'docs/screenshots'/('p7_'+name+'.png'))
shutil.copyfile(root/'qa/v3_p6/choice_1600.png',root/'docs/screenshots/p7_loading.png')
play=folder/'Play_P7.cmd'
play.write_bytes(b'@echo off\r\nstart "" "%~dp0ForestRail_P7.exe" -- "--profile-dir=%~dp0profile"\r\nexit /b 0\r\n')
archive=folder/'ForestRail_P7_preview.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as output:
    for path in [exe,play,report_path,root/'docs/P7_LAYOUT_PLAN_RU.md',root/'docs/P7_PRESENTATION_RU.md',
                 root/'docs/screenshots/p7_loading.png',*[root/'docs/screenshots'/('p7_'+n+'.png') for n in images]]:
        output.write(path,Path('ForestRail_P7')/path.name)
with zipfile.ZipFile(archive) as output:
    if output.testzip(): raise RuntimeError('Corrupt P7 archive')
print(json.dumps({'archive':str(archive),'bytes':archive.stat().st_size,'native_suites':len(native)}))
