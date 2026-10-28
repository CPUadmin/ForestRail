"""Run one continuous native GUI session; retain failures and guard interruptions."""
import argparse
import json
from pathlib import Path
import subprocess
import time

parser=argparse.ArgumentParser()
parser.add_argument('engine',type=Path)
parser.add_argument('--duration',type=int,default=1200)
args=parser.parse_args()
root=Path(__file__).resolve().parents[1]
folder=root/'qa/v3_p8'
stop=root/'qa/autonomous_run/stop.json'
if stop.exists(): raise SystemExit('Autonomous stop marker exists')
log=folder/('soak_probe.log' if args.duration<1200 else 'soak_native.log')
command=[str(args.engine.resolve()),'--max-fps','30','--','--qa-suite=check_soak_p8',
         '--soak-output='+str(folder),'--soak-duration='+str(args.duration),'--stop-file='+str(stop)]
start=time.monotonic()
with log.open('w',encoding='utf-8') as output:
    try:
        result=subprocess.run(command,stdout=output,stderr=subprocess.STDOUT,
                              timeout=args.duration+180,creationflags=subprocess.CREATE_NO_WINDOW)
        code=result.returncode
    except subprocess.TimeoutExpired:
        output.write('\nFAIL: soak exceeded bounded runtime\n')
        code=124
content=log.read_text(encoding='utf-8',errors='replace')
report=json.loads((folder/'soak_results.json').read_text(encoding='utf-8')) if (folder/'soak_results.json').exists() else {}
success=code==0 and report.get('complete',False) and not report.get('failures') and 'SCRIPT ERROR' not in content
summary={'success':success,'exit_code':code,'wall_s':time.monotonic()-start,'log':log.name,'guard_stopped':stop.exists()}
(folder/('soak_probe_runner.json' if args.duration<1200 else 'soak_runner.json')).write_text(json.dumps(summary,indent=2),encoding='utf-8')
print(json.dumps(summary))
raise SystemExit(0 if success else 1)
