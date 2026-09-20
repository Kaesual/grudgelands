#!/usr/bin/env python3
"""Check actual map output against native input and the guarded R5-air witness."""
import argparse
from collections import Counter
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("native", type=Path)
parser.add_argument("guarded", type=Path)
parser.add_argument("candidate", type=Path)
parser.add_argument("--reload", type=Path)
args = parser.parse_args()


def read(path):
    rows = {}
    complete = False
    for line in path.read_text().splitlines():
        fields = line.split("\t")
        if fields[0] == "column":
            # Early probe output omitted the two trailing fields only for
            # the unowned immutable channel (nil biome). Preserve that
            # explicit metadata-only coverage in the native baseline.
            if len(fields) == 6:
                assert fields[5] == "immutable_dragon_channel"
                fields += ["-", ""]
            _, case, x, y, z, water, biome, nodes = fields
            rows[case, int(x), int(z)] = (int(y), water, biome, tuple(nodes.split(",")))
        if fields[0] == "complete":
            complete = True
    assert complete, f"incomplete witness: {path}"
    return rows


native, guarded, candidate = map(read, (args.native, args.guarded, args.candidate))
assert native.keys() == candidate.keys(), "witness coordinate population changed"
for key in native:
    assert native[key][:3] == candidate[key][:3], f"terrain/ownership changed at {key}"


def air_run(row):
    return row[3][:4] == ("air:0",) * 4


counts = Counter()
for z in range(-2460, -2455):
    for x in range(-73, -68):
        key = "reported_roof", x, z
        old, raw, now = guarded[key], native[key], candidate[key]
        y = raw[0]
        lower = any(native["reported_roof", x + dx, z + dz][0] <= y - 2
                    for dx, dz in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        neighborhood = all(air_run(native["reported_roof", x + dx, z + dz])
                           for dx in (-1, 0, 1) for dz in (-1, 0, 1))
        # Guarded output came from the identical R5 planner/adapter with the
        # old broad landmark veto still active. It directly witnesses which
        # original air survived R5 before the newly admitted skin/opening pass.
        opening = air_run(raw) and air_run(old) and (lower or neighborhood)
        if opening:
            assert now[3][4:] == ("air:0", "air:0"), f"roof/dust remains at {key}"
            assert air_run(now), f"opening cave air filled at {key}"
            counts["openings"] += 1
        else:
            for index in (1, 2, 3):
                if raw[3][index] == "air:0" and old[3][index] == "air:0":
                    assert now[3][index] == "default:stone:0", f"thin skin remains at {key}"
                    counts["skin_nodes"] += 1

center = candidate["reported_roof", -71, -2458]
assert center[0] == 21 and center[3] == ("air:0",) * 6
assert guarded["reported_roof", -71, -2458][3][4] == "default:dirt_with_grass:0"
assert counts["openings"] > 0
for key, row in candidate.items():
    case, _, _ = key
    if case in ("wyrmglass", "stormscale", "high_freshwater") and row[1] == "land":
        assert row[3][4] in ("default:stone:0", "default:gravel:0"), f"non-rock rim at {key}"
        counts[case + "_rock_columns"] += 1
assert candidate["gravesalt", -2500, 164][3][4] == "default:sand:0"
assert all(counts[name + "_rock_columns"] > 0 for name in ("wyrmglass", "stormscale", "high_freshwater"))
print("R10 engine output PASS")
print("columns", len(candidate), "geometry/ownership unchanged")
for key, value in sorted(counts.items()):
    print(key, value)
print("reported_point", "-71/21/-2458", "grass-roof -> air; native cave retained")
print("gravesalt", "sand support retained")

if args.reload:
    reloaded = read(args.reload)
    assert reloaded.keys() == candidate.keys(), "reload coordinate population differs"
    checked = 0
    for key, old in candidate.items():
        new = reloaded[key]
        assert new[:3] == old[:3], f"reload geometry changed at {key}"
        if len(old[3]) == 6:
            assert old[3] == new[3], f"persisted nodes/param2 changed at {key}"
            checked += 1
        assert len(new[3]) == 6, f"reload telemetry remains truncated at {key}"
    print("persistence", checked, "six-node columns byte-identical; full reload telemetry", len(reloaded))
