from pathlib import Path
import subprocess, re
repo=Path('/home/jan/projects/grudgelands')
files=subprocess.check_output(['rg','--files','mods'],cwd=repo,text=True).splitlines()
production=sorted(f for f in files if re.search(r'/grug_[^/]+/.*\.lua$',f))
changed=sorted(set(subprocess.check_output(['git','diff','--name-only','291faff'],cwd=repo,text=True).splitlines()))
changedlua=[f for f in changed if f.endswith('.lua') and (repo/f).exists()]
subprocess.run(['tools/bin/luac51','-p']+sorted(set(production+changedlua)),cwd=repo,check=True)
print('Parser PASS',len(production),'production files;',len(changedlua),'changed Lua files')
for f in changedlua:
 out=subprocess.check_output(['tools/bin/luac51','-l','-p',f],cwd=repo,text=True)
 hits=[line for line in out.splitlines() if 'SETGLOBAL' in line]
 if hits: print('SETGLOBAL',f,*hits,sep='\n')
 if f.startswith('mods/'):
  expected={'mods/ENTITIES/grug_mobs/init.lua':'grug_mobs','mods/ITEMS/grug_trees/init.lua':'grug_trees'}.get(f)
  assert (not hits if expected is None else len(hits)==1 and expected in hits[0]), f
patterns=[r'(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::',r'\\u\{|\\x[0-9A-Fa-f]|\\z',r'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.',r'[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]',r'\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\.']
for idx,p in enumerate(patterns,1):
 result=subprocess.run(['rg','-n',p]+sorted(set(production+changedlua)),cwd=repo,text=True,capture_output=True)
 assert result.returncode in (0,1),(idx,result.stderr)
 print('SWEEP',idx,result.stdout if result.stdout else 'no matches')
subprocess.run(['git','diff','--check'],cwd=repo,check=True)
print('Static diagnostics and diff check complete; inspect comment/offline-tool hits.')
