#!/usr/bin/env bash
# The offline measurements of this package, all of them from the committed
# field and scan TSVs, so a reviewer can re-take every number in the research
# note without booting an engine.
#
#   walkability     per capital, per gate seed, before and after: the share of
#                   the envelope's own LAND columns from which a land neighbour
#                   is more than one node up. One node is the jump height, so
#                   this is "how much of this capital can a player not walk".
#   plot legality   the 36 Highcourt lots and the 9 Dur Brannoc district plots
#                   against both gate seeds, before and after, plus the
#                   `--repair` proposal that moved three lots.
#   capital walk    `tools/wp13/capital_terrain_fixture.lua`, which is the KAT:
#                   all six capitals in the +-128 district ring against the
#                   committed ceilings.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
here="$repo/tools/wp13/evidence/20260915-capital-terrain"
cd "$repo"
out="$here/measurements"
mkdir -p "$out"
fields="$here/fields"

python3 - "$fields" >"$out/walkability.txt" <<'PYTHON'
import sys, os

def read(path):
    reach, heights, land = None, {}, {}
    for line in open(path):
        if line.startswith('#'):
            if 'reach=' in line:
                reach = int(line.split('reach=')[1].split()[0])
            continue
        line = line.rstrip('\n')
        if not line:
            continue
        z, numbers, flags = line.split('\t')
        z = int(z)
        heights[z] = [int(v) for v in numbers.split()]
        land[z] = flags
    return reach, heights, land

def measure(path, lim):
    reach, H, L = read(path)
    land_total = bad = worst = 0
    for z in range(-lim, lim + 1):
        row, flags = H[z], L[z]
        for x in range(-lim, lim + 1):
            if flags[x + reach] != '1':
                continue
            land_total += 1
            here = row[x + reach]
            climb = 0
            for nx, nz in ((x + 1, z), (x - 1, z), (x, z + 1), (x, z - 1)):
                if -reach <= nx <= reach and -reach <= nz <= reach and \
                        L[nz][nx + reach] == '1':
                    d = H[nz][nx + reach] - here
                    if d > climb:
                        climb = d
            if climb > 1:
                bad += 1
            if climb > worst:
                worst = climb
    return land_total, bad, worst

fields = sys.argv[1]
print("Unclimbable land columns of a capital's +-250 envelope: a land")
print("neighbour more than one node up, which is more than the jump height.")
print()
for lim in (128, 250):
    print("== window +-%d ==" % lim)
    print("%-14s %-20s %-7s %9s %9s %9s %5s" %
          ("capital", "seed", "tree", "land", "unclimb", "permille", "max"))
    for key in ("highcourt", "dur_brannoc"):
        for seed in ("8675309", "531802985935182545"):
            for tree in ("before", "after"):
                path = os.path.join(fields, "%s-%s-%s.tsv" % (tree, key, seed))
                if not os.path.exists(path):
                    continue
                land, bad, worst = measure(path, lim)
                print("%-14s %-20s %-7s %9d %9d %9d %5d" %
                      (key, seed, tree, land, bad, bad * 1000 // land, worst))
    print()
PYTHON
cat "$out/walkability.txt"

echo "== the 36 Highcourt lots, before and after =="
for tree in before after; do
	luajit tools/wp13/highcourt_plots.lua "$repo" \
		"$fields/$tree-highcourt-8675309.tsv" \
		"$fields/$tree-highcourt-531802985935182545.tsv" \
		>"$out/plot-legality-highcourt-$tree.txt" 2>&1 && verdict=PASS || verdict=FAIL
	printf '  %-7s %s (%s)\n' "$tree" "$verdict" \
		"$out/plot-legality-highcourt-$tree.txt"
done
# The repair that moved three of them, re-derivable.
luajit tools/wp13/highcourt_plots.lua "$repo" \
	"$fields/after-highcourt-8675309.tsv" \
	"$fields/after-highcourt-531802985935182545.tsv" --repair \
	>"$out/plot-repair-highcourt.txt" 2>&1
echo "  repair proposal: $out/plot-repair-highcourt.txt"

echo "== the 9 Dur Brannoc district plots =="
if [[ -f "$here/dur_brannoc/scan-8675309.tsv" ]]; then
	luajit tools/wp13/capital_plots.lua "$repo" dur_brannoc \
		"$here/dur_brannoc/scan-8675309.tsv" \
		"$here/dur_brannoc/scan-531802985935182545.tsv" \
		>"$out/plot-legality-dur_brannoc-after.txt" 2>&1 && verdict=PASS || verdict=FAIL
	printf '  after   %s (%s)\n' "$verdict" \
		"$out/plot-legality-dur_brannoc-after.txt"
else
	echo "  (no committed scan; run tools/wp13/run_capital.sh <out> dur_brannoc scan <seed>)"
fi

echo "== the capital walkability KAT, all six =="
luajit tools/wp13/capital_terrain_fixture.lua "$repo" \
	>"$out/capital-walk.txt" 2>&1 && verdict=PASS || verdict=FAIL
printf '  %s (%s)\n' "$verdict" "$out/capital-walk.txt"
cat "$out/capital-walk.txt"
