"""Package the verified local P2 build, preserving the player profile."""
from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import zipfile

root=Path(__file__).resolve().parents[1]
folder=root/'qa/v3_p2'
# Exported res:// is based beside the EXE, rather than the source project.
# Keep native captures distinct from the source screenshots during testing.
native_capture=root/'qa/qa/v3_p2'
native=json.loads((folder/'native/export_checks.json').read_text(encoding='utf-8'))
geometry=json.loads((native_capture/'geometry_results.json').read_text(encoding='utf-8'))
station=json.loads((root/'qa/v3_p1/results.json').read_text(encoding='utf-8'))
required={'check_model','check_physics','check_world_geometry','check_station_service','check_art_v3','check_handcar_revision','check_instruments','drive_campaign'}
if required!={r['suite'] for r in native} or not all(r['success'] for r in native) or geometry['failures'] or station['failures']:
    raise RuntimeError('P2 native checks must all pass before packaging')
user=Path(os.environ['APPDATA'])/'ForestRail'
installation=json.loads((root/'qa/installation_120-preview2.json').read_text(encoding='utf-8-sig'))
before={name:value.lower() for name,value in installation['save_hashes'].items() if name.startswith('save_v2')}
after={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in user.glob('save_v2*.json')}
exe=folder/'ForestRail_P2.exe'
report={'version':'1.2.0-preview.2','stage':'P2','specification':'3.0',
        'source_commit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
        'exe_sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),
        'geometry':geometry,'station_checks':station['checks'],'station_failures':station['failures'],
        'native_checks':native,'campaign':json.loads((user/'qa_model/drive_campaign.json').read_text(encoding='utf-8')),
        'player_save_files_unchanged_since_install_check':before==after,'save_baseline':'installation pre/post hashes; P0 snapshot predates player progress','human_novice_trial':'not performed',
        'remaining_stages':['P3','P4','P5','P6','P7','P8']}
report_path=root/'qa/world_geometry_p2.json'
report_path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
screens=root/'docs/screenshots'
images=['scale_sheet','handcar_zoom_0.75','handcar_zoom_1.0','handcar_zoom_1.5','motorcar_zoom_1.0','locomotive_zoom_1.0','terrain_flat','terrain_up','terrain_crest','terrain_down','control_closeup']
for name in images: shutil.copyfile(native_capture/f'{name}.png',screens/f'p2_{name}.png')
launch=folder/'Play_P2.cmd'
launch.write_bytes(b'@echo off\r\nstart "" "%~dp0ForestRail_P2.exe" -- "--profile-dir=%~dp0profile"\r\nexit /b 0\r\n')
notes=folder/'README_P2.txt'
notes.write_text('Лесная колея — P2 / 1.2.0-preview.2\n\n'
    'Откройте Play_P2.cmd. Прогресс этой копии хранится в profile рядом с игрой.\n'
    'Новые пропорции машин и зданий, сцепки по длине состава, груз на настиле.\n'
    'Моторная техника: Пульт [C] открывает крупное управление мышью. C или Esc закрывает его.\n'
    'M — карта, колесо мыши — масштаб мира. Красную рукоять вниз — отпустить тормоз.\n'
    'Выгружайте нужные предметы на выделенную платформу или в панель станции.\n\n'
    'Проверены 1195 случаев геометрии/пульта, 135 случаев разгрузки и 13 полных автоматических рейсов.\n'
    'Новая физика ручного привода ещё впереди: P3/P4. Полный редизайн интерфейса — P5/P7.\n'
    'Это проверочная версия P2, пользовательская приёмка новичком не проведена.\n',encoding='utf-8-sig')
archive=folder/'ForestRail_P2_preview.zip'
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as output:
    for path in [exe,launch,notes,report_path,root/'docs/P2_DIMENSIONS_RU.md',*[screens/f'p2_{n}.png' for n in images]]:
        output.write(path,Path('ForestRail_P2')/path.name)
with zipfile.ZipFile(archive) as output:
    if output.testzip(): raise RuntimeError('Corrupt P2 archive')
print(json.dumps({'archive':str(archive),'bytes':archive.stat().st_size,'player_saves_unchanged':before==after,'native_suites':len(native)},ensure_ascii=False))
