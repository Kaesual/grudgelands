#!/usr/bin/env bash
# Round 84 SITE: site.lua over seeds and variants, each run one Lua process
# through the shared queue (about 45 s and 2 GB each).
#   tools/r84_site/run.sh <outdir> <parallel> "<variants>" <seed>...
# Then: python3 tools/r84_site/cmp.py <outdir> <variant> <seeds...>
#       python3 tools/r84_site/render.py <outdir> <seeds...>
set -uo pipefail
export LC_ALL=C
repo="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd -P)"
out="${1:?outdir}"; par="${2:?parallel}"; variants="${3:?variants}"; shift 3
queue="$HOME/projects/grudgelands-orchestration/r45/lua_run.sh"
mkdir -p "$out"
for seed in "$@"; do
	for v in $variants; do
		[[ -f "$out/$v-$seed/meta.tsv" ]] && continue
		echo "$seed $v"
	done
done | out="$out" queue="$queue" repo="$repo" xargs -P "$par" -L 1 sh -c '
	mkdir -p "$out/$2-$1"
	"$queue" r84-site 1 luajit "$repo/tools/r84_site/site.lua" "$repo" "$1" "$out/$2-$1" "$2" 8 \
		>"$out/$2-$1.log" 2>&1 || echo "FAIL $1 $2: $(tail -n 3 "$out/$2-$1.log")"
	tail -n 1 "$out/$2-$1.log"' _
