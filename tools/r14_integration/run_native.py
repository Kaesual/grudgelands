#!/usr/bin/env python3
"""Three bounded POI chunks in an immutable isolated game snapshot."""
import hashlib, json, pathlib, shutil, subprocess, tempfile
repo = pathlib.Path(__file__).resolve().parents[2]
root = pathlib.Path(tempfile.mkdtemp(prefix='grug-r14-integration-', dir='/tmp'))
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
# Observability only: demonstrate the real production consumers were entered.
for filename, needle, marker in (
    ('r7_manifest.lua', 'function module.new(inputs)', 'manifest.new'),
    ('planner.lua', 'local function planner_plan_slice(self, minp, maxp)', 'planner.plan_slice')):
    path = game/'mods/MAPGEN/grug_mapgen/wp40'/filename
    text = path.read_text()
    assert text.count(needle) == 1
    path.write_text(text.replace(needle, needle+'\n core.log("action", "[r14_integration] consumer '+marker+'")'))
probe = game/'mods/r14_integration_probe'
probe.mkdir()
(probe/'mod.conf').write_text('name = r14_integration_probe\ndepends = grug_quests, grug_mobs, grug_mapgen\n')
shutil.copyfile(repo/'tools/r14_integration/probe.lua', probe/'init.lua')
(root/'executed-snapshot.json').write_text(json.dumps({str(p.relative_to(game)): hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(game.rglob('*')) if p.is_file()}, sort_keys=True, indent=2))
world = root/'world'; world.mkdir()
(world/'world.mt').write_text('gameid = grudgelands\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n')
config = root/'server.conf'
config.write_text((game/'minetest.conf').read_text()+'\nport = 32987\nbind_address = 127.0.0.1\nserver_announce = false\nfixed_map_seed = 8675309\nnum_emerge_threads = 1\n')
log = root/'server.log'
cmd = ['flatpak', 'run', '--command=luanti', f'--filesystem={root}', f'--env=LUANTI_USER_PATH={root}/user', f'--env=XDG_CACHE_HOME={root}/cache', f'--env=XDG_DATA_HOME={root}/data', f'--env=XDG_CONFIG_HOME={root}/config', 'org.luanti.luanti', '--server', '--gameid', 'grudgelands', '--world', str(world), '--config', str(config), '--logfile', str(log), '--color', 'never']
print(root, flush=True)
result = subprocess.run(['timeout', '--kill-after=5', '150']+cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
(root/'console.log').write_text(result.stdout)
text = log.read_text() if log.exists() else result.stdout
print('\n'.join(line for line in text.splitlines() if 'r14_integration' in line or 'ERROR' in line), flush=True)
assert result.returncode == 0 and 'ERROR[' not in text, str(log)
assert '[r14_integration] PASS three_chunks=3 catalog=66/24' in text, str(log)
assert 'consumer manifest.new' in text and 'consumer planner.plan_slice' in text
print('PASS', root)
