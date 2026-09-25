#!/usr/bin/env python3
"""Explicit single fresh prefix comparison; no personal engine paths are used."""
import argparse
import datetime
import hashlib
import json
import os
import pathlib
import shutil
import signal
import subprocess
import sys
import tempfile
import time

from instrument import instrument

REPO = pathlib.Path(__file__).resolve().parents[2]


def dump(path, value):
    path.write_text(json.dumps(value, sort_keys=True, indent=2) + '\n')


def read_stat(path):
    text = path.read_text()
    fields = text[text.rindex(')') + 2:].split()
    return dict(name=text[text.index('(') + 1:text.rindex(')')], state=fields[0],
                ticks=int(fields[11]) + int(fields[12]), starttime=fields[19],
                rss=int(fields[21]) * os.sysconf('SC_PAGE_SIZE'),
                blkio_ticks=int(fields[39]))


def matches(world):
    found = []
    for item in pathlib.Path('/proc').glob('[0-9]*/cmdline'):
        try:
            args = item.read_bytes().split(b'\0')
            if b'--server' not in args or b'--world' not in args:
                continue
            if args[args.index(b'--world') + 1] != os.fsencode(world):
                continue
            executable = pathlib.Path(os.readlink(item.parent / 'exe'))
            if executable.name != 'luanti.bin':
                continue
            found.append(int(item.parent.name))
        except (OSError, IndexError):
            pass
    return found


def alive(pid, starttime):
    try:
        return read_stat(pathlib.Path(f'/proc/{pid}/stat'))['starttime'] == starttime
    except OSError:
        return False


def diagnostic_events(log):
    return [json.loads(line.split('[pregen_diag] ',1)[1]) for line in log.read_text().splitlines() if '[pregen_diag] ' in line]


