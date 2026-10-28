from pathlib import Path
from html.parser import HTMLParser
from urllib.parse import unquote
import json,zipfile,shutil
root=Path(r"C:\Users\Lenovo\Documents\ChatGPT\дрезина\ForestRail\assets\art_v3")
out=Path(r"C:\Users\Lenovo\Documents\Codex\2026-10-27\new-chat\outputs\ForestRail_Art_v3")
work=Path(__file__).parent
mp=root/"manifest.json";m=json.loads(mp.read_text(encoding="utf-8"))
a=m["assets"]["mechanism/axle"];x,y,w,h=a["region_px"];centre=[x+(w-1)/2,y+(h-1)/2]
a["pivot_px"]=centre;a["pins_px"]={"axis":centre}
mp.write_text(json.dumps(m,ensure_ascii=False,indent=2),encoding="utf-8")
hp=root/"OPEN_ME.html"
html=hp.read_text(encoding="utf-8")
start=html.index('<script id="asset-data" type="application/json">')+len('<script id="asset-data" type="application/json">')
end=html.index("</script>",start)
html=html[:start]+json.dumps(m,ensure_ascii=False)+html[end:]
hp.write_text(html,encoding="utf-8")
iw,ih=a["size_px"];cx,cy=centre
svg='<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d"><image href="../../mechanism/axle.png" width="%d" height="%d"/><g stroke="#ff4dc2" fill="none" stroke-width="3"><path d="M%d %sH%dM%s %sV%s"/><circle cx="%s" cy="%s" r="16"/></g><text x="%s" y="%s" font-family="sans-serif" font-size="27" fill="#ff4dc2">shaft axis</text></svg>'%(iw,ih,iw,ih,x,cy,x+w,cx,cy-25,cy+25,cx,cy,cx+25,cy-25)
(root/"rig"/"markers"/"axle.svg").write_text(svg,encoding="utf-8")
rp=root/"verification"/"report.json";report=json.loads(rp.read_text(encoding="utf-8"))
if (work/"browser_report.json").exists():report["browser"]=json.loads((work/"browser_report.json").read_text())
report["material_seam_check"]="seam_check.json"
rp.write_text(json.dumps(report,ensure_ascii=False,indent=2),encoding="utf-8")
missing=[]
class Links(HTMLParser):
 def handle_starttag(self,tag,attrs):
  for key,value in attrs:
   if key in ("href","src") and value and not value.startswith(("http:","https:","#","data:")):
    if not (self.base/unquote(value.split("#")[0])).resolve().exists():missing.append(str(self.base/value))
for p in root.glob("*.html"):
 parser=Links();parser.base=p.parent;parser.feed(p.read_text(encoding="utf-8"))
assert not missing,missing
shutil.copytree(root,out,dirs_exist_ok=True,ignore=shutil.ignore_patterns("*.import","*.uid"))
archive=out.parent/"ForestRail_Art_v3.zip"
files=sorted(p for p in out.rglob("*") if p.is_file())
with zipfile.ZipFile(archive,"w",zipfile.ZIP_DEFLATED) as z:
 for p in files:z.write(p,Path("ForestRail_Art_v3")/p.relative_to(out))
with zipfile.ZipFile(archive) as z:assert z.testzip() is None
print(json.dumps({"png_assets":len(m["assets"]),"files":len(files),"archive_bytes":archive.stat().st_size,"broken_local_links":len(missing),"zip_integrity":"passed"},ensure_ascii=False))
