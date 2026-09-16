#!/usr/bin/env bash
# Every WP13 KAT this lane can move, under BOTH interpreters, with the two
# outputs compared byte for byte.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
out="$repo/tools/wp13/evidence/20260916-polish/kat"
mkdir -p "$out"

run() {
	local name="$1" interp="$2" bin="$3"
	if "$bin" -e "io.write(dofile('tools/wp13/$name.lua')('.'))" \
			>"$out/$name-$interp.txt" 2>"$out/$name-$interp.err"; then
		echo "PASS $name $interp  $(wc -c <"$out/$name-$interp.txt") bytes"
	else
		echo "FAIL $name $interp: $(tail -1 "$out/$name-$interp.err")"
	fi
}

for name in lethariel_kat kezamba_kat gor_drazhak_kat highcourt_kat \
		dur_brannoc_kat nhal_veyr_kat blueprint_kat library_kat seam_kat \
		route_gates_kat settlement_sockets_kat lane_crossing_kat; do
	run "$name" luajit luajit
	run "$name" puc51 "$repo/tools/bin/lua51"
	if cmp -s "$out/$name-luajit.txt" "$out/$name-puc51.txt"; then
		echo "     $name: LuaJIT and PUC 5.1 byte-identical"
	else
		echo "     $name: INTERPRETERS DISAGREE"
	fi
done

echo "== the mutation this lane's two new KAT sections exist for =="
echo "(run by hand; both were run on 2026-09-16 and both go red)"
echo "  1. elf_parts.tree_platform tread param2 2 -> 0"
echo "     lethariel_kat: \"the bough house's tread 1 at turn 0 carries param2 0\""
echo "  2. troll_palette BASALT roof_stair_outer -> stairs:stair_outer_junglewood"
echo "     kezamba_kat: \"roof_stair_outer is bound to ..., which is not basalt\""
echo "  3. parts.lua SHAPED loses grug_decor:darkage_basalt_stair_outer"
echo "     kezamba_kat: \"wp13 parts: ... has no paramtype2\" at construction"

echo "== wp40 r7 unit =="
bash tools/wp40/r7/run.sh unit 2>&1 | tail -3
