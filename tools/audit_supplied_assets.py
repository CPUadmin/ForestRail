"""Verify the supplied chat's original PNGs and the packaged art manifests."""
from pathlib import Path
import argparse
import hashlib
import json

root=Path(__file__).resolve().parents[1]
parser=argparse.ArgumentParser()
parser.add_argument('--originals',type=Path,required=True)
args=parser.parse_args()
sha=lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
copies={}
for base in [root/'ForestRail/assets',root/'outputs/ForestRail_Visuals_v1',root/'outputs/ForestRail_DevSpec_v3/images']:
    for path in base.rglob('*.png'):
        copies.setdefault(sha(path),[]).append(path.relative_to(root).as_posix())
originals=[]
for path in sorted(args.originals.glob('*.png')):
    value=sha(path)
    originals.append({'original':path.name,'sha256':value,'project_copies':copies.get(value,[])})
missing=[r['original'] for r in originals if not r['project_copies']]
v3=json.loads((root/'ForestRail/assets/art_v3/manifest.json').read_text(encoding='utf-8'))
v3_checks=[]
for ident,meta in v3['assets'].items():
    path=root/'ForestRail/assets/art_v3'/meta['file']
    v3_checks.append({'id':ident,'file':path.relative_to(root).as_posix(),'matches':path.is_file() and sha(path)==meta['sha256']})
references=json.loads((root/'outputs/ForestRail_Visuals_v1/files.json').read_text(encoding='utf-8'))
reference_checks=[]
for item in references:
    paths=[root/'outputs/ForestRail_Visuals_v1'/item['file'],root/'outputs/ForestRail_DevSpec_v3/images'/item['file']]
    reference_checks.append({'file':item['file'],'matches':all(p.is_file() and sha(p)==item['sha256'] for p in paths)})
legacy=json.loads((root/'ForestRail/assets_manifest.json').read_text(encoding='utf-8'))
legacy_files=[]
def collect_files(value):
    if isinstance(value,dict):
        if isinstance(value.get('file'),str): legacy_files.append(value['file'])
        for item in value.values(): collect_files(item)
    elif isinstance(value,list):
        for item in value: collect_files(item)
collect_files(legacy)
legacy_checks=[{'file':name,'exists':(root/'ForestRail'/name).is_file()} for name in sorted(set(legacy_files))]
report={'source_chat':'01a17dc9-4ff2-7713-96f0-63fb09f7891f','original_pngs':originals,'originals_without_exact_copy':missing,'art_v3':v3_checks,'visual_references':reference_checks,'legacy_files':legacy_checks,
        'scope':'File preservation and checksum validation. Runtime use is documented separately; reference illustrations are not finished game screens.'}
out=root/'qa/supplied_assets_audit.json'
out.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'original_pngs':len(originals),'preserved':len(originals)-len(missing),'missing':missing,'v3_assets':len(v3_checks),'v3_mismatches':[r['id'] for r in v3_checks if not r['matches']],'visual_references':len(reference_checks),'reference_mismatches':[r['file'] for r in reference_checks if not r['matches']],'legacy_missing':[r['file'] for r in legacy_checks if not r['exists']]},ensure_ascii=False))
raise SystemExit(0 if originals and not missing and all(r['matches'] for r in v3_checks+reference_checks) and all(r['exists'] for r in legacy_checks) else 1)
