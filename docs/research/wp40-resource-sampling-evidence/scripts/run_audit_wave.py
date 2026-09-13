import os,subprocess,sys
from pathlib import Path
label=sys.argv[1]
seeds=['0','4074524248646631899','4655649881628627392']
processes=[]
for i,seed in enumerate(seeds):
 env=dict(os.environ,WP40_PROFILE_GAME_ROOT='/tmp/grug-sampling-audit-'+label+'-game',WP40_PROFILE_OUTPUT='/tmp/grug-sampling-audit-results/'+label+'-'+str(i),WP40_PROFILE_SEED=seed,WP40_PROFILE_CASES='/tmp/grug-sampling-depth-cases.lua',WP40_PROFILE_FULL_DIGEST='1',WP40_PROFILE_PORT_BASE=str(32660+i*2))
 log=open('/tmp/grug-sampling-audit-results/'+label+'-'+str(i)+'.log','w')
 proc=subprocess.Popen(['chrt','--idle','0','ionice','-c3','bash','/tmp/grug-sampling-audit-harness/tools/wp40/profile/run.sh','/tmp/grug-throughput-flatpak.sh'],env=env,stdout=log,stderr=subprocess.STDOUT)
 processes.append((proc,log,i))
failed=False
for proc,log,i in processes:
 code=proc.wait();log.close();print(label,i,code,flush=True);failed=failed or code!=0
raise SystemExit(1 if failed else 0)
