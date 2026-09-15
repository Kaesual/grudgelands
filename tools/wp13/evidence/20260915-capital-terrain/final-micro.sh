#!/usr/bin/env bash
# The single bounded final-byte process for the capital-terrain package: every
# WP13 fixture in one interpreter process, run once under LuaJIT and once under
# the engine's bundled PUC 5.1 build, with the exact input set hashed before and
# after so the two runs provably saw the same bytes. Then the two LuaJIT-only
# terrain fixtures this package is about -- the six starts' fitting, which must
# not move, and the six capitals' walkability, which is the property it added.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
out="$repo/tools/wp13/evidence/20260915-capital-terrain/final-micro"
cd "$repo"
rm -rf "$out"
mkdir -p "$out"

INPUTS=(
	mods/MAPGEN/grug_mapgen/wp13/highcourt_quadrants.lua
	mods/MAPGEN/grug_mapgen/wp40/coupled_grade.lua
	mods/MAPGEN/grug_mapgen/wp40/height.lua
	mods/MAPGEN/grug_mapgen/wp40/r6_planner.lua
	mods/MAPGEN/grug_mapgen/wp40/r6_settlement.lua
	mods/MAPGEN/grug_mapgen/wp40/simple_map.lua
	mods/MAPGEN/grug_mapgen/wp40/source/simple_map.lua
	mods/MAPGEN/grug_mapgen/wp40/zones.lua
	tools/wp13/capital_terrain_fixture.lua
	tools/wp13/final_micro.lua
	tools/wp13/highcourt_kat.lua
	tools/wp13/highcourt_plots.lua
	tools/wp13/terrain_fixture.lua
	/usr/bin/luajit
	tools/bin/lua51
)

sha256sum "${INPUTS[@]}" >"$out/inputs-before.sha256"
luajit tools/wp13/final_micro.lua "$repo" "$out/micro-luajit.tsv" luajit \
	>"$out/micro-luajit.log"
tools/bin/lua51 tools/wp13/final_micro.lua "$repo" "$out/micro-puc51.tsv" puc51 \
	>"$out/micro-puc51.log"
sha256sum "${INPUTS[@]}" >"$out/inputs-after.sha256"
cmp "$out/inputs-before.sha256" "$out/inputs-after.sha256"
cmp "$out/micro-luajit.tsv" "$out/micro-puc51.tsv"
echo "WP13 FINAL MICRO PAIR BYTE-IDENTICAL"

# The terrain layer. Both are LuaJIT development fixtures for the same reason:
# they build the real WP40 height authority for whole seeds, which is a
# LuaJIT-sized job and not a portable micro-KAT one.
luajit tools/wp13/terrain_fixture.lua "$repo" >"$out/start-terrain.tsv"
echo "START TERRAIN FIXTURE PASS (5 seeds x 6 starts)"
luajit tools/wp13/capital_terrain_fixture.lua "$repo" >"$out/capital-walk.tsv"
echo "CAPITAL WALKABILITY FIXTURE PASS (2 gate seeds x 6 capitals)"

# The six starts' terrain must be BYTE-IDENTICAL to the round-B evidence: this
# package may not move a start by one node.
cmp tools/wp13/evidence/20260914-round-b-terrain/terrain-luajit.tsv \
	"$out/start-terrain.tsv" &&
	echo "SIX-START TERRAIN BYTE-IDENTICAL TO 20260914-round-b-terrain"

luajit tools/wp13/evidence/20260914-capital-parts/start_identity.lua "$repo" \
	>"$out/start-identity.txt"
diff <(tail -n +2 tools/wp13/evidence/20260915-dur-brannoc/identity.txt | head -6) \
	"$out/start-identity.txt" &&
	echo "SIX START BLUEPRINT IDENTITIES BYTE-IDENTICAL TO 20260915-dur-brannoc"

( cd "$repo" && sha256sum \
	tools/wp13/evidence/20260915-capital-terrain/final-micro/micro-luajit.tsv \
	tools/wp13/evidence/20260915-capital-terrain/final-micro/micro-puc51.tsv \
	tools/wp13/evidence/20260915-capital-terrain/final-micro/start-terrain.tsv \
	tools/wp13/evidence/20260915-capital-terrain/final-micro/capital-walk.tsv ) \
	>"$out/digests.txt"
cat "$out/digests.txt"
