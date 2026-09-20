"""Two bounded, isolated historical witnesses. Run only after coordinator slot grant."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import os, subprocess, json
root=Path('/tmp/grudgelands-r10/overlay-attribution')
source=root/'historical'
def run(case):
 key,port=case;output=root/('historical-engine-'+key)
 assert not output.exists(),output
 env=os.environ.copy();env.update(LC_ALL='C',WP13_CAPITAL_PORT=str(port),WP13_CAPITAL_TIMEOUT='900')
 log=root/('historical-engine-'+key+'-runner.log')
 with log.open('xb') as f:
  process=subprocess.run(['nice','-n','19','chrt','--idle','0','ionice','-c3','bash',str(source/'tools/wp13/run_capital.sh'),str(output),key,'full','531802985935182545'],cwd=source,env=env,stdout=f,stderr=subprocess.STDOUT)
 return dict(capital=key,port=port,status=process.returncode,output=str(output),log=str(log))
with ThreadPoolExecutor(max_workers=2) as pool:
 rows=list(pool.map(run,[('gor_drazhak',31870),('lethariel',31871)]))
(root/'historical-engines-results.json').write_text(json.dumps(rows,indent=2)+'\n')
print(json.dumps(rows,indent=2))
