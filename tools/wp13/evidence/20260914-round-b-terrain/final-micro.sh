#!/usr/bin/env bash
# The frozen-byte WP13 micro-KAT pair: the same bytes once under LuaJIT and once
# under the engine's bundled PUC 5.1 build, byte-identical.
set -euo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd -P)"
out="$repo/tools/wp13/evidence/20260914-round-b-terrain/final-micro"
[[ ! -e "$out" ]] || { echo "final micro evidence exists" >&2; exit 2; }
mkdir -p "$out"
cd "$repo"
luajit tools/wp13/final_micro.lua "$repo" "$out/luajit.tsv" luajit \
	| tee "$out/luajit.log"
tools/bin/lua51 tools/wp13/final_micro.lua "$repo" "$out/puc51.tsv" puc51 \
	| tee "$out/puc51.log"
cmp "$out/luajit.tsv" "$out/puc51.tsv"
sha256sum "$out/luajit.tsv" "$out/puc51.tsv" >"$out/output.sha256"
echo "WP13 FINAL MICRO PAIR BYTE-IDENTICAL"
cat "$out/output.sha256"
