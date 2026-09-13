#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd -P)"
output="${1:?absent absolute output directory required}"
[[ "$output" == /* && ! -e "$output" ]] || exit 2
mkdir -p "$output"
# Parser/static gates precede this final-only runtime pair. No seed fleet.
mapfile -t inputs < <(cd "$repo" && {
	rg --files mods/MAPGEN/grug_mapgen tools/wp40/tree_slices tools/wp40/resource_rank
	printf '%s\n' tools/wp40/r6/common.lua tools/wp40/simple_map_r5_vm.lua
	printf '%s\n' mods/BASE/default/schematics/pine_tree.mts
} | sort -u)
(cd "$repo" && sha256sum "${inputs[@]}") >"$output/inputs.sha256"
"$repo/tools/bin/lua51" -v >"$output/puc-version.txt" 2>&1
luajit -v >"$output/luajit-version.txt" 2>&1
chrt --idle 0 ionice -c3 "$repo/tools/bin/lua51" \
	"$repo/tools/wp40/resource_rank/final_micro.lua" "$repo" >"$output/puc.tsv"
chrt --idle 0 ionice -c3 luajit \
	"$repo/tools/wp40/resource_rank/final_micro.lua" "$repo" >"$output/luajit.tsv"
cmp "$output/puc.tsv" "$output/luajit.tsv"
(cd "$repo" && sha256sum -c "$output/inputs.sha256") >"$output/inputs-check.txt"
sha256sum "$output/puc.tsv" "$output/luajit.tsv" >"$output/output.sha256"
printf 'Final tree/resource micro-KAT PASS: %s\n' "$output"
