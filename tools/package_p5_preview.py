"""Package the verified native P5 preview and its evidence."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import zipfile

root=Path(__file__).resolve().parents[1]
folder=root/'qa/v3_p5'
native=json.loads((folder/'native/export_checks.json').read_text(encoding='utf-8'))
motor=json.loads((folder/'motor_results.json').read_text(encoding='utf-8'))
required={'check_motor_controls','check_model','check_physics','check_world_geometry',
          'check_station_service','check_instruments','check_art_v3','check_handcar_revision',
          'check_handcar_drive','check_handcar_input','check_mechanism','check_mechanism_bench','drive_campaign'}
if {row['suite'] for row in native}!=required or not all(row['success'] for row in native) or motor['failures']:
    raise RuntimeError('P5 acceptance incomplete or failed')
exe=folder/'build/ForestRail_P5.exe'
report={'version':'1.2.0-preview.5','stage':'P5',
        'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
        'exe_sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),
        'motor':motor,'native_checks':native,'human_trial':'not performed','remaining':'P6-P8'}
report_path=root/'qa/motor_controls_p5.json'
report_path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
images=[id+'_'+str(width) for id in ['motorcar','locomotive'] for width in [1280,1600,1920]]
for name in images: shutil.copyfile(folder/(name+'.png'),root/'docs/screenshots'/('p5_'+name+'.png'))
play=folder/'Play_P5.cmd'
play.write_bytes(b'@echo off\r\nstart "" "%~dp0ForestRail_P5.exe" -- "--profile-dir=%~dp0profile"\r\nexit /b 0\r\n')
archive=folder/'ForestRail_P5_preview.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as output:
    for path in [exe,play,report_path,root/'docs/P5_CONTROLS_RU.md',*[root/'docs/screenshots'/('p5_'+n+'.png') for n in images]]:
        output.write(path,Path('ForestRail_P5')/path.name)
with zipfile.ZipFile(archive) as output:
    if output.testzip(): raise RuntimeError('Corrupt P5 archive')
print(json.dumps({'archive':str(archive),'bytes':archive.stat().st_size,'native_suites':len(native)}))
