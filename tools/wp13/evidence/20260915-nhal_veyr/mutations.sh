#!/usr/bin/env bash
# Does the work-socket rule actually bite? Three mutations, run against a COPY
# of the tree in a scratch directory, never against the tree itself.
#
# The independent review of 2026-09-16 found that it did not: the feature search
# read one course BELOW the socket's feet, and the `mine` and `pray` sets
# carried the paving roles, so a miner standing on a paved court was satisfied
# by the court's own floor. Both are fixed; these are the tests that say so.
#
#   1. DELETE THE QUARRY FACE the bone rampart's two miners work. Red before
#      the fix and red after it: the rule is load-bearing where it is used.
#   2. RETYPE A `pray` SOCKET OF THE PAVED PYRE COURT TO `mine`. Nothing there
#      is a rock face. GREEN before the fix -- satisfied by the court's paving
#      one course down -- and RED after it.
#   3. MOVE THE ALTAR'S VOTIVE LIGHTS UP ONE COURSE, out of the window the
#      contract gives a resident. Green before, red after.
#   4. DISARM THE CURTAIN WALL'S CORNER CLAMP (`wp13/wall.lua` section 1b): the
#      corners are still visited and counted, but the datum is not applied. The
#      KAT's own shouldered ground then shows the defect the wave-2 review
#      found -- two runs' walks meeting six nodes apart through a three-course
#      opening -- and rule (f) goes red. This is the "red without the fix" the
#      coordinator asked the corner commit to carry.
#   5. TAKE THE GATE TUNNEL'S FLOOR AWAY (`wp13/nhal_veyr.lua`'s `gate_road`
#      section 3): the road arrives at the gate point at the free terrain there,
#      which can stand above the lowest ground of the band the curtain clears,
#      and then the curtain's passage leaves air under the carriageway. The
#      engine's read-back is what found that; the KAT's rule (f) is what holds
#      it now, and this is the mutation that says so.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
scratch="$(mktemp -d /tmp/grug-nv-mutation.XXXXXX)"
trap 'rm -rf -- "$scratch"' EXIT

run_kat() {
	( cd "$1" && luajit -e \
		"io.write(dofile('tools/wp13/nhal_veyr_kat.lua')('.'))" \
		>/dev/null 2>"$1/kat.err" )
}

mutate() {
	local name="$1"; shift
	local tree="$scratch/$name"
	rm -rf "$tree"
	mkdir -p "$tree"
	( cd "$repo" && tar -cf - mods tools/wp13 tools/wp40 tools/bin ) |
		( cd "$tree" && tar -xf - )
	"$@" "$tree"
	if run_kat "$tree"; then
		printf '%-24s KAT GREEN (exit 0)\n' "$name"
	else
		printf '%-24s KAT RED: %s\n' "$name" \
			"$(head -1 "$tree/kat.err" | cut -c1-160)"
	fi
}

drop_quarry_face() {
	local tree="$1"
	python3 - "$tree" <<'PY'
import sys
p = sys.argv[1] + "/mods/MAPGEN/grug_mapgen/wp13/nhal_veyr_district_martial.lua"
s = open(p).read()
old = """				for _, span in ipairs({{-7, -3}, {3, 7}}) do
					for x = span[1], span[2] do
						for y = 1, 2 do
							buf:put(x, y, -3, "default:cobble")
						end
					end
				end"""
assert old in s, "the quarry face moved"
open(p, "w").write(s.replace(old, "", 1))
PY
}

pray_to_mine() {
	local tree="$1"
	python3 - "$tree" <<'PY'
import sys
p = sys.argv[1] + "/mods/MAPGEN/grug_mapgen/wp13/nhal_veyr_district_martial.lua"
s = open(p).read()
old = '''plots.work("vigil_south", "pray",'''
assert old in s, "the pyre court's south vigil moved"
open(p, "w").write(s.replace(old, '''plots.work("vigil_south", "mine",''', 1))
PY
}

raise_altar_lights() {
	local tree="$1"
	python3 - "$tree" <<'PY'
import sys
p = sys.argv[1] + "/mods/MAPGEN/grug_mapgen/wp13/undead_parts.lua"
s = open(p).read()
old = """			parts.floor_torch(buf, palette, x, 2, z)
			lights[#lights + 1] = {x = x, y = 2, z = z}"""
assert old in s, "the candle court's altar lights moved"
new = """			buf:put(x, 2, z, mark(palette))
			parts.floor_torch(buf, palette, x, 3, z)
			lights[#lights + 1] = {x = x, y = 3, z = z}"""
open(p, "w").write(s.replace(old, new, 1))
PY
}

disarm_corner_clamp() {
	local tree="$1"
	python3 - "$tree" <<'PY2'
import sys
p = sys.argv[1] + "/mods/MAPGEN/grug_mapgen/wp13/wall.lua"
s = open(p).read()
old = """				if datum > floor[corner.p] then
					floor[corner.p] = datum
					level = envelope(floor)
				end
"""
assert old in s, "the corner clamp moved"
open(p, "w").write(s.replace(old, "", 1))
PY2
}

drop_tunnel_floor() {
	local tree="$1"
	python3 - "$tree" <<'PY3'
import sys
p = sys.argv[1] + "/mods/MAPGEN/grug_mapgen/wp13/nhal_veyr.lua"
s = open(p).read()
old = """					for y = bottom, low[entry.key] - 1 do
						piece.cells[#piece.cells + 1] = {x = entry.x, y = y,
							z = entry.z, name = PAVING, param2 = 0}
						tunnel = tunnel + 1
					end
"""
assert old in s, "the gate tunnel's floor moved"
open(p, "w").write(s.replace(old, "", 1))
PY3
}

printf '== the tree as it ships\n'
if run_kat "$repo"; then echo "shipped tree           KAT GREEN (exit 0)"; fi
printf '== mutations\n'
mutate drop_quarry_face drop_quarry_face
mutate pray_to_mine pray_to_mine
mutate raise_altar_lights raise_altar_lights
mutate disarm_corner_clamp disarm_corner_clamp
mutate drop_tunnel_floor drop_tunnel_floor
