#!/usr/bin/env python3
"""Registration smoke gate in an isolated snapshot; no generation requests."""
import hashlib, json, pathlib, shutil, subprocess, tempfile
repo = pathlib.Path(__file__).resolve().parents[2]
root = pathlib.Path(tempfile.mkdtemp(prefix='grug-r18-integration-', dir='/tmp'))
game = root/'user/games/grudgelands'
game.mkdir(parents=True)
for name in ('game.conf', 'mods', 'minetest.conf', 'settingtypes.txt'):
    source = repo/name
    if source.is_dir(): shutil.copytree(source, game/name)
    else: shutil.copyfile(source, game/name)
manifest = {str(p.relative_to(game)): hashlib.sha256(p.read_bytes()).hexdigest()
            for p in sorted(game.rglob('*')) if p.is_file()}
(root/'production-snapshot.json').write_text(json.dumps(manifest, sort_keys=True, indent=2))
# Scratch-only scheduling stop; keep initialization/APIs and all mapgen semantics.
path = game/'mods/CORE/grug_core/starts_preload.lua'
text = path.read_text()
needle = 'local pending, stopped, failed = false, false, false'
assert text.count(needle) == 1
path.write_text(text.replace(needle, 'local pending, stopped, failed = false, true, false'))
probe = game/'mods/r18_integration_probe'
probe.mkdir()
(probe/'mod.conf').write_text('name = r18_integration_probe\ndepends = grug_quests, grug_mobs, grug_mapgen, grug_map, grug_gear, grug_food, grug_home, grug_parties\n')
shutil.copyfile(repo/'tools/r18_final/probe.lua', probe/'init.lua')
(root/'executed-snapshot.json').write_text(json.dumps({str(p.relative_to(game)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(game.rglob('*')) if p.is_file()}, sort_keys=True, indent=2))
world = root/'world'; world.mkdir()
(world/'world.mt').write_text('gameid = grudgelands\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n')
config = root/'server.conf'
config.write_text((game/'minetest.conf').read_text()+'\nport = 33018\nbind_address = 127.0.0.1\nserver_announce = false\nfixed_map_seed = 8675309\nnum_emerge_threads = 1\n')
log = root/'server.log'
cmd = ['flatpak', 'run', '--command=luanti', f'--filesystem={root}', f'--env=LUANTI_USER_PATH={root}/user', f'--env=XDG_CACHE_HOME={root}/cache', f'--env=XDG_DATA_HOME={root}/data', f'--env=XDG_CONFIG_HOME={root}/config', 'org.luanti.luanti', '--server', '--gameid', 'grudgelands', '--world', str(world), '--config', str(config), '--logfile', str(log), '--color', 'never']
print(root, flush=True)
result = subprocess.run(['timeout', '--kill-after=5', '60']+cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
(root/'console.log').write_text(result.stdout)
text = log.read_text() if log.exists() else result.stdout
print('\n'.join(line for line in text.splitlines() if 'r18_integration' in line or 'ERROR' in line), flush=True)
assert result.returncode == 0 and 'ERROR[' not in text, str(log)
assert '[r18_integration] PASS homes=' in text, str(log)
print('PASS', root)
