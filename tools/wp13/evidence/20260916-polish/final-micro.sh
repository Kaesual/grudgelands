#!/usr/bin/env bash
# The final micro-KAT pair on the frozen bytes: every WP13 fixture in ONE
# process under LuaJIT and again under the engine's bundled PUC 5.1 build, with
# the input set hashed before and after and the two outputs compared byte for
# byte (docs/research/luanti-lua.md, "Interpreter and test strategy").
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
out="$repo/tools/wp13/evidence/20260916-polish/final-micro"
rm -rf -- "$out"
mkdir -p "$out"

inputs() {
	find mods/MAPGEN/grug_mapgen/wp13 mods/MAPGEN/grug_mapgen/wp40 tools/wp13 \
		-name '*.lua' -type f -print0 | sort -z | xargs -0 sha256sum
}
inputs >"$out/inputs-before.sha256"

luajit tools/wp13/final_micro.lua . "$out/micro-luajit.tsv" luajit \
	>"$out/micro-luajit.log" 2>&1
echo "luajit: $(cat "$out/micro-luajit.log")"
tools/bin/lua51 tools/wp13/final_micro.lua . "$out/micro-puc51.tsv" puc51 \
	>"$out/micro-puc51.log" 2>&1
echo "puc51:  $(cat "$out/micro-puc51.log")"

inputs >"$out/inputs-after.sha256"
if cmp -s "$out/inputs-before.sha256" "$out/inputs-after.sha256"; then
	echo "inputs immutable across the pair"
else
	echo "INPUTS MOVED DURING THE PAIR"
fi
if cmp -s "$out/micro-luajit.tsv" "$out/micro-puc51.tsv"; then
	echo "PAIR IDENTICAL: $(sha256sum <"$out/micro-luajit.tsv")"
else
	echo "PAIR DIFFERS"
	diff "$out/micro-luajit.tsv" "$out/micro-puc51.tsv" | head -20
fi
