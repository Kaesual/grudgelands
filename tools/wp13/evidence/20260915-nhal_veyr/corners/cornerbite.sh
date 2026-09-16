#!/usr/bin/env bash
# Would the committed `corner-digest` actually move if the corner reconciliation
# were dropped? Built offline out of the same WP40 height session, restricted to
# the four corner boxes the probe's region dumps.
set -uo pipefail
export LC_ALL=C
SP="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
after="${1:?after}"
before="$SP/nvbefore"
mkdir -p "$SP/bite"
for pair in "before:$before" "after:$after"; do
	name="${pair%%:*}"; tree="${pair##*:}"
	( cd "$tree" && nice -n 19 luajit \
		"$after/tools/wp13/evidence/20260915-nhal_veyr/corners/wall_cells.lua" \
		"$tree" 531802985935182545 nhal_veyr "$SP/bite/$name.tsv" )
done
python3 - "$SP/bite" <<'PY'
import sys
base = sys.argv[1]
PAD, CORNER = 12, 256


def boxed(path):
    out = set()
    for line in open(path):
        if line.startswith("#"):
            continue
        f = line.rstrip("\n").split("\t")
        if len(f) < 6:
            continue
        x, y, z = int(f[1]), int(f[2]), int(f[3])
        for sx in (-1, 1):
            for sz in (-1, 1):
                if (abs(x - sx * CORNER) <= PAD and
                        abs(z - sz * CORNER) <= PAD):
                    out.add((x, y, z, f[4], f[5]))
    return out


b = boxed(base + "/before.tsv")
a = boxed(base + "/after.tsv")
print("corner-box cells before=%d after=%d" % (len(b), len(a)))
print("cells only before=%d, only after=%d, differing=%d"
      % (len(b - a), len(a - b), len(b ^ a)))
PY
