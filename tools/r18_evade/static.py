#!/usr/bin/env python3
"""Parser/global inventory and all five sweeps, including the portable fixture."""
import pathlib, subprocess
repo = pathlib.Path(__file__).resolve().parents[2]
files = ['mods/CORE/grug_core/combat.lua', 'mods/ENTITIES/grug_mobs/aggro.lua',
         'mods/ENTITIES/grug_mobs/init.lua', 'mods/ENTITIES/mobs/api.lua',
         'tools/r18_evade/micro.lua', 'mods/ENTITIES/grug_mobs/zombie.lua',
 'mods/ENTITIES/grug_mobs/night_families.lua', 'mods/ENTITIES/grug_mobs/zero_asset_variants.lua']
patterns = [r'(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::',
 r'\\u\{|\\x[0-9A-Fa-f]|\\z',
 r'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.',
 r'[^:/]//|[[:alnum:]_)"] *(&|\||<<|>>) *[[:alnum:]_("]',
 r'\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\.']
for path in files:
 subprocess.run([str(repo/'tools/bin/luac51'),'-p',path],cwd=repo,check=True)
 out=subprocess.check_output([str(repo/'tools/bin/luac51'),'-l','-p',path],cwd=repo,text=True)
 for line in out.splitlines():
  if 'SETGLOBAL' in line: print('GLOBAL',path,line.strip())
print('PARSER PASS files='+str(len(files)))
paths=sorted(str(p.relative_to(repo)) for p in repo.glob('mods/*/grug_*/**/*.lua'))
paths += ['tools/r18_evade/micro.lua','mods/ENTITIES/mobs/api.lua']
for i,pattern in enumerate(patterns,1):
 out=subprocess.run(['rg','-n','--',pattern]+paths,cwd=repo,text=True,capture_output=True)
 if out.returncode not in (0,1): raise RuntimeError(out.stderr)
 print('SWEEP',i); print(out.stdout.rstrip() or 'no hits')
print('Inspect global writes and sweep hits; comments/strings may match.')
