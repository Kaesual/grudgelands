#!/usr/bin/env python3
"""Export plans without an engine. At most two idle LuaJIT workers."""
import argparse
import concurrent.futures
import pathlib
import json
import subprocess

ROOT = pathlib.Path(__file__).resolve().parents[2]
HERE = pathlib.Path(__file__).resolve().parent
SEEDS = ('12345', '3684797457838814663', '17713522922938657774')


def export(job):
    mode, filename, *args = job
    target = HERE / 'data' / filename
    if target.exists():
        print(f'Reusing {target.name}; delete this file explicitly to re-export.', flush=True)
        return
    temporary = target.with_suffix('.pending')
    cmd = ['chrt', '--idle', '0', 'ionice', '-c3', 'luajit',
           'tools/r70_design/export.lua', mode, str(temporary), *args]
    with target.with_suffix('.log').open('w') as log:
        subprocess.run(cmd, cwd=ROOT, stderr=log, check=True)
    json.loads(temporary.read_text())
    temporary.replace(target)
    print(f'Exported {filename}', flush=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--blueprints-only', action='store_true')
    parser.add_argument('--lakes', action='store_true', help='Paired radius-56 lake sensitivity runs')
    args = parser.parse_args()
    (HERE / 'data').mkdir(exist_ok=True)
    if args.lakes:
        export(('lakes', 'lakes.json'))
        jobs = [('planner', f'{seed}-{variant}.json', seed, variant)
                for seed in SEEDS for variant in ('lake0', 'lake_shift')]
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            for _ in pool.map(export, jobs):
                pass
        return
    export(('blueprints', 'blueprints.json'))
    export(('geometry', 'geometry.json'))
    export(('bindings', 'bindings.json'))
    if not args.blueprints_only:
        fleet = set((ROOT / 'tools/seed_fleet/seeds.txt').read_text().splitlines())
        assert set(SEEDS) <= fleet
        jobs = [('planner', f'{seed}-{variant}.json', seed, variant)
                for seed in SEEDS for variant in ('today', 'proposed')]
        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            for _ in pool.map(export, jobs):
                pass


if __name__ == '__main__':
    main()
