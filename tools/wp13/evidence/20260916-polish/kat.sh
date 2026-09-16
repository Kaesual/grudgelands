#!/usr/bin/env bash
# Every WP13 KAT this lane can move, under BOTH interpreters, with the two
# outputs compared byte for byte.
#
# `OUT=<dir>` writes the per-KAT outputs somewhere else. The default is this
# evidence directory, which is fine for the lane that owns it and is a trap for
# a READ-ONLY REVIEWER: running it in place modifies the repository. The
# independent review of 2026-09-16 hit exactly that and asked for the override.
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
out="${OUT:-$repo/tools/wp13/evidence/20260916-polish/kat}"
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

echo "== the mutations this lane's two new KAT sections exist for =="
echo "(run by hand; all were run on 2026-09-16 and all go red)"
echo "  1. elf_parts.tree_platform tread param2 2 -> 0"
echo "     lethariel_kat: \"the bough house's tread 1 at turn 0 carries param2 0\""
echo "  2. parts.lua SHAPED loses grug_decor:darkage_basalt_stair_outer"
echo "     kezamba_kat 6a: \"parts.shaped disagrees with the registry for ...\""
echo "     (and, while a basalt roof is bound, \"has no paramtype2\" at construction)"
echo "  3. troll_palette BASALT roof_stair_outer -> a name of another family"
echo "     kezamba_kat 6b: \"... is <other> and not <family>; a roof may not mix\""

echo "== wp40 r7 unit =="
bash tools/wp40/r7/run.sh unit 2>&1 | tail -3
