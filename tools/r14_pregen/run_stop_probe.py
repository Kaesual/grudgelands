#!/usr/bin/env python3
"""Bounded isolated three-boot native shutdown proof; no personal world access."""
import pathlib, tempfile, subprocess, shutil
repo = pathlib.Path(__file__).resolve().parents[2]
root = pathlib.Path(tempfile.mkdtemp(prefix='grug-pregen-stop-', dir='/tmp'))
game = root/'user/games/probe'
mod = game/'mods/stop_probe'
mod.mkdir(parents=True)
(root/'world').mkdir()
(game/'game.conf').write_text('title = Stop probe\n')
(mod/'mod.conf').write_text('name = stop_probe\n')
shutil.copyfile(repo/'tools/r14_pregen/stop_probe.lua',mod/'init.lua')
(root/'world/world.mt').write_text('gameid = probe\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n')
(root/'server.conf').write_text('port = 32989\nbind_address = 127.0.0.1\nserver_announce = false\nmg_name = singlenode\nchunksize = 5\nnum_emerge_threads = 1\n')
for boot in range(1,4):
    log = root/f'boot{boot}.log'
    cmd=['flatpak','run','--command=luanti',f'--filesystem={root}',f'--env=LUANTI_USER_PATH={root}/user',f'--env=XDG_CACHE_HOME={root}/cache',f'--env=XDG_DATA_HOME={root}/data',f'--env=XDG_CONFIG_HOME={root}/config','org.luanti.luanti','--server','--gameid','probe','--world',str(root/'world'),'--config',str(root/'server.conf'),'--logfile',str(log),'--color','never']
    result=subprocess.run(cmd,stdout=subprocess.PIPE,stderr=subprocess.STDOUT,text=True,timeout=30)
    (root/f'boot{boot}.console').write_text(result.stdout)
    print(result.returncode, log, flush=True)
    if result.returncode: print(result.stdout); break
print(root)
