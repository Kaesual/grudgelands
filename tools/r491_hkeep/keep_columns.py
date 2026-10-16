#!/usr/bin/env python3
"""0.49.1 study HKEEP: the "map reset, keep housing" deletion on a test world.

Deletes from ROOT/world/map.sqlite every mapblock whose mapchunk column is not
one of the listed columns (chunksize 5: a column is named by its node minp
corner "x0,z0", x0 and z0 = -32 + 80k). Every height of a kept column stays,
including blocks that were only written as another chunk's overgeneration
shell. This is the platform's step for the proposed mode; on PostgreSQL the
same rule is one statement (see docs/research/housing-keep-reset-study.md).

Usage: keep_columns.py ROOT x0,z0 [x0,z0 ...]   (the server of ROOT stopped)
"""
import os
import sqlite3
import sys


def chunk_index(block):
    # emerge.cpp getContainingChunk: chunk offset -chunksize/2 = -2 blocks
    return (block + 2) // 5


def main():
    if len(sys.argv) < 3:
        sys.exit(__doc__)
    root = os.path.realpath(sys.argv[1])
    if not os.path.basename(root).startswith("grudgelands-headless."):
        sys.exit("ROOT must be a kept /tmp/grudgelands-headless.* run directory")
    kept = set()
    for arg in sys.argv[2:]:
        x0, z0 = (int(v) for v in arg.split(","))
        if (x0 + 32) % 80 or (z0 + 32) % 80:
            sys.exit(f"not a chunk corner: {arg}")
        kept.add((chunk_index(x0 // 16), chunk_index(z0 // 16)))
    db = sqlite3.connect(os.path.join(root, "world", "map.sqlite"))
    names = [row[1] for row in db.execute("PRAGMA table_info(blocks)")]
    if "z" not in names:
        sys.exit("legacy pos schema: not handled by this study tool")
    before = db.execute("SELECT COUNT(*) FROM blocks").fetchone()[0]
    doomed = [(x, y, z) for x, y, z in db.execute("SELECT x, y, z FROM blocks")
              if (chunk_index(x), chunk_index(z)) not in kept]
    db.executemany("DELETE FROM blocks WHERE x = ? AND y = ? AND z = ?", doomed)
    db.commit()
    after = db.execute("SELECT COUNT(*) FROM blocks").fetchone()[0]
    db.execute("VACUUM")
    db.close()
    print(f"keep_columns: {len(kept)} kept columns, {before} blocks before, "
          f"{len(doomed)} deleted, {after} kept")


if __name__ == "__main__":
    main()
