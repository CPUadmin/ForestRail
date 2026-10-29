"""Gate preview.8 on actual soak, compatibility and final native checks."""
from pathlib import Path
import hashlib
import json
import subprocess
import zipfile

root=Path(__file__).resolve().parents[1]
folder=root/'qa/v3_p8'
soak=json.loads((folder/'soak_results.json').read_text(encoding='utf-8'))
runner=json.loads((folder/'soak_runner.json').read_text(encoding='utf-8'))
storage=json.loads((folder/'save_results.json').read_text(encoding='utf-8'))
native=json.loads((folder/'native/export_checks.json').read_text(encoding='utf-8'))
required={'check_model','check_physics','check_interaction','drive_campaign'}
if not soak.get('complete') or soak.get('target_s',0)<1200 or soak.get('elapsed_wall_s',0)<1200 or soak['failures'] or not runner['success']:
    raise RuntimeError('Continuous 20-minute session incomplete or failed')
if storage['failures'] or {r['suite'] for r in native}!=required or not all(r['success'] for r in native):
    raise RuntimeError('P8 compatibility/native checks incomplete or failed')
exe=folder/'build/ForestRail_P8_checked.exe'
digest=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
report={'version':'1.2.0-preview.8','stage':'P8 automated part',
        'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
        'delivery_exe_sha256':digest(exe),'soak_exe_sha256':digest(folder/'build/ForestRail_P8.exe'),
        'soak':soak,'save_compatibility':storage,'native_checks':native,
        'prior_p7_evidence':'qa/presentation_p7.json','human_novice_trial':'not performed','full_TZ_accepted':False,
        'candidate_difference':'version number, credits stage label and QA registrations; player model/UI unchanged from P7'}
report_path=root/'qa/acceptance_p8.json'
report_path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
play=folder/'Play_P8.cmd'
play.write_bytes(b'@echo off\r\nstart "" "%~dp0ForestRail_P8_checked.exe" -- "--profile-dir=%~dp0profile"\r\nexit /b 0\r\n')
notes=folder/'README_P8.md'
notes.write_text('# Лесная колея — проверочная версия 1.2.0-preview.8\n\n'
                 'Откройте Play_P8.cmd. Переносной прогресс хранится в profile рядом с игрой.\n'
                 'Качайте деревянный хват мышью; красная рукоять — тормоз. Можно брать часть груза.\n'
                 'M — карта, C — пульт моторной машины, Esc — пауза. Всё доступно мышью.\n\n'
                 'Автоматические проверки не заменяют пользовательскую пробу. Первый рейс новичком ещё не проверен.\n'
                 'Исходники и история Git поставляются отдельными файлами рядом с архивом.\n',encoding='utf-8')
archive=folder/'ForestRail_P8_preview.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as output:
    for path in [exe,play,notes,report_path,root/'docs/P8_ACCEPTANCE_RU.md',root/'docs/GODOT_LICENSE.txt',root/'docs/GODOT_COPYRIGHT.txt']:
        output.write(path,Path('ForestRail_P8')/path.name)
with zipfile.ZipFile(archive) as output:
    if output.testzip(): raise RuntimeError('Corrupt P8 archive')
print(json.dumps({'archive':str(archive),'bytes':archive.stat().st_size,'full_TZ_accepted':False}))
