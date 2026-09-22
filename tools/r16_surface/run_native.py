#!/usr/bin/env python3
"""Two bounded native boots, no timing estimate or full generation run."""
import pathlib, tempfile, subprocess, shutil, hashlib, json, re
repo=pathlib.Path(__file__).resolve().parents[2]
root=pathlib.Path(tempfile.mkdtemp(prefix='grug-r16-surface-native-',dir='/tmp'))
game=root/'user/games/grudgelands';game.mkdir(parents=True)
for name in ('game.conf','mods','minetest.conf','settingtypes.txt'):
 source=repo/name
 if source.is_dir():shutil.copytree(source,game/name)
 else:shutil.copyfile(source,game/name)
probe=game/'mods/r16_surface_probe';probe.mkdir()
(probe/'mod.conf').write_text('name = r16_surface_probe\ndepends = grug_core, grug_mapgen\n')
shutil.copyfile(repo/'tools/r16_surface/native_probe.lua',probe/'init.lua')
manifest={str(p.relative_to(game)):hashlib.sha256(p.read_bytes()).hexdigest() for p in game.rglob('*') if p.is_file()}
(root/'snapshot.json').write_text(json.dumps(manifest,sort_keys=True,indent=2))
world=root/'world';world.mkdir()
(world/'world.mt').write_text('gameid = grudgelands\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n')
print(root,flush=True)
previous_completed=None
for boot in (1,2):
 config=root/f'boot{boot}.conf'
 config.write_text((game/'minetest.conf').read_text()+f'\nport = 32987\nbind_address = 127.0.0.1\nserver_announce = false\nfixed_map_seed = 8675309\ngrug_prepare_full_world = {str(boot==1).lower()}\n')
 log=root/f'boot{boot}.log'
 cmd=['flatpak','run','--command=luanti',f'--filesystem={root}',f'--env=LUANTI_USER_PATH={root}/user',f'--env=XDG_CACHE_HOME={root}/cache',f'--env=XDG_DATA_HOME={root}/data',f'--env=XDG_CONFIG_HOME={root}/config','org.luanti.luanti','--server','--gameid','grudgelands','--world',str(world),'--config',str(config),'--logfile',str(log),'--color','never']
 result=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=70)
 (root/f'boot{boot}.console').write_text(result.stdout)
 print('boot',boot,'exit',result.returncode,flush=True)
 if result.returncode: print(result.stdout[-4000:]);raise SystemExit(1)
 text=log.read_text()
 assert 'ERROR[' not in text,text[-4000:]
 assert text.count('[r16_surface] column=')==5
 assert '[r16_surface] dispatch=2 ' in text and '[r16_surface] dispatch=3 ' not in text
 assert '[r16_surface] shutdown requests=2' in text
 if boot==2:
  assert "preparation config ignored" in text
  assert f'world preparation mode=full cursor={previous_completed}/8811' in text
 previous_completed=int(re.findall(r'\[r16_surface\] settled status=.*?completed=(\d+)',text)[-1])
 assert previous_completed>=boot
print('native real authority and bounded shutdown PASS',flush=True)
