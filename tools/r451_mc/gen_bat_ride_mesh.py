#!/usr/bin/env python3
"""0.45.1 lane MC: the ridden bats' mesh without the body's bob.

The cave bat mesh (grug_mobs_cave_bat.b3d, VoxeLibre mobs_mc_bat.b3d by
22i, GPL-3.0-or-later) moves its body bone up and down by about 1.9 mesh
units in the flight loop (frames 1-40). Ridden, that is 0.74 (Throng Cave
Bat) and 1.04 nodes (Giant Blood Bat) under a rider who stays put (the
user's playtest). This writes grug_mounts_bat_ride.b3d: a byte-for-byte
copy in which every position key of the body bone holds frame 1's position
(the frame the ridden bat holds on the ground). Rotations, the wings, head,
ears and legs are untouched. Only the ridden bats use it; the mobs and the
capital displays keep the original.

Usage: gen_bat_ride_mesh.py [--check] [REPO]
"""

import os
import struct
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "r28_a3"))
import mesh_bounds as mb  # noqa: E402

SOURCE = "mods/ENTITIES/grug_mobs/models/grug_mobs_cave_bat.b3d"
TARGET = "mods/PLAYER/grug_mounts/models/grug_mounts_bat_ride.b3d"
BODY_JOINT = 1      # the skinned "body" node, parent of head, wings and legs
HOLD_FRAME = 1      # Irrlicht frame, as the loader numbers keys


def key_chunks(data):
    """(joint index, KEYS chunk start, end) in the loader's depth-first order."""
    out = []
    counter = [0]

    def chunks(start, end):
        pos = start
        while pos + 8 <= end:
            tag = data[pos:pos + 4].decode("latin-1")
            size = struct.unpack_from("<i", data, pos + 4)[0]
            yield tag, pos + 8, pos + 8 + size
            pos += 8 + size

    def node(start, end):
        index = counter[0]
        counter[0] += 1
        pos = data.index(b"\0", start) + 1 + 40
        for tag, cstart, cend in chunks(pos, end):
            if tag == "NODE":
                node(cstart, cend)
            elif tag == "KEYS":
                out.append((index, cstart, cend))

    size = struct.unpack_from("<i", data, 4)[0]
    for tag, cstart, cend in chunks(12, 8 + size):
        if tag == "NODE":
            node(cstart, cend)
    return out


def build(repo):
    data = open(os.path.join(repo, SOURCE), "rb").read()
    model = mb.B3D(data).load()
    body = model.joints[BODY_JOINT]
    assert body.weights and body.pos, "the body joint moved"
    hold = mb.channel_at(body.pos, HOLD_FRAME, mb.lerp)
    out = bytearray(data)
    patched = 0
    for index, start, end in key_chunks(data):
        if index != BODY_JOINT:
            continue
        flags = struct.unpack_from("<i", data, start)[0]
        assert flags & 1, "the body joint has no position keys"
        p = start + 4
        while p < end:
            p += 4
            struct.pack_into("<3f", out, p, *hold)
            patched += 1
            p += 12
            if flags & 2:
                p += 12
            if flags & 4:
                p += 16
    assert patched == len(body.pos), "position keys missed"
    return bytes(out)


def main():
    args = [a for a in sys.argv[1:] if a != "--check"]
    repo = args[0] if args else os.path.join(HERE, "..", "..")
    result = build(repo)
    target = os.path.join(repo, TARGET)
    if "--check" in sys.argv:
        current = open(target, "rb").read() if os.path.exists(target) else b""
        if current != result:
            print("gen_bat_ride_mesh: %s is out of date" % TARGET)
            return 1
        print("gen_bat_ride_mesh: OK")
        return 0
    with open(target, "wb") as fh:
        fh.write(result)
    print("gen_bat_ride_mesh: wrote %s (%d bytes)" % (TARGET, len(result)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
