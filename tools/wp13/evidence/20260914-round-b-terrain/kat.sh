#!/usr/bin/env bash
# library_kat + blueprint_kat + integration_fixture in one process under both
# interpreters (must be byte-identical), then the two terrain-layer fixtures
# this round is about: the WP13 terrain fitting fixture (five seeds, the start
# pad and road-pin invariants plus the new pad-edge witness) and the portable
# quality geometry micro-KAT, also under both interpreters.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
out="$repo/tools/wp13/evidence/20260914-round-b-terrain"
cd "$repo"
prog='local r="." io.write(dofile(r.."/tools/wp13/library_kat.lua")(r)) io.write(dofile(r.."/tools/wp13/blueprint_kat.lua")(r)) io.write("wp13_integration\t"..dofile(r.."/tools/wp13/integration_fixture.lua")(r).."\n")'

luajit -e "$prog" >"$out/kat-luajit.txt"
tools/bin/lua51 -e "$prog" >"$out/kat-puc51.txt"
cmp "$out/kat-luajit.txt" "$out/kat-puc51.txt" && echo "KAT PAIR BYTE-IDENTICAL"

geometry='assert(loadfile("tools/wp40/quality_geometry_micro_kat.lua"))(os.getenv("PWD"))'
luajit -e "$geometry" >"$out/geometry-luajit.txt"
tools/bin/lua51 -e "$geometry" >"$out/geometry-puc51.txt"
cmp "$out/geometry-luajit.txt" "$out/geometry-puc51.txt" &&
	echo "GEOMETRY MICRO-KAT PAIR BYTE-IDENTICAL"

luajit tools/wp13/terrain_fixture.lua "$repo" >"$out/terrain-luajit.tsv"
echo "TERRAIN FIXTURE PASS (5 seeds x 6 starts)"

sha256sum "$out/kat-luajit.txt" "$out/kat-puc51.txt" \
	"$out/geometry-luajit.txt" "$out/geometry-puc51.txt" \
	"$out/terrain-luajit.tsv"
