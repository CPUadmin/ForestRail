from pathlib import Path
import os, subprocess, json
root = Path(__file__).resolve().parents[2]
out = Path(__file__).resolve().parent
godot = Path('C:/Users/Lenovo/Documents/Codex/2026-10-04/referenced-chatgpt-conversation-this-is-an/work/godot/Godot_v4.7.2-stable_win64_console.exe')
env = os.environ.copy()
env['APPDATA'] = str(out / 'isolated_appdata')
(out / 'isolated_appdata/ForestRail/qa_model').mkdir(parents=True,exist_ok=True)
summary = []
for suite in ['check_model','check_physics']:
    cmd = [str(godot),'--headless','--path',str(root/'ForestRail'),'--script','res://tests/runner.gd','--','--suite='+suite]
    p = subprocess.run(cmd,env=env,capture_output=True,timeout=90,creationflags=subprocess.CREATE_NO_WINDOW)
    log = (p.stdout+p.stderr).decode('utf-8',errors='replace')
    (out/(suite+'.log')).write_text(log,encoding='utf-8')
    summary.append({'suite':suite,'code':p.returncode,'tail':log[-1600:]})
    print(json.dumps(summary[-1],ensure_ascii=True),flush=True)
cmd = [str(godot),'--path',str(root/'ForestRail'),'--resolution','1600x900','--position','80,80','--audio-driver','Dummy','--script',str(out/'audit.gd')]
p = subprocess.run(cmd,env=env,capture_output=True,timeout=120,creationflags=subprocess.CREATE_NO_WINDOW)
log = (p.stdout+p.stderr).decode('utf-8',errors='replace')
(out/'runtime.log').write_text(log,encoding='utf-8')
summary.append({'suite':'runtime_audit','code':p.returncode})
(out/'run_status.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'suite':'runtime_audit','code':p.returncode,'report':'work/audit_v3/audit_results.json'},ensure_ascii=True))
