"""Package verified P3 gameplay and its independent mechanism bench."""
from pathlib import Path
import hashlib
import json
import shutil
import subprocess
import zipfile

root=Path(__file__).resolve().parents[1]
folder=root/'qa/v3_p3'
native=json.loads((folder/'native/export_checks.json').read_text(encoding='utf-8'))
mechanism=json.loads((folder/'mechanism_results.json').read_text(encoding='utf-8'))
bench=json.loads((folder/'bench_gui_results.json').read_text(encoding='utf-8'))
assets=json.loads((root/'qa/supplied_assets_audit.json').read_text(encoding='utf-8'))
if len(native)!=10 or not all(r['success'] for r in native) or mechanism['failures'] or bench['failures'] or assets['originals_without_exact_copy']:
    raise RuntimeError('P3 native acceptance is incomplete')
exe=folder/'ForestRail_P3.exe'
report={'version':'1.2.0-preview.3','stage':'P3','source_commit':subprocess.check_output(['git','rev-parse','HEAD'],text=True).strip(),
        'exe_sha256':hashlib.sha256(exe.read_bytes()).hexdigest(),'mechanism':mechanism,'bench_gui':bench,
        'native_checks':native,'supplied_original_pngs_preserved':len(assets['original_pngs']),
        'scope':'Continuous kinematics; force/inertia/train coupling remains P4','human_novice_trial':'not performed'}
report_path=root/'qa/handcar_mechanism_p3.json'
report_path.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
images=['bench_initial','bench_arbitrary_phase','bench_phase_0','bench_phase_90','bench_phase_180','bench_phase_270','bench_no_pins']
for name in images: shutil.copyfile(folder/f'{name}.png',root/'docs/screenshots'/f'p3_{name}.png')
play=folder/'Play_P3.cmd'
play.write_bytes(b'@echo off\r\nstart "" "%~dp0ForestRail_P3.exe" -- "--profile-dir=%~dp0profile"\r\nexit /b 0\r\n')
launch_bench=folder/'Mechanism_Bench.cmd'
launch_bench.write_bytes(b'@echo off\r\nstart "" "%~dp0ForestRail_P3.exe" -- --mechanism-bench\r\nexit /b 0\r\n')
notes=folder/'README_P3.txt'
notes.write_text('Лесная колея — P3 / 1.2.0-preview.3\n\n'
    'Play_P3.cmd — игра с отдельным прогрессом в profile.\n'
    'Mechanism_Bench.cmd — стенд ручного механизма.\n'
    'На стенде: Пробел — пауза, стрелки — шаг в один градус; ползунки задают скорость и фазу.\n'
    'Смена вращения не меняет фазу. Шарниры можно скрыть.\n\n'
    'P3 проверяет геометрию. Усилие руки, накат и движение состава будут связаны в P4.\n'
    'Полный редизайн интерфейса остаётся в P5/P7.\n'
    'В игре: C — крупный пульт моторной машины, M — карта, Esc — пауза.\n'
    'Все 48 исходных изображений соседнего чата сохранены.\n',encoding='utf-8-sig')
archive=folder/'ForestRail_P3_preview.zip'
files=[exe,play,launch_bench,notes,report_path,root/'docs/P3_MECHANISM_RU.md',root/'docs/SUPPLIED_ASSETS_RU.md',root/'docs/HANDCAR_CONTROL_NOTES_RU.md',*[root/'docs/screenshots'/f'p3_{name}.png' for name in images]]
with zipfile.ZipFile(archive,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as output:
    for path in files: output.write(path,Path('ForestRail_P3')/path.name)
with zipfile.ZipFile(archive) as output:
    if output.testzip(): raise RuntimeError('Corrupt P3 archive')
print(json.dumps({'archive':archive.name,'bytes':archive.stat().st_size,'native_suites':len(native),'checks':mechanism['checks']}))
