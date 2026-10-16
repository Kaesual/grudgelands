#!/usr/bin/env python3
"""Round 50 lane PTOOL: trims the map of a world make_world.sh built to the
blocks the pre-reset pass reads (every claim's block box,
migration/pack.py area_blocks), so the committed test world stays small.
The kept rows are byte for byte the engine's.

Usage: python3 tools/r50_ptool/trim.py WORLD_DIR
"""
import sqlite3
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from migration import pack, world as worldmod  # noqa: E402


def main(world):
    backends = worldmod.open_world(world)
    try:
        claims, _ = pack.read_claims(backends["mod_storage"])
    finally:
        worldmod.close_world(backends)
    boxes = [pack.area_blocks(claim) for claim in claims]
    conn = sqlite3.connect(Path(world, "map.sqlite"))
    rows = conn.execute("SELECT x, y, z FROM blocks").fetchall()
    drop = [r for r in rows if not any(
        all(lo[i] <= r[i] <= hi[i] for i in range(3)) for lo, hi in boxes)]
    with conn:
        conn.executemany("DELETE FROM blocks WHERE x = ? AND y = ? AND z = ?", drop)
    conn.execute("VACUUM")
    conn.close()
    print("trim: kept %d of %d blocks" % (len(rows) - len(drop), len(rows)))


if __name__ == "__main__":
    main(sys.argv[1])
