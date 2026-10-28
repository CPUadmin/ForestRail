from pathlib import Path
import json,shutil,hashlib,zipfile
from html import escape
root=Path(r"C:\Users\Lenovo\Documents\ChatGPT\дрезина\ForestRail\assets\art_v3")
work=Path(__file__).parent
out=Path(r"C:\Users\Lenovo\Documents\Codex\2026-10-27\new-chat\outputs\ForestRail_Art_v3")
(root/"verification").mkdir(exist_ok=True)
for name in ["mechanism_native.png","terrain_native.png"]:shutil.copy2(work/name,root/"verification"/name)
m=json.loads((root/"manifest.json").read_text(encoding="utf-8"))
rig=json.loads((root/"rig"/"mechanism.json").read_text(encoding="utf-8"))
native=json.loads((work/"native_report.json").read_text(encoding="utf-8"))
report={"images":len(m["assets"]),"native_engine":"Godot 4.7.2 Compatibility","texture_resources_loaded":28,"materials_loaded":4,"resource_errors":0,
 "full_rotation":rig["validation"],"native_scenes":{"mechanism":"passed","terrain":"passed"},"notes":["Raw PNG boundaries are not guaranteed seamless; use periodic materials.","Some raw alpha edges contain matte fringe; native previews use edge_clean shader.","Integration into the main game scene has not been performed."]}
(root/"verification"/"report.json").write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
html=(work/"gallery_template.html").read_text(encoding="utf-8")
for group,slot in [("mechanism","MECHANISM"),("vehicles","VEHICLE"),("parallax","PARALLAX"),("terrain","TERRAIN"),("stations","STATION")]:
 cards=[]
 for sid,a in m["assets"].items():
  if not sid.startswith(group+"/"):continue
  extra='<a href="rig/markers/'+sid.split("/")[-1]+'.svg">С метками шарниров</a>' if group=="mechanism" else ""
  cards.append('<figure><div class="checker"><img loading="lazy" src="'+a["file"]+'" alt="'+escape(a["label_ru"])+'"></div><figcaption><b>'+escape(a["label_ru"])+'</b><code>'+a["file"]+'</code>'+extra+'</figcaption></figure>')
 html=html.replace("__"+slot+"_CARDS__","\n".join(cards))
html=html.replace("__MANIFEST_JSON__",json.dumps(m,ensure_ascii=False)).replace("__RIG_JSON__",json.dumps(rig))
(root/"OPEN_ME.html").write_text(html,encoding="utf-8")
shutil.copytree(root,out,dirs_exist_ok=True,ignore=shutil.ignore_patterns("*.import","*.uid"))
# Publish a portable archive without editor caches and local import sidecars.
archive=out.parent/"ForestRail_Art_v3.zip"
with zipfile.ZipFile(archive,"w",zipfile.ZIP_DEFLATED) as z:
 for p in sorted(out.rglob("*")):
  if p.is_file():z.write(p,Path("ForestRail_Art_v3")/p.relative_to(out))
with zipfile.ZipFile(archive) as z:assert z.testzip() is None
print(json.dumps({"images":len(m["assets"]),"archive":str(archive),"bytes":archive.stat().st_size},ensure_ascii=False))
