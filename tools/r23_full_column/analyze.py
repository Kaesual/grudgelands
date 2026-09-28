#!/usr/bin/env python3
"""Offline summary of one run_region.sh output directory; starts no engine.

Chunk classes (from the engine heightmap of each generated owner chunk):
  air-fast   the fast path applies (air_chunks.lua)
  air-full   native air in the owner, but the writer may place something
             (near the surface envelope, or our terrain above v7's)
  surface    some columns have native ground in the owner
  underground every column's native top is at or above the owner top
engine_ms is the time between the previous on_generated exit and this entry
(finishGen of the previous chunk, main-environment callbacks, makeChunk);
lua_ms is the fast-path decision plus the full writer when it ran.
"""
import os
import re
import statistics
import sys

WORLD_TILES = 8811  # preparation_plan.lua bounds at chunksize 5

GEN = re.compile(r'\[r23c\] gen (-?\d+),(-?\d+),(-?\d+) fast=(\d) gap_us=(-?\d+) '
                 r'decide_us=(\d+) full_us=(\d+) result=(\S+) hm_ground=(\d+) '
                 r'hm_top=(-?\d+) hm_bottom=(-?\d+) dd=(-?\d+) dp=(-?\d+) dl=(-?\d+) vol=(\d+)')
TILE = re.compile(r'\[r23p\] tile (\d+)/(\d+) x=(-?\d+) z=(-?\d+) y_min=(-?\d+) '
                  r'y_max=(-?\d+) us=(\d+)')


def classify(row):
    y, fast, ground, bottom = row['y'], row['fast'], row['ground'], row['bottom']
    if fast:
        return 'air-fast'
    if ground == 0:
        return 'air-full'
    if ground == 6400 and bottom >= y + 79:
        return 'underground'
    return 'surface'


def main(out):
    logs = sorted(f for f in os.listdir(out) if f.startswith('server') and f.endswith('.log')
                  and 'console' not in f)
    chunks, tiles, geo, stops = [], [], [], []
    for name in logs:
        with open(os.path.join(out, name), errors='replace') as handle:
            for line in handle:
                m = GEN.search(line)
                if m:
                    v = m.groups()
                    chunks.append({'x': int(v[0]), 'y': int(v[1]), 'z': int(v[2]),
                                   'fast': v[3] == '1', 'gap': int(v[4]),
                                   'decide': int(v[5]), 'full': int(v[6]), 'result': v[7],
                                   'ground': int(v[8]), 'top': int(v[9]),
                                   'bottom': int(v[10]), 'dd': int(v[11]),
                                   'dp': int(v[12]), 'dl': int(v[13]), 'vol': int(v[14])})
                    continue
                m = TILE.search(line)
                if m:
                    v = [int(x) for x in m.groups()]
                    tiles.append({'cursor': v[0], 'total': v[1], 'x': v[2], 'z': v[3],
                                  'y_min': v[4], 'y_max': v[5], 'us': v[6]})
                    continue
                if '[r23g]' in line or '[r23s] stop' in line:
                    (geo if '[r23g]' in line else stops).append(line.split('ACTION[Server]: ')[-1].strip())
    print('chunks generated: %d, tiles committed: %d' % (len(chunks), len(tiles)))
    for line in stops:
        print(line)
    classes = {}
    for row in chunks:
        classes.setdefault(classify(row), []).append(row)
    print('\nclass         n   engine_ms(med)  decide_ms(mean)  full_ms(mean)  results')
    for name in ('air-fast', 'air-full', 'surface', 'underground'):
        rows = classes.get(name, [])
        if not rows:
            continue
        gaps = [r['gap'] / 1000 for r in rows if 0 <= r['gap'] < 5000000]
        full = [r['full'] / 1000 for r in rows if r['full'] > 0]
        results = {}
        for r in rows:
            results[r['result']] = results.get(r['result'], 0) + 1
        print('%-12s %4d  %10.1f  %14.2f  %13.1f  %s' % (
            name, len(rows), statistics.median(gaps) if gaps else float('nan'),
            statistics.mean(r['decide'] / 1000 for r in rows),
            statistics.mean(full) if full else 0.0,
            ' '.join('%s=%d' % kv for kv in sorted(results.items()))))
    verified = [r for r in chunks if r['fast'] and r['dd'] >= 0]
    if verified:
        bad = [r for r in verified if r['dd'] or r['dp'] or r['dl'] or
               r['result'] != 'noop_equal_content']
        print('\nfast-path equivalence: %d chunks compared over the whole VoxelManip '
              '(content, param2, light; %d nodes each), %d differ' %
              (len(verified), verified[0]['vol'], len(bad)))
        for r in bad[:20]:
            print('  DIFF', r)
    if tiles:
        span = (tiles[-1]['us'] - tiles[0]['us']) / 1e6
        per_tile = span / max(1, len(tiles) - 1)
        units = [(t['y_max'] - t['y_min']) // 80 + 1 for t in tiles]
        print('\ntiles %d..%d of %d; %.1f s between first and last commit; %.2f s/tile, '
              '%.1f chunks/s overall' % (
                  tiles[0]['cursor'], tiles[-1]['cursor'], tiles[0]['total'], span, per_tile,
                  len(chunks) / span if span > 0 else float('nan')))
        print('chunks per tile: mean %.2f min %d max %d; y_min range %d..%d, y_max range %d..%d' % (
            statistics.mean(units), min(units), max(units),
            min(t['y_min'] for t in tiles), max(t['y_min'] for t in tiles),
            min(t['y_max'] for t in tiles), max(t['y_max'] for t in tiles)))
        print('extrapolated full world (region mix, %d tiles): %.0f chunks, %.1f h' % (
            WORLD_TILES, WORLD_TILES * statistics.mean(units), WORLD_TILES * per_tile / 3600))
    samples_path = os.path.join(out, 'samples.tsv')
    if os.path.exists(samples_path):
        with open(samples_path) as handle:
            rows = [line.split('\t') for line in handle.read().splitlines()[1:]]
        rss = [int(r[1]) for r in rows if len(r) == 3 and r[1].isdigit()]
        if rss:
            print('\npeak RSS: %.2f GB' % (max(rss) / 1024 / 1024))
    db_path = os.path.join(out, 'final_db_bytes')
    if os.path.exists(db_path) and tiles:
        with open(db_path) as handle:
            db = int(handle.read().strip() or 0)
        committed = tiles[-1]['cursor']  # the world may hold earlier boots' tiles
        print('map DB: %.1f MB for %d committed tiles (incl. speculative and start chunks): '
              '%.2f MB/tile, extrapolated full world %.1f GB' % (
                  db / 1e6, committed, db / 1e6 / committed,
                  db / committed * WORLD_TILES / 1e9))
    for line in geo:
        print(line)


if __name__ == '__main__':
    main(sys.argv[1])
