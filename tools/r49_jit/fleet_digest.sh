#!/usr/bin/env bash
# Round 49 lane JIT: the written chunks of the seed fleet's quick seeds, one
# line each (tools/r49_jit/fleet_digest.lua), for comparing two trees.
#   tools/r49_jit/fleet_digest.sh TREE OUT [perturb]
# TREE: a checkout or export (its own seed fleet and mapgen run); OUT: the
# result file (the CHUNK and OK/FAIL lines, sorted; an OK line keeps the
# roster, chunk count and tree roll-up, not its seconds). JOBS=<n> parallel
# seeds (default 8; through the shared queue, take that many slots).
# COUNT=<n> seeds (default 100, the quick list). Compare two results with
# diff.
set -uo pipefail
export LC_ALL=C
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo="$(cd "$here/../.." && pwd -P)"
tree="$(cd "${1:?usage: fleet_digest.sh TREE OUT [perturb]}" && pwd -P)"
out="${2:?usage: fleet_digest.sh TREE OUT [perturb]}"
mode="${3:-}"
jobs="${JOBS:-8}"; count="${COUNT:-100}"
idle=()
command -v chrt >/dev/null && idle+=(chrt --idle 0)
work="$(mktemp -d /tmp/grug_r49_jit_digest.XXXXXX)"
grep -v '^#' "$repo/tools/seed_fleet/seeds.txt" | grep . | head -n "$count" >"$work/seeds"
export tree work mode here
xargs -a "$work/seeds" -P "$jobs" -I{} "${idle[@]}" sh -c \
	'luajit "$here/fleet_digest.lua" "$tree" "$1" $mode >"$work/$1.log" 2>&1' _ {}
# (the OK line without its CPU seconds, which differ between runs)
cat "$work"/*.log | grep -E '^(CHUNK|OK|FAIL)' |
	awk -F'\t' '$1 == "OK" { print $1, $2, $4, $5, $7; next } { print }' | sort >"$out"
echo "$(grep -c '^CHUNK' "$out") chunks, $(grep -c '^OK' "$out") seeds OK," \
	"$(grep -c '^FAIL' "$out") failed -> $out"
rm -rf "$work"
