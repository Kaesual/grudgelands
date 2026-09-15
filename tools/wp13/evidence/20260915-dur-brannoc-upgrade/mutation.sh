#!/usr/bin/env bash
# DOES THE KAT DEFEND THE PROPERTY IT ADVERTISES?
#
# The composition KAT claims that a work socket's feature check is "the rule a
# moved piece of dressing breaks, and nothing else in the tree would see it".
# A claim like that is only worth what a MUTATION says about it: break the
# feature and the KAT must turn red.
#
# The independent review of 2026-09-15 ran exactly this on the first version of
# the package and the KAT stayed GREEN for `mine`, because the `mine` node set
# named the palette's paving roles (`plaza`, `plaza_edge`, `path`, `foundation`,
# `signature`, `wall_accent` -- three nodes between them, all of which a plot
# paves its own ground with) and the search ran at `dy = -1`, the ground course
# itself. The set is masonry-only now and `mine` searches at `dy = 0..1`, the
# contract's own "at head or chest height".
#
# This script re-runs the mutation on a throw-away copy of the tree -- never on
# the worktree -- for the three activities whose feature is a piece of dwarf
# dressing, and asserts RED for each. It also asserts that the unmutated tree is
# GREEN, so a KAT that is red for an unrelated reason cannot pass this by
# accident.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
work="$(mktemp -d /tmp/grug-wp13-mutation.XXXXXX)"
trap 'rm -rf -- "$work"' EXIT
cd "$repo"

copy() {
	rm -rf "$work/tree"
	mkdir -p "$work/tree"
	cp -a mods tools "$work/tree/"
}

run_kat() {
	( cd "$work/tree" && luajit -e \
		"io.write(dofile('tools/wp13/dur_brannoc_kat.lua')('.'))" \
		>"$work/out.txt" 2>"$work/err.txt" )
}

expect() {
	local want="$1" label="$2"
	run_kat
	local rc=$?
	local got=GREEN
	[[ "$rc" -ne 0 ]] && got=RED
	if [[ "$got" == "$want" ]]; then
		printf '%-44s %-5s as expected\n' "$label" "$got"
		[[ "$got" == RED ]] && sed -n '1p' "$work/err.txt" | sed 's/^/    /'
		return 0
	fi
	printf '%-44s %-5s BUT %s WAS EXPECTED\n' "$label" "$got" "$want"
	[[ "$got" == RED ]] && sed -n '1p' "$work/err.txt" | sed 's/^/    /'
	return 1
}

failures=0

echo "== control: the tree as committed =="
copy
expect GREEN "unmutated" || failures=$((failures + 1))

echo
echo "== mine: the ore yard's rock face deleted =="
copy
python3 - "$work/tree" <<'PY'
import sys
p = sys.argv[1] + '/mods/MAPGEN/grug_mapgen/wp13/dur_brannoc_district.lua'
s = open(p, encoding='utf-8').read()
old = '''				area.dwarf.rock_face(buf, palette, area.x0 + 2, area.z0 + 1,
					area.x0 + 5, area.z0 + 1, 2)'''
assert old in s, 'ore yard rock face not found'
open(p, 'w', encoding='utf-8').write(s.replace(old, '\t\t\t\tlocal _ = buf', 1))
PY
expect RED "mine: forge_ore_yard rock face removed" || failures=$((failures + 1))

echo
echo "== mine: the ore court's rock face and mine mouth deleted =="
copy
python3 - "$work/tree" <<'PY'
import sys
p = sys.argv[1] + '/mods/MAPGEN/grug_mapgen/wp13/dur_brannoc_district.lua'
s = open(p, encoding='utf-8').read()
old = '''				dwarf.rock_face(buf, palette, -10, 9, -4, 9, 5)
				dwarf.mine_mouth(buf, palette, 2, 9, 9, 5)'''
assert old in s, 'ore court face not found'
open(p, 'w', encoding='utf-8').write(s.replace(old, '\t\t\t\tlocal _ = dwarf', 1))
PY
expect RED "mine: forge_ore_court face and mouth removed" || failures=$((failures + 1))

echo
echo "== carve: the carvers' cut blocks deleted =="
copy
python3 - "$work/tree" <<'PY'
import sys
p = sys.argv[1] + '/mods/MAPGEN/grug_mapgen/wp13/dur_brannoc_district_lore.lua'
s = open(p, encoding='utf-8').read()
old = '''				area.dwarf.cut_blocks(buf, palette, area.x0 + 2, area.z0 + 1,
					4, "x")'''
assert old in s, 'carvers cut blocks not found'
open(p, 'w', encoding='utf-8').write(s.replace(old, '\t\t\t\tlocal _ = buf', 1))
PY
expect RED "carve: deep_carvers blocks removed" || failures=$((failures + 1))

echo
echo "== brew: the brewhouse vats deleted =="
copy
python3 - "$work/tree" <<'PY'
import sys
p = sys.argv[1] + '/mods/MAPGEN/grug_mapgen/wp13/dur_brannoc_district_homes.lua'
s = open(p, encoding='utf-8').read()
old = '''				area.dwarf.brew_vats(buf, palette, area.x0 + 2, area.z0 + 1,
					2, "x")'''
assert old in s, 'brewhouse vats not found'
open(p, 'w', encoding='utf-8').write(s.replace(old, '\t\t\t\tlocal _ = buf', 1))
PY
expect RED "brew: terrace_brewhouse vats removed" || failures=$((failures + 1))

echo
if [[ "$failures" -eq 0 ]]; then
	echo "MUTATION SUITE PASS: every deleted feature turns the KAT red"
	exit 0
fi
echo "MUTATION SUITE FAIL: $failures case(s) did not behave as expected"
exit 1
