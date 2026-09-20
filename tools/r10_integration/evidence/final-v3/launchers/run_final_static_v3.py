from pathlib import Path
import subprocess,json,hashlib
repo=Path('/home/jan/projects/grudgelands/.claude/worktrees/r10-integration')
out=Path('/tmp/grudgelands-r10-final-static-v3')
if out.exists():raise SystemExit('Refusing existing final-static evidence')
if subprocess.check_output(['git','status','--porcelain'],cwd=repo,text=True):raise SystemExit('Need clean candidate')
out.mkdir()
head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=repo,text=True).strip()
files=subprocess.check_output(['git','diff','--name-only','--diff-filter=ACMR','1831ec68','HEAD','--','*.lua'],cwd=repo,text=True).splitlines()
(out/'files.txt').write_text('\n'.join(files)+'\n')
with (out/'static.log').open('w') as f:
 status=subprocess.run(['bash','tools/r9_perf/static.sh',*files],cwd=repo,stdout=f,stderr=subprocess.STDOUT).returncode
with (out/'fresh-server.log').open('w') as f:
 fresh=subprocess.run(['python3','tools/check_fresh_server.py'],cwd=repo,stdout=f,stderr=subprocess.STDOUT).returncode
with (out/'diff-check.log').open('w') as f:
 diff=subprocess.run(['git','diff','--check','1831ec68','HEAD'],cwd=repo,stdout=f,stderr=subprocess.STDOUT).returncode
(out/'inputs.sha256').write_text(''.join(hashlib.sha256((repo/name).read_bytes()).hexdigest()+'  '+name+'\n' for name in files))
result={'candidate':head,'lua_files':len(files),'parser_sweeps':status,'fresh_server':fresh,'diff_check':diff,'note':'Coordinator must inspect all SETGLOBAL and sweep hits; process exit alone is not semantic approval.'}
(out/'result.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result))
raise SystemExit(int(any([status,fresh,diff])))
