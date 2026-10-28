from pathlib import Path
from PIL import Image
import numpy as np,math,json
root=Path(r"C:\Users\Lenovo\Documents\ChatGPT\дрезина\ForestRail\assets\art_v3")
m=json.loads((root/"manifest.json").read_text(encoding="utf-8"))
results=[]
for sid in ["terrain/soil","terrain/ballast","terrain/grass","terrain/rail"]:
 a=m["assets"][sid];im=Image.open(root/a["file"]).convert("RGBA")
 x,y,w,h=a["region_px"];arr=np.asarray(im,dtype=float)[y:y+h,x:x+w]/255
 def sample(u,v):
  px=np.clip(u,0,1)*(w-1);py=np.clip(v,0,1)*(h-1)
  x0=int(px);y0=int(py);x1=min(w-1,x0+1);y1=min(h-1,y0+1);fx=px-x0;fy=py-y0
  c=(arr[y0,x0]*(1-fx)+arr[y0,x1]*fx)*(1-fy)+(arr[y1,x0]*(1-fx)+arr[y1,x1]*fx)*fy
  return np.r_[c[:3]*c[3],c[3]]
 tile_y=sid in ["terrain/soil","terrain/ballast"]
 def periodic(u,v):
  u=u%1;v=v%1 if tile_y else np.clip(v,0,1)
  wx=math.sin(math.pi*u)**2;wy=math.sin(math.pi*v)**2 if tile_y else 1
  return sample(u,v)*wx*wy+sample((u+.5)%1,v)*(1-wx)*wy+sample(u,(v+.5)%1 if tile_y else v)*wx*(1-wy)+sample((u+.5)%1,(v+.5)%1 if tile_y else v)*(1-wx)*(1-wy)
 eps=1e-7
 error=max(float(np.max(np.abs(periodic(-eps,v)-periodic(eps,v)))) for v in np.linspace(.01,.99,33))
 if tile_y:error=max(error,max(float(np.max(np.abs(periodic(u,-eps)-periodic(u,eps)))) for u in np.linspace(.01,.99,33)))
 assert error<.002,(sid,error)
 results.append({"asset":sid,"raw_left_right_mean_delta_0_1":float(np.mean(np.abs(arr[:,0]-arr[:,-1]))),"material_boundary_epsilon":eps,"material_max_channel_delta":error,"passed":True})
(root/"verification"/"seam_check.json").write_text(json.dumps(results,indent=2),encoding="utf-8")
print(json.dumps({"periodic_materials":results}))
