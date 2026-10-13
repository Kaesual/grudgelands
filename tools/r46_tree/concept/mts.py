"""Read a Luanti .mts schematic (version 4) into plain node cells.

Used by build.py to show today's trees next to the drafts. Pure stdlib.
"""
import struct
import zlib


def read_mts(path):
    with open(path, "rb") as handle:
        raw = handle.read()
    if raw[:4] != b"MTSM":
        raise ValueError(path + ": not an MTS file")
    version, sx, sy, sz = struct.unpack(">HHHH", raw[4:12])
    pos = 12
    if version >= 3:
        pos += sy  # y-slice probabilities
    (count,) = struct.unpack(">H", raw[pos:pos + 2])
    pos += 2
    names = []
    for _ in range(count):
        (length,) = struct.unpack(">H", raw[pos:pos + 2])
        pos += 2
        names.append(raw[pos:pos + length].decode())
        pos += length
    body = zlib.decompress(raw[pos:])
    total = sx * sy * sz
    content = struct.unpack(">%dH" % total, body[:2 * total])
    prob = body[2 * total:3 * total]
    param2 = body[3 * total:4 * total]
    cells = []
    index = 0
    for z in range(sz):
        for y in range(sy):
            for x in range(sx):
                name = names[content[index]]
                p = prob[index] & 0x7F
                if version < 4:
                    p = prob[index] >> 1  # older files store 0..255
                if name not in ("air", "ignore") and p > 0:
                    cells.append({"x": x, "y": y, "z": z, "name": name,
                                  "prob": p, "param2": param2[index]})
                index += 1
    return {"size": (sx, sy, sz), "cells": cells}


if __name__ == "__main__":
    import sys
    for path in sys.argv[1:]:
        data = read_mts(path)
        kinds = {}
        for cell in data["cells"]:
            kinds[cell["name"]] = kinds.get(cell["name"], 0) + 1
        ys = [c["y"] for c in data["cells"]]
        print(path.rsplit("/", 1)[-1], data["size"], "y", min(ys), max(ys), kinds)
