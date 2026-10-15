#!/usr/bin/env python3
"""Lane MGPROF: make a kept world's measured chunks generate fresh again.

Deletes, from ROOT/world/map.sqlite, every mapblock of the chunk columns the
probe listed in ROOT/world/mgprof_columns.txt ("x0 z0" per line, the 80 x 80
minp corner), widened by one mapblock on each side (the halo blocks a chunk's
generation writes into its neighbours), over every height. Nothing else in
the world is touched, so a re-used world keeps its finished preparation and
world-folder caches while the measured chunks are new again.

Usage: reset_columns.py ROOT        (the server of ROOT must be stopped)
"""
import os
import sqlite3
import sys


def unsigned_to_signed(value, max_positive):
    return value - 2 * max_positive if value >= max_positive else value


def legacy_decode(pos):
    # database.cpp getIntegerAsBlock
    x = unsigned_to_signed(pos % 4096, 2048)
    pos = (pos - x) // 4096
    y = unsigned_to_signed(pos % 4096, 2048)
    pos = (pos - y) // 4096
    z = unsigned_to_signed(pos % 4096, 2048)
    return x, y, z


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    root = os.path.realpath(sys.argv[1])
    if not os.path.basename(root).startswith("grudgelands-headless."):
        sys.exit("ROOT must be a kept /tmp/grudgelands-headless.* run directory")
    world = os.path.join(root, "world")
    with open(os.path.join(world, "mgprof_columns.txt")) as handle:
        columns = [tuple(int(v) for v in line.split()) for line in handle if line.strip()]
    boxes = []
    for x0, z0 in columns:
        # blocks of the chunk column plus one block of halo on each side
        boxes.append((x0 // 16 - 1, (x0 + 79) // 16 + 1, z0 // 16 - 1, (z0 + 79) // 16 + 1))

    def inside(bx, bz):
        return any(a <= bx <= b and c <= bz <= d for a, b, c, d in boxes)

    db = sqlite3.connect(os.path.join(world, "map.sqlite"))
    names = [row[1] for row in db.execute("PRAGMA table_info(blocks)")]
    deleted = 0
    if "z" in names:
        for a, b, c, d in boxes:
            cur = db.execute("DELETE FROM blocks WHERE x BETWEEN ? AND ? AND z BETWEEN ? AND ?",
                             (a, b, c, d))
            deleted += cur.rowcount
    else:
        doomed = [(pos,) for (pos,) in db.execute("SELECT pos FROM blocks")
                  if inside(legacy_decode(pos)[0], legacy_decode(pos)[2])]
        db.executemany("DELETE FROM blocks WHERE pos = ?", doomed)
        deleted = len(doomed)
    db.commit()
    total = db.execute("SELECT COUNT(*) FROM blocks").fetchone()[0]
    db.close()
    print(f"reset_columns: {len(columns)} columns, deleted {deleted} blocks, "
          f"{total} blocks remain ({'xyz' if 'z' in names else 'pos'} schema)")


if __name__ == "__main__":
    main()
