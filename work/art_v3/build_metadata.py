from pathlib import Path
from PIL import Image
import numpy as np,json,math,hashlib
root=Path(r"C:\Users\Lenovo\Documents\ChatGPT\дрезина\ForestRail\assets\art_v3")
holes=json.loads((Path(__file__).parent/"geometry_holes.json").read_text())
labels={
"mechanism/lever":"Качающийся рычаг","mechanism/support":"Неподвижная опора","mechanism/connecting_rod":"Шатун","mechanism/crank":"Кривошип","mechanism/gear":"Шестерня","mechanism/axle":"Ось, разобранный вид","mechanism/axle_end":"Торец ведущей оси",
"vehicles/handcar_body":"Кузов ручной дрезины","vehicles/petrol_motorcar_body":"Кузов бензиновой дрезины","vehicles/battery_locomotive_body":"Кузов аккумуляторного локомотива","vehicles/freight_wagon_body":"Грузовой вагон","vehicles/wheel_small":"Колесо дрезины и вагона","vehicles/wheel_large":"Колесо локомотива","vehicles/coupler":"Сцепка",
"parallax/sky":"Небо","parallax/far_hills":"Дальние холмы","parallax/far_forest":"Дальний лес","parallax/mid_forest":"Средний лес","parallax/foreground":"Ближняя растительность",
"terrain/grass":"Трава","terrain/soil":"Грунт","terrain/ballast":"Щебёночная насыпь","terrain/sleeper":"Шпала","terrain/rail":"Рельс",
"stations/depot":"Депо","stations/platform":"Платформа","stations/station_house":"Станционный домик","stations/sawmill_shelter":"Навес лесопилки"}
widths={"mechanism/lever":2.2,"mechanism/support":1.0,"mechanism/connecting_rod":1.2,"mechanism/crank":.25,"mechanism/gear":.36,"mechanism/axle":1.0,"mechanism/axle_end":.14,
"vehicles/handcar_body":3.2,"vehicles/petrol_motorcar_body":3.2,"vehicles/battery_locomotive_body":4.0,"vehicles/freight_wagon_body":2.8,"vehicles/wheel_small":.42,"vehicles/wheel_large":.55,"vehicles/coupler":.36,
"terrain/sleeper":.72,"terrain/rail":2.0,"terrain/grass":2.0,"terrain/soil":2.0,"terrain/ballast":2.0,"stations/depot":7,"stations/platform":7,"stations/station_house":5,"stations/sawmill_shelter":7}
parallax={"sky":0,"far_hills":.08,"far_forest":.18,"mid_forest":.42,"foreground":1.12}
items={}
tex_dir=root/"textures";tex_dir.mkdir(exist_ok=True)
markers=root/"rig"/"markers";markers.mkdir(exist_ok=True)
for p in sorted(root.rglob("*.png")):
 sid=p.relative_to(root).with_suffix("").as_posix()
 im=Image.open(p)
 if im.mode=="RGBA":
  alpha=np.asarray(im.getchannel("A"));ys,xs=np.nonzero(alpha>=32)
  bb=[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)]
  transparent_ratio=float(np.mean(alpha==0))
 else:bb=[0,0,im.width,im.height];transparent_ratio=0
 x,y,x1,y1=bb;bw=x1-x;bh=y1-y
 item={"id":sid,"label_ru":labels.get(sid,sid),"file":p.relative_to(root).as_posix(),"size_px":list(im.size),"region_px":[x,y,bw,bh],"mode":im.mode,
 "transparent_ratio":round(transparent_ratio,5),"sha256":hashlib.sha256(p.read_bytes()).hexdigest(),
 "pivot_px":[(x+x1-1)/2,y1-1],"pins_px":{}}
 if sid in holes:
  for i,h in enumerate(holes[sid]):
   if "center" in h:item["pins_px"][["pivot","link"][i] if sid=="mechanism/lever" else ("pivot" if i==0 else "end")]=h["center"]
 if sid in ["mechanism/connecting_rod","mechanism/crank"]:
  item["pins_px"]={"start":holes[sid][0]["center"],"end":holes[sid][1]["center"]}
 if item["pins_px"]:item["pivot_px"]=next(iter(item["pins_px"].values()))
 if sid.startswith("vehicles/") and "body" in sid:
  # Axle bearings are at the same construction fractions of this chassis family.
  frac={"handcar_body":(.280,.720,.80),"petrol_motorcar_body":(.277,.714,.86),"battery_locomotive_body":(.278,.720,.90),"freight_wagon_body":(.279,.718,.80)}[p.stem]
  py=y1-im.width*.0325
  if p.stem=="handcar_body":py=445.5
  item["wheel_centres_px"]=[[im.width*frac[0],py],[im.width*frac[1],py]]
  item["pivot_px"]=[sum(c[0] for c in item["wheel_centres_px"])/2,py]
  item["anchor_status"]="Bearing centres visually aligned; inspect vehicle preview before integration."
 if sid.startswith("vehicles/wheel") or sid=="mechanism/axle_end":
  item["pivot_px"]=[(x+x1-1)/2,(y+y1-1)/2]
 if sid in widths:
  item["physical_width_m"]=widths[sid]
  item["scale_at_128_px_per_m"]=128*widths[sid]/bw
 if sid.startswith("parallax/"):
  item["parallax_speed"]=parallax[p.stem]
  item["scale_policy"]="camera background; no shared physical metre scale"
 item["resource"]="textures/"+sid.replace("/","_")+".tres"
 t='[gd_resource type="AtlasTexture" load_steps=2 format=3]\n\n[ext_resource type="Texture2D" path="../%s" id="1"]\n\n[resource]\natlas = ExtResource("1")\nregion = Rect2(%s)\nfilter_clip = true\n'%(item["file"],", ".join(map(str,item["region_px"])))
 (root/item["resource"]).write_text(t,encoding="utf-8")
 items[sid]=item