def stop_resume(root, production_hash):
    """Two separately authorized boots, using the completed prefix's world only."""
    root=root.resolve()
    assert root.name.startswith('grug-preparation-fullspeed-') and root.parent==pathlib.Path('/tmp')
    initial=json.loads((root/'result.json').read_text())
    assert initial['exit']==0 and initial['reason']=='normal-prefix-shutdown' and not initial['survivors']
    initial_events=diagnostic_events(root/'engine.log')
    assert initial_events[-1]['kind']=='shutdown' and initial_events[-1]['data']['status']['completed']==561
    world=pathlib.Path(initial['world'])
    assert world.parent.parent==REPO/'tools/wp40/results'
    assert not matches(world)
    production_path=REPO/'mods/CORE/grug_core/starts_preload.lua'
    production=production_path.read_text()
    assert hashlib.sha256(production_path.read_bytes()).hexdigest()==production_hash
    receipt=[]
    cursor=561
    previous_selection=None
    parent=root/'stop-resume'
    parent.mkdir()  # Refuse accidental repetition of this two-boot case.
    for label,mode in [('A','stop_pending'),('B','resume')]:
        stage=parent/label
        game=stage/'user/games/grudgelands'
        shutil.copytree(root/'user/games/grudgelands',game)
        target=game/'mods/CORE/grug_core/starts_preload.lua'
        target.write_text(instrument(production,mode=mode,limit=cursor+2))
        subprocess.run([str(REPO/'tools/bin/luac51'),'-p',str(target)],check=True)
        listing=subprocess.check_output([str(REPO/'tools/bin/luac51'),'-l','-p',str(target)],text=True)
        assert 'SETGLOBAL' not in listing
        # Same observer source, only mode/limit literals differ from the statically
        # checked prefix variant. No production bytes or world plan are rewritten.
        dump(stage/'inputs.json',dict(production_sha256=production_hash,
            instrumented_sha256=hashlib.sha256(target.read_bytes()).hexdigest(),
            mode=mode,limit=cursor+2,expected_boot_cursor=cursor))
        (stage/'instrumented.lua').write_bytes(target.read_bytes())
        (stage/'run.conf').write_bytes((root/'run.conf').read_bytes())
        command=json.loads((root/'command.json').read_text())
        command=[arg.replace(str(root),str(stage)) if str(root) in arg else arg for arg in command]
        # The disk world path belongs to a separate root and remains unchanged.
        dump(stage/'command.json',command)
        started=time.monotonic();pid=None;birth=None;forced=False
        proc=subprocess.Popen(command,stdout=(stage/'console.log').open('w'),stderr=subprocess.STDOUT,start_new_session=True)
        try:
            while proc.poll() is None:
                if pid is None:
                    candidates=matches(world);assert len(candidates)<=1
                    if candidates:
                        pid=candidates[0];birth=read_stat(pathlib.Path(f'/proc/{pid}/stat'))['starttime']
                        dump(stage/'engine-identity.json',dict(pid=pid,starttime=birth,
                            engine_sha256=hashlib.sha256(pathlib.Path(f'/proc/{pid}/exe').read_bytes()).hexdigest()))
                if time.monotonic()-started>=60:
                    forced=True
                    break
                time.sleep(.05)
        finally:
            if pid and alive(pid,birth):os.kill(pid,signal.SIGINT)
            try:proc.wait(timeout=15)
            except subprocess.TimeoutExpired:
                if pid and alive(pid,birth):os.kill(pid,signal.SIGTERM)
                try:proc.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    if pid and alive(pid,birth):os.kill(pid,signal.SIGKILL)
                    os.killpg(proc.pid,signal.SIGKILL);proc.wait(timeout=5)
            survivors=matches(world)
            result=dict(exit=proc.returncode,elapsed=time.monotonic()-started,pid=pid,
                starttime=birth,forced=forced,survivors=survivors)
            dump(stage/'result.json',result)
        assert proc.returncode==0 and not forced and not survivors,result
        log=stage/'engine.log'
        assert 'ERROR[' not in log.read_text()
        es=diagnostic_events(log)
        boot=next(e for e in es if e['kind']=='boot')['data']
        assert boot['status']['completed']==cursor
        requests=[e for e in es if e['kind']=='dispatch']
        completions=[e for e in es if e['kind']=='complete']
        stops=[e for e in es if e['kind']=='stop_request'];assert len(stops)==1
        stop=stops[0]
        shutdowns=[e for e in es if e['kind']=='shutdown'];assert len(shutdowns)==1
        shutdown=shutdowns[0]['data']
        assert len(requests)==len(completions)==2
        assert max(e['data']['inflight'] for e in requests)==2
        assert not any(e['kind']=='dispatch' and e['us']>stop['us'] for e in es)
        settled=max([cursor]+[e['data']['cursor'] for e in completions])
        assert shutdown['status']['completed']==settled and shutdown['inflight']==0
        assert shutdown['queue_depth']<=2
        queue_rows=shutdown.get('queue_rows')
        if queue_rows is None:
            assert shutdown['queue_depth']==0
            queue_rows=[]
        assert len(queue_rows)==shutdown['queue_depth']
        assert all(row['status']!='pending' for row in queue_rows)
        if label=='B' and previous_selection is not None:
            assert requests[0]['data']['selection']==previous_selection
        if label=='A':
            assert stop['data']['inflight']==2 and stop['data']['queue_depth']==2
            assert cursor<=settled<=cursor+2
        else:
            assert stop['data']['inflight']==0 and stop['data']['queue_depth']==0
            assert settled==cursor+2 and shutdown['queue_depth']==0
        receipt.append(dict(boot=label,start_cursor=cursor,settled_cursor=settled,
            stop=stop['data'],shutdown=shutdown,result=result,
            terminal_requests=[e['data'] for e in completions]))
        cursor=settled
        previous_selection=shutdown.get('selection')
    dump(parent/'summary.json',receipt)
    print(json.dumps(receipt,indent=2),flush=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--execute',action='store_true',required=True)
    parser.add_argument('--production-sha256',required=True,help='frozen source hash approved in preflight')
    parser.add_argument('--stop-resume-root',type=pathlib.Path,help='completed prefix run root; separately authorized two-boot follow-up only')
    args=parser.parse_args()
    if args.stop_resume_root is not None:
        return stop_resume(args.stop_resume_root,args.production_sha256)
    root = pathlib.Path(tempfile.mkdtemp(prefix='grug-preparation-fullspeed-', dir='/tmp'))
    (REPO / 'tools/wp40/results').mkdir(exist_ok=True)
    world_root = pathlib.Path(tempfile.mkdtemp(prefix='preparation-fullspeed-', dir=REPO / 'tools/wp40/results'))
    world = world_root / 'world'
    world.mkdir()
    game = root / 'user/games/grudgelands'
    game.mkdir(parents=True)
    for name in ('game.conf', 'mods', 'minetest.conf', 'settingtypes.txt'):
        source = REPO / name
        if source.is_dir():
            shutil.copytree(source, game / name)
        else:
            shutil.copyfile(source, game / name)
    target = game / 'mods/CORE/grug_core/starts_preload.lua'
    production = target.read_text()
    assert hashlib.sha256(target.read_bytes()).hexdigest()==args.production_sha256, 'production differs from approved frozen input'
    target.write_text(instrument(production))
    assert 'diag_prefix_limit = 561' in target.read_text()
    subprocess.run([str(REPO / 'tools/bin/luac51'), '-p', str(target)], check=True)
    listing = subprocess.check_output([str(REPO / 'tools/bin/luac51'), '-l', '-p', str(target)], text=True)
    assert 'SETGLOBAL' not in listing
    patterns = [r'(^|[^[:alnum:]_.:])goto[[:space:](]|::[A-Za-z_]+::',
                r'\\u\{|\\x[0-9A-Fa-f]|\\z',
                r'table\.(unpack|pack|move)|rawlen|coroutine\.isyieldable|math\.(type|tointeger)|utf8\.',
                r'[^:/]//|[[:alnum:]_)\"] *(&|\||<<|>>) *[[:alnum:]_(\"]',
                r'\brequire[[:space:]]*\(|io\.popen|os\.(execute|exit)|\bminetest\.']
    for pattern in patterns:
        result = subprocess.run(['rg', '-n', pattern, str(target)], capture_output=True, text=True)
        assert result.returncode == 1, (pattern, result.stdout, result.stderr)
    (root / 'snapshot-static.txt').write_text('luac51 parse PASS; SETGLOBAL none; five explicit source sweeps zero hits\n')
    (root / 'instrumentation.diff').write_text(subprocess.run(
        ['diff', '-u', str(REPO / 'mods/CORE/grug_core/starts_preload.lua'), str(target)],
        capture_output=True, text=True).stdout)
    dump(root / 'snapshot.json', {str(p.relative_to(game)): hashlib.sha256(p.read_bytes()).hexdigest()
                                for p in game.rglob('*') if p.is_file()})
    dump(root / 'inputs.json', {str(p.relative_to(REPO)): hashlib.sha256(p.read_bytes()).hexdigest()
                               for p in [REPO / 'mods/CORE/grug_core/starts_preload.lua',
                                         REPO / 'mods/CORE/grug_core/preparation_plan.lua',
                                         pathlib.Path(__file__), pathlib.Path(__file__).with_name('instrument.py')]})
    (root / 'system.txt').write_text(subprocess.check_output(['uname', '-a'], text=True) +
        subprocess.check_output(['lscpu'], text=True) +
        subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=REPO, text=True) +
        subprocess.check_output(['df', '-T', str(root), str(world)], text=True))
    (world / 'world.mt').write_text('gameid = grudgelands\nbackend = sqlite3\nplayer_backend = sqlite3\nauth_backend = sqlite3\nmod_storage_backend = sqlite3\n')
    (root / 'run.conf').write_text((game / 'minetest.conf').read_text() +
        '\nport = 32991\nbind_address = 127.0.0.1\nserver_announce = false\nfixed_map_seed = 8675309\ngrug_prepare_full_world = true\n')
    command = ['flatpak', 'run', '--command=luanti', f'--filesystem={root}',
        f'--filesystem={world_root}', f'--env=LUANTI_USER_PATH={root}/user',
        f'--env=XDG_CACHE_HOME={root}/cache', f'--env=XDG_DATA_HOME={root}/data',
        f'--env=XDG_CONFIG_HOME={root}/config', 'org.luanti.luanti', '--server',
        '--gameid', 'grudgelands', '--world', str(world), '--config', str(root / 'run.conf'),
        '--logfile', str(root / 'engine.log'), '--color', 'never']
    dump(root / 'command.json', command)
    print(root, flush=True)
    started = time.monotonic()
    started_utc = datetime.datetime.now(datetime.timezone.utc).isoformat()
    proc = subprocess.Popen(command, stdout=(root / 'console.log').open('w'), stderr=subprocess.STDOUT, start_new_session=True)
    pid = None
    process_start = None
    previous = {}
    hz = os.sysconf('SC_CLK_TCK')
    next_sample = started
    samples = []
    stop_reason = 'normal-prefix-shutdown'
    engine_exit_elapsed = None
    try:
        with (root / 'engine-os.jsonl').open('w') as output, (root / 'engine-minutes.jsonl').open('w') as minutes:
            while proc.poll() is None:
                now = time.monotonic()
                if now - started >= 420:
                    stop_reason = 'seven-minute-safety-cap'
                    break
                if pid is None:
                    candidates = matches(world)
                    assert len(candidates) <= 1, candidates
                    if not candidates:
                        time.sleep(0.02)
                        continue
                    pid = candidates[0]
                    process_start = read_stat(pathlib.Path(f'/proc/{pid}/stat'))['starttime']
                    executable = pathlib.Path(f'/proc/{pid}/exe')
                    dump(root / 'engine-identity.json', dict(pid=pid, starttime=process_start,
                        exe=os.readlink(executable), affinity=sorted(os.sched_getaffinity(pid)),
                        engine_sha256=hashlib.sha256(executable.read_bytes()).hexdigest(),
                        started_utc=started_utc, first_seen_elapsed=now-started,clock_ticks_per_second=hz))
                if not alive(pid, process_start):
                    engine_exit_elapsed = now - started
                    break
                if now < next_sample:
                    time.sleep(min(0.05, next_sample - now))
                    continue
                ps = read_stat(pathlib.Path(f'/proc/{pid}/stat'))
                row = dict(utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),
                           elapsed=now-started, monotonic_raw_us=int(time.clock_gettime(time.CLOCK_MONOTONIC_RAW)*1e6), pid=pid, cpus=os.cpu_count(), process=ps)
                def cpu(key, value):
                    old = previous.get(key)
                    previous[key] = (value['ticks'], now)
                    if old:
                        return (value['ticks']-old[0])/hz/(now-old[1])*100
                pcpu = cpu('process', ps)
                if pcpu is not None:
                    row['cpu_one_core_pct'] = pcpu
                    row['cpu_machine_pct'] = pcpu/os.cpu_count()
                threads = []
                for task in pathlib.Path(f'/proc/{pid}/task').iterdir():
                    try:
                        data = read_stat(task / 'stat')
                        data['tid'] = int(task.name)
                        data['cpu_one_core_pct'] = cpu(data['tid'], data)
                        data['wchan'] = (task / 'wchan').read_text().strip()
                        threads.append(data)
                    except OSError:
                        pass
                row['threads'] = threads
                row['io'] = {k:int(v) for k,v in (line.split(':') for line in pathlib.Path(f'/proc/{pid}/io').read_text().splitlines())}
                row['system_cpu'] = pathlib.Path('/proc/stat').read_text().splitlines()[0]
                row['meminfo'] = {k:v.strip() for k,v in (line.split(':',1) for line in pathlib.Path('/proc/meminfo').read_text().splitlines()) if k in ('MemAvailable','SwapFree')}
                output.write(json.dumps(row)+'\n');output.flush();samples.append(row)
                if len(samples) == 12:
                    values = [x['cpu_one_core_pct'] for x in samples if 'cpu_one_core_pct' in x]
                    summary = dict(elapsed=row['elapsed'], cpu_mean=sum(values)/len(values),
                                   cpu_min=min(values), cpu_max=max(values), rss=ps['rss'], pid=pid)
                    minutes.write(json.dumps(summary)+'\n');minutes.flush();print(json.dumps(summary),flush=True);samples=[]
                if ps['rss'] > 12*1024**3 or shutil.disk_usage(world).free < 5*1024**3:
                    stop_reason = 'resource-safety-cap'
                    break
                next_sample += 5
    finally:
        if pid and alive(pid, process_start):
            os.kill(pid, signal.SIGINT)
        try:
            proc.wait(timeout=45)
        except subprocess.TimeoutExpired:
            if pid and alive(pid, process_start):
                os.kill(pid, signal.SIGTERM)
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                if pid and alive(pid, process_start):
                    os.kill(pid, signal.SIGKILL)
                os.killpg(proc.pid, signal.SIGKILL)
                proc.wait(timeout=5)
        survivors = matches(world)
        dump(root / 'result.json', dict(exit=proc.returncode, elapsed=time.monotonic()-started,
            engine_exit_elapsed=engine_exit_elapsed, started_utc=started_utc, pid=pid,
            starttime=process_start, reason=stop_reason, survivors=survivors, world=str(world)))
        assert not survivors, survivors
    assert proc.returncode == 0, (root/'console.log').read_text()[-2000:]
    text = (root/'engine.log').read_text()
    assert 'ERROR[' not in text
    events = [json.loads(line.split('[pregen_diag] ',1)[1]) for line in text.splitlines() if '[pregen_diag] ' in line]
    completions = [e for e in events if e['kind']=='complete']
    assert len(completions) == 561
    assert sorted(e['data']['id'] for e in completions)==list(range(1,562))
    shutdown=[e for e in events if e['kind']=='shutdown']
    assert len(shutdown)==1 and shutdown[0]['data']['status']['completed']==561
    assert shutdown[0]['data']['inflight']==0
    assert len([e for e in events if e['kind']=='dispatch']) == 561
    assert max(e['data']['inflight'] for e in events if e['kind']=='dispatch')<=2
    print('matched 561-tile prefix, bounded inflight and normal shutdown PASS',flush=True)


if __name__ == '__main__':
    main()
