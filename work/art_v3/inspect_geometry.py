from pathlib import Path
from PIL import Image
import numpy as np,json
from collections import deque
root=Path(r"C:\Users\Lenovo\Documents\ChatGPT\дрезина\ForestRail\assets\art_v3")
seeds={
 "mechanism/lever":[[1015,377],[1471,376]],
 "mechanism/support":[[645,205]],
 "mechanism/connecting_rod":[[166,380],[1814,380]],
 "mechanism/crank":[[390,395],[1734,402]],
 "mechanism/gear":[[633,620]],
 "vehicles/handcar_body":[[569,445],[1464,446]]
}
def hole(im,seed):
 a=np.asarray(im.getchannel('A'));h,w=a.shape;sx,sy=seed
 if a[sy,sx]>=32:return {"seed":seed,"error":"seed not transparent","alpha":int(a[sy,sx])}
 seen={(sx,sy)};q=deque([(sx,sy)]);xs=[];ys=[]
 while q:
  x,y=q.popleft();xs.append(x);ys.append(y)
  if len(seen)>250000:return {"seed":seed,"error":"open background"}
  for nx,ny in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
   if 0<=nx<w and 0<=ny<h and (nx,ny) not in seen and a[ny,nx]<32:seen.add((nx,ny));q.append((nx,ny))
 return {"seed":seed,"center":[(min(xs)+max(xs))/2,(min(ys)+max(ys))/2],"bounds":[min(xs),min(ys),max(xs)+1,max(ys)+1],"area":len(xs)}
out={}
for sid,points in seeds.items():
 im=Image.open(root/(sid+".png"))
 out[sid]=[hole(im,p) for p in points]
(Path(__file__).parent/"geometry_holes.json").write_text(json.dumps(out,indent=2),encoding='utf-8')
print(json.dumps(out))
