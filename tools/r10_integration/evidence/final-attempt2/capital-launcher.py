"""Six immutable isolated capital runs; caller reserves six engine process slots."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
import os, subprocess, json, time
repo=Path('/home/jan/projects/grudgelands/.claude/worktrees/r10-integration')
output=Path('/tmp/grudgelands-r10-final-engines/capitals-v2')
if output.exists(): raise SystemExit('Refusing to overwrite engine evidence')
if subprocess.check_output(['git','status','--porcelain'],cwd=repo,text=True):
 raise SystemExit('Integration candidate must be clean')
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip()
output.mkdir(parents=True)
keys=['highcourt','dur_brannoc','lethariel','gor_drazhak','kezamba','nhal_veyr']
(output/'candidate.txt').write_text(head+'\n')
def run(index,key):
 env=dict(os.environ,WP13_CAPITAL_PORT=str(31940+index),WP13_CAPITAL_TIMEOUT='1500')
 started=time.monotonic()
 with (output/(key+'-runner.log')).open('w') as log:
  result=subprocess.run(['chrt','--idle','0','ionice','-c3','bash',str(repo/'tools/wp13/run_capital.sh'),str(output/key),key,'full','531802985935182545'],cwd=repo,env=env,stdout=log,stderr=subprocess.STDOUT)
 row={'capital':key,'exit':result.returncode,'elapsed_seconds':round(time.monotonic()-started,3)}
 print(json.dumps(row),flush=True)
 return row
with ThreadPoolExecutor(max_workers=6) as executor:
 rows=[f.result() for f in as_completed([executor.submit(run,i,key) for i,key in enumerate(keys)])]
rows.sort(key=lambda row:row['capital'])
(output/'results.json').write_text(json.dumps({'candidate':head,'width':6,'runs':rows},indent=2)+'\n')
if subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip()!=head:
 raise SystemExit('ERROR integration HEAD moved during capital runs')
raise SystemExit(int(any(row['exit'] for row in rows)))
