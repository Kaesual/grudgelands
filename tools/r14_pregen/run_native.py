#!/usr/bin/env python3
"""Immutable isolated production snapshot; three tiny stop/resume boots per mode."""
import pathlib, tempfile, subprocess, shutil, hashlib, json, sys
sample = "--sample-only" in sys.argv
repo = pathlib.Path(__file__).resolve().parents[2]
root = pathlib.Path(tempfile.mkdtemp(prefix='grug-pregen-native-', dir='/tmp'))
game = root/'user/games/grudgelands'
game.mkdir(parents=True)
for name in ('game.conf','mods','minetest.conf','settingtypes.txt'):
    source=repo/name
    if source.is_dir(): shutil.copytree(source,game/name)
    else: shutil.copyfile(source,game/name)
# Test-only geometry shrink inside the snapshot; production constants untouched.
planfile=game/'mods/CORE/grug_core/preparation_plan.lua'
s=planfile.read_text().replace('local b = bounds or M.bounds','local b = bounds or {x_min=-32,x_max=127,y_min=-32,y_max=47,z_min=-2592,z_max=-2513}')
if sample: s=s.replace('x_max=127','x_max=207')
planfile.write_text(s)
probe=game/'mods/r14_probe';probe.mkdir()
(probe/'mod.conf').write_text('name = r14_probe\ndepends = grug_core, grug_mapgen\n')
(probe/'init.lua').write_text('''
local count = 0
local start = core.get_us_time()
local emerge = core.emerge_area
core.emerge_area = function(a,b,fn)
 count = count+1
 local begun = core.get_us_time()
 core.log("action","[r14_probe] dispatch="..count.." lo="..core.pos_to_string(a))
 emerge(a,b,function(p,action,left)
  fn(p,action,left)
  if left==0 then core.log("action","[r14_probe] settled_us="..(core.get_us_time()-begun).." status="..core.serialize(grug_core.world_preparation_status())) end
 end)
 -- Each boot allows a tiny prefix, then requests a normal shutdown during
 -- the next request; no full-world or six-start population is run.
 if count==2 then core.after(0.01,function()
  core.log("action","[r14_probe] stop_us="..core.get_us_time())
  core.request_shutdown("bounded production preparation probe",false,0)
 end) end
end
core.register_on_preparation_progress(function() end)
core.register_on_shutdown(function()
 core.log("action","[r14_probe] shutdown_us="..core.get_us_time().." count="..count.." status="..core.serialize(grug_core.world_preparation_status()))
end)
core.after(20,function() core.request_shutdown("bounded fixture time limit",false,0) end)
'''.replace('core.register_on_preparation_progress','grug_core.register_on_preparation_progress'))
if sample:
    probe_file=probe/'init.lua'
    probe_file.write_text(probe_file.read_text().replace('count==2','count==4'))
manifest={str(p.relative_to(game)):hashlib.sha256(p.read_bytes()).hexdigest() for p in game.rglob('*') if p.is_file()}
(root/'snapshot.json').write_text(json.dumps(manifest,sort_keys=True,indent=2))
for mode in (('full',) if sample else ('starts','full')):
    world=root/mode;world.mkdir()
    (world/'world.mt').write_text('gameid = grudgelands\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n')
    for boot in range(1,2 if sample else 4):
        full=(mode=='full') if boot==1 else (mode!='full')
        config=root/f'{mode}{boot}.conf'
        config.write_text((game/'minetest.conf').read_text()+f'\nport = 32989\nbind_address = 127.0.0.1\nserver_announce = false\nfixed_map_seed = 8675309\ngrug_prepare_full_world = {str(full).lower()}\n')
        log=root/f'{mode}{boot}.log'
        cmd=['flatpak','run','--command=luanti',f'--filesystem={root}',f'--env=LUANTI_USER_PATH={root}/user',f'--env=XDG_CACHE_HOME={root}/cache',f'--env=XDG_DATA_HOME={root}/data',f'--env=XDG_CONFIG_HOME={root}/config','org.luanti.luanti','--server','--gameid','grudgelands','--world',str(world),'--config',str(config),'--logfile',str(log),'--color','never']
        result=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=50)
        (root/f'{mode}{boot}.console').write_text(result.stdout)
        print(result.returncode,log,flush=True)
        if result.returncode: print(result.stdout[-3000:]);raise SystemExit(1)
        text=log.read_text()
        assert 'ERROR[' not in text, str(log)
        if sample:
            assert 'completed=3' in text and 'ready=true' in text, str(log)
        else:
            cursor=boot-1 if mode=='starts' else min(boot-1,2)
            total=90 if mode=='starts' else 2
            assert f'mode={mode} cursor={cursor}/{total}' in text, str(log)
            if boot>1: assert 'preparation config ignored' in text, str(log)
            if mode=='full' and boot==3: assert '[r14_probe] dispatch=' not in text, str(log)
print(root)
