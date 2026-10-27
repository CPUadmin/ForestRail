import hashlib
import json
from pathlib import Path
import shutil
import zipfile

ROOT = Path(__file__).resolve().parents[1]
VERSION = '1.0.0'
release = ROOT/'release'/'ForestRail'
release.mkdir(parents=True, exist_ok=True)
shutil.copytree(ROOT/'docs', release/'docs', dirs_exist_ok=True)
shutil.copyfile(ROOT/'README_RU.md', release/'ИНСТРУКЦИЯ.md')
(release/'НАЧАТЬ_ЗДЕСЬ.txt').write_text(
    'Лесная колея 1.0.0\n\nЗапуск: ForestRail.exe\n\n'
    'Новая игра → депо → M01 → К погрузке.\n'
    'Перетащите два мешка на дрезину, нажмите Отправиться, отпустите красный тормоз вниз.\n'
    'Зажмите правый конец деревянного рычага и плавно качайте мышью вверх-вниз.\n'
    'На станции затяните тормоз до 100%, выгрузите мешки на нижнюю площадку.\n'
    'Разверните пустой состав и вернитесь в Лесную за оплатой.\n\n'
    'Esc — пауза и помощь депо. Колесо мыши — приблизить машину.\n'
    'Моторная дрезина: бензин. Электролокомотив: аккумулятор с рекуперацией.\n'
    'Заправка и зарядка бесплатны дома.\n\n'
    'Сохранения: %APPDATA%\\ForestRail\\\n'
    'Подробная инструкция: ИНСТРУКЦИЯ.md. Сверка с ТЗ: docs\\ACCEPTANCE_RU.md.\n', encoding='utf-8-sig')
results = release/'qa'
results.mkdir(exist_ok=True)
for name in ['export_checks.json', 'model_results.json', 'physics_results.json',
             'drive_campaign.json', 'interaction_results.json', 'visual_results.json']:
    source = ROOT/'qa'/name
    if source.exists(): shutil.copyfile(source, results/name)
for log in (ROOT/'qa').glob('export_*.log'):
    shutil.copyfile(log, results/(log.stem+'.txt'))

def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

manifest = {'version': VERSION, 'engine': '4.7.2.stable.official.ed1daf0bf', 'platform': 'Windows x86_64',
            'files': {str(p.relative_to(release)).replace('\\', '/'): {'bytes': p.stat().st_size, 'sha256': digest(p)}
                      for p in sorted(release.rglob('*')) if p.is_file() and p.name != 'manifest.json'}}
(release/'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding='utf-8')
portable = ROOT/'release'/f'ForestRail_{VERSION}_Windows_x64.zip'
with zipfile.ZipFile(portable, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for p in sorted(release.rglob('*')):
        if p.is_file(): archive.write(p, Path('ForestRail')/p.relative_to(release))
source_zip = ROOT/'release'/f'ForestRail_{VERSION}_Source.zip'
with zipfile.ZipFile(source_zip, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
    for folder in ['ForestRail', 'docs']:
        for p in sorted((ROOT/folder).rglob('*')):
            if p.is_file() and '.godot' not in p.parts:
                archive.write(p, p.relative_to(ROOT))
    for p in [ROOT/'README_RU.md', ROOT/'tools'/'fetch_windows_template.py',
              ROOT/'tools'/'run_checks.py', ROOT/'tools'/'package_release.py']:
        archive.write(p, p.relative_to(ROOT))
for p in [portable, source_zip]:
    with zipfile.ZipFile(p) as archive:
        if archive.testzip() is not None: raise RuntimeError('Corrupt archive')
    print(json.dumps({'name': p.name, 'bytes': p.stat().st_size, 'sha256': digest(p)}), flush=True)
