"""Require native full and partial-trip evidence before packaging P6."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import zipfile

root=Path(__file__).resolve().parents[1]
folder=root/'qa/v3_p6'
native=json.loads((folder/'native/export_checks.json').read_text(encoding='utf-8'))
partial=json.loads((folder/'partial/export_checks.json').read_text(encoding='utf-8'))
loading=json.loads((folder/'loading_results.json').read_text(encoding='utf-8'))
required={'check_loading_selection','check_model','check_station_service','check_motor_controls','check_physics',
          'check_world_geometry','check_instruments','check_art_v3','check_handcar_revision','check_handcar_drive',
          'check_handcar_input','check_mechanism','check_mechanism_bench','drive_campaign'}
if {r['suite'] for r in native}!=required or not all(r['success'] for r in native) or loading['failures']:
    raise RuntimeError('P6 native acceptance incomplete or failed')
if len(partial)!=1 or not partial[0]['success']:
    raise RuntimeError('Partial first trip not verified')
exe=folder/'build/ForestRail_P6.exe'
report={'version':'1.2.0-preview.6','stage':'P6',
        'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
        'exe_sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),
        'loading':loading,'native_checks':native,'partial_driving':partial,
        'human_trial':'not performed','remaining':'P7-P8'}
report_path=root/'qa/loading_selection_p6.json'
report_path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
images=[name+'_'+str(width) for name in ['choice','return'] for width in [1280,1600,1920]]
for name in images: shutil.copyfile(folder/(name+'.png'),root/'docs/screenshots'/('p6_'+name+'.png'))
play=folder/'Play_P6.cmd'
play.write_bytes(b'@echo off\r\nstart "" "%~dp0ForestRail_P6.exe" -- "--profile-dir=%~dp0profile"\r\nexit /b 0\r\n')
archive=folder/'ForestRail_P6_preview.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as output:
    for path in [exe,play,report_path,root/'docs/P6_LOADING_RU.md',*[root/'docs/screenshots'/('p6_'+n+'.png') for n in images]]:
        output.write(path,Path('ForestRail_P6')/path.name)
with zipfile.ZipFile(archive) as output:
    if output.testzip(): raise RuntimeError('Corrupt P6 archive')
print(json.dumps({'archive':str(archive),'bytes':archive.stat().st_size,'native_suites':len(native)}))
