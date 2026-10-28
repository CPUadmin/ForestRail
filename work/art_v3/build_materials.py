from pathlib import Path
import json
root=Path(r"C:\Users\Lenovo\Documents\ChatGPT\дрезина\ForestRail\assets\art_v3")
m=json.loads((root/"manifest.json").read_text(encoding="utf-8"))
for kind in ["grass","soil","ballast","rail"]:
 a=m["assets"]["terrain/"+kind];x,y,w,h=a["region_px"];iw,ih=a["size_px"]
 region=[x/iw,y/ih,w/iw,h/ih]
 text='[gd_resource type="ShaderMaterial" load_steps=3 format=3]\n\n[ext_resource type="Shader" path="periodic.gdshader" id="1"]\n[ext_resource type="Texture2D" path="../terrain/%s.png" id="2"]\n\n[resource]\nshader = ExtResource("1")\nshader_parameter/source_tex = ExtResource("2")\nshader_parameter/source_region = Vector4(%s)\nshader_parameter/repeat_y = %s\n'%(kind,', '.join(map(str,region)),'true' if kind in ['soil','ballast'] else 'false')
 (root/"materials"/(kind+".tres")).write_text(text,encoding="utf-8")
print("4 periodic materials created")
