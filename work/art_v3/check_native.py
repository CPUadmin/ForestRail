from pathlib import Path
import subprocess,json,sys
root=Path(r"C:\Users\Lenovo\Documents\ChatGPT\дрезина")
engine=Path(r"C:\Users\Lenovo\Documents\Codex\2026-10-04\referenced-chatgpt-conversation-this-is-an\work\godot\Godot_v4.7.2-stable_win64_console.exe")
startup=subprocess.STARTUPINFO();startup.dwFlags|=subprocess.STARTF_USESHOWWINDOW;startup.wShowWindow=subprocess.SW_HIDE
reports=[]
for name,scene in [("mechanism","MechanismPreview"),("terrain","TrackPreview")]:
 if len(sys.argv)>1 and name not in sys.argv[1:]:continue
 shot=root/"work"/"art_v3"/(name+"_native.png")
 log=root/"work"/"art_v3"/(name+"_native.log")
 cmd=[str(engine),"--path",str(root/"ForestRail"),"--rendering-method","gl_compatibility","--resolution","1600x900","res://assets/art_v3/rig/"+scene+".tscn","--","--art-preview-shot="+str(shot)]
 with log.open("w",encoding="utf-8") as out:
  try:
   p=subprocess.run(cmd,stdout=out,stderr=subprocess.STDOUT,startupinfo=startup,creationflags=subprocess.CREATE_NO_WINDOW,timeout=30)
   code=p.returncode
  except subprocess.TimeoutExpired:code=-1
 text=log.read_text(encoding="utf-8",errors="replace")
 ok=code==0 and shot.exists() and "SCRIPT ERROR" not in text and "SHADER ERROR" not in text and "ERROR:" not in text
 reports.append({"scene":name,"exit":code,"screenshot":shot.name,"passed":ok,"log_tail":text[-2200:]})
print(json.dumps(reports,ensure_ascii=False))
(root/"work"/"art_v3"/"native_report.json").write_text(json.dumps(reports,ensure_ascii=False,indent=2),encoding="utf-8")
