"""Package the local P1 preview with an isolated player profile and evidence."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import zipfile

root = Path(__file__).resolve().parents[1]
folder = root/'qa'/'v3_p1'
executable = folder/'ForestRail_P1.exe'
native = json.loads((folder/'checks'/'export_checks.json').read_text(encoding='utf-8'))
station = json.loads((folder/'results.json').read_text(encoding='utf-8'))
if not all(row['success'] for row in native) or station['failures']:
    raise RuntimeError('Preview cannot be packaged with failing checks')
user = Path(os.environ['APPDATA'])/'ForestRail'
before = json.loads((root/'qa'/'v3_p0'/'user_save_hashes.json').read_text(encoding='utf-8'))
after = {p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in user.glob('save_v2*.json')}
report = {'version':'1.2.0-preview.1', 'specification':'3.0', 'stage':'P1',
          'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
          'native_executable_sha256':hashlib.sha256(executable.read_bytes()).hexdigest(),
          'station':station,'native_checks':native,
          'campaign':json.loads((user/'qa_model'/'drive_campaign.json').read_text(encoding='utf-8')),
          'player_save_files_unchanged':before==after,'human_novice_trial':'not performed',
          'remaining_stages':['P2','P3','P4','P5','P6','P7','P8']}
(root/'qa'/'station_service_p1.json').write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
screens=root/'docs'/'screenshots'
shutil.copyfile(folder/'03_world_platform_success.png',screens/'p1_world_platform.png')
shutil.copyfile(folder/'01_brake94.png',screens/'p1_brake94.png')
launch=folder/'Play_P1.cmd'
launch.write_bytes(b'@echo off\r\nstart "" "%~dp0ForestRail_P1.exe" "--profile-dir=%~dp0profile"\r\nexit /b 0\r\n')
notes=folder/'README_P1.txt'
notes.write_text('Лесная колея — проверочная версия P1\n\n'
                 'Запуск: распакуйте архив в отдельную папку и откройте Play_P1.cmd.\n'
                 'Прогресс этой проверки хранится в папке profile рядом с игрой.\n\n'
                 'Первый рейс: перетащите мешки в свободные места, отправляйтесь и отпустите тормоз.\n'
                 'Качайте правый деревянный хват. На станции остановитесь у отметки и затяните тормоз.\n'
                 'Груз можно отпустить на выделенную платформу или в панель Разгрузка.\n'
                 'Можно выбрать его кликом и нажать Выгрузить выбранный. Оплата — после возвращения домой.\n'
                 'M — карта, Esc — пауза.\n\n'
                 'В этой проверке реализован P1 ТЗ 3.0. Масштаб, сцепки и новая физика ручного привода\n'
                 'остаются следующими этапами P2–P4. Полная пользовательская приёмка ещё впереди.\n',encoding='utf-8-sig')
archive=folder/'ForestRail_P1_preview.zip'
files=[executable,launch,notes,root/'qa'/'station_service_p1.json',screens/'p1_world_platform.png',screens/'p1_brake94.png']
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as output:
    for path in files: output.write(path,Path('ForestRail_P1')/path.name)
with zipfile.ZipFile(archive) as output:
    if output.testzip() is not None: raise RuntimeError('Corrupt preview archive')
print(json.dumps({'archive':archive.name,'bytes':archive.stat().st_size,'station_checks':station['checks'],
                  'player_saves_unchanged':before==after,'native_suites':len(native)},ensure_ascii=False))
