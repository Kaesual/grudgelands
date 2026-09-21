#!/usr/bin/env python3
"""Plain-5.1 parser/global gate and five source sweeps on this lane's files."""
import pathlib,re,subprocess
repo=pathlib.Path(__file__).resolve().parents[2]
files=[repo/p for p in ('mods/CORE/grug_core/starts_preload.lua','mods/CORE/grug_core/preparation_plan.lua','mods/PLAYER/grug_factions/init.lua','tools/r14_pregen/kat.lua','tools/r14_pregen/stop_probe.lua')]
patterns=[r'(^|[^\w.:])goto\s*[( ]|::[A-Za-z_]+::',r'\\u\{|\\x[0-9A-Fa-f]|\\z',r'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.',r'[^:/]//|[\w)\"] *(&|\||<<|>>) *[\w(\"]',r'\brequire\s*\(|io\.popen|os\.(execute|exit)|\bminetest\.']
for path in files:
    subprocess.run([str(repo/'tools/bin/luac51'),'-p',str(path)],check=True)
    listing=subprocess.check_output([str(repo/'tools/bin/luac51'),'-l','-p',str(path)],text=True)
    globals=[s for s in listing.splitlines() if 'SETGLOBAL' in s]
    assert len(globals)==(1 if path.name=='init.lua' else 0),(path,globals)
    for i,pattern in enumerate(patterns,1):
        for no,line in enumerate(path.read_text().splitlines(),1):
            code=line.split('--',1)[0]
            if i==4 and 'params = "[<player>] [throng|accord]"' in code: continue
            assert not re.search(pattern,code),(path,no,i,line)
print('r14-pregen static: parser, SETGLOBAL and all five source sweeps PASS')
