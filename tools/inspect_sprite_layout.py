"""Record visible alpha bounds; original bitmap assets remain untouched."""
import json
from pathlib import Path
from PIL import Image

root = Path(__file__).resolve().parents[1]/'ForestRail'
manifest = json.loads((root/'assets_manifest.json').read_text(encoding='utf-8'))
sheets = {key: Image.open(root/value['file']).convert('RGBA') for key, value in manifest['sheets'].items()}
layout = {}
for item in manifest['sprites']:
    x, y, width, height = item['region_px']
    region = sheets[item['sheet']].crop((x, y, x+width, y+height))
    bounds = region.getchannel('A').point(lambda alpha: 255 if alpha > 48 else 0).getbbox()
    layout[item['id']] = list(bounds or (0, 0, width, height))
(root/'data'/'visual_layout.json').write_text(json.dumps(layout, indent=2), encoding='utf-8')
