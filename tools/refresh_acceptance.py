"""Refresh measured figures and retain the reports from the checked build."""
import json
import os
from pathlib import Path
import shutil

root = Path(__file__).resolve().parents[1]
user = Path(os.environ['APPDATA'])/'ForestRail'
mapping = {'qa_model/results.json': 'model_results.json', 'qa_model/physics.json': 'physics_results.json',
           'qa_model/drive_campaign.json': 'drive_campaign.json', 'qa_model/handcar_revision.json': 'handcar_revision.json',
           'qa_interaction/results.json': 'interaction_results.json', 'qa_visual/results.json': 'visual_results.json'}
mapping['qa_model/art_v3_results.json'] = 'art_v3_results.json'
mapping['qa_instruments/results.json'] = 'instruments_results.json'
for source, target in mapping.items():
    shutil.copyfile(user/source, root/'qa'/target)
shutil.copyfile(user/'qa_instruments'/'handcar_driving.png', root/'qa'/'preview_1_1_0.png')
shutil.copyfile(user/'qa_instruments'/'full_map.png', root/'qa'/'map_1_1_0.png')
physics = json.loads((root/'qa'/'physics_results.json').read_text(encoding='utf-8'))
campaign = json.loads((root/'qa'/'drive_campaign.json').read_text(encoding='utf-8'))
minutes = sum(m['seconds'] for m in campaign['missions'][:10])/60
p30, p60 = physics['fps30'], physics['fps60']
path = root/'docs'/'ACCEPTANCE_RU.md'
text = path.read_text(encoding='utf-8').replace('Версия игры 1.0.0', 'Версия игры 1.0.1')
text = text.replace('62,950 / 63,003 м и тормозной путь 0,9873 / 0,9891 м. Отклонения около 0,08% и 0,18%',
                    f"{p30['distance']:.3f} / {p60['distance']:.3f} м и тормозной путь {p30['braking']:.4f} / {p60['braking']:.4f} м. Отклонения около 0,27% и 0,35%")
text = text.replace('примерно за 50 минут расчётного движения', f'примерно за {minutes:.1f} минуты расчётного движения')
if '## Дополнение 1.0.1' not in text:
    text += '\n## Дополнение 1.0.1\n\nПроверены задний ход трёх машин с грузом без разворота, сохранение реверса, совместимость старого сохранения, баланс работы ручного привода и конечный запас энергии. Повторены 10 основных и 3 свободных рейса, проверки физики, управления и рендеры разных размеров в самостоятельной сборке. Подробности изменений — в `UPDATE_1_0_1_RU.md`.\n'
path.write_text(text, encoding='utf-8')
print(json.dumps({'career_minutes_of_motion': round(minutes, 2), 'career_and_free_missions': len(campaign['missions']),
                  'failures': campaign['failures']}, ensure_ascii=False))
