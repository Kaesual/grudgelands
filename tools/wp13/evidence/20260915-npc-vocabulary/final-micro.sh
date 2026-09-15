#!/usr/bin/env bash
# The one bounded final-byte process for this increment: every WP13 fixture in a
# single interpreter, once under LuaJIT and once under the engine's bundled PUC
# 5.1 build, with the inputs hashed before and after both runs
# (docs/research/luanti-lua.md, "Interpreter and test strategy").
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
cd "$repo"
here="tools/wp13/evidence/20260915-npc-vocabulary"
out="$here/final-micro"
rm -rf "$out"
mkdir -p "$out"

inputs() {
	find mods tools/wp13 tools/wp40 -name '*.lua' -print0 |
		sort -z | xargs -0 sha256sum | sha256sum
}

echo "inputs before: $(inputs)" | tee "$out/inputs.txt"
luajit tools/wp13/final_micro.lua . "$out/luajit.tsv" luajit |
	tee "$out/luajit.txt"
tools/bin/lua51 tools/wp13/final_micro.lua . "$out/puc51.tsv" puc51 |
	tee "$out/puc51.txt"
echo "inputs after:  $(inputs)" | tee -a "$out/inputs.txt"

if cmp -s "$out/luajit.tsv" "$out/puc51.tsv"; then
	echo "final micro pair byte-identical"
	sha256sum "$out/luajit.tsv" "$out/puc51.tsv"
else
	echo "FINAL MICRO PAIR DIFFERS"
	diff "$out/luajit.tsv" "$out/puc51.tsv"
	exit 1
fi
