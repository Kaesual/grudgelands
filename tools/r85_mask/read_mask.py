#!/usr/bin/env python3
"""Round 85 MASK: read a world's claim mask files without the game
(docs/technical/claim-mask-format.md): the snapshot grug_claim_mask.txt and,
when present, the scan cache grug_claim_ground.txt.

  python3 tools/r85_mask/read_mask.py <world dir>

Checks each file's trailer hash and prints the snapshot's header, its chunk
rows per faction and the cache's key and row count. Exit 1 when a file is
damaged.
"""
import hashlib
import os
import sys


def sealed_lines(path):
    """The file's lines without the trailer, or raise ValueError."""
    data = open(path, 'rb').read()
    head, sep, tail = data.rpartition(b'end ')
    if not sep or not tail.endswith(b'\n') or (head and not head.endswith(b'\n')):
        raise ValueError('trailer missing')
    if tail[:-1].decode() != hashlib.sha256(head).hexdigest():
        raise ValueError('file hash differs')
    return head.decode('ascii').split('\n')[:-1]


def read_snapshot(path):
    lines = sealed_lines(path)
    if lines[0] != 'grug_claim_mask_v1':
        raise ValueError('format differs: ' + lines[0])
    header, n = {}, 1
    while not lines[n].startswith('chunks '):
        name, value = lines[n].split('=', 1)
        header[name] = value
        n += 1
    count = int(lines[n].split()[1])
    rows = []
    for line in lines[n + 1:]:
        f, cx, cz, *digests = line.split(' ')
        rows.append((f, int(cx), int(cz), dict(zip(
            ('height', 'water', 'zone', 'roads', 'places'), digests))))
    if len(rows) != count:
        raise ValueError('chunk rows differ from their count')
    return header, rows


def read_cache(path):
    lines = sealed_lines(path)
    if lines[0] != 'grug_claim_ground_v1':
        raise ValueError('format differs: ' + lines[0])
    key = [line.split('=', 1) for line in lines[1:] if not line.startswith('s ')]
    scans = {}
    for line in lines[1 + len(key):]:
        _, cx, cz, f, code, cap = line.split(' ')
        scans[(int(cx), int(cz), f)] = (code, cap == '1')
    return dict(key), scans


def main():
    world = sys.argv[1]
    bad = 0
    try:
        header, rows = read_snapshot(os.path.join(world, 'grug_claim_mask.txt'))
        print('snapshot:', ', '.join('%s=%s' % kv for kv in header.items()))
        for f in ('accord', 'throng'):
            print('  %s: %d claim-ground chunks' % (f, sum(1 for r in rows if r[0] == f)))
    except (OSError, ValueError) as e:
        print('snapshot:', e)
        bad = 1
    path = os.path.join(world, 'grug_claim_ground.txt')
    if os.path.exists(path):
        try:
            key, scans = read_cache(path)
            ok = sum(1 for v in scans.values() if v[0] == 'ok')
            print('cache: %d scans (%d ok), seed %s' % (len(scans), ok, key.get('seed')))
        except ValueError as e:
            print('cache:', e)
            bad = 1
    return bad


if __name__ == '__main__':
    sys.exit(main())
