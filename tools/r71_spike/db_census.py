#!/usr/bin/env python3
"""Round 71 lane SPIKE: what a run left in a world's map database.

Usage: db_census.py <map.sqlite>
Prints the file size, the block count, and for the blocks beyond x 4100 (the
slots) the count and stored bytes per mapchunk layer and in total.
"""
import collections
import os
import sqlite3
import sys


def unpack(key):
    def signed(value):
        return value - 4096 if value >= 2048 else value
    x = signed(key & 4095)
    key = (key - x) >> 12
    y = signed(key & 4095)
    key = (key - y) >> 12
    return x, y, signed(key & 4095)


def main():
    path = sys.argv[1]
    db = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    columns = [row[1] for row in db.execute("PRAGMA table_info(blocks)")]
    if "pos" in columns:
        rows = ((*unpack(pos), size) for pos, size in
                db.execute("SELECT pos, length(data) FROM blocks"))
    else:
        rows = db.execute("SELECT x, y, z, length(data) FROM blocks")
    total = off = off_bytes = all_bytes = 0
    layers = collections.Counter()
    layer_bytes = collections.Counter()
    chunks = set()
    for x, y, z, size in rows:
        total += 1
        all_bytes += size
        if x * 16 > 4100:
            off += 1
            off_bytes += size
            k = ((x + 2) // 5, (y + 2) // 5, (z + 2) // 5)
            chunks.add(k)
            layers[k[1]] += 1
            layer_bytes[k[1]] += size
    print(f"file {os.path.getsize(path)} bytes, {total} blocks, {all_bytes} block bytes")
    print(f"off the map: {off} blocks, {off_bytes} bytes, {len(chunks)} chunks")
    for layer in sorted(layers):
        print(f"  chunk layer {layer} (y {80 * layer - 32}..{80 * layer + 47}): "
              f"{layers[layer]} blocks, {layer_bytes[layer]} bytes")


if __name__ == "__main__":
    main()
