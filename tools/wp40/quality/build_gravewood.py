#!/usr/bin/env python3
"""Build original Grudgelands dead-tree schematics; no imported geometry."""
from pathlib import Path
import struct
import zlib

ROOT = Path(__file__).resolve().parents[3]
NAMES = ['air', 'grug_trees:gravewood_tree', 'grug_trees:gravewood_leaves']


def build(name, tall):
    size = (7, 9 if tall else 7, 7)
    wood = {(0, y, 0) for y in range(4)}
    # Face-connected bends, then asymmetrical forked dead branches.
    wood.update((1, y, 0) for y in range(3, 7 if tall else 6))
    wood.update({(-1, 3, 0), (-2, 3, 0), (-2, 4, 0),
                 (-2, 4, 1), (1, 4, -1), (1, 4, -2), (1, 5, -2),
                 (1, 5, 1), (1, 5, 2), (0, 5, 2)})
    leaves = {(-2, 5, 1), (-3, 4, 1), (1, 6, -2), (2, 5, -2), (0, 6, 2)}
    if tall:
        wood.update({(2, 6, 0), (2, 7, 0), (2, 7, -1), (0, 6, 2), (0, 7, 2)})
        leaves.discard((0, 6, 2))
        leaves.update({(2, 8, -1), (3, 7, -1), (-1, 7, 2), (0, 8, 2)})
    # Every wood node must remain connected even if every leaf is omitted.
    reached = {(0, 0, 0)}
    while True:
        more = {p for p in wood if any(tuple(p[i] + d[i] for i in range(3)) in reached
                for d in [(1,0,0),(-1,0,0),(0,1,0),(0,-1,0),(0,0,1),(0,0,-1)])}
        if more <= reached: break
        reached |= more
    assert reached == wood and not wood & leaves
    assert all(-3 <= x <= 3 and 0 <= y < size[1] and -3 <= z <= 3 for x,y,z in wood | leaves)
    ids, prob, param2 = [], [], []
    for z in range(-3, 4):
        for y in range(size[1]):
            for x in range(-3, 4):
                pos = (x, y, z)
                ids.append(1 if pos in wood else 2 if pos in leaves else 0)
                prob.append(127 if pos in wood else 48 if pos in leaves else 0)
                param2.append(0)
    header = b'MTSM' + struct.pack('>HHHH', 4, *size) + bytes([127] * size[1])
    header += struct.pack('>H', len(NAMES))
    for node in NAMES:
        data = node.encode('ascii')
        header += struct.pack('>H', len(data)) + data
    data = b''.join(struct.pack('>H', value) for value in ids) + bytes(prob) + bytes(param2)
    path = ROOT / 'mods/ITEMS/grug_trees/schematics' / name
    path.write_bytes(header + zlib.compress(data, 9))
    print(f'{name}: size={size}, connected wood={len(wood)}, optional leaf cells={len(leaves)}')

if __name__ == '__main__':
    build('grug_gravewood_small.mts', False)
    build('grug_gravewood_tall.mts', True)