# Use measured pin separation, not a stretched connecting rod.
lever=items["mechanism/lever"];ls=lever["scale_at_128_px_per_m"]
lp=np.array(lever["pins_px"]["pivot"]);la=np.array(lever["pins_px"]["link"])
R=float(np.linalg.norm(la-lp)*ls)
body=items["vehicles/handcar_body"];bs=body["scale_at_128_px_per_m"]
right=(np.array(body["wheel_centres_px"][1])-np.array(body["pivot_px"]))*bs
S=np.array([0.,-1.1*128]);C=right
rod_len=float(np.linalg.norm(S+np.array([R,0])-C));crank_radius=.125*128
rig={"units":"pixels at 128 px/m, +Y down","origin":"midpoint between handcar wheel centres",
 "rocker_pivot":S.tolist(),"crank_pivot":C.tolist(),"rocker_pin_radius":R,"crank_radius":crank_radius,"rod_length":rod_len,
 "lever_source_angle":float(math.atan2(la[1]-lp[1],la[0]-lp[0])),
 "support_scale":(.84*128)/(items["mechanism/support"]["region_px"][1]+items["mechanism/support"]["region_px"][3]-1-items["mechanism/support"]["pivot_px"][1]),
 "drive_wheel":"right","gear_ratio":1,"branch":"rightmost circle intersection",
 "axis_note":"Use axle_end at assembled wheel axis. Long axle.png is the disassembled shaft side view."}
errs=[];angles=[]
for phase in np.linspace(0,2*math.pi,1441):
 B=C+crank_radius*np.array([math.cos(phase),math.sin(phase)])
 delta=B-S;dist=float(np.linalg.norm(delta));u=delta/dist
 a=(R*R-rod_len*rod_len+dist*dist)/(2*dist);h2=R*R-a*a
 assert h2>0
 h=math.sqrt(h2);base=S+u*a;perp=np.array([u[1],-u[0]])
 A=base+perp*h
 errs.append(abs(float(np.linalg.norm(A-B))-rod_len));angles.append(math.atan2(A[1]-S[1],A[0]-S[0]))
rig["validation"]={"samples":1441,"max_rod_length_error_px":max(errs),"rocker_degrees":[math.degrees(min(angles)),math.degrees(max(angles))],"full_rotation_valid":True}
(root/"rig"/"mechanism.json").write_text(json.dumps(rig,ensure_ascii=False,indent=2),encoding="utf-8")
for sid,item in items.items():
 if not sid.startswith("mechanism/"):continue
 w,h=item["size_px"];pins=item["pins_px"] or {"axis":item["pivot_px"]}
 svg='<svg xmlns="http://www.w3.org/2000/svg" width="%d" height="%d" viewBox="0 0 %d %d"><image href="../../%s" width="%d" height="%d"/>'%(w,h,w,h,item["file"],w,h)
 for name,(px,py) in pins.items():
  svg+='<g stroke="#ff4dc2" fill="none" stroke-width="3"><circle cx="%s" cy="%s" r="14"/><path d="M%s %sh36M%s %sv36"/></g><text x="%s" y="%s" fill="#ff4dc2" font-size="27" font-family="sans-serif">%s</text>'%(px,py,px-18,py,px,py-18,px+22,py-22,name)
 svg+='</svg>'
 (markers/(sid.split("/")[-1]+".svg")).write_text(svg,encoding="utf-8")
manifest={"version":3,"style":"orthographic side / painted wood and pine-green steel","world_px_per_m":128,"assets":items,"raw_png_seamless_guarantee":False,
 "terrain_seamless":"Use materials/*.tres; periodic four-sample blending. Use arclength UVs on slopes.",
 "edge_cleanup":"Optional materials/edge_clean.gdshader suppresses saturated matte fringe without modifying source PNG.",
 "generator":"built-in image_gen","rig":"rig/mechanism.json"}
(root/"manifest.json").write_text(json.dumps(manifest,ensure_ascii=False,indent=2),encoding="utf-8")
print(json.dumps({"images":len(items),"rig":rig},ensure_ascii=False))
