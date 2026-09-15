#!/usr/bin/env bash
# The interpreter pair: every WP13 fixture once under LuaJIT and once under
# the engine's own PUC 5.1 build, with the input set hashed before and after so
# nothing moved between the two runs.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
here="$repo/tools/wp13/evidence/20260915-lane-routes"
cd "$repo"
out="$here/final-micro"
rm -rf "$out"
mkdir -p "$out"

inputs() {
	find mods/MAPGEN/grug_mapgen/wp13 mods/MAPGEN/grug_mapgen/wp40 tools/wp13 \
		-name '*.lua' -print0 | sort -z | xargs -0 sha256sum | sha256sum
}

echo "inputs before: $(inputs)"
luajit tools/wp13/final_micro.lua "$repo" "$out/luajit.tsv" luajit
tools/bin/lua51 tools/wp13/final_micro.lua "$repo" "$out/puc51.tsv" puc51
echo "inputs after:  $(inputs)"
if cmp -s "$out/luajit.tsv" "$out/puc51.tsv"; then
	echo "INTERPRETER PAIR IDENTICAL: $(sha256sum "$out/luajit.tsv" | cut -d' ' -f1)"
else
	echo "INTERPRETER PAIR DIFFERS"
	diff "$out/luajit.tsv" "$out/puc51.tsv" | head -20
	exit 1
fi
